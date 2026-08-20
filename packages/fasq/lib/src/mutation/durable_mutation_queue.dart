import 'dart:async';

import 'package:fasq/src/mutation/sync_engine/conflict/conflict_policy.dart';
import 'package:fasq/src/mutation/sync_engine/conflict/conflict_repair.dart';
import 'package:fasq/src/mutation/sync_engine/codecs/mutation_codec.dart';
import 'package:fasq/src/mutation/sync_engine/execution/auth_session.dart';
import 'package:fasq/src/mutation/sync_engine/execution/execution_context.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/observation/observation.dart';
import 'package:fasq/src/mutation/sync_engine/projection/projection.dart';
import 'package:fasq/src/mutation/sync_engine/repair/repair.dart';
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
    RepairIdentityFactory? repairIdentityFactory,
    RepairTelemetryAdapter? repairTelemetry,
  }) {
    final resolvedRegistrations =
        registrations ?? MutationRegistrationRegistry();
    final resolvedNow = now ?? DateTime.now;
    return DurableMutationQueue._(
      store: store,
      registrations: resolvedRegistrations,
      now: resolvedNow,
      idGenerator: idGenerator ?? _newUuid,
      authSessionProvider: authSessionProvider,
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
      repairService: DurableRepairService(
        store: store,
        identities: repairIdentityFactory,
        telemetry: repairTelemetry,
        now: resolvedNow,
      ),
    );
  }

  DurableMutationQueue._({
    required DurableOutboxStore store,
    required MutationRegistrationRegistry registrations,
    required DateTime Function() now,
    required String Function() idGenerator,
    AuthSessionProvider? authSessionProvider,
    required DurableReplayCoordinator coordinator,
    ProjectionCoordinator? projectionCoordinator,
    void Function(String queryKey, Object? value)? projectionSink,
    required DurableRepairService repairService,
  }) : _store = store,
       _registrations = registrations,
       _now = now,
       _idGenerator = idGenerator,
       _authSessionProvider = authSessionProvider,
       _coordinator = coordinator,
       _projectionCoordinator = projectionCoordinator,
       _projectionSink = projectionSink,
       _repairService = repairService,
       _observationChanges = StreamController<OutboxSnapshot>.broadcast(
         sync: true,
       );

  static const _uuid = Uuid();

  final DurableOutboxStore _store;
  final MutationRegistrationRegistry _registrations;
  final DateTime Function() _now;
  final String Function() _idGenerator;
  final AuthSessionProvider? _authSessionProvider;
  final DurableReplayCoordinator _coordinator;
  final ProjectionCoordinator? _projectionCoordinator;
  final void Function(String queryKey, Object? value)? _projectionSink;
  final DurableRepairService _repairService;
  final StreamController<OutboxSnapshot> _observationChanges;
  StreamSubscription<AuthSessionSnapshot>? _observationAuthSubscription;
  AuthScope? _observationAuthScope;
  bool _isOpen = false;

  /// Whether the queue currently owns an open durable store.
  bool get isOpen => _isOpen;

  /// Current projection state, when projection integration is configured.
  ProjectionState? get projectionState => _projectionCoordinator?.state;

  /// Snapshot acknowledged by the durable store.
  OutboxSnapshot get snapshot => _store.snapshot;

  /// Current durable store generation.
  int get generation => _store.generation;

  /// Current public-safe observation snapshot.
  DurableQueueObservation get observation =>
      DurableObservation.fromSnapshot(_store.snapshot).queueObservation(
        filter: _boundObservationFilter(),
      );

  /// Looks up one retained operation without exposing variables or errors.
  DurableOperationObservation? observeOperation(
    OperationId operationId, {
    AuthScope? authScope,
  }) {
    return DurableObservation.fromSnapshot(_store.snapshot).getOperation(
      operationId,
      filter: _boundObservationFilter(
        requested: DurableOperationFilter(
          authScope: authScope,
          includeUnauthenticated: true,
        ),
      ),
    );
  }

  /// Lists retained operations using exact, scope-aware filters.
  List<DurableOperationObservation> listOperations({
    DurableOperationFilter? filter,
  }) {
    return DurableObservation.fromSnapshot(_store.snapshot).listOperations(
      _boundObservationFilter(requested: filter),
    );
  }

  /// Returns aggregate state for retained work visible to [authScope].
  DurableQueueAggregateState aggregateState({AuthScope? authScope}) {
    return DurableObservation.fromSnapshot(_store.snapshot)
        .queueObservation(
          filter: _boundObservationFilter(
            requested: DurableOperationFilter(
              authScope: authScope,
              includeUnauthenticated: true,
            ),
          ),
        )
        .aggregateState;
  }

  /// Explicitly retries one retryable dead letter with fresh identities.
  Future<RepairActionResult> retryDeadLetter({
    required OperationId operationId,
    required String idempotencyKey,
    AuthScope? currentAuthScope,
  }) => _runRepairAction(
    () => _repairService.retry(
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      currentAuthScope: currentAuthScope,
    ),
  );

  /// Replaces one repairable dead letter with explicit variables.
  Future<RepairActionResult> repairDeadLetter({
    required OperationId operationId,
    required String idempotencyKey,
    required Object? variables,
    MutationKey? mutationKey,
    ConflictPrecondition? conflictPrecondition,
    AuthScope? currentAuthScope,
  }) => _runRepairAction(
    () => _repairService.repair(
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      variables: variables,
      mutationKey: mutationKey,
      conflictPrecondition: conflictPrecondition,
      currentAuthScope: currentAuthScope,
    ),
  );

  /// Explicitly discards one dead letter while retaining its evidence.
  Future<RepairActionResult> discardDeadLetter({
    required OperationId operationId,
    required String idempotencyKey,
    AuthScope? currentAuthScope,
  }) => _runRepairAction(
    () => _repairService.discard(
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      currentAuthScope: currentAuthScope,
    ),
  );

  /// Restores one quarantined operation after exact scope validation.
  Future<RepairActionResult> restoreQuarantinedOperation({
    required OperationId operationId,
    required String idempotencyKey,
    required AuthScope currentAuthScope,
  }) => _runRepairAction(
    () => _repairService.restoreQuarantine(
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      currentAuthScope: currentAuthScope,
    ),
  );

  /// Returns retained completion entries for one operation.
  List<DurableHistoryObservation> operationHistory(
    OperationId operationId, {
    AuthScope? authScope,
  }) {
    return DurableObservation.fromSnapshot(_store.snapshot).getOperationHistory(
      operationId,
      authScope: authScope ?? _observationAuthScope,
      scopeBound: true,
      includeUnauthenticated: true,
    );
  }

  /// Watches durable public-safe snapshots.
  ///
  /// Each listener receives an initial snapshot from durable storage, followed
  /// by updates after queue mutations. The returned stream is broadcast and
  /// listeners do not share subscription state.
  Stream<DurableQueueObservation> watch({
    DurableOperationFilter? filter,
  }) {
    final requestedFilter = filter;
    late final StreamController<DurableQueueObservation> controller;
    StreamSubscription<OutboxSnapshot>? subscription;
    controller = StreamController<DurableQueueObservation>.broadcast(
      sync: true,
      onListen: () {
        subscription = _observationChanges.stream.listen((snapshot) {
          controller.add(
            buildQueueObservation(
              snapshot,
              filter: _boundObservationFilter(requested: requestedFilter),
            ),
          );
        });
        scheduleMicrotask(() {
          if (controller.isClosed) return;
          controller.add(
            buildQueueObservation(
              _store.snapshot,
              filter: _boundObservationFilter(requested: requestedFilter),
            ),
          );
        });
      },
      onCancel: () async {
        await subscription?.cancel();
        if (!controller.isClosed) await controller.close();
      },
    );
    return controller.stream;
  }

  DurableOperationFilter _boundObservationFilter({
    DurableOperationFilter? requested,
  }) {
    final filter = requested ?? const DurableObservationFilter();
    final scope = _authSessionProvider == null
        ? filter.authScope
        : _observationAuthScope;
    return filter.bindToScope(scope);
  }

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

  /// Whether [idempotencyKey] is retained in active, dead-letter, or history data.
  bool hasRetainedIdempotencyKey(IdempotencyKey idempotencyKey) {
    final current = _store.snapshot;
    return current.active.any(
          (item) => item.idempotencyKey == idempotencyKey,
        ) ||
        current.deadLetters.any(
          (entry) => entry.operation.idempotencyKey == idempotencyKey,
        ) ||
        current.history.any(
          (entry) => entry.idempotencyKey == idempotencyKey,
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
      await _backfillHistoryIdempotencyKeys(_retainedIdempotencyKeys());
      _restoreProjectionState();
      await _refreshObservationScope();
      _isOpen = true;
      _listenForObservationScopeChanges();
      _publishObservation();
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
      await _observationAuthSubscription?.cancel();
      _observationAuthSubscription = null;
      _observationAuthScope = null;
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

  Future<void> _refreshObservationScope() async {
    final provider = _authSessionProvider;
    if (provider == null) {
      _observationAuthScope = null;
      return;
    }
    try {
      _observationAuthScope = (await provider.currentSession()).scope;
    } on Object {
      // Fail closed when the auth boundary cannot resolve its current scope.
      _observationAuthScope = null;
    }
  }

  void _listenForObservationScopeChanges() {
    final provider = _authSessionProvider;
    if (provider == null || _observationAuthSubscription != null) return;
    _observationAuthSubscription = provider.changes.listen((session) {
      _observationAuthScope = session.scope;
      _publishObservation();
    });
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
    _publishObservation(committed);
    return DurableEnqueueAcknowledgement(acknowledged);
  }

  /// Explicitly replays all currently admissible durable work.
  Future<ReplayRunResult> replay({
    ReplayCancellationToken? cancellationToken,
  }) async {
    final retainedIdentities = _retainedIdempotencyKeys();
    try {
      final result = await _coordinator.replay(
        cancellationToken: cancellationToken,
      );
      await _backfillHistoryIdempotencyKeys(retainedIdentities);
      await _syncProjectionOutcomes();
      return result;
    } finally {
      _publishObservation();
    }
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

  /// Remaps a temporary identifier in projections and active queued work.
  ///
  /// The projection metadata and active operation variables are committed in
  /// one outbox transaction so a restart cannot observe only half the map.
  Future<ProjectionOutcome> remapProjectionId({
    required String temporaryId,
    required String serverId,
  }) {
    return _mutateProjection(
      (coordinator) => coordinator.remapId(
        temporaryId: temporaryId,
        serverId: serverId,
      ),
      operationTransform: (operation) => operation.copyWith(
        variables: remapProjectionReferences(
          operation.variables,
          temporaryId: temporaryId,
          serverId: serverId,
        ),
        projections: operation.projections
            .map((descriptor) => descriptor.mapKeys(temporaryId, serverId))
            .toList(growable: false),
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
  Future<ProjectionOutcome> markProjectionConflict(
    OperationId operationId, {
    Map<String, Object?>? conflictEvidence,
  }) {
    return _mutateProjection(
      (coordinator) => coordinator.markConflict(
        operationId,
        conflictEvidence: conflictEvidence,
      ),
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

  void _publishObservation([OutboxSnapshot? committed]) {
    if (!_isOpen && committed == null) return;
    if (!_observationChanges.isClosed) {
      _observationChanges.add(committed ?? _store.snapshot);
    }
  }

  Future<RepairActionResult> _runRepairAction(
    Future<RepairActionResult> Function() action,
  ) async {
    _requireOpen();
    final retainedIdentities = _retainedIdempotencyKeys();
    final result = await action();
    await _backfillHistoryIdempotencyKeys(retainedIdentities);
    _publishObservation();
    return result;
  }

  Map<OperationId, IdempotencyKey> _retainedIdempotencyKeys() {
    final current = _store.snapshot;
    return <OperationId, IdempotencyKey>{
      for (final operation in current.active)
        operation.operationId: operation.idempotencyKey,
      for (final deadLetter in current.deadLetters)
        deadLetter.operation.operationId: deadLetter.operation.idempotencyKey,
      for (final entry in current.history)
        if (entry.idempotencyKey case final idempotencyKey?)
          entry.operationId: idempotencyKey,
    };
  }

  Future<void> _backfillHistoryIdempotencyKeys(
    Map<OperationId, IdempotencyKey> retainedIdentities,
  ) async {
    if (retainedIdentities.isEmpty) return;
    final current = _store.snapshot;
    final hasBackfillableHistory = current.history.any(
      (entry) =>
          entry.idempotencyKey == null &&
          retainedIdentities.containsKey(entry.operationId),
    );
    if (!hasBackfillableHistory) return;

    await _commit((latest) {
      return latest.copyWith(
        history: latest.history
            .map((entry) {
              if (entry.idempotencyKey != null) return entry;
              final idempotencyKey = retainedIdentities[entry.operationId];
              if (idempotencyKey == null) return entry;
              return _historyWithIdempotencyKey(entry, idempotencyKey);
            })
            .toList(growable: false),
      );
    });
  }

  static OutboxHistoryEntry _historyWithIdempotencyKey(
    OutboxHistoryEntry entry,
    IdempotencyKey idempotencyKey,
  ) {
    return OutboxHistoryEntry.validated(
      operationId: entry.operationId,
      state: entry.state,
      completedAt: entry.completedAt,
      idempotencyKey: idempotencyKey,
      authScope: entry.authScope,
      resultProjection: entry.resultProjection,
    );
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
    ProjectionOutcome Function(ProjectionCoordinator coordinator) change, {
    MutationOperation Function(MutationOperation operation)? operationTransform,
  }) async {
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
          active: operationTransform == null
              ? current.active
              : current.active.map(operationTransform).toList(growable: false),
        ),
      );
      _publishObservation();
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

  Future<void> _syncProjectionOutcomes() async {
    final current = _store.snapshot;
    for (final entry in current.history) {
      if (entry.state != MutationOperationState.succeeded ||
          !_needsProjectionReconciliation(entry.operationId)) {
        continue;
      }
      await completeProjection(entry.operationId, entry.resultProjection);
    }
    for (final entry in current.deadLetters) {
      final operationId = entry.operation.operationId;
      if (!_needsProjectionReconciliation(operationId)) {
        continue;
      }
      if (entry.category == MutationFailureCategory.conflict) {
        await markProjectionConflict(
          operationId,
          conflictEvidence: entry.conflictEvidence,
        );
      } else {
        await failProjection(operationId);
      }
    }
  }

  bool _needsProjectionReconciliation(
    OperationId operationId,
  ) {
    final coordinator = _projectionCoordinator;
    if (coordinator == null) return false;
    for (final overlay in coordinator.state.overlays) {
      if (overlay.operationId != operationId) continue;
      if (overlay.state == ProjectionOverlayState.resolved) return false;
      if (overlay.state == ProjectionOverlayState.conflicted) {
        return false;
      }
      return true;
    }
    return false;
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
      (entry) =>
          entry.operationId.value == operationId ||
          entry.idempotencyKey?.value == idempotencyKey,
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
