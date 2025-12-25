import 'package:flutter_test/flutter_test.dart';
import 'package:fasq/fasq.dart';
import 'package:fasq_security/src/providers/drift_persistence_provider.dart';
import 'package:fasq_security/src/exceptions/persistence_exception.dart';
import 'package:fasq_security/src/exceptions/encryption_exception.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DriftPersistenceProvider', () {
    late DriftPersistenceProvider provider;
    late MockEncryptionProvider mockEncryptionProvider;

    setUp(() async {
      provider = DriftPersistenceProvider();
      mockEncryptionProvider = MockEncryptionProvider();
      await provider.initialize();
      await provider.clear();
    });

    tearDown(() async {
      await provider.dispose();
    });

    group('rotateEncryptionKey', () {
      test('throws exception when not initialized', () async {
        final uninitializedProvider = DriftPersistenceProvider();

        expect(
          () => uninitializedProvider.rotateEncryptionKey(
            'old-key',
            'new-key',
            mockEncryptionProvider,
          ),
          throwsA(isA<PersistenceException>()),
        );
      });

      test('returns early when key is unchanged', () async {
        final oldKey = 'valid-key';
        final newKey = 'valid-key';

        await provider.rotateEncryptionKey(
          oldKey,
          newKey,
          mockEncryptionProvider,
        );

        // Verify no encryption operations occurred
        expect(mockEncryptionProvider.decryptCallCount, equals(0));
        expect(mockEncryptionProvider.encryptCallCount, equals(0));
      });

      test('successfully re-encrypts all existing data', () async {
        final oldKey = 'old-valid-key';
        final newKey = 'new-valid-key';

        // Setup existing data
        await provider.persist('key1', [1, 2, 3]);
        await provider.persist('key2', [4, 5, 6]);
        await provider.persist('key3', [7, 8, 9]);

        // Setup decryption/encryption responses
        mockEncryptionProvider.decryptResponses = {
          'key1': [1, 10, 11],
          'key2': [4, 13, 14],
          'key3': [7, 16, 17],
        };
        mockEncryptionProvider.encryptResponses = {
          'key1': [20, 21, 22],
          'key2': [23, 24, 25],
          'key3': [26, 27, 28],
        };

        await provider.rotateEncryptionKey(
          oldKey,
          newKey,
          mockEncryptionProvider,
        );

        // Verify all data was re-encrypted
        expect(mockEncryptionProvider.decryptCallCount, equals(3));
        expect(mockEncryptionProvider.encryptCallCount, equals(3));

        // Verify correct keys were processed
        expect(
          mockEncryptionProvider.decryptedKeys,
          containsAll(['key1', 'key2', 'key3']),
        );
        expect(
          mockEncryptionProvider.encryptedKeys,
          containsAll(['key1', 'key2', 'key3']),
        );

        // Verify data was persisted
        expect(await provider.exists('key1'), isTrue);
        expect(await provider.exists('key2'), isTrue);
        expect(await provider.exists('key3'), isTrue);
      });

      test('handles partial failures gracefully', () async {
        final oldKey = 'old-valid-key';
        final newKey = 'new-valid-key';

        // Setup existing data
        await provider.persist('key1', [1, 2, 3]);
        await provider.persist('key2', [4, 5, 6]);
        await provider.persist('key3', [7, 8, 9]);

        // Setup decryption/encryption responses with one failure
        mockEncryptionProvider.decryptResponses = {
          'key1': [1, 10, 11],
          'key2': [4, 13, 14],
          'key3': [7, 16, 17],
        };
        mockEncryptionProvider.encryptResponses = {
          'key1': [20, 21, 22],
          'key3': [26, 27, 28],
        };
        // Configure mock to throw for key2
        mockEncryptionProvider.keysToThrowOnEncrypt.add('key2');

        await expectLater(
          provider.rotateEncryptionKey(
            oldKey,
            newKey,
            mockEncryptionProvider,
          ),
          throwsA(isA<PersistenceException>()),
        );

        expect(mockEncryptionProvider.decryptCallCount, equals(3));
        expect(mockEncryptionProvider.encryptCallCount, equals(3));

        expect(await provider.exists('key1'), isTrue);
        expect(await provider.exists('key2'), isTrue);
        expect(await provider.exists('key3'), isTrue);
      });

      test('calls progress callback correctly', () async {
        final oldKey = 'old-valid-key';
        final newKey = 'new-valid-key';

        // Setup existing data
        await provider.persist('key1', [1, 2, 3]);
        await provider.persist('key2', [4, 5, 6]);
        await provider.persist('key3', [7, 8, 9]);

        // Setup successful responses
        mockEncryptionProvider.decryptResponses = {
          'key1': [1, 10, 11],
          'key2': [4, 13, 14],
          'key3': [7, 16, 17],
        };
        mockEncryptionProvider.encryptResponses = {
          'key1': [20, 21, 22],
          'key2': [23, 24, 25],
          'key3': [26, 27, 28],
        };

        final progressCalls = <int, int>{};
        await provider.rotateEncryptionKey(
          oldKey,
          newKey,
          mockEncryptionProvider,
          onProgress: (current, total) {
            progressCalls[current] = total;
          },
        );

        // Verify progress was called correctly
        expect(progressCalls[0], equals(3)); // Initial call
        expect(progressCalls[1], equals(3)); // After key1
        expect(progressCalls[2], equals(3)); // After key2
        expect(progressCalls[3], equals(3)); // After key3
      });

      test('handles empty cache gracefully', () async {
        final oldKey = 'old-valid-key';
        final newKey = 'new-valid-key';

        // No data in database (empty cache)

        await provider.rotateEncryptionKey(
          oldKey,
          newKey,
          mockEncryptionProvider,
        );

        // Verify no encryption operations occurred
        expect(mockEncryptionProvider.decryptCallCount, equals(0));
        expect(mockEncryptionProvider.encryptCallCount, equals(0));
      });
    });

    group('basic operations', () {
      test('persist and retrieve data', () async {
        final testData = [1, 2, 3, 4, 5];
        const testKey = 'test-key';

        await provider.persist(testKey, testData);
        final retrievedData = await provider.retrieve(testKey);

        expect(retrievedData, equals(testData));
      });

      test('returns null for non-existent key', () async {
        final retrievedData = await provider.retrieve('non-existent-key');
        expect(retrievedData, isNull);
      });

      test('removes data correctly', () async {
        final testData = [1, 2, 3, 4, 5];
        const testKey = 'test-key';

        await provider.persist(testKey, testData);
        expect(await provider.exists(testKey), isTrue);

        await provider.remove(testKey);
        expect(await provider.exists(testKey), isFalse);
      });

      test('clears all data', () async {
        await provider.persist('key1', [1, 2, 3]);
        await provider.persist('key2', [4, 5, 6]);

        await provider.clear();

        expect(await provider.getAllKeys(), isEmpty);
      });

      test('gets all keys', () async {
        await provider.persist('key1', [1, 2, 3]);
        await provider.persist('key2', [4, 5, 6]);
        await provider.persist('key3', [7, 8, 9]);

        final keys = await provider.getAllKeys();
        expect(keys, containsAll(['key1', 'key2', 'key3']));
      });
    });

    group('batch operations', () {
      test('retrieveMultiple returns correct data', () async {
        await provider.persist('key1', [1, 2, 3]);
        await provider.persist('key2', [4, 5, 6]);
        await provider.persist('key3', [7, 8, 9]);

        final result = await provider.retrieveMultiple([
          'key1',
          'key2',
          'key4',
        ]);

        expect(result['key1'], equals([1, 2, 3]));
        expect(result['key2'], equals([4, 5, 6]));
        expect(result.containsKey('key4'), isFalse);
      });

      test('persistMultiple stores all data', () async {
        final entries = {
          'key1': [1, 2, 3],
          'key2': [4, 5, 6],
          'key3': [7, 8, 9],
        };

        await provider.persistMultiple(entries);

        expect(await provider.retrieve('key1'), equals([1, 2, 3]));
        expect(await provider.retrieve('key2'), equals([4, 5, 6]));
        expect(await provider.retrieve('key3'), equals([7, 8, 9]));
      });

      test('removeMultiple removes all keys', () async {
        await provider.persist('key1', [1, 2, 3]);
        await provider.persist('key2', [4, 5, 6]);
        await provider.persist('key3', [7, 8, 9]);

        await provider.removeMultiple(['key1', 'key3']);

        expect(await provider.exists('key1'), isFalse);
        expect(await provider.exists('key2'), isTrue);
        expect(await provider.exists('key3'), isFalse);
      });
    });
  });
}

