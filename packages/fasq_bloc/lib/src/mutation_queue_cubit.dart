import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Bloc adapter for the public durable mutation queue.
///
/// The cubit observes public-safe queue metadata and forwards the complete
/// observation, replay, projection, and repair command surface to the core
/// [DurableMutationQueue]. The underlying queue remains available through
/// [queue] for registration and advanced commands. It borrows the queue;
/// closing this cubit never closes the runtime or durable store.
class MutationQueueCubit extends Cubit<DurableQueueObservation> {
  /// Creates a queue cubit from an explicit queue or a runtime queue.
  factory MutationQueueCubit({
    DurableMutationQueue? queue,
    FasqRuntime? runtime,
    DurableOperationFilter? filter,
  }) {
    assert(
      queue == null || runtime == null,
      'Provide either queue or runtime, not both.',
    );
    final resolvedQueue = queue ?? _queueFromRuntime(runtime);
    return MutationQueueCubit._(resolvedQueue, filter);
  }

  MutationQueueCubit._(
    DurableMutationQueue queue,
    DurableOperationFilter? filter,
  ) : _queue = queue,
      _filter = filter,
      super(_initialObservation(queue, filter)) {
    _subscribe();
  }

  final DurableMutationQueue _queue;
  DurableOperationFilter? _filter;
  StreamSubscription<DurableQueueObservation>? _subscription;
  var _watchGeneration = 0;

  static DurableMutationQueue _queueFromRuntime(FasqRuntime? runtime) {
    final queue = runtime?.mutationQueue;
    if (queue == null) {
      throw StateError(
        'MutationQueueCubit requires a durable queue or a runtime with one.',
      );
    }
    return queue;
  }

  static DurableQueueObservation _initialObservation(
    DurableMutationQueue queue,
    DurableOperationFilter? filter,
  ) {
    if (filter == null) return queue.observation;
    return filterQueueObservation(queue.observation, filter);
  }

  /// The borrowed core queue.
  DurableMutationQueue get queue => _queue;

  /// Current filtered public-safe observation.
  DurableQueueObservation get observation => state;

  /// Current persisted outbox snapshot.
  OutboxSnapshot get snapshot => _queue.snapshot;

  /// Whether the durable outbox is open.
  bool get isOpen => _queue.isOpen;

  /// Whether the configured connectivity source reports online.
  bool get isOnline => _queue.isOnline;

  /// Current durable-store generation.
  int get generation => _queue.generation;

  /// Recovery diagnostics, when the outbox could not be opened cleanly.
  DurableOutboxRecovery? get recovery => _queue.recovery;

  /// Aggregate state for the current queue scope and optional filter.
  DurableQueueAggregateState aggregateState({AuthScope? authScope}) {
    final configuredFilter = _filter ?? const DurableOperationFilter();
    final boundFilter = DurableOperationFilter(
      operationId: configuredFilter.operationId,
      mutationKey: configuredFilter.mutationKey,
      states: configuredFilter.states,
      authScope:
          authScope ?? _queue.currentAuthScope ?? configuredFilter.authScope,
      includeUnauthenticated: configuredFilter.includeUnauthenticated,
      scopeBound: true,
      includeDeadLetters: configuredFilter.includeDeadLetters,
      limit: configuredFilter.limit,
    );
    return DurableObservation.fromSnapshot(
      _queue.snapshot,
    ).queueObservation(filter: boundFilter).aggregateState;
  }

  /// Aggregate state represented by the cubit's current filtered [state].
  DurableQueueAggregateState get currentAggregateState => state.aggregateState;

  /// Current projection state, when configured.
  ProjectionState? get projectionState => _queue.projectionState;

  /// Current auth scope used by queue observations.
  AuthScope? get currentAuthScope => _queue.currentAuthScope;

  /// Installs a new observation filter and reconnects the queue watcher.
  void setFilter(DurableOperationFilter? filter) {
    if (isClosed) return;
    _filter = filter;
    unawaited(_subscription?.cancel());
    emit(_initialObservation(_queue, filter));
    _subscribe();
  }

  void _subscribe() {
    final watchGeneration = ++_watchGeneration;
    _subscription = _queue.watch(filter: _filter).listen((nextObservation) {
      if (!isClosed && watchGeneration == _watchGeneration) {
        emit(nextObservation);
      }
    });
  }

  /// Watches queue observations directly, preserving the core stream API.
  Stream<DurableQueueObservation> watch({DurableOperationFilter? filter}) {
    return _queue.watch(filter: filter);
  }

  /// Whether a mutation key has a durable replay registration.
  bool hasRegistration(MutationKey key) => _queue.hasRegistration(key);

  /// Whether an operation is retained in active, dead-letter, or history data.
  bool hasRetainedOperation(OperationId operationId) {
    return _queue.hasRetainedOperation(operationId);
  }

  /// Whether an idempotency key is retained by the queue.
  bool hasRetainedIdempotencyKey(IdempotencyKey idempotencyKey) {
    return _queue.hasRetainedIdempotencyKey(idempotencyKey);
  }

