import 'package:fasq/src/mutation/sync_engine/conflict/conflict_repair.dart';
import 'package:fasq/src/mutation/sync_engine/conflict/conflict_policy.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/repair/repair.dart';
import 'package:fasq/src/mutation/sync_engine/store/durable_outbox.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('retry is idempotent and preserves lineage', () async {
    final original = _operation(
      'failed',
      MutationOperationState.failedTerminal,
    );
    final store = _store(deadLetters: [_deadLetter(original, retryable: true)]);
    final service = DurableRepairService(
      store: store,
      identities: _Identities(),
    );

    final first = await service.retry(
      operationId: original.operationId,
      idempotencyKey: 'request-1',
    );
    final second = await service.retry(
      operationId: original.operationId,
      idempotencyKey: 'request-1',
    );

    expect(first.idempotentReplay, isFalse);
    expect(second.idempotentReplay, isTrue);
    expect(second.operationId, first.operationId);
    expect(first.operationId, isNot(original.operationId));
    expect(first.idempotencyKey, isNot(original.idempotencyKey));
    expect(first.lineageId, original.lineageId);
    expect(store.snapshot.active, hasLength(1));
    expect(store.snapshot.deadLetters, hasLength(1));
  });

  test('denies mismatched auth scope and emits redacted telemetry', () async {
    final original = _operation(
      'scoped',
      MutationOperationState.failedTerminal,
      scope: _scope('user-1'),
    );
    final events = <RepairTelemetryEvent>[];
    final service = DurableRepairService(
      store: _store(deadLetters: [_deadLetter(original, retryable: true)]),
      identities: _Identities(),
      telemetry: events.add,
    );

    await expectLater(
      service.retry(
        operationId: original.operationId,
        idempotencyKey: 'secret-request',
        currentAuthScope: _scope('user-2'),
      ),
      throwsA(
        isA<RepairActionException>().having(
          (error) => error.code,
          'code',
          RepairActionErrorCode.authScopeMismatch,
        ),
      ),
    );
    expect(events.single.outcome, 'denied');
    expect(
      events.single.metadata.toString(),
      isNot(contains('secret-request')),
    );
    expect(events.single.metadata.toString(), isNot(contains('user-1')));
  });

  test(
    'replacement preserves evidence and redacts replacement variables',
    () async {
      final original = _operation(
        'conflict',
        MutationOperationState.failedTerminal,
        variables: const {'value': 'original-private'},
        conflictPrecondition: ConflictPrecondition('version-1'),
      );
      final deadLetter = _deadLetter(
        original,
        repairable: true,
        category: MutationFailureCategory.conflict,
        conflictEvidence: const {'messageKey': 'sync.conflict.stale'},
      );
      final events = <RepairTelemetryEvent>[];
      final store = _store(deadLetters: [deadLetter]);
      final service = DurableRepairService(
        store: store,
        identities: _Identities(),
        telemetry: events.add,
      );

      final result = await service.repair(
        operationId: original.operationId,
        idempotencyKey: 'replace-1',
        variables: const {'value': 'replacement-private'},
        conflictPrecondition: ConflictPrecondition('version-2'),
      );
      final replacement = store.snapshot.active.single;

      expect(result.createdOperation, isTrue);
      expect(replacement.lineageId, original.lineageId);
      expect(store.snapshot.deadLetters.single.conflictEvidence, {
        'messageKey': 'sync.conflict.stale',
      });
      expect(
        result.toJson().toString(),
        isNot(contains('replacement-private')),
      );
      expect(
        events.single.metadata.toString(),
        isNot(contains('original-private')),
      );
    },
  );

  test(
    'repair rebinds blocked dependents and discard leaves them blocked',
    () async {
      final parent = _operation(
        'parent',
        MutationOperationState.failedTerminal,
      );
      final child = _operation(
        'child',
        MutationOperationState.pending,
        dependencies: [
          MutationDependency(parentOperationId: parent.operationId),
        ],
      );
      final repairStore = _store(
        active: [child],
        deadLetters: [_deadLetter(parent, repairable: true)],
      );
      final repaired =
          await DurableRepairService(
            store: repairStore,
            identities: _Identities(),
          ).repair(
            operationId: parent.operationId,
            idempotencyKey: 'repair-parent',
            variables: const {'value': 'fixed'},
          );
      final rebound = repairStore.snapshot.active.firstWhere(
        (operation) => operation.operationId == child.operationId,
      );
      expect(repaired.blockedDependentCount, 1);
      expect(rebound.state, MutationOperationState.blocked);
      expect(
        rebound.dependencies.single.parentOperationId,
        repaired.operationId,
      );

      final discardStore = _store(
        active: [child],
        deadLetters: [_deadLetter(parent)],
      );
      final discarded =
          await DurableRepairService(
            store: discardStore,
            identities: _Identities(),
          ).discard(
            operationId: parent.operationId,
            idempotencyKey: 'discard-parent',
          );
      expect(discarded.blockedDependentCount, 1);
      expect(
        discardStore.snapshot.active.single.state,
        MutationOperationState.blocked,
      );
    },
  );

  test('quarantine restore returns exact operation to pending', () async {
    final scope = _scope('user-1');
    final operation = _operation(
      'quarantined',
      MutationOperationState.quarantined,
      scope: scope,
    );
    final store = _store(active: [operation]);
    final result =
        await DurableRepairService(
          store: store,
          identities: _Identities(),
        ).restoreQuarantine(
          operationId: operation.operationId,
          idempotencyKey: 'restore-1',
          currentAuthScope: scope,
        );

    expect(result.createdOperation, isFalse);
    expect(store.snapshot.active.single.operationId, operation.operationId);
    expect(store.snapshot.active.single.state, MutationOperationState.pending);
  });

  test('conflict dead letters require explicit fresh preconditions', () async {
    final oldPrecondition = ConflictPrecondition('version-1');
    final original = _operation(
      'conflict-retry',
      MutationOperationState.failedTerminal,
      conflictPrecondition: oldPrecondition,
    );
    final store = _store(
      deadLetters: [
        _deadLetter(
          original,
          category: MutationFailureCategory.conflict,
          retryable: true,
          repairable: true,
        ),
      ],
    );
    final service = DurableRepairService(
      store: store,
      identities: _Identities(),
    );

    await expectLater(
      service.retry(
        operationId: original.operationId,
        idempotencyKey: 'conflict-retry',
      ),
      throwsA(
        isA<RepairActionException>().having(
          (error) => error.code,
          'code',
          RepairActionErrorCode.notRetryable,
        ),
      ),
    );
    await expectLater(
      service.repair(
        operationId: original.operationId,
        idempotencyKey: 'conflict-replace-stale',
        variables: const {'value': 'fixed'},
        conflictPrecondition: oldPrecondition,
      ),
      throwsA(
        isA<RepairActionException>().having(
          (error) => error.code,
          'code',
          RepairActionErrorCode.conflictPreconditionRequired,
        ),
      ),
    );
    final result = await service.repair(
      operationId: original.operationId,
      idempotencyKey: 'conflict-replace-fresh',
      variables: const {'value': 'fixed'},
      conflictPrecondition: ConflictPrecondition('version-2'),
    );
    expect(
      store.snapshot.active.single.conflictPrecondition?.token,
      'version-2',
    );
    expect(result.createdOperation, isTrue);
  });

  test('discard writes visible audit history and cannot be repeated', () async {
    final original = _operation(
      'discarded',
      MutationOperationState.failedTerminal,
    );
    final store = _store(deadLetters: [_deadLetter(original)]);
    final service = DurableRepairService(
      store: store,
      identities: _Identities(),
    );

    await service.discard(
      operationId: original.operationId,
      idempotencyKey: 'discard-once',
    );

    expect(
      store.snapshot.history.single.state,
      MutationOperationState.discarded,
    );
    await expectLater(
      service.discard(
        operationId: original.operationId,
        idempotencyKey: 'discard-twice',
      ),
      throwsA(
        isA<RepairActionException>().having(
          (error) => error.code,
          'code',
          RepairActionErrorCode.invalidState,
        ),
      ),
    );
  });
}

