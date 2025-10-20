import 'package:fasq_riverpod/fasq_riverpod.dart';

StateNotifierProvider<MutationNotifier<T, TVariables>, MutationState<T>>
    mutationProvider<T, TVariables>(
  Future<T> Function(TVariables variables) mutationFn, {
  MutationOptions<T, TVariables>? options,
}) {
  return StateNotifierProvider<MutationNotifier<T, TVariables>,
      MutationState<T>>((ref) {
    return MutationNotifier<T, TVariables>(
      mutationFn: mutationFn,
      options: options,
    );
  });
}
