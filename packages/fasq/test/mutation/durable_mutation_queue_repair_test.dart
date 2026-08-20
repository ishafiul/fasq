import 'package:fasq/src/mutation/durable_mutation_queue.dart';
import 'package:fasq/src/mutation/sync_engine/conflict/conflict_repair.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/observation/observation_models.dart';
import 'package:fasq/src/mutation/sync_engine/repair/repair.dart';
import 'package:fasq/src/mutation/sync_engine/store/durable_outbox.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'queue exposes explicit retry and publishes the repaired state',
    () async {
      final operation = _operation('failed');
      final store = _MemoryStore(
        OutboxSnapshot(
          deadLetters: [
            OutboxDeadLetter(
              operation: operation,
              category: MutationFailureCategory.business,
              messageKey: 'sync.business.failure',
              retryable: true,
              repairable: false,
              failedAt: DateTime.utc(2026, 8, 21),
            ),
          ],
        ),
      );
      final queue = DurableMutationQueue(
        store: store,
        repairIdentityFactory: _Identities(),
      );

      await queue.open();
      final result = await queue.retryDeadLetter(
        operationId: operation.operationId,
        idempotencyKey: 'retry-request',
      );

      expect(result.createdOperation, isTrue);
      expect(queue.listOperations(), hasLength(2));
      expect(
        queue.listOperations().where(
          (item) => item.recordKind == DurableObservationRecordKind.active,
        ),
        hasLength(1),
      );
      expect(
        queue.observation.aggregateState,
        DurableQueueAggregateState.attentionRequired,
      );
      await queue.close();
    },
  );

  test('queue repair denies a different authenticated scope', () async {
    final owner = _scope('owner');
    final operation = _operation('scoped', scope: owner);
    final store = _MemoryStore(
      OutboxSnapshot(
        deadLetters: [
          OutboxDeadLetter(
            operation: operation,
            category: MutationFailureCategory.business,
            messageKey: 'sync.business.failure',
            retryable: true,
            repairable: false,
            failedAt: DateTime.utc(2026, 8, 21),
          ),
        ],
      ),
    );
    final queue = DurableMutationQueue(store: store);

    await queue.open();
    await expectLater(
      queue.retryDeadLetter(
        operationId: operation.operationId,
        idempotencyKey: 'wrong-scope-request',
        currentAuthScope: _scope('other'),
      ),
      throwsA(
        isA<RepairActionException>().having(
          (error) => error.code,
          'code',
          RepairActionErrorCode.authScopeMismatch,
        ),
      ),
    );
    await queue.close();
  });
}

AuthScope _scope(String principalId) => AuthScope(
  principalId: principalId,
  tenantId: 'tenant',
  authRealm: 'test',
);

MutationOperation _operation(String id, {AuthScope? scope}) =>
    MutationOperation(
      operationId: OperationId(id),
      mutationKey: MutationKey(namespace: 'test', name: 'save'),
      variables: const <String, Object?>{'value': 'private'},
      createdAt: DateTime.utc(2026),
      idempotencyKey: IdempotencyKey('idempotency-$id'),
      lineageId: LineageId('lineage-$id'),
      authPolicy: scope == null ? AuthPolicy.none : AuthPolicy.required,
      authScope: scope,
      state: MutationOperationState.failedTerminal,
    );

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
      throw StateError('generation mismatch');
    }
    _snapshot = transaction(_snapshot);
    _generation++;
    return _snapshot;
  }

  @override
  Future<void> close() async {}
}
