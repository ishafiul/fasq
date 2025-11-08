import 'query_key.dart';

class MutationMeta {
  const MutationMeta({
    this.successMessageId,
    this.errorMessageId,
    this.invalidateKeys = const [],
    this.refetchKeys = const [],
    this.triggerCriticalHandler = false,
  });

  final String? successMessageId;
  final String? errorMessageId;
  final List<QueryKey> invalidateKeys;
  final List<QueryKey> refetchKeys;
  final bool triggerCriticalHandler;
}
