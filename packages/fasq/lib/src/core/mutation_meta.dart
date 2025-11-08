import 'query_key.dart';

class MutationMeta {
  const MutationMeta({
    this.successMessage,
    this.errorMessage,
    this.invalidateKeys = const [],
    this.refetchKeys = const [],
    this.triggerCriticalHandler = false,
  });

  final String? successMessage;
  final String? errorMessage;
  final List<QueryKey> invalidateKeys;
  final List<QueryKey> refetchKeys;
  final bool triggerCriticalHandler;
}
