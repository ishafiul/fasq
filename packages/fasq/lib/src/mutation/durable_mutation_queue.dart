import 'package:fasq/src/mutation/sync_engine/codecs/mutation_codec.dart';
import 'package:fasq/src/mutation/sync_engine/execution/auth_session.dart';
import 'package:fasq/src/mutation/sync_engine/execution/execution_context.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/replay/replay_coordinator.dart';
import 'package:fasq/src/mutation/sync_engine/replay/retry_policy.dart';
import 'package:fasq/src/mutation/sync_engine/store/durable_outbox.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';
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
    );
  }

  DurableMutationQueue._({
    required DurableOutboxStore store,
    required MutationRegistrationRegistry registrations,
    required DateTime Function() now,
    required String Function() idGenerator,
    required DurableReplayCoordinator coordinator,
  }) : _store = store,
       _registrations = registrations,
       _now = now,
       _idGenerator = idGenerator,
       _coordinator = coordinator;

  static const _uuid = Uuid();

  final DurableOutboxStore _store;
  final MutationRegistrationRegistry _registrations;
  final DateTime Function() _now;
  final String Function() _idGenerator;
  final DurableReplayCoordinator _coordinator;
  bool _isOpen = false;

  /// Whether the queue currently owns an open durable store.
  bool get isOpen => _isOpen;

  /// Snapshot acknowledged by the durable store.
  OutboxSnapshot get snapshot => _store.snapshot;

  /// Current durable store generation.
  int get generation => _store.generation;

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
    DateTime? createdAt,
    int priority = 0,
    List<MutationDependency> dependencies = const <MutationDependency>[],
    List<MutationProjectionDescriptor> projections =
        const <MutationProjectionDescriptor>[],
    int maxAttempts = 5,
    Duration maxAge = const Duration(days: 30),
    String? rateLimitBucket,
  }) async {
    _requireOpen();
    final encodedVariables = _registrations.encodeVariables(key, variables);
    final operation = MutationOperation(
      operationId: operationId ?? OperationId(_idGenerator()),
      mutationKey: key,
      variables: encodedVariables,
      createdAt: createdAt ?? _now(),
      idempotencyKey: idempotencyKey ?? IdempotencyKey(_idGenerator()),
      lineageId: lineageId ?? LineageId(_idGenerator()),
      authPolicy: _registrations.authPolicyFor(key),
      authScope: authScope,
      state: MutationOperationState.pending,
      priority: priority,
      dependencies: dependencies,
      projections: projections,
      maxAttempts: maxAttempts,
      maxAge: maxAge,
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
  }) => _coordinator.replay(cancellationToken: cancellationToken);

  /// Compatibility alias for callers that previously requested queue work
  /// through `processQueue`.
  Future<ReplayRunResult> processQueue({
    ReplayCancellationToken? cancellationToken,
  }) => replay(cancellationToken: cancellationToken);

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
