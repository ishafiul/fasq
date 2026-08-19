// Background and readiness adapters are deliberate substitution boundaries.
// ignore_for_file: one_member_abstracts

import 'dart:async';

import 'package:fasq/src/mutation/network_status.dart';
import 'package:fasq/src/mutation/sync_engine/execution/auth_session.dart';
import 'package:fasq/src/mutation/sync_engine/replay/replay_coordinator.dart';

/// Source of a replay request.
enum ReplayLifecycleTrigger {
  /// Store and registrations completed startup.
  startup,

  /// Connectivity changed from offline to online.
  reconnect,

  /// Application returned to foreground.
  foreground,

  /// Authentication scope or readiness changed.
  authentication,

  /// Platform requested a best-effort background wake-up.
  background,
}

/// Readiness barrier required before lifecycle-triggered replay.
class ReplayReadiness {
  /// Creates a readiness snapshot.
  const ReplayReadiness({
    this.storeReady = false,
    this.registrationsReady = false,
    this.encryptionReady = false,
    this.connectivityReady = false,
    this.authReady = false,
  });

  /// Whether durable state loaded and validated.
  final bool storeReady;

  /// Whether mutation codecs and executors are registered.
  final bool registrationsReady;

  /// Whether required encryption material is available.
  final bool encryptionReady;

  /// Whether connectivity permits network work.
  final bool connectivityReady;

  /// Whether the current authentication state has been resolved.
  final bool authReady;

  /// Whether every required readiness condition is met.
  bool get isReady =>
      storeReady &&
      registrationsReady &&
      encryptionReady &&
      connectivityReady &&
      authReady;

  /// Returns a changed readiness snapshot.
  ReplayReadiness copyWith({
    bool? storeReady,
    bool? registrationsReady,
    bool? encryptionReady,
    bool? connectivityReady,
    bool? authReady,
  }) {
    return ReplayReadiness(
      storeReady: storeReady ?? this.storeReady,
      registrationsReady: registrationsReady ?? this.registrationsReady,
      encryptionReady: encryptionReady ?? this.encryptionReady,
      connectivityReady: connectivityReady ?? this.connectivityReady,
      authReady: authReady ?? this.authReady,
    );
  }
}

/// Mutable readiness barrier with observable state.
class ReplayReadinessBarrier {
  /// Creates a barrier.
  ReplayReadinessBarrier({ReplayReadiness initial = const ReplayReadiness()})
    : _current = initial;

  final StreamController<ReplayReadiness> _controller =
      StreamController<ReplayReadiness>.broadcast();
  ReplayReadiness _current;

  /// Current readiness state.
  ReplayReadiness get current => _current;

  /// Readiness changes.
  Stream<ReplayReadiness> get changes => _controller.stream;

  /// Updates readiness atomically.
  void update({
    bool? storeReady,
    bool? registrationsReady,
    bool? encryptionReady,
    bool? connectivityReady,
    bool? authReady,
  }) {
    _current = _current.copyWith(
      storeReady: storeReady,
      registrationsReady: registrationsReady,
      encryptionReady: encryptionReady,
      connectivityReady: connectivityReady,
      authReady: authReady,
    );
    if (!_controller.isClosed) _controller.add(_current);
  }

  /// Closes the readiness stream.
  Future<void> dispose() => _controller.close();
}

/// Platform boundary for best-effort background wake-up requests.
abstract interface class BackgroundReplayAdapter {
  /// Requests a wake-up; no guarantee of process execution is implied.
  Future<void> requestWakeUp(BackgroundReplayRequest request);
}

/// Safe metadata supplied to a background scheduling adapter.
class BackgroundReplayRequest {
  /// Creates a background request.
  const BackgroundReplayRequest({required this.requestedAt});

  /// Time at which the request was issued.
  final DateTime requestedAt;
}

/// Debounced, single-flight bridge from lifecycle signals to replay.
class ReplayLifecycleController {
  /// Creates a lifecycle controller.
  ReplayLifecycleController({
    required ReplayReadinessBarrier readiness,
    required Future<ReplayRunResult> Function() replay,
    AuthSessionProvider? authSessionProvider,
    NetworkStatus? networkStatus,
    this.backgroundAdapter,
    Duration debounce = Duration.zero,
    DateTime Function()? now,
    Future<void> Function(Duration duration)? delay,
    void Function(Object error, StackTrace stackTrace)? onReplayError,
  }) : _readiness = readiness,
       _replay = replay,
       _debounce = debounce,
       _now = now ?? DateTime.now,
       _delay = delay ?? _defaultReplayDelay,
       _onReplayError = onReplayError {
    _readinessSubscription = _readiness.changes.listen(_onReadinessChanged);
    final resolvedNetworkStatus = networkStatus ?? NetworkStatus.instance;
    _networkSubscription = resolvedNetworkStatus.stream.listen(
      _onConnectivityChanged,
    );
    _readiness.update(connectivityReady: resolvedNetworkStatus.isOnline);
    if (authSessionProvider != null) {
      _authSubscription = authSessionProvider.changes.listen(_onAuthChanged);
      unawaited(_resolveInitialAuth(authSessionProvider));
    }
  }

  final ReplayReadinessBarrier _readiness;
  final Future<ReplayRunResult> Function() _replay;
  final Duration _debounce;
  final DateTime Function() _now;
  final Future<void> Function(Duration duration) _delay;
  final void Function(Object error, StackTrace stackTrace)? _onReplayError;
  StreamSubscription<ReplayReadiness>? _readinessSubscription;
  StreamSubscription<bool>? _networkSubscription;
  StreamSubscription<AuthSessionSnapshot>? _authSubscription;
  Future<ReplayRunResult?>? _inFlight;
  Completer<ReplayRunResult?>? _debouncedRequest;
  Completer<ReplayRunResult?>? _readinessRequest;
  ReplayLifecycleTrigger? _pendingTrigger;
  bool _isClosed = false;

