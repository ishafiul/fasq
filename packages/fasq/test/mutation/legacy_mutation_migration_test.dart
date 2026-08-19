import 'dart:convert';

import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late OfflineQueueManager legacyQueue;

  setUp(() async {
    legacyQueue = OfflineQueueManager.instance();
    await legacyQueue.resetForTesting();
  });

  tearDown(OfflineQueueManager.resetForTestingStatic);

  test('moves legacy nodes into durable storage and replays them', () async {
    final key = MutationKey(namespace: 'legacy', name: 'create');
    var calls = 0;
    final durableQueue = DurableMutationQueue(store: _MemoryOutboxStore());
    final migrator = LegacyMutationQueueMigrator(
      registrations: {
        'legacy-create':
            TypedLegacyMutationRegistration<String, Map<String, Object?>>(
              mutationType: 'legacy-create',
              key: key,
              codec: _mapCodec,
              mutationFn: (variables) async {
                calls++;
                return 'created:${variables['title']}';
              },
            ),
      },
    );

    await legacyQueue.enqueue(
      'legacy-key',
      'legacy-create',
      <String, Object?>{'title': 'offline'},
      idempotencyKey: 'legacy-idempotency',
      maxRetries: 4,
    );
    final legacyNode = legacyQueue.entries.single;

    final report = await migrator.migrate(
      source: legacyQueue,
      destination: durableQueue,
      removeSourceAfterCommit: false,
    );

    expect(report.migratedCount, 1);
    expect(report.migratedOperationIds.single.value, legacyNode.id);
    expect(legacyQueue.entries, hasLength(1));
    expect(
      durableQueue.snapshot.active.single.operationId.value,
      legacyNode.id,
    );
    expect(
      durableQueue.snapshot.active.single.idempotencyKey.value,
      'legacy-idempotency',
    );
    expect(durableQueue.snapshot.active.single.mutationKey, key);

    final rerun = await migrator.migrate(
      source: legacyQueue,
      destination: durableQueue,
    );

    expect(rerun.migratedCount, 0);
    expect(rerun.alreadyPresentOperationIds.single.value, legacyNode.id);
    expect(legacyQueue.entries, isEmpty);

    final replay = await durableQueue.replay();

    expect(replay.didExecute, isTrue);
    expect(calls, 1);
    expect(
      durableQueue.snapshot.history.single.state,
      MutationOperationState.succeeded,
    );
    await durableQueue.close();
  });

  test(
    'rejects legacy records without stable migration registration',
    () async {
      final durableQueue = DurableMutationQueue(store: _MemoryOutboxStore());
      await legacyQueue.enqueue('legacy-key', 'unknown-legacy-type', {
        'value': 1,
      });

      expect(
        () => const LegacyMutationQueueMigrator(registrations: {}).migrate(
          source: legacyQueue,
          destination: durableQueue,
        ),
        throwsA(isA<LegacyMutationMigrationException>()),
      );
      expect(legacyQueue.entries, hasLength(1));
      expect(durableQueue.snapshot.active, isEmpty);
    },
  );

  test('rejects missing dependencies before durable writes', () async {
    final key = MutationKey(namespace: 'legacy', name: 'child');
    final durableQueue = DurableMutationQueue(store: _MemoryOutboxStore());
    final migrator = LegacyMutationQueueMigrator(
      registrations: {
        'legacy-child':
            TypedLegacyMutationRegistration<Object?, Map<String, Object?>>(
              mutationType: 'legacy-child',
              key: key,
              codec: _mapCodec,
              mutationFn: (variables) async => variables,
            ),
      },
    );
    await legacyQueue.enqueue(
      'legacy-key',
      'legacy-child',
      <String, Object?>{'value': 1},
      dependsOnIds: const <String>['missing-parent'],
    );

    expect(
      () => migrator.migrate(
        source: legacyQueue,
        destination: durableQueue,
      ),
      throwsA(isA<LegacyMutationMigrationException>()),
    );
    expect(legacyQueue.entries, hasLength(1));
    expect(durableQueue.snapshot.active, isEmpty);
  });

  test('preflights all nodes before importing any legacy records', () async {
    final key = MutationKey(namespace: 'legacy', name: 'create');
    final durableQueue = DurableMutationQueue(store: _MemoryOutboxStore());
    final migrator = LegacyMutationQueueMigrator(
      registrations: {
        'legacy-create':
            TypedLegacyMutationRegistration<String, Map<String, Object?>>(
              mutationType: 'legacy-create',
              key: key,
              codec: _mapCodec,
              mutationFn: (variables) async => 'created:${variables['title']}',
            ),
      },
    );
    final validNode = OfflineMutationNode(
      id: 'valid-operation',
      key: 'legacy-key',
      mutationType: 'legacy-create',
      variables: <String, Object?>{'title': 'valid'},
      createdAt: DateTime.utc(2026, 8, 20),
      idempotencyKey: 'valid-idempotency',
    );
    final invalidNode = OfflineMutationNode(
      id: '',
      key: 'legacy-key',
      mutationType: 'legacy-create',
      variables: <String, Object?>{'title': 'invalid'},
      createdAt: DateTime.utc(2026, 8, 20),
      idempotencyKey: 'invalid-idempotency',
    );
    final queueFile = await legacyQueue.resolveQueueStorageFileForTesting();
    await queueFile.writeAsString(
      jsonEncode({
        'schemaVersion': 2,
        'nodes': [validNode.toJson(), invalidNode.toJson()],
      }),
      flush: true,
    );
    legacyQueue.clearInMemoryOnly();

    expect(
      () => migrator.migrate(
        source: legacyQueue,
        destination: durableQueue,
      ),
      throwsA(isA<LegacyMutationMigrationException>()),
    );
    expect(durableQueue.snapshot.active, isEmpty);

    await legacyQueue.load();
    expect(legacyQueue.entries, hasLength(2));
  });
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

class _MemoryOutboxStore implements DurableOutboxStore {
  OutboxSnapshot _snapshot = OutboxSnapshot();
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
    if (expectedGeneration != null && expectedGeneration != _generation) {
      throw const OutboxGenerationConflictException();
    }
    _snapshot = transaction(_snapshot);
    _generation++;
    return _snapshot;
  }

  @override
  Future<void> close() async {
    _isOpen = false;
  }
}
