import 'dart:async';

import 'package:fasq/src/mutation/durable_mutation_queue.dart';
import 'package:fasq/src/mutation/sync_engine/codecs/mutation_codec.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/observation/observation.dart';
import 'package:fasq/src/mutation/sync_engine/observation/observation_models.dart';
import 'package:fasq/src/mutation/sync_engine/store/durable_outbox.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = MutationKey(namespace: 'todos', name: 'create');
  final mapCodec = JsonMutationCodec<Map<String, Object?>>(
    encoder: (value) => value,
    decoder: (payload) => Map<String, Object?>.from(payload! as Map),
  );

  test('exposes retained history and redacted dead-letter metadata', () async {
    final operation = _operation(
      operationId: OperationId('dead-letter-operation'),
      key: key,
      state: MutationOperationState.failedTerminal,
      variables: <String, Object?>{'secret': 'must-not-leak'},
    );
    final store = _MemoryOutboxStore(
      snapshot: OutboxSnapshot(
        deadLetters: [
          OutboxDeadLetter(
            operation: operation,
            category: MutationFailureCategory.business,
            messageKey: 'todo.rejected',
            retryable: false,
            repairable: true,
            failedAt: DateTime.utc(2026, 8, 21),
          ),
        ],
        history: [
          OutboxHistoryEntry.validated(
            operationId: OperationId('completed-operation'),
            state: MutationOperationState.succeeded,
            completedAt: DateTime.utc(2026, 8, 20),
            resultProjection: <String, Object?>{'id': 'server-1'},
          ),
        ],
      ),
    );
    final queue = DurableMutationQueue(store: store);

    await queue.open();

    final deadLetter = queue.observeOperation(operation.operationId);
    expect(deadLetter?.recordKind, DurableObservationRecordKind.deadLetter);
    expect(deadLetter?.failure?.messageKey, 'todo.rejected');
    expect(queue.observation.history.single.hasResultProjection, isTrue);
    expect(
      queue.observation.operations.single.toString(),
      isNot(contains('must-not-leak')),
    );
    await queue.close();
  });

  test('watch emits durable initial state and enqueue updates', () async {
    final store = _MemoryOutboxStore();
    final queue = DurableMutationQueue(store: store);
    queue.register<Map<String, Object?>, Map<String, Object?>>(
      key: key,
      codec: mapCodec,
      mutationFn: (variables) async => variables,
    );
    await queue.open();

    final states = <int>[];
    final subscription = queue.watch().listen(
      (snapshot) => states.add(snapshot.operations.length),
    );
    await Future<void>.delayed(Duration.zero);

    await queue.enqueue(
      key: key,
      variables: <String, Object?>{'title': 'offline'},
      operationId: OperationId('watch-operation'),
      idempotencyKey: IdempotencyKey('watch-idempotency'),
      lineageId: LineageId('watch-lineage'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(states, <int>[0, 1]);
    await subscription.cancel();
    await queue.close();
  });

  test(
    'replay updates observation with retained history after restart',
    () async {
      final store = _MemoryOutboxStore();
      final firstQueue = DurableMutationQueue(store: store);
      firstQueue.register<Map<String, Object?>, Map<String, Object?>>(
        key: key,
        codec: mapCodec,
        mutationFn: (variables) async => variables,
      );
      await firstQueue.open();
      await firstQueue.enqueue(
        key: key,
        variables: <String, Object?>{'title': 'offline'},
        operationId: OperationId('restart-operation'),
        idempotencyKey: IdempotencyKey('restart-idempotency'),
        lineageId: LineageId('restart-lineage'),
      );
      await firstQueue.close();

      final secondQueue = DurableMutationQueue(store: store);
      secondQueue.register<Map<String, Object?>, Map<String, Object?>>(
        key: key,
        codec: mapCodec,
        mutationFn: (variables) async => variables,
      );
      await secondQueue.open();
      final initial = <DurableQueueObservation>[];
      final subscription = secondQueue.watch().listen(initial.add);
      await Future<void>.delayed(Duration.zero);
      expect(
        initial.single.operations.single.operationId.value,
        'restart-operation',
      );
      await subscription.cancel();

      await secondQueue.replay();

      expect(
        secondQueue.observeOperation(OperationId('restart-operation')),
        isNull,
      );
      expect(
        secondQueue.observation.history.single.operationId.value,
        'restart-operation',
      );
      await secondQueue.close();
    },
  );

  test('auth scope filter matches exact scope only', () async {
    final key = MutationKey(namespace: 'todos', name: 'authenticated');
    final scopeA = AuthScope(
      principalId: 'user-a',
      tenantId: 'tenant',
      authRealm: 'realm',
    );
    final scopeB = AuthScope(
      principalId: 'user-b',
      tenantId: 'tenant',
      authRealm: 'realm',
    );
    final queue = DurableMutationQueue(store: _MemoryOutboxStore());
    queue.register<Map<String, Object?>, Map<String, Object?>>(
      key: key,
      codec: mapCodec,
      authPolicy: AuthPolicy.required,
      mutationFn: (variables) async => variables,
    );
    await queue.open();
    await queue.enqueue(
      key: key,
      variables: <String, Object?>{},
      authScope: scopeA,
      operationId: OperationId('scope-a'),
      idempotencyKey: IdempotencyKey('scope-a-idempotency'),
      lineageId: LineageId('scope-a-lineage'),
    );
    await queue.enqueue(
      key: key,
      variables: <String, Object?>{},
      authScope: scopeB,
      operationId: OperationId('scope-b'),
      idempotencyKey: IdempotencyKey('scope-b-idempotency'),
      lineageId: LineageId('scope-b-lineage'),
    );

    final visible = queue.listOperations(
      filter: DurableObservationFilter(
        authScope: scopeA,
        includeUnauthenticated: false,
      ),
    );
    expect(visible.map((item) => item.operationId.value), <String>['scope-a']);
    await queue.close();
  });
}

MutationOperation _operation({
  required OperationId operationId,
  required MutationKey key,
  required MutationOperationState state,
  required Object? variables,
}) {
  return MutationOperation(
    operationId: operationId,
    mutationKey: key,
    variables: variables,
    createdAt: DateTime.utc(2026, 8, 21),
    idempotencyKey: IdempotencyKey('${operationId.value}-idempotency'),
    lineageId: LineageId('${operationId.value}-lineage'),
    authPolicy: AuthPolicy.none,
    state: state,
  );
}

class _MemoryOutboxStore implements DurableOutboxStore {
  _MemoryOutboxStore({OutboxSnapshot? snapshot})
    : _snapshot = snapshot ?? OutboxSnapshot();

  OutboxSnapshot _snapshot;
  int _generation = 0;
  bool _isOpen = false;

  @override
  Future<OutboxSnapshot> open() async {
    _isOpen = true;
    return _snapshot;
  }

  @override
  OutboxSnapshot get snapshot => _snapshot;

  @override
  int get generation => _generation;

  @override
  Future<OutboxSnapshot> transact(
    DurableOutboxTransaction transaction, {
    int? expectedGeneration,
  }) async {
    if (!_isOpen) throw StateError('store is closed');
    _snapshot = transaction(_snapshot);
    _generation++;
    return _snapshot;
  }

  @override
  Future<void> close() async {
    _isOpen = false;
  }
}
