import 'package:fasq/src/mutation/durable_mutation_queue.dart';
import 'package:fasq/src/mutation/mutation_contract.dart';
import 'package:fasq/src/mutation/mutation_options.dart';
import 'package:fasq/src/mutation/sync_engine/conflict/conflict_policy.dart';
import 'package:fasq/src/mutation/sync_engine/mutation_contracts.dart';

/// Runtime registration contract for one durable mutation.
///
/// Implementations are registered before the durable outbox opens so replay
/// can resolve the same executor used by immediate mutations.
abstract interface class DurableMutationDefinitionBase {
  /// Stable type-erased key used for catalog lookup and durable persistence.
  MutationKey get key;

  /// Registers this definition with [queue].
  void register(DurableMutationQueue queue);
}

/// Low-level durable mutation registration contract.
///
/// Use the higher-level `DurableMutation` handle for new application code.
/// This type remains public for advanced queue composition and compatibility
/// with earlier setup APIs.
class DurableMutationDefinition<TData, TVariables>
    implements DurableMutationDefinitionBase {
  /// Creates a low-level durable mutation definition.
  const DurableMutationDefinition({
    required this.contractKey,
    required this.codec,
    required this.execute,
    this.authPolicy = AuthPolicy.none,
    this.resultEncoder,
    this.dependencies =
        const <FasqMutationDependency<Object?, Object?, Object?, Object?>>[],
  });

  /// Compile-time typed mutation identity.
  final FasqMutationKey<TData, TVariables> contractKey;

  /// Stable type-erased identity used by durable storage.
  @override
  MutationKey get key => contractKey.runtimeKey;

  /// JSON-safe variables codec.
  final MutationCodec<TVariables> codec;

  /// Immediate and replay executor.
  final Future<TData> Function(TVariables variables) execute;

  /// Auth requirement for queued work.
  final AuthPolicy authPolicy;

  /// Optional JSON-safe result projection for dependent operations.
  final Object? Function(TData data)? resultEncoder;

  /// Producer-result to current-input dependency mappings.
  final List<FasqMutationDependency<Object?, Object?, Object?, Object?>>
  dependencies;

  /// Binds this bootstrapped definition to [queue] for widget execution.
  MutationOptions<TData, TVariables> bind(
    DurableMutationQueue queue, {
    MutationOptions<TData, TVariables>? base,
  }) {
    return MutationOptions<TData, TVariables>(
      onSuccess: base?.onSuccess,
      onError: base?.onError,
      onMutate: base?.onMutate,
      queueWhenOffline: true,
      durableQueue: DurableMutationQueueOptions<TVariables>(
        queue: queue,
        mutationKey: key,
        codec: codec,
        authPolicy: authPolicy,
        authScope: base?.durableQueue?.authScope,
        conflictPolicy:
            base?.durableQueue?.conflictPolicy ?? ConflictPolicy.none,
        conflictPrecondition: base?.durableQueue?.conflictPrecondition,
        writeAhead: true,
        dependencies: dependencies,
      ),
      resultEncoder: base?.resultEncoder ?? resultEncoder,
      projectionPlan: base?.projectionPlan,
      projectionBuilder: base?.projectionBuilder,
      maxRetries: base?.maxRetries,
      onQueued: base?.onQueued,
      priority: base?.priority ?? 0,
      meta: base?.meta,
    );
  }

  @override
  void register(DurableMutationQueue queue) {
    queue.register<TData, TVariables>(
      key: key,
      codec: codec,
      mutationFn: execute,
      authPolicy: authPolicy,
      resultEncoder: resultEncoder,
      dependencies: dependencies,
    );
  }
}
