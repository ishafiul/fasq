import 'package:fasq/src/query/keys/query_key.dart';

/// Metadata for mutation side effects and user-facing messages.
class MutationMeta {
  /// Creates metadata that controls invalidation/refetch behavior and messages.
  const MutationMeta({
    this.successMessage,
    this.errorMessage,
    this.invalidateKeys = const [],
    this.refetchKeys = const [],
    this.triggerCriticalHandler = false,
  });

  /// Optional message shown when the mutation succeeds.
  final String? successMessage;

  /// Optional message shown when the mutation fails.
  final String? errorMessage;

  /// Query keys to invalidate after mutation completion.
  final List<QueryKey> invalidateKeys;

  /// Query keys to refetch after mutation completion.
  final List<QueryKey> refetchKeys;

  /// Whether to trigger the global critical-error handler on failure.
  final bool triggerCriticalHandler;
}
