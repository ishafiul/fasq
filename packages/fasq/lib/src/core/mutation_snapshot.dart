import 'mutation_meta.dart';
import 'mutation_options.dart';
import 'mutation_state.dart';

class MutationSnapshot<TData, TVariables> {
  const MutationSnapshot({
    required this.previousState,
    required this.currentState,
    required this.variables,
    required this.options,
  });

  final MutationState<TData> previousState;
  final MutationState<TData> currentState;
  final TVariables? variables;
  final MutationOptions<TData, TVariables>? options;

  MutationMeta? get meta => options?.meta;
}
