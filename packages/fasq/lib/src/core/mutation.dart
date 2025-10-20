import 'dart:async';

import 'mutation_options.dart';
import 'mutation_state.dart';
import 'network_status.dart';
import 'offline_queue.dart';

class Mutation<T, TVariables> {
  final Future<T> Function(TVariables variables) mutationFn;
  final MutationOptions<T, TVariables>? options;

  MutationState<T> _currentState = const MutationState.idle();
  late final StreamController<MutationState<T>> _controller;
  bool _isDisposed = false;

  Mutation({
    required this.mutationFn,
    this.options,
  }) {
    _controller = StreamController<MutationState<T>>.broadcast();
  }

  Stream<MutationState<T>> get stream => _controller.stream;

  MutationState<T> get state => _currentState;

  bool get isDisposed => _isDisposed;

  Future<void> mutate(TVariables variables) async {
    if (_isDisposed) return;

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

    _updateState(const MutationState.loading());

    try {
      final data = await mutationFn(variables);

      if (!_isDisposed) {
        _updateState(MutationState.success(data));
        options?.onMutate?.call(data, variables);
        options?.onSuccess?.call(data);
      }
    } catch (error, stackTrace) {
      if (!_isDisposed) {
        _updateState(MutationState.error(error, stackTrace));
        options?.onError?.call(error);
      }
    }
  }

  String _getMutationType() {
    // Generate a unique mutation type based on the mutation function
    // In a real app, you'd want to register these explicitly
    return 'mutation_${mutationFn.hashCode}';
  }

  void reset() {
    if (_isDisposed) return;
    _updateState(const MutationState.idle());
  }

  void _updateState(MutationState<T> newState) {
    _currentState = newState;
    if (!_controller.isClosed) {
      _controller.add(newState);
    }
  }

  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _controller.close();
  }
}
