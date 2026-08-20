import 'package:fasq/src/mutation/sync_engine/conflict/conflict_policy.dart';
import 'package:fasq/src/mutation/sync_engine/codecs/mutation_codec.dart';
import 'package:fasq/src/mutation/sync_engine/execution/auth_session.dart';
import 'package:fasq/src/mutation/sync_engine/execution/execution_context.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/projection/projection.dart';
import 'package:fasq/src/mutation/sync_engine/replay/replay_coordinator.dart';
import 'package:fasq/src/mutation/sync_engine/replay/retry_policy.dart';
import 'package:fasq/src/mutation/sync_engine/store/durable_outbox.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';
import 'package:fasq/src/query/keys/query_key.dart';
import 'package:uuid/uuid.dart';

/// Public durable queue facade for registered mutation functions.
///
/// Registration uses the same mutation function that performs an immediate
/// mutation. Queueing stores only its encoded variables and stable operation
/// identity; replay resolves the function from the runtime registry.
class DurableMutationQueue {
  /// Creates a durable queue over [store].
  factory DurableMutationQueue({
    required DurableOutboxStore store,
    MutationRegistrationRegistry? registrations,
    DateTime Function()? now,
    String Function()? idGenerator,
    MutationExecutionAdapter? executionAdapter,
    RetryPolicy retryPolicy = const RetryPolicy(),
    AuthSessionProvider? authSessionProvider,
    bool Function()? isOnline,
    ProjectionCoordinator? projectionCoordinator,
    void Function(String queryKey, Object? value)? projectionSink,
  }) {
    final resolvedRegistrations =
        registrations ?? MutationRegistrationRegistry();
    final resolvedNow = now ?? DateTime.now;
    return DurableMutationQueue._(
      store: store,
      registrations: resolvedRegistrations,
      now: resolvedNow,
      idGenerator: idGenerator ?? _newUuid,
      coordinator: DurableReplayCoordinator(
        store: store,
        registrations: resolvedRegistrations,
        now: resolvedNow,
        executionAdapter: executionAdapter,
        retryPolicy: retryPolicy,
        authSessionProvider: authSessionProvider,
        isOnline: isOnline,
      ),
      projectionCoordinator: projectionCoordinator,
      projectionSink: projectionSink,
    );
  }

  DurableMutationQueue._({
    required DurableOutboxStore store,
    required MutationRegistrationRegistry registrations,
    required DateTime Function() now,
    required String Function() idGenerator,
    required DurableReplayCoordinator coordinator,
    ProjectionCoordinator? projectionCoordinator,
    void Function(String queryKey, Object? value)? projectionSink,
  }) : _store = store,
       _registrations = registrations,
       _now = now,
       _idGenerator = idGenerator,
       _coordinator = coordinator,
       _projectionCoordinator = projectionCoordinator,
       _projectionSink = projectionSink;

  static const _uuid = Uuid();

  final DurableOutboxStore _store;
  final MutationRegistrationRegistry _registrations;
  final DateTime Function() _now;
  final String Function() _idGenerator;
  final DurableReplayCoordinator _coordinator;
  final ProjectionCoordinator? _projectionCoordinator;
  final void Function(String queryKey, Object? value)? _projectionSink;
  bool _isOpen = false;

  /// Whether the queue currently owns an open durable store.
  bool get isOpen => _isOpen;

  /// Current projection state, when projection integration is configured.
  ProjectionState? get projectionState => _projectionCoordinator?.state;

  /// Snapshot acknowledged by the durable store.
  OutboxSnapshot get snapshot => _store.snapshot;

  /// Current durable store generation.
  int get generation => _store.generation;

  /// Whether [key] has a runtime codec and executor registration.
  bool hasRegistration(MutationKey key) => _registrations.contains(key);

  /// Whether [operationId] is retained in active, dead-letter, or history data.
  bool hasRetainedOperation(OperationId operationId) {
    final current = _store.snapshot;
    return current.active.any((item) => item.operationId == operationId) ||
        current.deadLetters.any(
          (entry) => entry.operation.operationId == operationId,
        ) ||
        current.history.any((entry) => entry.operationId == operationId);
  }

