import 'dart:async';

import 'package:fasq/src/core/mutation_options.dart';
import 'package:fasq/src/core/mutation_snapshot.dart';
import 'package:fasq/src/core/mutation_state.dart';
import 'package:fasq/src/core/network_status.dart';
import 'package:fasq/src/core/offline_queue.dart';
import 'package:fasq/src/core/query_client.dart';

/// Executes and tracks a mutation with optional offline queueing.
class Mutation<T, TVariables> {
  /// Creates a mutation executor for [mutationFn] with optional [options].
  Mutation({
    required this.mutationFn,
    this.options,
  }) {
    _controller = StreamController<MutationState<T>>.broadcast();
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
      final queueManager = OfflineQueueManager.instance;
      final mutationType = _getMutationType();

      await queueManager.enqueue(
        'mutation_${DateTime.now().millisecondsSinceEpoch}',
        mutationType,
        variables,
        priority: options?.priority ?? 0,
      );

      _updateState(const MutationState.queued());
      options?.onQueued?.call(variables);
      return;
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

  String _getMutationType() {
    // Generate a unique mutation type based on the mutation function
    // In a real app, you'd want to register these explicitly
    return 'mutation_${mutationFn.hashCode}';
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
