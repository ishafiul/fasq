import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/client_provider.dart';

/// Riverpod adapter for the public durable mutation queue observation surface.
///
/// The notifier observes redacted queue metadata and forwards queue commands.
/// It borrows the queue from the caller or runtime; disposing this provider
/// only cancels its watcher and never closes the runtime-owned queue.
class MutationQueueNotifier
    extends AutoDisposeNotifier<DurableQueueObservation> {
  DurableMutationQueue? _providedQueue;
  FasqRuntime? _providedRuntime;
  DurableOperationFilter? _filter;

  DurableMutationQueue? _queue;
  StreamSubscription<DurableQueueObservation>? _subscription;
  var _cleanedUp = false;
  var _watchGeneration = 0;

  /// Initializes the notifier from an explicit queue or runtime.
  void configure({
    DurableMutationQueue? queue,
    FasqRuntime? runtime,
    DurableOperationFilter? filter,
  }) {
    assert(
      queue == null || runtime == null,
      'Provide either queue or runtime, not both.',
    );
    _providedQueue = queue;
    _providedRuntime = runtime;
    _filter = filter;
  }

  @override
  DurableQueueObservation build() {
    _cleanup();
    _cleanedUp = false;
    final keepAlive = ref.keepAlive();
    ref.onCancel(keepAlive.close);
    final runtime = _providedRuntime ?? ref.watch(fasqRuntimeProvider);
    final queue = _providedQueue ?? runtime?.mutationQueue;
    if (queue == null) {
      throw StateError(
        'MutationQueueNotifier requires a durable queue or runtime with one.',
      );
    }
    _queue = queue;
    ref.onDispose(_cleanup);
    final initial = _initialObservation(queue, _filter);
    state = initial;
    _subscribe();
    return initial;
  }

  /// The borrowed core queue.
  DurableMutationQueue get queue {
    final value = _queue;
    if (value == null) {
      throw StateError('The MutationQueueNotifier has not been initialized.');
    }
    return value;
  }

  /// Current filtered public-safe observation.
  DurableQueueObservation get observation => state;

  /// Current durable outbox snapshot.
  OutboxSnapshot get snapshot => queue.snapshot;

  /// Whether the durable outbox is open.
  bool get isOpen => queue.isOpen;

  /// Whether the configured connectivity source reports online.
  bool get isOnline => queue.isOnline;

  /// Current durable-store generation.
  int get generation => queue.generation;

  /// Recovery diagnostics, when available.
  DurableOutboxRecovery? get recovery => queue.recovery;

  /// Current projection state, when configured.
  ProjectionState? get projectionState => queue.projectionState;

  /// Current observation auth scope.
  AuthScope? get currentAuthScope => queue.currentAuthScope;

  /// Aggregate state for the current filtered observation.
  DurableQueueAggregateState get aggregateState => state.aggregateState;

  /// Aggregate state for an optional exact auth scope.
  DurableQueueAggregateState aggregateStateFor({AuthScope? authScope}) {
    final configuredFilter = _filter ?? const DurableOperationFilter();
    final boundFilter = DurableOperationFilter(
      operationId: configuredFilter.operationId,
      mutationKey: configuredFilter.mutationKey,
      states: configuredFilter.states,
      authScope:
          authScope ?? queue.currentAuthScope ?? configuredFilter.authScope,
      includeUnauthenticated: configuredFilter.includeUnauthenticated,
      scopeBound: true,
      includeDeadLetters: configuredFilter.includeDeadLetters,
      limit: configuredFilter.limit,
    );
    return DurableObservation.fromSnapshot(
      queue.snapshot,
    ).queueObservation(filter: boundFilter).aggregateState;
  }

  /// Installs a new filter and reconnects the queue watcher.
  void setFilter(DurableOperationFilter? filter) {
    if (_cleanedUp) return;
    _filter = filter;
    unawaited(_subscription?.cancel());
    state = _initialObservation(queue, filter);
    _subscribe();
  }

  void _subscribe() {
    final generation = ++_watchGeneration;
    _subscription = queue.watch(filter: _filter).listen((nextObservation) {
      if (!_cleanedUp && generation == _watchGeneration) {
        state = nextObservation;
      }
    });
  }

  /// Watches queue observations directly through the core stream.
  Stream<DurableQueueObservation> watch({DurableOperationFilter? filter}) {
    return queue.watch(filter: filter);
  }

  /// Whether a mutation key has a durable replay registration.
  bool hasRegistration(MutationKey key) => queue.hasRegistration(key);

  /// Whether an operation is retained in active, dead-letter, or history data.
  bool hasRetainedOperation(OperationId operationId) {
    return queue.hasRetainedOperation(operationId);
  }

  /// Whether an idempotency key is retained by the queue.
  bool hasRetainedIdempotencyKey(IdempotencyKey idempotencyKey) {
    return queue.hasRetainedIdempotencyKey(idempotencyKey);
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
    queue.register<TData, TVariables>(
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
    return queue.enqueue<TVariables>(
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

  /// Opens the queue and publishes its resulting observation.
  Future<void> open() async {
    await queue.open();
    if (!_cleanedUp) state = _initialObservation(queue, _filter);
  }

  /// Closes the borrowed queue. It does not close the runtime itself.
  Future<void> closeQueue() async {
    await queue.close();
    if (!_cleanedUp) state = _initialObservation(queue, _filter);
  }

  /// Replays currently admissible durable operations.
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

  /// Remaps a temporary projection identifier.
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

  /// Removes an optimistic projection after terminal failure.
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

  /// Restores one quarantined operation after scope validation.
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

  static DurableQueueObservation _initialObservation(
    DurableMutationQueue queue,
    DurableOperationFilter? filter,
  ) {
    if (filter == null) return queue.observation;
    return filterQueueObservation(queue.observation, filter);
  }

  void _cleanup() {
    if (_cleanedUp) return;
    _cleanedUp = true;
    _watchGeneration++;
    unawaited(_subscription?.cancel());
    _subscription = null;
  }
}

/// Creates a Riverpod provider that observes a durable mutation queue.
AutoDisposeNotifierProvider<MutationQueueNotifier, DurableQueueObservation>
mutationQueueProvider({
  DurableMutationQueue? queue,
  FasqRuntime? runtime,
  DurableOperationFilter? filter,
}) {
  assert(
    queue == null || runtime == null,
    'Provide either queue or runtime, not both.',
  );
  return AutoDisposeNotifierProvider<
    MutationQueueNotifier,
    DurableQueueObservation
  >(() {
    final notifier = MutationQueueNotifier();
    notifier.configure(queue: queue, runtime: runtime, filter: filter);
    return notifier;
  });
}