/// Mock implementation of EncryptionProvider for testing
class MockEncryptionProvider implements EncryptionProvider {
  int decryptCallCount = 0;
  int encryptCallCount = 0;
  List<String> decryptedKeys = [];
  List<String> encryptedKeys = [];
  Map<String, List<int>> decryptResponses = {};
  Map<String, List<int>> encryptResponses = {};
  Set<String> keysToThrowOnEncrypt = {};

  @override
  Future<List<int>> decrypt(List<int> data, String key) async {
    decryptCallCount++;
    // Simulate key extraction for tracking
    final keyName = _extractKeyName(data);
    decryptedKeys.add(keyName);
    return decryptResponses[keyName] ?? data;
  }

  @override
  Future<List<int>> encrypt(List<int> data, String key) async {
    encryptCallCount++;
    // Simulate key extraction for tracking
    // Simulate key extraction for tracking
    final keyName = _extractKeyName(data);
    if (keysToThrowOnEncrypt.contains(keyName)) {
      throw EncryptionException('Simulated encryption failure for $keyName');
    }
    encryptedKeys.add(keyName);
    return encryptResponses[keyName] ?? data;
  }

  @override
  bool isValidKey(String key) {
    return key.length > 5; // Simple validation for testing
  }

  @override
  String generateKey() {
    return 'generated-key';
  }

  @override
  Future<void> dispose() async {}

  String _extractKeyName(List<int> data) {
    // Simple heuristic to identify which key this data belongs to
    if (data.contains(1)) return 'key1';
    if (data.contains(4)) return 'key2';
    if (data.contains(7)) return 'key3';
    return 'unknown';
  }
}
