import 'package:fasq/src/mutation/durable_mutation_queue.dart';
import 'package:fasq/src/mutation/mutation_contract.dart';
import 'package:fasq/src/mutation/mutation_meta.dart';
import 'package:fasq/src/mutation/sync_engine/conflict/conflict_policy.dart';
import 'package:fasq/src/mutation/sync_engine/mutation_contracts.dart';
import 'package:fasq/src/mutation/sync_engine/projection/projection.dart';
import 'package:meta/meta.dart';

/// Configuration required to persist and replay a mutation after restart.
///
/// The key identifies the logical mutation definition. The codec keeps the
/// queued variables JSON-safe and reconstructs their typed value before the
/// registered mutation executor runs.
@immutable
class DurableMutationQueueOptions<TVariables> {
  /// Creates durable queue configuration for a mutation.
  const DurableMutationQueueOptions({
    required this.queue,
    required this.mutationKey,
    required this.codec,
    this.authPolicy = AuthPolicy.none,
    this.authScope,
    this.conflictPolicy = ConflictPolicy.none,
    this.conflictPrecondition,
    this.writeAhead = false,
    this.dependencies =
        const <FasqMutationDependency<Object?, Object?, Object?, Object?>>[],
  });

  /// Durable queue used to persist and replay this mutation.
  final DurableMutationQueue queue;

  /// Stable, versioned identity for the logical mutation definition.
  final MutationKey mutationKey;

  /// Typed codec for the persisted mutation variables.
  final MutationCodec<TVariables> codec;

  /// Authentication requirement captured with each queued operation.
  final AuthPolicy authPolicy;

  /// Exact non-secret identity captured with each authenticated operation.
  final AuthScope? authScope;

  /// Explicit stale-write policy captured with queued operations.
  final ConflictPolicy conflictPolicy;

  /// Opaque compare-and-set token captured with queued operations.
  final ConflictPrecondition? conflictPrecondition;

  /// Whether every invocation is durably committed before execution.
  final bool writeAhead;

  /// Typed producer-result to current-input mappings.
  final List<FasqMutationDependency<Object?, Object?, Object?, Object?>>
  dependencies;
}

/// Configuration options for mutation behavior and lifecycle callbacks.
class MutationOptions<T, TVariables> {
  /// Creates mutation options.
  const MutationOptions({
    this.onSuccess,
    this.onError,
    this.onMutate,
    this.queueWhenOffline = false,
    this.durableQueue,
    this.resultEncoder,
    this.projectionPlan,
    this.projectionBuilder,
    this.maxRetries,
    this.onQueued,
    this.priority = 0,
    this.meta,
  }) : assert(
         !queueWhenOffline || durableQueue != null,
         'queueWhenOffline requires durableQueue configuration',
       );

  /// Called when the mutation succeeds.
  final void Function(T data)? onSuccess;

  /// Called when the mutation fails.
  final void Function(Object error)? onError;

  /// Called before execution to observe mutation variables and current data.
  final void Function(T data, TVariables variables)? onMutate;

  /// Whether to queue this mutation when offline.
  final bool queueWhenOffline;

  /// Stable identity, typed codec, and auth policy for durable queueing.
  ///
  /// This must be provided when [queueWhenOffline] is true. It is ignored for
  /// online-only mutations and does not change immediate execution behavior.
  final DurableMutationQueueOptions<TVariables>? durableQueue;

  /// Encodes mutation results for durable replay history.
  final Object? Function(T data)? resultEncoder;

  /// Serializable projection plan applied when offline work is queued.
  final ProjectionPlan? projectionPlan;

  /// Builds a runtime overlay from the acknowledged operation identity.
  final ProjectionOverlay Function(
    OperationId operationId,
    LineageId lineageId,
    TVariables variables,
  )?
  projectionBuilder;

  /// Stable logical identity for this mutation, if durable queueing is enabled.
  MutationKey? get mutationKey => durableQueue?.mutationKey;

  /// Typed variable codec, if durable queueing is enabled.
  MutationCodec<TVariables>? get codec => durableQueue?.codec;

  /// Authentication policy for queued operations.
  AuthPolicy get authPolicy => durableQueue?.authPolicy ?? AuthPolicy.none;

  /// Validates the durable queue contract at a runtime integration boundary.
  ///
  /// The constructor assertion catches invalid configuration in debug builds;
  /// this method keeps the same rejection behavior when assertions are off.
  void validateDurableConfiguration() {
    if (queueWhenOffline && durableQueue == null) {
      throw ArgumentError(
        'queueWhenOffline requires durableQueue configuration',
      );
    }
    if (projectionBuilder != null && projectionPlan == null) {
      throw ArgumentError(
        'projectionBuilder requires projectionPlan configuration',
      );
    }
    final durableQueueOptions = durableQueue;
    durableQueueOptions?.conflictPolicy.validate(
      durableQueueOptions.conflictPrecondition,
    );
  }

  /// Maximum retry attempts for failed mutations.
  final int? maxRetries;

  /// Called when a mutation is queued instead of executed immediately.
  final void Function(TVariables variables)? onQueued;

  /// Priority used for queue ordering. Higher values are processed first.
  final int priority; // Higher number = higher priority

  /// Optional metadata for side effects and user-facing messages.
  final MutationMeta? meta;
}
