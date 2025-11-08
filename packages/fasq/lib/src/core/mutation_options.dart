import 'mutation_meta.dart';

class MutationOptions<T, TVariables> {
  final void Function(T data)? onSuccess;
  final void Function(Object error)? onError;
  final void Function(T data, TVariables variables)? onMutate;
  final bool queueWhenOffline;
  final int? maxRetries;
  final void Function(TVariables variables)? onQueued;
  final int priority; // Higher number = higher priority
  final MutationMeta? meta;

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
}