AuthScope _scope(String principalId) => AuthScope(
  principalId: principalId,
  tenantId: 'tenant-1',
  authRealm: 'test',
);

MutationOperation _operation(
  String id,
  MutationOperationState state, {
  AuthScope? scope,
  Object? variables = const {'value': 'private'},
  List<MutationDependency> dependencies = const [],
  ConflictPrecondition? conflictPrecondition,
}) => MutationOperation(
  operationId: OperationId(id),
  mutationKey: MutationKey(namespace: 'test', name: 'save'),
  variables: variables,
  createdAt: DateTime.utc(2026),
  idempotencyKey: IdempotencyKey('idempotency-$id'),
  lineageId: LineageId('lineage-root'),
  authPolicy: scope == null ? AuthPolicy.none : AuthPolicy.required,
  conflictPolicy: conflictPrecondition == null
      ? ConflictPolicy.none
      : ConflictPolicy.required,
  conflictPrecondition: conflictPrecondition,
  authScope: scope,
  state: state,
  dependencies: dependencies,
);

OutboxDeadLetter _deadLetter(
  MutationOperation operation, {
  MutationFailureCategory category = MutationFailureCategory.business,
  bool retryable = false,
  bool repairable = false,
  Map<String, Object?>? conflictEvidence,
}) => OutboxDeadLetter(
  operation: operation,
  category: category,
  messageKey: 'sync.test.failure',
  retryable: retryable,
  repairable: repairable,
  failedAt: DateTime.utc(2026, 1, 2),
  conflictEvidence: conflictEvidence,
);

_MemoryStore _store({
  List<MutationOperation> active = const [],
  List<OutboxDeadLetter> deadLetters = const [],
}) => _MemoryStore(OutboxSnapshot(active: active, deadLetters: deadLetters));

class _Identities implements RepairIdentityFactory {
  var _counter = 0;

  @override
  OperationId newOperationId() => OperationId('repair-operation-${_counter++}');

  @override
  IdempotencyKey newIdempotencyKey() =>
      IdempotencyKey('repair-idempotency-${_counter++}');
}

class _MemoryStore implements DurableOutboxStore {
  _MemoryStore(this._snapshot);

  OutboxSnapshot _snapshot;
  var _generation = 0;

  @override
  Future<OutboxSnapshot> open() async => _snapshot;

  @override
  OutboxSnapshot get snapshot => _snapshot;

  @override
  int get generation => _generation;

  @override
  Future<OutboxSnapshot> transact(
    DurableOutboxTransaction transaction, {
    int? expectedGeneration,
  }) async {
    if (expectedGeneration != null && expectedGeneration != _generation) {
      throw const OutboxGenerationConflictException();
    }
    _snapshot = transaction(_snapshot);
    _generation++;
    return _snapshot;
  }

  @override
  Future<void> close() async {}
}
