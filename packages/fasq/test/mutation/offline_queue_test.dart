import 'dart:async';
import 'dart:convert';

import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineQueueManager', () {
    late OfflineQueueManager queueManager;

    setUp(() async {
      queueManager = OfflineQueueManager.instance();
      MutationTypeRegistry.clearForTesting();
      await queueManager.resetForTesting();
    });

    test('should enqueue mutation node', () async {
      await queueManager.enqueue('test-key', 'test-mutation-type', {
        'data': 'test',
      });

      expect(queueManager.length, equals(1));
      expect(queueManager.entries.first.key, equals('test-key'));
      expect(
        queueManager.entries.first.mutationType,
        equals('test-mutation-type'),
      );
      expect(queueManager.entries.first.variables, equals({'data': 'test'}));
      expect(queueManager.entries.first.status, OfflineMutationStatus.pending);
      expect(queueManager.entries.first.maxRetries, equals(5));
      expect(queueManager.entries.first.idempotencyKey, isNotEmpty);
    });

    test('should enqueue with forward-compatible fields', () async {
      await queueManager.enqueue(
        'test-key',
        'test-mutation-type',
        {'data': 'test'},
        dependsOnIds: const <String>['parent-1'],
        idempotencyKey: 'idem-123',
        maxRetries: 9,
      );

      final node = queueManager.entries.first;
      expect(node.dependsOnIds, equals(const <String>['parent-1']));
      expect(node.idempotencyKey, equals('idem-123'));
      expect(node.maxRetries, equals(9));
    });

    test('should remove mutation node by id', () async {
      await queueManager.enqueue('test-key', 'test-mutation-type', {
        'data': 'test',
      });
      final id = queueManager.entries.first.id;

      await queueManager.remove(id);

      expect(queueManager.length, equals(0));
    });

    test('should clear all active nodes', () async {
      await queueManager.enqueue('key1', 'mutation-type-1', {'data': 'test1'});
      await queueManager.enqueue('key2', 'mutation-type-2', {'data': 'test2'});

      await queueManager.clear();

      expect(queueManager.length, equals(0));
    });

    test('should emit stream updates', () async {
      final streamValues = <List<OfflineMutationNode>>[];
      final subscription = queueManager.stream.listen(streamValues.add);

      await queueManager.enqueue('test-key', 'test-mutation-type', {
        'data': 'test',
      });
      await queueManager.remove(queueManager.entries.first.id);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(streamValues.length, equals(2));
      expect(streamValues[0].length, equals(1));
      expect(streamValues[1].length, equals(0));

      unawaited(subscription.cancel());
    });

    test('should create unique ids for nodes', () async {
      await queueManager.enqueue('key1', 'mutation-type-1', {'data': 'test1'});
      await queueManager.enqueue('key2', 'mutation-type-2', {'data': 'test2'});

      final ids = queueManager.entries.map((e) => e.id).toList();
      expect(ids[0], isNot(equals(ids[1])));
    });

    test('should persist nodes to disk and reload them', () async {
      await queueManager.enqueue(
        'persist-key',
        'persist-mutation',
        {'value': 42},
        dependsOnIds: const <String>['create-1'],
        idempotencyKey: 'persist-idem',
        maxRetries: 4,
      );
      final persistedId = queueManager.entries.first.id;

      queueManager.clearInMemoryOnly();
      expect(queueManager.length, equals(0));

      await queueManager.load();

      expect(queueManager.length, equals(1));
      final node = queueManager.entries.first;
      expect(node.id, equals(persistedId));
      expect(node.variables, equals({'value': 42}));
      expect(node.dependsOnIds, equals(const <String>['create-1']));
      expect(node.idempotencyKey, equals('persist-idem'));
      expect(node.maxRetries, equals(4));
    });

    test(
      'should migrate legacy array payload to v2 envelope on load',
      () async {
        final queueFile = await queueManager
            .resolveQueueStorageFileForTesting();
        final legacyPayload = <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'legacy-1',
            'key': 'legacy-key',
            'mutationType': 'legacy-type',
            'variables': {'legacy': true},
            'createdAt': '2026-01-01T00:00:00.000Z',
            'attempts': 2,
            'lastError': 'old-error',
            'priority': 7,
          },
        ];

        await queueFile.writeAsString(jsonEncode(legacyPayload), flush: true);
        queueManager.clearInMemoryOnly();

        await queueManager.load();

        expect(queueManager.length, equals(1));
        final migrated = queueManager.entries.first;
        expect(migrated.id, equals('legacy-1'));
        expect(migrated.status, equals(OfflineMutationStatus.pending));
        expect(migrated.dependsOnIds, isEmpty);
        expect(migrated.idempotencyKey, equals('legacy-1'));
        expect(migrated.maxRetries, equals(5));

        final rewritten =
            jsonDecode(await queueFile.readAsString()) as Map<String, dynamic>;
        expect(rewritten['schemaVersion'], equals(2));
        final nodes = rewritten['nodes'] as List<dynamic>;
        expect(nodes, hasLength(1));
        expect((nodes.first as Map<String, dynamic>)['id'], equals('legacy-1'));
      },
    );

    test('should preserve v2-only fields across load/save/load', () async {
      final queueFile = await queueManager.resolveQueueStorageFileForTesting();
      final nextRunAt = DateTime.utc(2026, 2, 1, 12, 30);

      final payload = <String, dynamic>{
        'schemaVersion': 2,
        'nodes': <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'v2-node',
            'key': 'v2-key',
            'mutationType': 'v2-type',
            'variables': {'value': 1},
            'createdAt': '2026-02-01T00:00:00.000Z',
            'status': 'retryScheduled',
            'attempts': 3,
            'lastError': 'retry later',
            'priority': 9,
            'dependsOnIds': <String>['parent-a', 'parent-b'],
            'idempotencyKey': 'idem-v2',
            'maxRetries': 8,
            'nextRunAt': nextRunAt.toIso8601String(),
          },
        ],
      };

      await queueFile.writeAsString(jsonEncode(payload), flush: true);
      queueManager.clearInMemoryOnly();

      await queueManager.load();

      expect(queueManager.length, equals(1));
      final node = queueManager.entries.first;
      expect(node.status, equals(OfflineMutationStatus.retryScheduled));
      expect(node.dependsOnIds, equals(const <String>['parent-a', 'parent-b']));
      expect(node.idempotencyKey, equals('idem-v2'));
      expect(node.maxRetries, equals(8));
      expect(node.nextRunAt, equals(nextRunAt));

      await queueManager.save();
      queueManager.clearInMemoryOnly();
      await queueManager.load();

      final reloaded = queueManager.entries.first;
      expect(reloaded.status, equals(OfflineMutationStatus.retryScheduled));
      expect(
        reloaded.dependsOnIds,
        equals(const <String>['parent-a', 'parent-b']),
      );
      expect(reloaded.idempotencyKey, equals('idem-v2'));
      expect(reloaded.maxRetries, equals(8));
      expect(reloaded.nextRunAt, equals(nextRunAt));
    });

    test('should move node to dead-letter when handler is missing', () async {
      await queueManager.enqueue('missing-key', 'missing-handler-type', {
        'x': 1,
      });

      await queueManager.processQueue();

      expect(queueManager.length, equals(0));
      expect(queueManager.deadLetterLength, equals(1));
      final deadLetter = queueManager.deadLetters.first;
      expect(deadLetter.reason, equals('missing_handler'));
      expect(deadLetter.node.mutationType, equals('missing-handler-type'));
    });

    test(
      'should move node to dead-letter when max retries are exceeded',
      () async {
        MutationTypeRegistry.register<void, Map<String, dynamic>>(
          'always-fails',
          (_) async {
            throw StateError('boom');
          },
        );

        await queueManager.enqueue(
          'failing-key',
          'always-fails',
          <String, dynamic>{'x': 1},
          maxRetries: 1,
        );

        await queueManager.processQueue();

        expect(queueManager.length, equals(0));
        expect(queueManager.deadLetterLength, equals(1));
        final deadLetter = queueManager.deadLetters.first;
        expect(deadLetter.reason, equals('max_retries_exceeded'));
        expect(deadLetter.node.attempts, equals(1));
        expect(
          deadLetter.node.status,
          equals(OfflineMutationStatus.failedTerminal),
        );
        expect(deadLetter.errorMessage, contains('boom'));

        final deadLetterFile = await queueManager
            .resolveDeadLetterStorageFileForTesting();
        final stored =
            jsonDecode(await deadLetterFile.readAsString())
                as Map<String, dynamic>;
        expect(stored['schemaVersion'], equals(1));
        final entries = stored['entries'] as List<dynamic>;
        expect(entries, hasLength(1));
      },
    );
  });

  group('OfflineMutationNode', () {
    test('should serialize to json', () {
      final entry = OfflineMutationNode(
        id: 'test-id',
        key: 'test-key',
        mutationType: 'test-mutation-type',
        variables: {'data': 'test'},
        createdAt: DateTime(2023),
        status: OfflineMutationStatus.retryScheduled,
        attempts: 2,
        lastError: 'test error',
        priority: 7,
        dependsOnIds: const <String>['a', 'b'],
        idempotencyKey: 'idem-1',
        maxRetries: 11,
        nextRunAt: DateTime(2023, 1, 1, 1),
      );

      final json = entry.toJson();

      expect(json['id'], equals('test-id'));
      expect(json['key'], equals('test-key'));
      expect(json['mutationType'], equals('test-mutation-type'));
      expect(json['variables'], equals({'data': 'test'}));
      expect(json['createdAt'], equals('2023-01-01T00:00:00.000'));
      expect(json['status'], equals('retryScheduled'));
      expect(json['attempts'], equals(2));
      expect(json['lastError'], equals('test error'));
      expect(json['priority'], equals(7));
      expect(json['dependsOnIds'], equals(const <String>['a', 'b']));
      expect(json['idempotencyKey'], equals('idem-1'));
      expect(json['maxRetries'], equals(11));
      expect(json['nextRunAt'], equals('2023-01-01T01:00:00.000'));
    });

    test('should deserialize from json', () {
      final json = <String, dynamic>{
        'id': 'test-id',
        'key': 'test-key',
        'mutationType': 'test-mutation-type',
        'variables': {'data': 'test'},
        'createdAt': '2023-01-01T00:00:00.000',
        'status': 'retryScheduled',
        'attempts': 2,
        'lastError': 'test error',
        'priority': 7,
        'dependsOnIds': <String>['x'],
        'idempotencyKey': 'idem-2',
        'maxRetries': 6,
        'nextRunAt': '2023-01-01T02:00:00.000',
      };

      final entry = OfflineMutationNode.fromJson(json);

      expect(entry.id, equals('test-id'));
      expect(entry.key, equals('test-key'));
      expect(entry.mutationType, equals('test-mutation-type'));
      expect(entry.variables, equals({'data': 'test'}));
      expect(entry.createdAt, equals(DateTime(2023)));
      expect(entry.status, equals(OfflineMutationStatus.retryScheduled));
      expect(entry.attempts, equals(2));
      expect(entry.lastError, equals('test error'));
      expect(entry.priority, equals(7));
      expect(entry.dependsOnIds, equals(const <String>['x']));
      expect(entry.idempotencyKey, equals('idem-2'));
      expect(entry.maxRetries, equals(6));
      expect(entry.nextRunAt, equals(DateTime(2023, 1, 1, 2)));
    });

    test('should copy with new values', () {
      final entry = OfflineMutationNode(
        id: 'test-id',
        key: 'test-key',
        mutationType: 'test-mutation-type',
        variables: {'data': 'test'},
        createdAt: DateTime(2023),
        attempts: 1,
        lastError: 'old error',
        idempotencyKey: 'idem-1',
      );

      final updated = entry.copyWith(
        status: OfflineMutationStatus.retryScheduled,
        attempts: 2,
        lastError: 'new error',
        nextRunAt: DateTime(2023, 1, 1, 3),
      );

      expect(updated.id, equals('test-id'));
      expect(updated.key, equals('test-key'));
      expect(updated.mutationType, equals('test-mutation-type'));
      expect(updated.variables, equals({'data': 'test'}));
      expect(updated.createdAt, equals(DateTime(2023)));
      expect(updated.status, equals(OfflineMutationStatus.retryScheduled));
      expect(updated.attempts, equals(2));
      expect(updated.lastError, equals('new error'));
      expect(updated.nextRunAt, equals(DateTime(2023, 1, 1, 3)));
    });
  });

  group('OfflineDeadLetterEntry', () {
    test('should serialize and deserialize dead-letter entry', () {
      final source = OfflineDeadLetterEntry(
        id: 'dl-1',
        node: OfflineMutationNode(
          id: 'node-1',
          key: 'k',
          mutationType: 't',
          variables: {'ok': true},
          createdAt: DateTime(2023),
          idempotencyKey: 'idem',
        ),
        reason: 'max_retries_exceeded',
        failedAt: DateTime(2023, 2),
        errorMessage: 'boom',
      );

      final encoded = source.toJson();
      final decoded = OfflineDeadLetterEntry.fromJson(encoded);

      expect(decoded.id, equals('dl-1'));
      expect(decoded.reason, equals('max_retries_exceeded'));
      expect(decoded.errorMessage, equals('boom'));
      expect(decoded.node.id, equals('node-1'));
    });
  });

  group('NetworkStatus', () {
    late NetworkStatus networkStatus;

    setUp(() {
      networkStatus = NetworkStatus.instance;
    });

    test('should default to online', () {
      expect(networkStatus.isOnline, isTrue);
    });

    test('should update online status', () {
      networkStatus.setOnline(online: false);
      expect(networkStatus.isOnline, isFalse);

      networkStatus.setOnline(online: true);
      expect(networkStatus.isOnline, isTrue);
    });

    test('should emit stream updates', () async {
      final streamValues = <bool>[];
      final subscription = networkStatus.stream.listen(streamValues.add);

      networkStatus
        ..setOnline(online: false)
        ..setOnline(online: true);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(streamValues, equals([false, true]));

      unawaited(subscription.cancel());
    });

    test('should not emit duplicate values', () async {
      final streamValues = <bool>[];
      final subscription = networkStatus.stream.listen(streamValues.add);

      networkStatus
        ..setOnline(online: true) // Already true
        ..setOnline(online: false)
        ..setOnline(online: false) // Duplicate
        ..setOnline(online: true);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(streamValues, equals([false, true]));

      await subscription.cancel();
    });
  });
}