  /// Whether [idempotencyKey] is retained in active or dead-letter data.
  bool hasRetainedIdempotencyKey(IdempotencyKey idempotencyKey) {
    final current = _store.snapshot;
    return current.active.any(
          (item) => item.idempotencyKey == idempotencyKey,
        ) ||
        current.deadLetters.any(
          (entry) => entry.operation.idempotencyKey == idempotencyKey,
        );
  }

  /// Registers the existing immediate mutation function for durable replay.
  ///
  /// This is the only executor registration point. Replay never accepts a
  /// second offline-only function.
  void register<TData, TVariables>({
    required MutationKey key,
    required MutationCodec<TVariables> codec,
    required Future<TData> Function(TVariables variables) mutationFn,
    AuthPolicy authPolicy = AuthPolicy.none,
    Object? Function(TData data)? resultEncoder,
  }) {
    _registrations.register<TData, TVariables>(
      key: key,
      codec: codec,
      mutationFn: mutationFn,
      authPolicy: authPolicy,
      resultEncoder: resultEncoder,
    );
  }

  /// Opens the queue and recovers interrupted durable work.
  Future<void> open() async {
    if (_isOpen) return;
    try {
      await _coordinator.open();
      _restoreProjectionState();
      _isOpen = true;
    } on DurableOutboxException {
      rethrow;
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        const DurableMutationQueueStorageException(),
        stackTrace,
      );
    }
  }

  /// Closes the queue and releases durable store ownership.
  Future<void> close() async {
    if (!_isOpen) return;
    try {
      await _coordinator.close();
      _isOpen = false;
    } on DurableOutboxException {
      rethrow;
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const DurableMutationQueueStorageException(),
        stackTrace,
      );
    }
  }

  /// Encodes and durably commits one pending mutation operation.
  Future<DurableEnqueueAcknowledgement> enqueue<TVariables>({
    required MutationKey key,
    required TVariables variables,
    OperationId? operationId,
    IdempotencyKey? idempotencyKey,
    LineageId? lineageId,
    AuthScope? authScope,
    ConflictPolicy conflictPolicy = ConflictPolicy.none,
    ConflictPrecondition? conflictPrecondition,
    DateTime? createdAt,
    int priority = 0,
    List<MutationDependency> dependencies = const <MutationDependency>[],
    List<MutationProjectionDescriptor> projections =
        const <MutationProjectionDescriptor>[],
    MutationOperationState state = MutationOperationState.pending,
    int attemptCount = 0,
    int maxAttempts = 5,
    Duration maxAge = const Duration(days: 30),
    DateTime? nextRunAt,
    String? rateLimitBucket,
  }) async {
    _requireOpen();
    if (state != MutationOperationState.pending &&
        state != MutationOperationState.retryScheduled) {
      throw InvalidMutationEnqueueStateException(state);
    }
    final encodedVariables = _registrations.encodeVariables(key, variables);
    final operation = MutationOperation(
      operationId: operationId ?? OperationId(_idGenerator()),
      mutationKey: key,
      variables: encodedVariables,
      createdAt: createdAt ?? _now(),
      idempotencyKey: idempotencyKey ?? IdempotencyKey(_idGenerator()),
      lineageId: lineageId ?? LineageId(_idGenerator()),
      authPolicy: _registrations.authPolicyFor(key),
      conflictPolicy: conflictPolicy,
      conflictPrecondition: conflictPrecondition,
      authScope: authScope,
      state: state,
      priority: priority,
      dependencies: dependencies,
      projections: projections,
      attemptCount: attemptCount,
      maxAttempts: maxAttempts,
      maxAge: maxAge,
      nextRunAt: nextRunAt,
      rateLimitBucket: rateLimitBucket,
    );

    final committed = await _commit((current) {
      _rejectDuplicateIdentity(current, operation);
      return current.copyWith(active: [...current.active, operation]);
    });
    final acknowledged = committed.active.firstWhere(
      (item) => item.operationId == operation.operationId,
    );
    return DurableEnqueueAcknowledgement(acknowledged);
  }

  /// Explicitly replays all currently admissible durable work.
  Future<ReplayRunResult> replay({
    ReplayCancellationToken? cancellationToken,
  }) async {
    final beforeHistory = _store.snapshot.history
        .map((entry) => entry.operationId)
        .toSet();
    final beforeDeadLetters = _store.snapshot.deadLetters
        .map((entry) => entry.operation.operationId)
        .toSet();
    final result = await _coordinator.replay(
      cancellationToken: cancellationToken,
    );
    await _syncProjectionOutcomes(beforeHistory, beforeDeadLetters);
    return result;
  }

  /// Compatibility alias for callers that previously requested queue work
  /// through `processQueue`.
  Future<ReplayRunResult> processQueue({
    ReplayCancellationToken? cancellationToken,
  }) => replay(cancellationToken: cancellationToken);

  /// Adds one restart-safe optimistic overlay after enqueue acknowledgement.
  Future<ProjectionOutcome> enqueueProjection(ProjectionOverlay overlay) {
    return _mutateProjection((coordinator) => coordinator.enqueue(overlay));
  }

  /// Applies a confirmed remote base while preserving pending overlays.
  Future<ProjectionOutcome> setProjectionRemoteBase(
    QueryKey key,
    Object? value, {
    int? revision,
  }) {
    return _mutateProjection(
      (coordinator) => coordinator.setRemoteBase(
        key,
        value,
        revision: revision,
      ),
    );
  }

  /// Materializes one projection view for a cache or UI integration.
  ProjectionView? materializeProjection(QueryKey key) {
    return _projectionCoordinator?.materialize(key);
  }

  /// Completes the matching optimistic overlay after successful replay.
  Future<ProjectionOutcome> completeProjection(
    OperationId operationId,
    Object? result,
  ) {
    return _mutateProjection(
      (coordinator) => coordinator.complete(operationId, result),
    );
  }

  /// Removes an overlay after a non-conflict terminal failure.
  Future<ProjectionOutcome> failProjection(OperationId operationId) {
    return _mutateProjection((coordinator) => coordinator.fail(operationId));
  }

  /// Marks an overlay conflicted without discarding local intent.
  Future<ProjectionOutcome> markProjectionConflict(OperationId operationId) {
    return _mutateProjection(
      (coordinator) => coordinator.markConflict(operationId),
    );
  }

  Future<OutboxSnapshot> _commit(DurableOutboxTransaction transaction) async {
    try {
      return await _store.transact(transaction);
    } on DurableOutboxException {
      rethrow;
    } on MutationContractException {
      rethrow;
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        const DurableMutationQueueStorageException(),
        stackTrace,
      );
    }
  }

  void _requireOpen() {
    if (!_isOpen) {
      throw StateError('The durable mutation queue is not open');
    }
  }

  static const _projectionMetadataKey = 'projectionState';

  void _restoreProjectionState() {
    final coordinator = _projectionCoordinator;
    if (coordinator == null) return;
    final raw = _store.snapshot.metadata[_projectionMetadataKey];
    if (raw is! Map<Object?, Object?>) return;
    try {
      coordinator.restore(ProjectionState.fromJson(_stringMap(raw)));
    } on Object {
      // Keep durable mutations usable; projection state is independently
      // repairable and must never block queue recovery.
    }
  }

  Future<ProjectionOutcome> _mutateProjection(
    ProjectionOutcome Function(ProjectionCoordinator coordinator) change,
  ) async {
    _requireOpen();
    final coordinator = _projectionCoordinator;
    if (coordinator == null) {
      return ProjectionOutcome(
        ProjectionState(),
        <String>[],
        const ProjectionFailure(null, null, 'projection.not_configured'),
      );
    }
    final previousState = coordinator.state;
    final outcome = change(coordinator);
    try {
      await _commit(
        (current) => current.copyWith(
          metadata: {
            ...current.metadata,
            _projectionMetadataKey: outcome.state.toJson(),
          },
        ),
      );
      _notifyProjection(outcome.changedKeys);
      return outcome;
    } on Object {
      coordinator.restore(previousState);
      return ProjectionOutcome(
        previousState,
        const <String>[],
        const ProjectionFailure(null, null, 'projection.persist_failed'),
      );
    }
  }

  void _notifyProjection(Iterable<String> keys) {
    final sink = _projectionSink;
    final coordinator = _projectionCoordinator;
    if (sink == null || coordinator == null) return;
    for (final key in keys.toSet()) {
      final view = coordinator.materialize(StringQueryKey(key));
      if (view.failure == null) sink(key, view.value);
    }
  }

  Future<void> _syncProjectionOutcomes(
    Set<OperationId> beforeHistory,
    Set<OperationId> beforeDeadLetters,
  ) async {
    final current = _store.snapshot;
    for (final entry in current.history) {
      if (entry.state != MutationOperationState.succeeded ||
          beforeHistory.contains(entry.operationId)) {
        continue;
      }
      await completeProjection(entry.operationId, entry.resultProjection);
    }
    for (final entry in current.deadLetters) {
      if (beforeDeadLetters.contains(entry.operation.operationId)) continue;
      if (entry.category == MutationFailureCategory.conflict) {
        await markProjectionConflict(entry.operation.operationId);
      } else {
        await failProjection(entry.operation.operationId);
      }
    }
  }

  static Map<String, Object?> _stringMap(Map<Object?, Object?> value) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const InvalidMutationPayloadException(
          'Projection metadata keys must be strings',
        );
      }
      result[entry.key! as String] = entry.value;
    }
    return result;
  }

  void _rejectDuplicateIdentity(
    OutboxSnapshot snapshot,
    MutationOperation operation,
  ) {
    final operationId = operation.operationId.value;
    final idempotencyKey = operation.idempotencyKey.value;
    final duplicateOperation =
        [
          ...snapshot.active,
          ...snapshot.deadLetters.map((entry) => entry.operation),
        ].any(
          (existing) =>
              existing.operationId.value == operationId ||
              existing.idempotencyKey.value == idempotencyKey,
        );
    final duplicateHistory = snapshot.history.any(
      (entry) => entry.operationId.value == operationId,
    );
    if (duplicateOperation || duplicateHistory) {
      throw DuplicateMutationOperationException(operationId);
    }
  }

  static String _newUuid() => _uuid.v4();
}

