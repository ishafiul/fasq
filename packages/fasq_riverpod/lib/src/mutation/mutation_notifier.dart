import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/client_provider.dart';

/// Riverpod-native adapter for a core [Mutation].
///
/// Both immediate functions and typed durable [FasqMutationKey] contracts are
/// supported. The notifier exposes the core mutation and its full submission
/// receipt, including the opaque local reference created for queued work.
class MutationNotifier<T, TVariables>
    extends AutoDisposeNotifier<MutationState<T>> {
  Future<T> Function(TVariables variables)? _mutationFn;
  FasqMutationKey<T, TVariables>? _mutationKey;
  MutationOptions<T, TVariables>? _options;
  QueryClient? _providedClient;
  FasqRuntime? _providedRuntime;

  Mutation<T, TVariables>? _mutation;
  QueryClient? _resolvedQueryClient;
  FasqRuntime? _resolvedRuntime;
  StreamSubscription<MutationState<T>>? _subscription;
  var _cleanedUp = false;

  /// Initializes the notifier with an immediate or durable mutation.
  void configure({
    Future<T> Function(TVariables variables)? mutationFn,
    FasqMutationKey<T, TVariables>? mutationKey,
    MutationOptions<T, TVariables>? options,
    QueryClient? client,
    FasqRuntime? runtime,
  }) {
    _mutationFn = mutationFn;
    _mutationKey = mutationKey;
    _options = options;
    _providedClient = client;
    _providedRuntime = runtime;
  }

  /// The client that owns mutation lifecycle notifications.
  QueryClient get queryClient {
    final existing = _resolvedQueryClient;
    if (existing != null) return existing;
    final resolved =
        _providedClient ??
        _providedRuntime?.queryClient ??
        _resolvedRuntime?.queryClient ??
        ref.read(fasqClientProvider);
    _resolvedQueryClient = resolved;
    return resolved!;
  }

  /// Explicit client supplied to this provider, if any.
  QueryClient? get client => _providedClient ?? _providedRuntime?.queryClient;

  /// The runtime explicitly or implicitly supplied to this adapter.
  FasqRuntime? get runtime => _resolvedRuntime ?? _providedRuntime;

  /// The underlying core mutation.
  Mutation<T, TVariables> get mutation {
    final value = _mutation;
    if (value == null) {
      throw StateError('The MutationNotifier has not been initialized.');
    }
    return value;
  }

  /// Variables passed to the latest submission.
  TVariables? get lastVariables => mutation.lastVariables;

  /// Whether the underlying mutation has been disposed.
  bool get isDisposed => mutation.isDisposed;

  /// Whether the mutation is currently loading.
  bool get isLoading => state.isLoading;

  /// Whether the mutation is durably queued.
  bool get isQueued => state.isQueued;

  /// Whether the mutation succeeded.
  bool get isSuccess => state.isSuccess;

  /// Whether the mutation failed.
  bool get isError => state.isError;

  /// Whether the mutation is idle.
  bool get isIdle => state.isIdle;

  /// Whether successful data exists.
  bool get hasData => state.hasData;

  /// Whether an error exists.
  bool get hasError => state.hasError;

  /// Latest mutation data.
  T? get data => state.data;

  /// Latest mutation error.
  Object? get error => state.error;

  /// Latest mutation stack trace.
  StackTrace? get stackTrace => state.stackTrace;

  @override
  MutationState<T> build() {
    _cleanupMutation();
    _cleanedUp = false;
    final keepAlive = ref.keepAlive();
    ref.onCancel(keepAlive.close);

    final configuredRuntime =
        _providedRuntime ?? ref.watch(fasqRuntimeProvider);
    final QueryClient configuredClient =
        _providedClient ??
        configuredRuntime?.queryClient ??
        ref.watch(fasqClientProvider);
    _resolvedRuntime = configuredRuntime;
    _resolvedQueryClient = configuredClient;

    final mutationKey = _mutationKey;
    final mutationFn = _mutationFn;
    if ((mutationKey == null) == (mutationFn == null)) {
      throw StateError(
        'MutationNotifier requires exactly one of mutationFn or mutationKey.',
      );
    }

    final configuredMutation = mutationKey == null
        ? MutationFactory.fromFunction<T, TVariables>(
            mutationFn: mutationFn!,
            options: _options,
            client: configuredClient,
          )
        : _createDurableMutation(
            mutationKey,
            configuredRuntime,
            configuredClient,
          );
    _mutation = configuredMutation;
    ref.onDispose(_cleanup);
    _subscription = configuredMutation.stream.listen((nextState) {
      if (!_cleanedUp) state = nextState;
    });
    return configuredMutation.state;
  }

  Mutation<T, TVariables> _createDurableMutation(
    FasqMutationKey<T, TVariables> mutationKey,
    FasqRuntime? configuredRuntime,
    QueryClient configuredClient,
  ) {
    final runtime = configuredRuntime;
    if (runtime == null) {
      throw StateError('Mutation ${mutationKey.value} requires a FasqRuntime.');
    }
    final queue = runtime.mutationQueue;
    if (queue == null) {
      throw StateError(
        'Mutation ${mutationKey.value} requires a runtime with a durable queue.',
      );
    }
    return MutationFactory.fromKey<T, TVariables>(
      key: mutationKey,
      catalog: runtime.mutations,
      queue: queue,
      options: _options,
      client: configuredClient,
    );
  }

  /// Submits a mutation and returns its complete core receipt.
  Future<MutationSubmission<T>> submit(TVariables variables) async {
    final submission = await mutation.submit(variables);
    if (!_cleanedUp) state = mutation.state;
    return submission;
  }

  /// Backward-compatible imperative mutation method.
  ///
  /// The return type is now the core submission receipt; callers that only
  /// await completion remain source-compatible, while durable callers can
  /// inspect [MutationSubmission.localReference] and its outcome.
  Future<MutationSubmission<T>> mutate(TVariables variables) {
    return submit(variables);
  }

  /// Resets the mutation to idle.
  void reset() {
    mutation.reset();
    if (!_cleanedUp) state = mutation.state;
  }

  void _cleanupMutation() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    _mutation?.dispose();
    _mutation = null;
  }

  void _cleanup() {
    if (_cleanedUp) return;
    _cleanedUp = true;
    _cleanupMutation();
  }
}
