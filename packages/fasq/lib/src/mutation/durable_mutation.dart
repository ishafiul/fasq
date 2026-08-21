import 'package:fasq/src/mutation/durable_mutation_definition.dart';
import 'package:fasq/src/mutation/durable_mutation_queue.dart';
import 'package:fasq/src/mutation/mutation_options.dart';
import 'package:fasq/src/mutation/sync_engine/conflict/conflict_policy.dart';
import 'package:fasq/src/mutation/sync_engine/mutation_contracts.dart';

/// One durable mutation handle shared by immediate execution and replay.
///
/// Use [DurableMutation.define] when code generation is not a fit. The handle
/// owns the mutation identity and codec, so widgets do not need to know about
/// queue registration or outbox configuration.
class DurableMutation<TData, TVariables>
    extends DurableMutationDefinition<TData, TVariables> {
  /// Defines a durable mutation using a readable dot-separated key.
  factory DurableMutation.define({
    required String key,
    required MutationCodec<TVariables> codec,
    required Future<TData> Function(TVariables variables) execute,
    int version = 1,
    AuthPolicy authPolicy = AuthPolicy.none,
    Object? Function(TData data)? resultEncoder,
  }) {
    return DurableMutation._(
      key: _parseKey(key, version),
      codec: codec,
      execute: execute,
      authPolicy: authPolicy,
      resultEncoder: resultEncoder,
    );
  }

  const DurableMutation._({
    required super.key,
    required super.codec,
    required super.execute,
    super.authPolicy,
    super.resultEncoder,
  });

  /// Binds this handle to an initialized durable queue.
  ///
  /// [base] may contain normal mutation callbacks and UI metadata. Queue
  /// details are supplied by this handle and cannot drift from the replay
  /// registration.
  MutationOptions<TData, TVariables> bind(
    DurableMutationQueue queue, {
    MutationOptions<TData, TVariables>? base,
  }) {
    final baseOptions = base;
    return MutationOptions<TData, TVariables>(
      onSuccess: baseOptions?.onSuccess,
      onError: baseOptions?.onError,
      onMutate: baseOptions?.onMutate,
      queueWhenOffline: true,
      durableQueue: DurableMutationQueueOptions<TVariables>(
        queue: queue,
        mutationKey: key,
        codec: codec,
        authPolicy: authPolicy,
        authScope: baseOptions?.durableQueue?.authScope,
        conflictPolicy:
            baseOptions?.durableQueue?.conflictPolicy ?? ConflictPolicy.none,
        conflictPrecondition: baseOptions?.durableQueue?.conflictPrecondition,
      ),
      resultEncoder: baseOptions?.resultEncoder ?? resultEncoder,
      projectionPlan: baseOptions?.projectionPlan,
      projectionBuilder: baseOptions?.projectionBuilder,
      maxRetries: baseOptions?.maxRetries,
      onQueued: baseOptions?.onQueued,
      priority: baseOptions?.priority ?? 0,
      meta: baseOptions?.meta,
    );
  }

  static MutationKey _parseKey(String value, int version) {
    final normalized = value.trim();
    final separator = normalized.lastIndexOf('.');
    if (separator <= 0 || separator == normalized.length - 1) {
      throw ArgumentError.value(
        value,
        'key',
        'must contain a namespace and name separated by a dot',
      );
    }
    return MutationKey(
      namespace: normalized.substring(0, separator),
      name: normalized.substring(separator + 1),
      version: version,
    );
  }
}
