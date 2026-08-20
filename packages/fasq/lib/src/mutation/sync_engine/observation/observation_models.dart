import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';

/// Public durable state exposed for one observed operation.
enum DurableOperationState {
  /// Operation is persisted and eligible for replay.
  queued,

  /// Operation executor is currently running.
  running,

  /// Operation is waiting for its next retry time.
  retryScheduled,

  /// Operation is waiting for authentication readiness.
  authBlocked,

  /// Operation is denied by the current authorization policy.
  authorizationBlocked,

  /// Operation conflicts with current remote state.
  conflict,

  /// Operation cannot run because a dependency is unresolved.
  blockedByDependency,

  /// Operation is retained for a different authentication scope.
  quarantined,

  /// Operation completed successfully.
  succeeded,

  /// Operation failed permanently.
  failedTerminal,

  /// Operation outcome is ambiguous and needs explicit handling.
  unknownOutcome,

  /// Operation was explicitly paused.
  paused,

  /// Operation was discarded.
  discarded,

  /// Stored operation needs migration before it can execute.
  migrationRequired,

  /// Durable storage could not validate the operation.
  storageCorrupt,
}

/// Durable aggregate state for a filtered queue view.
enum DurableQueueAggregateState {
  /// No matching active or dead-letter work exists.
  idle,

  /// At least one matching operation is currently executing.
  syncing,

  /// Matching work is waiting for a future condition or retry.
  waiting,

  /// Matching work needs explicit user or application attention.
  attentionRequired,

  /// Matching work is quarantined for another authentication scope.
  quarantined,
}

/// Identifies which durable retention area produced an observation.
enum DurableObservationRecordKind {
  /// Operation remains active in the outbox.
  active,

  /// Operation is retained as a dead letter.
  deadLetter,
}

/// Safe failure metadata retained for public observation.
class DurableFailureObservation {
  /// Creates safe failure metadata.
  const DurableFailureObservation({
    required this.category,
    required this.messageKey,
    required this.retryable,
    required this.repairable,
  });

  /// Normalized failure category.
  final MutationFailureCategory category;

  /// Stable application message key. No exception text is retained.
  final String messageKey;

  /// Whether an explicit retry is permitted by the failure classification.
  final bool retryable;

  /// Whether an explicit repair is permitted by the failure classification.
  final bool repairable;
}

/// Safe dependency metadata for one observed operation.
class DurableDependencyObservation {
  /// Creates dependency metadata without variable paths or payloads.
  const DurableDependencyObservation({required this.parentOperationId});

  /// Parent operation required before this operation can execute.
  final OperationId parentOperationId;
}

/// Immutable, redacted view of active or dead-letter operation metadata.
class DurableOperationObservation {
  /// Creates an immutable operation observation.
  DurableOperationObservation({
    required this.operationId,
    required this.mutationKey,
    required this.idempotencyKey,
    required this.lineageId,
    required this.authPolicy,
    required this.authScope,
    required this.state,
    required this.createdAt,
    required this.attemptCount,
    required this.maxAttempts,
    required this.priority,
    required List<DurableDependencyObservation> dependencies,
    required this.nextRunAt,
    required this.lastAttemptAt,
    required this.recordKind,
    this.failure,
    this.failedAt,
  }) : dependencies = List.unmodifiable(dependencies);

  /// Stable identity for one durable operation occurrence.
  final OperationId operationId;

  /// Logical registered mutation identity.
  final MutationKey mutationKey;

  /// Stable retry identity. Retries reuse this value.
  final IdempotencyKey idempotencyKey;

  /// Repair lineage identity.
  final LineageId lineageId;

  /// Authentication policy captured at enqueue.
  final AuthPolicy authPolicy;

  /// Exact non-secret scope captured at enqueue, when required.
  final AuthScope? authScope;

  /// Public lifecycle state.
  final DurableOperationState state;

  /// Time at which operation was queued.
  final DateTime createdAt;

  /// Number of attempts already persisted.
  final int attemptCount;

  /// Maximum automatic attempts configured for operation.
  final int maxAttempts;

  /// Scheduling priority.
  final int priority;

  /// Parent identities required before execution.
  final List<DurableDependencyObservation> dependencies;

  /// Next eligible retry time, when scheduled.
  final DateTime? nextRunAt;

  /// Most recent attempt time, when an attempt occurred.
  final DateTime? lastAttemptAt;

  /// Durable retention area containing this operation.
  final DurableObservationRecordKind recordKind;

  /// Safe failure classification for dead letters.
  final DurableFailureObservation? failure;

  /// Dead-letter retention time, when this is a dead letter.
  final DateTime? failedAt;

  /// Builds an observation without exposing variables or conflict evidence.
  factory DurableOperationObservation.fromOperation(
    MutationOperation operation, {
    required DurableObservationRecordKind recordKind,
    DurableFailureObservation? failure,
    DateTime? failedAt,
  }) {
    return DurableOperationObservation(
      operationId: operation.operationId,
      mutationKey: operation.mutationKey,
      idempotencyKey: operation.idempotencyKey,
      lineageId: operation.lineageId,
      authPolicy: operation.authPolicy,
      authScope: operation.authScope,
      state: _publicState(operation.state, failure?.category),
      createdAt: operation.createdAt,
      attemptCount: operation.attemptCount,
      maxAttempts: operation.maxAttempts,
      priority: operation.priority,
      dependencies: operation.dependencies
          .map(
            (dependency) => DurableDependencyObservation(
              parentOperationId: dependency.parentOperationId,
            ),
          )
          .toList(growable: false),
      nextRunAt: operation.nextRunAt,
      lastAttemptAt: operation.lastAttemptAt,
      recordKind: recordKind,
      failure: failure,
      failedAt: failedAt,
    );
  }
}