/// Durable acknowledgement returned after the enqueue transaction commits.
class DurableEnqueueAcknowledgement {
  /// Creates an acknowledgement for [operation].
  const DurableEnqueueAcknowledgement(this.operation);

  /// Operation snapshot acknowledged by durable storage.
  final MutationOperation operation;

  /// Stable operation occurrence identity.
  OperationId get operationId => operation.operationId;

  /// Stable retry/restart idempotency identity.
  IdempotencyKey get idempotencyKey => operation.idempotencyKey;

  /// Stable repair lineage identity.
  LineageId get lineageId => operation.lineageId;
}

/// Safe typed storage failure raised when a backend returns an unknown error.
class DurableMutationQueueStorageException extends DurableOutboxException {
  /// Creates a generic queue storage failure.
  const DurableMutationQueueStorageException()
    : super(
        DurableOutboxErrorCode.storage,
        'The durable mutation queue storage operation failed',
      );
}

/// Raised when an operation or idempotency identity is already retained.
class DuplicateMutationOperationException extends MutationContractException {
  /// Creates a duplicate-identity failure.
  DuplicateMutationOperationException(String operationId)
    : super('Mutation operation identity is already retained: $operationId');
}

/// Raised when callers try to enqueue a non-replayable operation state.
class InvalidMutationEnqueueStateException extends MutationContractException {
  /// Creates an invalid enqueue-state failure.
  InvalidMutationEnqueueStateException(MutationOperationState state)
    : super('Mutation enqueue state is not replayable: ${state.name}');
}
