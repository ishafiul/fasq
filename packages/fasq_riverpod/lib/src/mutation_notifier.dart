import 'dart:async';

import 'package:fasq_riverpod/fasq_riverpod.dart';

class MutationNotifier<T, TVariables> extends StateNotifier<MutationState<T>> {
  late final Mutation<T, TVariables> _mutation;
  StreamSubscription<MutationState<T>>? _subscription;

  MutationNotifier({
    required Future<T> Function(TVariables variables) mutationFn,
    MutationOptions<T, TVariables>? options,
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
