import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'use_query_client.dart';

/// Observes and controls the durable queue exposed by the nearest runtime.
UseMutationQueueResult useMutationQueue({DurableOperationFilter? filter}) {
  final runtime = useFasqRuntime();
  final queue = runtime.mutationQueue;
  if (queue == null) {
    throw StateError(
      'useMutationQueue requires OfflineSync to be configured in Fasq.',
    );
  }
  final observation = useState<DurableQueueObservation>(queue.observation);

  useEffect(() {
    observation.value = queue.observation;
    final subscription = queue.watch(filter: filter).listen((nextObservation) {
      observation.value = nextObservation;
    });
    return () => unawaited(subscription.cancel());
  }, [queue, filter]);

  return UseMutationQueueResult(queue: queue, observation: observation.value);
}

/// Reactive queue observation plus the complete durable queue command surface.
class UseMutationQueueResult {
  /// Creates a queue result.
  const UseMutationQueueResult({
    required this.queue,
    required this.observation,
  });

  /// Underlying core queue for advanced APIs.
  final DurableMutationQueue queue;

  /// Current filtered public-safe observation.
  final DurableQueueObservation observation;

  /// Current persisted outbox snapshot.
  OutboxSnapshot get snapshot => queue.snapshot;

  /// Whether the durable outbox is open.
  bool get isOpen => queue.isOpen;

  /// Whether the configured connectivity source reports online.
  bool get isOnline => queue.isOnline;

  /// Current durable-store generation.
  int get generation => queue.generation;

  /// Recovery diagnostics, when the outbox could not be opened cleanly.
  DurableOutboxRecovery? get recovery => queue.recovery;

  /// Current aggregate state.
  DurableQueueAggregateState get aggregateState => observation.aggregateState;

  /// Current projection state, when configured.
  ProjectionState? get projectionState => queue.projectionState;

  /// Current auth scope used for observations.
  AuthScope? get currentAuthScope => queue.currentAuthScope;

  /// Replays admissible durable operations.
  Future<ReplayRunResult> replay({ReplayCancellationToken? cancellationToken}) {
    return queue.replay(cancellationToken: cancellationToken);
  }

  /// Adds a restart-safe optimistic projection overlay.
  Future<ProjectionOutcome> enqueueProjection(ProjectionOverlay overlay) {
    return queue.enqueueProjection(overlay);
  }

  /// Applies a confirmed remote projection base.
  Future<ProjectionOutcome> setProjectionRemoteBase(
    QueryKey key,
    Object? value, {
    int? revision,
  }) {
    return queue.setProjectionRemoteBase(key, value, revision: revision);
  }

  /// Remaps a temporary projection identifier to its server identifier.
  Future<ProjectionOutcome> remapProjectionId({
    required String temporaryId,
    required String serverId,
  }) {
    return queue.remapProjectionId(
      temporaryId: temporaryId,
      serverId: serverId,
    );
  }

  /// Materializes the current projection view for a query key.
  ProjectionView? materializeProjection(QueryKey key) {
    return queue.materializeProjection(key);
  }

  /// Completes an optimistic projection after successful replay.
  Future<ProjectionOutcome> completeProjection(
    OperationId operationId,
    Object? result,
  ) {
    return queue.completeProjection(operationId, result);
  }

  /// Removes an optimistic projection after a terminal failure.
  Future<ProjectionOutcome> failProjection(OperationId operationId) {
    return queue.failProjection(operationId);
  }

  /// Marks an optimistic projection as conflicted.
  Future<ProjectionOutcome> markProjectionConflict(
    OperationId operationId, {
    Map<String, Object?>? conflictEvidence,
  }) {
    return queue.markProjectionConflict(
      operationId,
      conflictEvidence: conflictEvidence,
    );
  }

  /// Returns one observed operation.
  DurableOperationObservation? observeOperation(
    OperationId operationId, {
    AuthScope? authScope,
  }) {
    return queue.observeOperation(operationId, authScope: authScope);
  }

  /// Lists observed operations.
  List<DurableOperationObservation> listOperations({
    DurableOperationFilter? filter,
  }) {
    return queue.listOperations(filter: filter);
  }

  /// Returns retained history for one operation.
  List<DurableHistoryObservation> operationHistory(
    OperationId operationId, {
    AuthScope? authScope,
  }) {
    return queue.operationHistory(operationId, authScope: authScope);
  }

  /// Retries one dead letter.
  Future<RepairActionResult> retryDeadLetter({
    required OperationId operationId,
    required String idempotencyKey,
    AuthScope? currentAuthScope,
  }) {
    return queue.retryDeadLetter(
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      currentAuthScope: currentAuthScope,
    );
  }

  /// Repairs one dead letter with explicit variables.
  Future<RepairActionResult> repairDeadLetter({
    required OperationId operationId,
    required String idempotencyKey,
    required Object? variables,
    MutationKey? mutationKey,
    ConflictPrecondition? conflictPrecondition,
    AuthScope? currentAuthScope,
  }) {
    return queue.repairDeadLetter(
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      variables: variables,
      mutationKey: mutationKey,
      conflictPrecondition: conflictPrecondition,
      currentAuthScope: currentAuthScope,
    );
  }

  /// Discards one dead letter while retaining its evidence.
  Future<RepairActionResult> discardDeadLetter({
    required OperationId operationId,
    required String idempotencyKey,
    AuthScope? currentAuthScope,
  }) {
    return queue.discardDeadLetter(
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      currentAuthScope: currentAuthScope,
    );
  }

  /// Restores one quarantined operation.
  Future<RepairActionResult> restoreQuarantinedOperation({
    required OperationId operationId,
    required String idempotencyKey,
    required AuthScope currentAuthScope,
  }) {
    return queue.restoreQuarantinedOperation(
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      currentAuthScope: currentAuthScope,
    );
  }
}
