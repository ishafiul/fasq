import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_query/flutter_query.dart';
import 'mutation_notifier.dart';

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

