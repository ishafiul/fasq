import 'package:fasq/src/mutation/mutation_meta.dart';

/// Configuration options for mutation behavior and lifecycle callbacks.
class MutationOptions<T, TVariables> {
  /// Creates mutation options.
  const MutationOptions({
    this.onSuccess,
    this.onError,
    this.onMutate,
    this.queueWhenOffline = false,
    this.maxRetries,
    this.onQueued,
    this.priority = 0,
    this.meta,
  });

  /// Called when the mutation succeeds.
  final void Function(T data)? onSuccess;

  /// Called when the mutation fails.
  final void Function(Object error)? onError;

  /// Called before execution to observe mutation variables and current data.
  final void Function(T data, TVariables variables)? onMutate;

  /// Whether to queue this mutation when offline.
  final bool queueWhenOffline;

  /// Maximum retry attempts for failed mutations.
  final int? maxRetries;

  /// Called when a mutation is queued instead of executed immediately.
  final void Function(TVariables variables)? onQueued;

  /// Priority used for queue ordering. Higher values are processed first.
  final int priority; // Higher number = higher priority

  /// Optional metadata for side effects and user-facing messages.
  final MutationMeta? meta;
}
