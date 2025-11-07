import 'dart:async';

import 'package:fasq_riverpod/fasq_riverpod.dart';

/// Wraps a FASQ [Mutation] in a Riverpod [StateNotifier].
///
/// Keeps mutation state in sync with widgets and exposes simple mutate/reset
/// helpers for consumers.
class MutationNotifier<T, TVariables> extends StateNotifier<MutationState<T>> {
  late final Mutation<T, TVariables> _mutation;
  StreamSubscription<MutationState<T>>? _subscription;

  MutationNotifier({
    required Future<T> Function(TVariables variables) mutationFn,
    MutationOptions<T, TVariables>? options,
    QueryClient? client,
  }) : super(const MutationState.idle()) {
    _mutation = Mutation<T, TVariables>(
      mutationFn: mutationFn,
      options: options,
    );

    _subscription = _mutation.stream.listen((newState) {
      if (mounted) {
        state = newState;
      }
    });
  }

  Future<void> mutate(TVariables variables) async {
    await _mutation.mutate(variables);
  }

  void reset() {
    _mutation.reset();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _mutation.dispose();
    super.dispose();
  }
}
