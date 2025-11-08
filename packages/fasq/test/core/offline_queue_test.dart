import 'package:flutter_test/flutter_test.dart';
import 'package:fasq/fasq.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OfflineQueueManager', () {
    late OfflineQueueManager queueManager;

    setUp(() async {
      queueManager = OfflineQueueManager.instance;
      await queueManager.resetForTesting();
    });

    test('should enqueue mutation entry', () async {
      await queueManager
          .enqueue('test-key', 'test-mutation-type', {'data': 'test'});

      expect(queueManager.length, equals(1));
      expect(queueManager.entries.first.key, equals('test-key'));
      expect(queueManager.entries.first.mutationType,
          equals('test-mutation-type'));
      expect(queueManager.entries.first.variables, equals({'data': 'test'}));
    });

    test('should remove mutation entry by id', () async {
      await queueManager
          .enqueue('test-key', 'test-mutation-type', {'data': 'test'});
      final id = queueManager.entries.first.id;

      await queueManager.remove(id);

      expect(queueManager.length, equals(0));
    });

    test('should clear all entries', () async {
      await queueManager.enqueue('key1', 'mutation-type-1', {'data': 'test1'});
      await queueManager.enqueue('key2', 'mutation-type-2', {'data': 'test2'});

      await queueManager.clear();

      expect(queueManager.length, equals(0));
    });

    test('should emit stream updates', () async {
      final streamValues = <List<OfflineMutationEntry>>[];
      final subscription = queueManager.stream.listen(streamValues.add);

      await queueManager
          .enqueue('test-key', 'test-mutation-type', {'data': 'test'});
      await queueManager.remove(queueManager.entries.first.id);

      await Future.delayed(Duration(milliseconds: 10));

      expect(streamValues.length, equals(2));
      expect(streamValues[0].length, equals(1));
      expect(streamValues[1].length, equals(0));

      subscription.cancel();
    });

    test('should create unique ids for entries', () async {
      await queueManager.enqueue('key1', 'mutation-type-1', {'data': 'test1'});
      await queueManager.enqueue('key2', 'mutation-type-2', {'data': 'test2'});

      final ids = queueManager.entries.map((e) => e.id).toList();
      expect(ids[0], isNot(equals(ids[1])));
    });

    test('should persist entries to disk and reload them', () async {
      await queueManager.enqueue(
        'persist-key',
        'persist-mutation',
        {'value': 42},
      );
      final persistedId = queueManager.entries.first.id;

      queueManager.clearInMemoryOnly();
      expect(queueManager.length, equals(0));

      await queueManager.load();

      expect(queueManager.length, equals(1));
      expect(queueManager.entries.first.id, equals(persistedId));
      expect(queueManager.entries.first.variables, equals({'value': 42}));
    });
  });

  group('OfflineMutationEntry', () {
    test('should serialize to json', () {
      final entry = OfflineMutationEntry(
        id: 'test-id',
        key: 'test-key',
        mutationType: 'test-mutation-type',
        variables: {'data': 'test'},
        createdAt: DateTime(2023, 1, 1),
        attempts: 2,
        lastError: 'test error',
      );

      final json = entry.toJson();

      expect(json['id'], equals('test-id'));
      expect(json['key'], equals('test-key'));
      expect(json['mutationType'], equals('test-mutation-type'));
      expect(json['variables'], equals({'data': 'test'}));
      expect(json['createdAt'], equals('2023-01-01T00:00:00.000'));
      expect(json['attempts'], equals(2));
      expect(json['lastError'], equals('test error'));
    });

    test('should deserialize from json', () {
      final json = {
        'id': 'test-id',
        'key': 'test-key',
        'mutationType': 'test-mutation-type',
        'variables': {'data': 'test'},
        'createdAt': '2023-01-01T00:00:00.000',
        'attempts': 2,
        'lastError': 'test error',
      };

      final entry = OfflineMutationEntry.fromJson(json);

      expect(entry.id, equals('test-id'));
      expect(entry.key, equals('test-key'));
      expect(entry.mutationType, equals('test-mutation-type'));
      expect(entry.variables, equals({'data': 'test'}));
      expect(entry.createdAt, equals(DateTime(2023, 1, 1)));
      expect(entry.attempts, equals(2));
      expect(entry.lastError, equals('test error'));
    });

    test('should copy with new values', () {
      final entry = OfflineMutationEntry(
        id: 'test-id',
        key: 'test-key',
        mutationType: 'test-mutation-type',
        variables: {'data': 'test'},
        createdAt: DateTime(2023, 1, 1),
        attempts: 1,
        lastError: 'old error',
      );

      final updated = entry.copyWith(
        attempts: 2,
        lastError: 'new error',
      );

      expect(updated.id, equals('test-id'));
      expect(updated.key, equals('test-key'));
      expect(updated.mutationType, equals('test-mutation-type'));
      expect(updated.variables, equals({'data': 'test'}));
      expect(updated.createdAt, equals(DateTime(2023, 1, 1)));
      expect(updated.attempts, equals(2));
      expect(updated.lastError, equals('new error'));
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
      networkStatus.setOnline(false);
      expect(networkStatus.isOnline, isFalse);

      networkStatus.setOnline(true);
      expect(networkStatus.isOnline, isTrue);
    });

    test('should emit stream updates', () async {
      final streamValues = <bool>[];
      final subscription = networkStatus.stream.listen(streamValues.add);

      networkStatus.setOnline(false);
      networkStatus.setOnline(true);

      await Future.delayed(Duration(milliseconds: 10));

      expect(streamValues, equals([false, true]));

      subscription.cancel();
    });

    test('should not emit duplicate values', () async {
      final streamValues = <bool>[];
      final subscription = networkStatus.stream.listen(streamValues.add);

      networkStatus.setOnline(true); // Already true
      networkStatus.setOnline(false);
      networkStatus.setOnline(false); // Duplicate
      networkStatus.setOnline(true);

      await Future.delayed(Duration(milliseconds: 10));

      expect(streamValues, equals([false, true]));

      subscription.cancel();
    });
  });
}