  /// Registers an immediate mutation function for durable replay.
  void register<TData, TVariables>({
    required MutationKey key,
    required MutationCodec<TVariables> codec,
    required Future<TData> Function(TVariables variables) mutationFn,
    AuthPolicy authPolicy = AuthPolicy.none,
    Object? Function(TData data)? resultEncoder,
    List<FasqMutationDependency<Object?, Object?, Object?, Object?>>
        dependencies =
        const <FasqMutationDependency<Object?, Object?, Object?, Object?>>[],
  }) {
    _queue.register<TData, TVariables>(
      key: key,
      codec: codec,
      mutationFn: mutationFn,
      authPolicy: authPolicy,
      resultEncoder: resultEncoder,
      dependencies: dependencies,
    );
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
  }) {
    return _queue.enqueue<TVariables>(
      key: key,
      variables: variables,
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      lineageId: lineageId,
      authScope: authScope,
      conflictPolicy: conflictPolicy,
      conflictPrecondition: conflictPrecondition,
      createdAt: createdAt,
      priority: priority,
      dependencies: dependencies,
      projections: projections,
      state: state,
      attemptCount: attemptCount,
      maxAttempts: maxAttempts,
      maxAge: maxAge,
      nextRunAt: nextRunAt,
      rateLimitBucket: rateLimitBucket,
    );
  }

  /// Opens the queue and publishes the resulting observation.
  Future<void> open() async {
    await _queue.open();
    if (!isClosed) emit(_initialObservation(_queue, _filter));
  }

  /// Closes the borrowed durable queue without closing this cubit.
  Future<void> closeQueue() async {
    await _queue.close();
    if (!isClosed) emit(_initialObservation(_queue, _filter));
  }

  /// Replays admissible durable operations.
  Future<ReplayRunResult> replay({ReplayCancellationToken? cancellationToken}) {
    return _queue.replay(cancellationToken: cancellationToken);
  }

  /// Adds a restart-safe optimistic projection overlay.
  Future<ProjectionOutcome> enqueueProjection(ProjectionOverlay overlay) {
    return _queue.enqueueProjection(overlay);
  }

  /// Applies a confirmed remote projection base.
  Future<ProjectionOutcome> setProjectionRemoteBase(
    QueryKey key,
    Object? value, {
    int? revision,
  }) {
    return _queue.setProjectionRemoteBase(key, value, revision: revision);
  }

  /// Remaps a temporary projection identifier to its server identifier.
  Future<ProjectionOutcome> remapProjectionId({
    required String temporaryId,
    required String serverId,
  }) {
    return _queue.remapProjectionId(
      temporaryId: temporaryId,
      serverId: serverId,
    );
  }

  /// Materializes the current projection view for a query key.
  ProjectionView? materializeProjection(QueryKey key) {
    return _queue.materializeProjection(key);
  }

  /// Completes an optimistic projection after successful replay.
  Future<ProjectionOutcome> completeProjection(
    OperationId operationId,
    Object? result,
  ) {
    return _queue.completeProjection(operationId, result);
  }

  /// Removes an optimistic projection after terminal failure.
  Future<ProjectionOutcome> failProjection(OperationId operationId) {
    return _queue.failProjection(operationId);
  }

  /// Marks an optimistic projection as conflicted.
  Future<ProjectionOutcome> markProjectionConflict(
    OperationId operationId, {
    Map<String, Object?>? conflictEvidence,
  }) {
    return _queue.markProjectionConflict(
      operationId,
      conflictEvidence: conflictEvidence,
    );
  }

  /// Returns one observed operation.
  DurableOperationObservation? observeOperation(
    OperationId operationId, {
    AuthScope? authScope,
  }) {
    return _queue.observeOperation(operationId, authScope: authScope);
  }

  /// Lists observed operations.
  List<DurableOperationObservation> listOperations({
    DurableOperationFilter? filter,
  }) {
    return _queue.listOperations(filter: filter);
  }

  /// Returns retained history for one operation.
  List<DurableHistoryObservation> operationHistory(
    OperationId operationId, {
    AuthScope? authScope,
  }) {
    return _queue.operationHistory(operationId, authScope: authScope);
  }

  /// Retries one dead letter.
  Future<RepairActionResult> retryDeadLetter({
    required OperationId operationId,
    required String idempotencyKey,
    AuthScope? currentAuthScope,
  }) {
    return _queue.retryDeadLetter(
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
    return _queue.repairDeadLetter(
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
    return _queue.discardDeadLetter(
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
    return _queue.restoreQuarantinedOperation(
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      currentAuthScope: currentAuthScope,
    );
  }

  @override
  Future<void> close() async {
    _watchGeneration++;
    await _subscription?.cancel();
    _subscription = null;
    await super.close();
  }
}

/// Descriptive alias for applications that prefer the durable queue name.
typedef DurableMutationQueueCubit = MutationQueueCubit;
