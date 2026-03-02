import 'package:fasq/src/query/keys/query_key.dart';

/// Describes optional metadata for query lifecycle side effects.
///
/// This can be attached to queries to provide UI messages and control related
/// cache invalidation or refetch behavior after updates.
class QueryMeta {
  /// Creates metadata used by query and mutation notifications.
  const QueryMeta({
    this.successMessage,
    this.errorMessage,
    this.invalidateKeys = const [],
    this.refetchKeys = const [],
    this.triggerCriticalHandler = false,
  });

  /// Message shown when the operation succeeds.
  final String? successMessage;

  /// Message shown when the operation fails.
  final String? errorMessage;

  /// Query keys that should be invalidated after a successful operation.
  final List<QueryKey> invalidateKeys;

  /// Query keys that should be refetched after a successful operation.
  final List<QueryKey> refetchKeys;

  /// Whether the global critical error handler should be triggered on failure.
  final bool triggerCriticalHandler;
}