  /// Optional platform background wake-up adapter.
  final BackgroundReplayAdapter? backgroundAdapter;

  /// Requests replay for a lifecycle signal.
  Future<ReplayRunResult?> request(ReplayLifecycleTrigger trigger) {
    if (_isClosed) return Future<ReplayRunResult?>.value();
    if (trigger == ReplayLifecycleTrigger.background) {
      return _requestBackgroundWakeUp();
    }
    if (!_readiness.current.isReady) {
      _pendingTrigger ??= trigger;
      return (_readinessRequest ??= Completer<ReplayRunResult?>()).future;
    }
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;
    if (_debounce == Duration.zero) return _runReplay();

    final pending = _debouncedRequest;
    if (pending != null) return pending.future;
    final completer = Completer<ReplayRunResult?>();
    _debouncedRequest = completer;
    unawaited(_runDebouncedReplay(completer));
    return completer.future;
  }

  /// Convenience startup trigger.
  Future<ReplayRunResult?> onStartup() =>
      request(ReplayLifecycleTrigger.startup);

  /// Convenience reconnect trigger.
  Future<ReplayRunResult?> onReconnect() =>
      request(ReplayLifecycleTrigger.reconnect);

  /// Convenience foreground trigger.
  Future<ReplayRunResult?> onForeground() =>
      request(ReplayLifecycleTrigger.foreground);

  /// Convenience authentication trigger.
  Future<ReplayRunResult?> onAuthentication() =>
      request(ReplayLifecycleTrigger.authentication);

  /// Cancels pending debounce work and rejects future requests.
  Future<void> dispose() async {
    _isClosed = true;
    final pending = _debouncedRequest;
    _debouncedRequest = null;
    if (pending != null && !pending.isCompleted) pending.complete(null);
    final readinessRequest = _readinessRequest;
    _readinessRequest = null;
    _pendingTrigger = null;
    if (readinessRequest != null && !readinessRequest.isCompleted) {
      readinessRequest.complete(null);
    }
    await _readinessSubscription?.cancel();
    await _networkSubscription?.cancel();
    await _authSubscription?.cancel();
  }

  Future<ReplayRunResult?> _runReplay() {
    final current = _inFlight;
    if (current != null) return current;
    final future = _replay().then<ReplayRunResult?>((result) => result);
    _inFlight = future;
    unawaited(
      future.then<void>(
        (_) => _clearInFlight(future),
        onError: (Object error, StackTrace stackTrace) {
          _clearInFlight(future);
          _reportReplayError(error, stackTrace);
        },
      ),
    );
    return future;
  }

  Future<ReplayRunResult?> _requestBackgroundWakeUp() async {
    final adapter = backgroundAdapter;
    if (adapter == null || !_readiness.current.isReady) return null;
    await adapter.requestWakeUp(BackgroundReplayRequest(requestedAt: _now()));
    return null;
  }

  Future<void> _runDebouncedReplay(
    Completer<ReplayRunResult?> completer,
  ) async {
    await _delay(_debounce);
    if (_isClosed || !identical(_debouncedRequest, completer)) return;
    _debouncedRequest = null;
    try {
      completer.complete(await _runReplay());
    } on Object catch (error, stackTrace) {
      completer.completeError(error, stackTrace);
    }
  }

  void _onReadinessChanged(ReplayReadiness readiness) {
    if (!readiness.isReady) return;
    final pending = _readinessRequest;
    if (pending != null) {
      _readinessRequest = null;
      final trigger = _pendingTrigger ?? ReplayLifecycleTrigger.startup;
      _pendingTrigger = null;
      _completePendingRequest(pending, trigger);
      return;
    }
    _scheduleAutomaticReplay(ReplayLifecycleTrigger.startup);
  }

  void _onConnectivityChanged(bool isOnline) {
    _readiness.update(connectivityReady: isOnline);
    if (isOnline) {
      _scheduleAutomaticReplay(ReplayLifecycleTrigger.reconnect);
    }
  }

  void _onAuthChanged(AuthSessionSnapshot session) {
    _readiness.update(
      authReady: session.status != AuthSessionStatus.unknown,
    );
    if (session.status != AuthSessionStatus.unknown) {
      _scheduleAutomaticReplay(ReplayLifecycleTrigger.authentication);
    }
  }

  Future<void> _resolveInitialAuth(AuthSessionProvider provider) async {
    try {
      _onAuthChanged(await provider.currentSession());
    } on Object catch (error, stackTrace) {
      _reportReplayError(error, stackTrace);
    }
  }

  void _scheduleAutomaticReplay(ReplayLifecycleTrigger trigger) {
    unawaited(
      request(trigger).then<void>(
        (_) {},
        onError: (Object error, StackTrace stackTrace) {
          _reportReplayError(error, stackTrace);
        },
      ),
    );
  }

  void _completePendingRequest(
    Completer<ReplayRunResult?> completer,
    ReplayLifecycleTrigger trigger,
  ) {
    unawaited(
      request(trigger).then<void>(
        completer.complete,
        onError: completer.completeError,
      ),
    );
  }

  void _clearInFlight(Future<ReplayRunResult?> future) {
    if (identical(_inFlight, future)) _inFlight = null;
  }

  void _reportReplayError(Object error, StackTrace stackTrace) {
    try {
      _onReplayError?.call(error, stackTrace);
    } on Object {
      // Error observers must not create a second unhandled replay failure.
    }
  }
}

Future<void> _defaultReplayDelay(Duration duration) => Future<void>.delayed(
  duration,
);
