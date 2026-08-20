import 'package:fasq/src/mutation/sync_engine/conflict/conflict_repair.dart';
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
      );
      final deadLetter = _deadLetter(
        original,
        repairable: true,
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
}) => MutationOperation(
  operationId: OperationId(id),
  mutationKey: MutationKey(namespace: 'test', name: 'save'),
  variables: variables,
  createdAt: DateTime.utc(2026),
  idempotencyKey: IdempotencyKey('idempotency-$id'),
  lineageId: LineageId('lineage-root'),
  authPolicy: scope == null ? AuthPolicy.none : AuthPolicy.required,
  authScope: scope,
  state: state,
  dependencies: dependencies,
);

OutboxDeadLetter _deadLetter(
  MutationOperation operation, {
  bool retryable = false,
  bool repairable = false,
  Map<String, Object?>? conflictEvidence,
}) => OutboxDeadLetter(
  operation: operation,
  category: MutationFailureCategory.conflict,
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
