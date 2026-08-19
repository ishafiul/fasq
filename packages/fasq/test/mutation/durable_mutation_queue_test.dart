// Registration calls intentionally use one receiver per test; the repository
// enables a conflicting cascade lint for this form.
// ignore_for_file: cascade_invocations

import 'package:fasq/src/mutation/durable_mutation_queue.dart';
import 'package:fasq/src/mutation/sync_engine/codecs/mutation_codec.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/store/durable_outbox.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = MutationKey(namespace: 'todos', name: 'create');

  test('acknowledges enqueue only after durable transaction commits', () async {
    final store = _MemoryOutboxStore();
    final queue = DurableMutationQueue(
      store: store,
      now: () => DateTime.utc(2026, 8, 20),
      idGenerator: _idGenerator(<String>[
        'generated-operation',
        'generated-idempotency',
        'generated-lineage',
      ]),
    );
    queue.register<Map<String, Object?>, Map<String, Object?>>(
      key: key,
      codec: _mapCodec,
      mutationFn: (variables) async => variables,
    );

    await queue.open();
    final acknowledgement = await queue.enqueue(
      key: key,
      variables: <String, Object?>{'title': 'offline'},
    );

    expect(store.transactionCount, 1);
    expect(acknowledgement.operationId.value, 'generated-operation');
    expect(acknowledgement.idempotencyKey.value, 'generated-idempotency');
    expect(acknowledgement.lineageId.value, 'generated-lineage');
    expect(queue.snapshot.active.single, acknowledgement.operation);
    expect(queue.generation, 1);
    await queue.close();
  });

  test(
    'rejects unknown registrations and non-JSON encoded variables',
    () async {
      final store = _MemoryOutboxStore();
      final queue = DurableMutationQueue(store: store);
      await queue.open();

      expect(
        () => queue.enqueue(key: key, variables: <String, Object?>{}),
        throwsA(isA<UnknownMutationKeyException>()),
      );

      final invalidKey = MutationKey(namespace: 'todos', name: 'invalid');
      queue.register<Object?, Object?>(
        key: invalidKey,
        codec: JsonMutationCodec<Object?>(
          encoder: (_) => DateTime.utc(2026),
          decoder: (payload) => payload,
        ),
        mutationFn: (_) async => null,
      );
      expect(
        () => queue.enqueue(key: invalidKey, variables: 'value'),
        throwsA(isA<InvalidMutationPayloadException>()),
      );
      expect(store.transactionCount, 0);
      await queue.close();
    },
  );

  test(
    'reopens and replays through the explicitly registered mutationFn',
    () async {
      final store = _MemoryOutboxStore();
      final operationId = OperationId('operation-1');
      final idempotencyKey = IdempotencyKey('idempotency-1');
      final lineageId = LineageId('lineage-1');
      var calls = 0;
      final firstQueue = DurableMutationQueue(store: store);
      firstQueue.register<Map<String, Object?>, Map<String, Object?>>(
        key: key,
        codec: _mapCodec,
        mutationFn: (variables) async => <String, Object?>{
          'created': variables['title'],
        },
      );
      await firstQueue.open();
      final acknowledgement = await firstQueue.enqueue(
        key: key,
        variables: <String, Object?>{'title': 'offline'},
        operationId: operationId,
        idempotencyKey: idempotencyKey,
        lineageId: lineageId,
      );
      await firstQueue.close();

      final secondQueue = DurableMutationQueue(store: store);
      secondQueue.register<Map<String, Object?>, Map<String, Object?>>(
        key: key,
        codec: _mapCodec,
        mutationFn: (variables) async {
          calls++;
          return <String, Object?>{'created': variables['title']};
        },
      );
      await secondQueue.open();
      final report = await secondQueue.replay();

      expect(acknowledgement.operationId, operationId);
      expect(report.executedOperationIds, <OperationId>[operationId]);
      expect(calls, 1);
      expect(secondQueue.snapshot.active, isEmpty);
      expect(secondQueue.snapshot.history.single.operationId, operationId);
      expect(
        secondQueue.snapshot.history.single.state,
        MutationOperationState.succeeded,
      );
      await secondQueue.close();
    },
  );

  test(
    'preserves typed storage failures and translates unknown backend errors',
    () async {
      final typedStore = _MemoryOutboxStore(
        failure: const OutboxCapacityExceededException(),
      );
      final typedQueue = DurableMutationQueue(store: typedStore);
      typedQueue.register<Map<String, Object?>, Map<String, Object?>>(
        key: key,
        codec: _mapCodec,
        mutationFn: (variables) async => variables,
      );
      await typedQueue.open();
      expect(
        () => typedQueue.enqueue(key: key, variables: <String, Object?>{}),
        throwsA(isA<OutboxCapacityExceededException>()),
      );
      await typedQueue.close();

      final unknownStore = _MemoryOutboxStore(failure: StateError('disk down'));
      final unknownQueue = DurableMutationQueue(store: unknownStore);
      unknownQueue.register<Map<String, Object?>, Map<String, Object?>>(
        key: key,
        codec: _mapCodec,
        mutationFn: (variables) async => variables,
      );
      await unknownQueue.open();
      expect(
        () => unknownQueue.enqueue(key: key, variables: <String, Object?>{}),
        throwsA(isA<DurableMutationQueueStorageException>()),
      );
      await unknownQueue.close();
    },
  );

  test('rejects retained duplicate operation identities', () async {
    final store = _MemoryOutboxStore();
    final queue = DurableMutationQueue(store: store);
    queue.register<Map<String, Object?>, Map<String, Object?>>(
      key: key,
      codec: _mapCodec,
      mutationFn: (variables) async => variables,
    );
    await queue.open();
    final operationId = OperationId('duplicate');
    await queue.enqueue(
      key: key,
      variables: <String, Object?>{},
      operationId: operationId,
      idempotencyKey: IdempotencyKey('first'),
      lineageId: LineageId('first'),
    );

    expect(
      () => queue.enqueue(
        key: key,
        variables: <String, Object?>{},
        operationId: operationId,
        idempotencyKey: IdempotencyKey('second'),
        lineageId: LineageId('second'),
      ),
      throwsA(isA<DuplicateMutationOperationException>()),
    );
    await queue.close();
  });

  test('rejects non-replayable enqueue states', () async {
    final queue = DurableMutationQueue(store: _MemoryOutboxStore());
    queue.register<Map<String, Object?>, Map<String, Object?>>(
      key: key,
      codec: _mapCodec,
      mutationFn: (variables) async => variables,
    );
    await queue.open();

    expect(
      () => queue.enqueue(
        key: key,
        variables: <String, Object?>{},
        state: MutationOperationState.succeeded,
      ),
      throwsA(isA<InvalidMutationEnqueueStateException>()),
    );
    expect(queue.snapshot.active, isEmpty);
    await queue.close();
  });

  test(
    'keeps processQueue as an explicit replay compatibility alias',
    () async {
      final store = _MemoryOutboxStore();
      var calls = 0;
      final queue = DurableMutationQueue(store: store);
      queue.register<Map<String, Object?>, Map<String, Object?>>(
        key: key,
        codec: _mapCodec,
        mutationFn: (variables) async {
          calls++;
          return variables;
        },
      );
      await queue.open();
      final operation = await queue.enqueue(
        key: key,
        variables: <String, Object?>{'title': 'compat'},
      );

      final report = await queue.processQueue();

      expect(report.executedOperationIds, <OperationId>[operation.operationId]);
      expect(calls, 1);
      expect(queue.snapshot.active, isEmpty);
      await queue.close();
    },
  );
}

final _mapCodec = JsonMutationCodec<Map<String, Object?>>(
  encoder: (value) => value,
  decoder: (payload) {
    if (payload is! Map<Object?, Object?> ||
        payload.keys.any((key) => key is! String)) {
      throw const InvalidMutationPayloadException('Expected a JSON object');
    }
    return Map<String, Object?>.fromEntries(
      payload.entries.map(
        (entry) => MapEntry(entry.key! as String, entry.value),
      ),
    );
  },
);

String Function() _idGenerator(List<String> ids) =>
    () => ids.removeAt(0);

class _MemoryOutboxStore implements DurableOutboxStore {
  _MemoryOutboxStore({this.failure});

  final Object? failure;
  OutboxSnapshot _snapshot = OutboxSnapshot();
  int _generation = 0;
  bool _isOpen = false;
  int transactionCount = 0;

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
    if (expectedGeneration != null && expectedGeneration != _generation) {
      throw const OutboxGenerationConflictException();
    }
    final error = failure;
    if (error != null) {
      Error.throwWithStackTrace(error, StackTrace.current);
    }
    _snapshot = transaction(_snapshot);
    _generation++;
    transactionCount++;
    return _snapshot;
  }

  @override
  Future<void> close() async {
    _isOpen = false;
  }
}