/// Immutable retained completion/deletion ledger entry.
class DurableHistoryObservation {
  /// Creates a safe history observation.
  const DurableHistoryObservation({
    required this.operationId,
    required this.state,
    required this.completedAt,
    required this.authScope,
    required this.hasResultProjection,
  });

  /// Operation identity retained in the completion ledger.
  final OperationId operationId;

  /// Final public lifecycle state.
  final DurableOperationState state;

  /// Completion or discard time.
  final DateTime completedAt;

  /// Exact non-secret scope that owned this operation, when authenticated.
  final AuthScope? authScope;

  /// Whether a JSON-safe result projection exists. Its contents stay private.
  final bool hasResultProjection;

  /// Converts a durable ledger entry without exposing projected result data.
  factory DurableHistoryObservation.fromEntry(OutboxHistoryEntry entry) {
    return DurableHistoryObservation(
      operationId: entry.operationId,
      state: _publicState(entry.state),
      completedAt: entry.completedAt,
      authScope: entry.authScope,
      hasResultProjection: entry.resultProjection != null,
    );
  }
}

/// Immutable filter for operation and dead-letter observation.
class DurableOperationFilter {
  /// Creates a filter. Auth scope matching is exact when [authScope] exists.
  const DurableOperationFilter({
    this.operationId,
    this.mutationKey,
    this.states = const <DurableOperationState>{},
    this.authScope,
    this.includeUnauthenticated = true,
    this.includeDeadLetters = true,
    this.limit,
  }) : assert(limit == null || limit > 0, 'limit must be positive');

  /// Restricts observation to one operation.
  final OperationId? operationId;

  /// Restricts observation to one logical mutation key.
  final MutationKey? mutationKey;

  /// Restricts observation to these public lifecycle states.
  final Set<DurableOperationState> states;

  /// Exact scope required for authenticated operations.
  final AuthScope? authScope;

  /// Whether operations without an auth scope remain visible alongside the
  /// exact requested scope.
  final bool includeUnauthenticated;

  /// Whether dead-letter records are included.
  final bool includeDeadLetters;

  /// Optional maximum number of matching records.
  final int? limit;

  /// Returns whether [observation] satisfies this filter.
  bool matches(DurableOperationObservation observation) {
    if (operationId != null && observation.operationId != operationId) {
      return false;
    }
    if (mutationKey != null && observation.mutationKey != mutationKey) {
      return false;
    }
    if (states.isNotEmpty && !states.contains(observation.state)) {
      return false;
    }
    if (!includeDeadLetters &&
        observation.recordKind == DurableObservationRecordKind.deadLetter) {
      return false;
    }
    if (authScope == null) return true;
    if (observation.authScope == authScope) return true;
    return includeUnauthenticated && observation.authScope == null;
  }
}

/// Queue-facing name for the durable operation filter.
typedef DurableObservationFilter = DurableOperationFilter;

/// Compatibility name for queue-level callers that filter observations.
typedef DurableQueueObservationFilter = DurableOperationFilter;

/// Immutable queue observation for one filtered durable snapshot.
class DurableQueueObservation {
  /// Creates an immutable queue observation.
  DurableQueueObservation({
    required List<DurableOperationObservation> operations,
    required List<DurableHistoryObservation> history,
    required this.aggregateState,
  }) : operations = List.unmodifiable(operations),
       history = List.unmodifiable(history);

  /// Matching active and dead-letter operations.
  final List<DurableOperationObservation> operations;

  /// Matching retained history entries.
  final List<DurableHistoryObservation> history;

  /// Derived aggregate state for [operations].
  final DurableQueueAggregateState aggregateState;
}

DurableOperationState _publicState(
  MutationOperationState state, [
  MutationFailureCategory? failureCategory,
]) {
  if (failureCategory != null) {
    return _failureState(failureCategory);
  }
  return switch (state) {
    MutationOperationState.pending => DurableOperationState.queued,
    MutationOperationState.running => DurableOperationState.running,
    MutationOperationState.retryScheduled =>
      DurableOperationState.retryScheduled,
    MutationOperationState.paused => DurableOperationState.paused,
    MutationOperationState.authBlocked => DurableOperationState.authBlocked,
    MutationOperationState.authorizationBlocked =>
      DurableOperationState.authorizationBlocked,
    MutationOperationState.quarantined => DurableOperationState.quarantined,
    MutationOperationState.blocked => DurableOperationState.blockedByDependency,
    MutationOperationState.succeeded => DurableOperationState.succeeded,
    MutationOperationState.failedTerminal =>
      DurableOperationState.failedTerminal,
    MutationOperationState.unknownOutcome =>
      DurableOperationState.unknownOutcome,
    MutationOperationState.discarded => DurableOperationState.discarded,
    MutationOperationState.migrationRequired =>
      DurableOperationState.migrationRequired,
    MutationOperationState.storageCorrupt =>
      DurableOperationState.storageCorrupt,
  };
}

DurableOperationState _failureState(MutationFailureCategory category) {
  return switch (category) {
    MutationFailureCategory.authentication => DurableOperationState.authBlocked,
    MutationFailureCategory.authorization =>
      DurableOperationState.authorizationBlocked,
    MutationFailureCategory.conflict => DurableOperationState.conflict,
    MutationFailureCategory.dependency =>
      DurableOperationState.blockedByDependency,
    MutationFailureCategory.migration =>
      DurableOperationState.migrationRequired,
    MutationFailureCategory.storage => DurableOperationState.storageCorrupt,
    MutationFailureCategory.unknown => DurableOperationState.unknownOutcome,
    _ => DurableOperationState.failedTerminal,
  };
}
