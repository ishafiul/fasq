import 'dart:async';

import 'package:fasq/src/client/query_client.dart';
import 'package:fasq/src/mutation/mutation_options.dart';
import 'package:fasq/src/mutation/mutation_snapshot.dart';
import 'package:fasq/src/mutation/mutation_state.dart';
import 'package:fasq/src/mutation/network_status.dart';

/// Executes and tracks a mutation with optional offline queueing.
class Mutation<T, TVariables> {
  /// Creates a mutation executor for [mutationFn] with optional [options].
  Mutation({
    required this.mutationFn,
    this.options,
  }) {
    _controller = StreamController<MutationState<T>>.broadcast();
    options?.validateDurableConfiguration();
    final durableQueue = options?.durableQueue;
    if (durableQueue != null) {
      durableQueue.queue.register<T, TVariables>(
        key: durableQueue.mutationKey,
        codec: durableQueue.codec,
        mutationFn: mutationFn,
        authPolicy: durableQueue.authPolicy,
      );
    }
  }

  /// Function that performs the mutation work.
  final Future<T> Function(TVariables variables) mutationFn;

  /// Optional mutation behavior and callbacks.
  final MutationOptions<T, TVariables>? options;

  MutationState<T> _currentState = const MutationState.idle();
  late final StreamController<MutationState<T>> _controller;
  bool _isDisposed = false;
  TVariables? _lastVariables;

  /// Broadcast stream of mutation state updates.
  Stream<MutationState<T>> get stream => _controller.stream;

  /// Current mutation state snapshot.
  MutationState<T> get state => _currentState;

  /// Whether this mutation instance has been disposed.
  bool get isDisposed => _isDisposed;

  /// Runs the mutation with [variables].
  ///
  /// When offline queueing is enabled and the device is offline, the mutation
  /// is queued instead of executed immediately.
  Future<void> mutate(TVariables variables) async {
    if (_isDisposed) return;

    final client = QueryClient.maybeInstance;

    final isOffline = !NetworkStatus.instance.isOnline;
    final shouldQueue = isOffline && (options?.queueWhenOffline ?? false);

    if (shouldQueue) {
      final durableQueue = options?.durableQueue;
      if (durableQueue == null) {
        throw StateError(
          'queueWhenOffline requires durable queue configuration',
        );
      }
      try {
        await durableQueue.queue.open();
        await durableQueue.queue.enqueue(
          key: durableQueue.mutationKey,
          variables: variables,
          authScope: durableQueue.authScope,
          priority: options?.priority ?? 0,
          maxAttempts: options?.maxRetries ?? 5,
        );
        _updateState(const MutationState.queued());
        options?.onQueued?.call(variables);
        return;
      } on Object catch (error, stackTrace) {
        if (!_isDisposed) {
          _updateState(MutationState.error(error, stackTrace));
          options?.onError?.call(error);
        }
        rethrow;
      }
    }

    _lastVariables = variables;

    final previousForLoading = _currentState;
    _updateState(const MutationState.loading());
    if (client != null) {
      final snapshot = _snapshot(previousForLoading);
      client.notifyMutationLoading(snapshot, options?.meta, null);
    }

    try {
      final data = await mutationFn(variables);

      if (!_isDisposed) {
        final previous = _currentState;
        _updateState(MutationState.success(data));
        options?.onMutate?.call(data, variables);
        options?.onSuccess?.call(data);
        if (client != null) {
          final snapshot = _snapshot(previous);
          client
            ..notifyMutationSuccess(snapshot, options?.meta, null)
            ..notifyMutationSettled(snapshot, options?.meta, null);
        }
      }
    } on Object catch (error, stackTrace) {
      if (!_isDisposed) {
        final previous = _currentState;
        _updateState(MutationState.error(error, stackTrace));
        options?.onError?.call(error);
        if (client != null) {
          final snapshot = _snapshot(previous);
          client
            ..notifyMutationError(snapshot, options?.meta, null)
            ..notifyMutationSettled(snapshot, options?.meta, null);
        }
      }
    }
  }

  /// Resets this mutation to the idle state.
  void reset() {
    if (_isDisposed) return;
    _lastVariables = null;
    _updateState(const MutationState.idle());
  }

  void _updateState(MutationState<T> newState) {
    _currentState = newState;
    if (!_controller.isClosed) {
      _controller.add(newState);
    }
  }

  MutationSnapshot<T, TVariables> _snapshot(
    MutationState<T> previousState,
  ) {
    return MutationSnapshot<T, TVariables>(
      previousState: previousState,
      currentState: _currentState,
      variables: _lastVariables,
      options: options,
    );
  }

  /// Variables passed to the most recent [mutate] call.
  TVariables? get lastVariables => _lastVariables;

  /// Disposes this mutation and closes its state stream.
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    unawaited(_controller.close());
  }
}
