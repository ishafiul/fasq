import 'package:fasq/src/mutation/mutation_meta.dart';
import 'package:fasq/src/mutation/mutation_options.dart';
import 'package:fasq/src/mutation/mutation_state.dart';

/// Snapshot of a mutation transition at a specific point in time.
class MutationSnapshot<TData, TVariables> {
  /// Creates a mutation snapshot from previous/current state and context.
  const MutationSnapshot({
    required this.previousState,
    required this.currentState,
    required this.variables,
    required this.options,
  });

  /// Mutation state before the latest transition.
  final MutationState<TData> previousState;

  /// Mutation state after the latest transition.
  final MutationState<TData> currentState;

  /// Variables used for the mutation, if provided.
  final TVariables? variables;

  /// Mutation options active during this transition.
  final MutationOptions<TData, TVariables>? options;

  /// Convenience access to metadata from [options], if present.
  MutationMeta? get meta => options?.meta;
}
