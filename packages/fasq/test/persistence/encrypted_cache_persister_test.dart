import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fasq/src/persistence/encrypted_cache_persister.dart';
import 'package:fasq/src/persistence/encryption_service.dart';
import 'package:fasq/src/persistence/secure_storage.dart';

void main() {
  group('EncryptedCachePersister', () {
    late EncryptedCachePersister persister;
    late MockSecureStorage mockSecureStorage;
    late MockEncryptionService mockEncryptionService;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      mockSecureStorage = MockSecureStorage();
      mockEncryptionService = MockEncryptionService();
      persister = EncryptedCachePersister(
        secureStorage: mockSecureStorage,
        encryptionService: mockEncryptionService,
        sharedPreferences: sharedPreferences,
      );
    });

    group('updateEncryptionKey', () {
      test('throws exception for invalid key format', () async {
        await persister.initialize();

        expect(
          () => persister.updateEncryptionKey('invalid-key'),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('throws exception when not initialized', () async {
        expect(
          () => persister.updateEncryptionKey('valid-key'),
          throwsA(isA<EncryptionException>()),
        );
      });

      test('returns early when key is unchanged', () async {
        await persister.initialize();
        final currentKey = mockSecureStorage.storedKey!;

        await persister.updateEncryptionKey(currentKey);

        // Verify no re-encryption occurred
        expect(mockEncryptionService.decryptCallCount, equals(0));
        expect(mockEncryptionService.encryptCallCount, equals(0));
      });

      test('successfully re-encrypts all existing data', () async {
        await persister.initialize();
        final newKey = 'new-valid-key';

        // Setup existing data in SharedPreferences
        await sharedPreferences.setString(
            'fasq_cache_key1', base64Encode([1, 2, 3]));
        await sharedPreferences.setString(
            'fasq_cache_key2', base64Encode([4, 5, 6]));
        await sharedPreferences.setString(
            'fasq_cache_key3', base64Encode([7, 8, 9]));

        // Setup decryption/encryption responses
        mockEncryptionService.decryptResponses = {
          'key1': [10, 11, 12],
          'key2': [13, 14, 15],
          'key3': [16, 17, 18],
        };
        mockEncryptionService.encryptResponses = {
          'key1': [20, 21, 22],
          'key2': [23, 24, 25],
          'key3': [26, 27, 28],
        };

        await persister.updateEncryptionKey(newKey);

        // Verify key was updated
        expect(mockSecureStorage.storedKey, equals(newKey));

        // Verify all data was re-encrypted
        expect(mockEncryptionService.decryptCallCount, equals(3));
        expect(mockEncryptionService.encryptCallCount, equals(3));

        // Verify correct keys were processed
        expect(mockEncryptionService.decryptedKeys,
            containsAll(['key1', 'key2', 'key3']));
        expect(mockEncryptionService.encryptedKeys,
            containsAll(['key1', 'key2', 'key3']));

        // Verify data was persisted to SharedPreferences
        expect(sharedPreferences.getString('fasq_cache_key1'), isNotNull);
        expect(sharedPreferences.getString('fasq_cache_key2'), isNotNull);
        expect(sharedPreferences.getString('fasq_cache_key3'), isNotNull);
      });

      test('handles partial failures gracefully', () async {
        await persister.initialize();
        final newKey = 'new-valid-key';

        // Setup existing data in SharedPreferences
        await sharedPreferences.setString(
            'fasq_cache_key1', base64Encode([1, 2, 3]));
        await sharedPreferences.setString(
            'fasq_cache_key2', base64Encode([4, 5, 6]));
        await sharedPreferences.setString(
            'fasq_cache_key3', base64Encode([7, 8, 9]));

        // Setup decryption/encryption responses with one failure
        mockEncryptionService.decryptResponses = {
          'key1': [10, 11, 12],
          'key3': [16, 17, 18], // key2 missing - will fail
        };
        mockEncryptionService.encryptResponses = {
          'key1': [20, 21, 22],
          'key3': [26, 27, 28], // key2 missing - will fail
        };

        await persister.updateEncryptionKey(newKey);

        // Verify key was still updated
        expect(mockSecureStorage.storedKey, equals(newKey));

        // Verify successful keys were processed
        expect(
            mockEncryptionService.decryptCallCount, equals(3)); // All attempted
        expect(mockEncryptionService.encryptCallCount,
            equals(2)); // Only successful ones

        // Verify only successful data was persisted
        expect(sharedPreferences.getString('fasq_cache_key1'), isNotNull);
        expect(sharedPreferences.getString('fasq_cache_key3'), isNotNull);
        expect(sharedPreferences.getString('fasq_cache_key2'),
            isNull); // Should be removed
      });

      test('rolls back on critical failure', () async {
        await persister.initialize();
        final oldKey = mockSecureStorage.storedKey!;
        final newKey = 'new-valid-key';

        // Setup existing data in SharedPreferences
        await sharedPreferences.setString(
            'fasq_cache_key1', base64Encode([1, 2, 3]));
        await sharedPreferences.setString(
            'fasq_cache_key2', base64Encode([4, 5, 6]));

        // Setup failure during key storage
        mockSecureStorage.shouldFailOnSetKey = true;

        expect(
          () => persister.updateEncryptionKey(newKey),
          throwsA(isA<PersistenceException>()),
        );

        // Verify rollback occurred
        expect(mockSecureStorage.rollbackAttempted, isTrue);
        expect(
            mockSecureStorage.storedKey, equals(oldKey)); // Should be restored
      });

      test('calls progress callback correctly', () async {
        await persister.initialize();
        final newKey = 'new-valid-key';

        // Setup existing data in SharedPreferences
        await sharedPreferences.setString(
            'fasq_cache_key1', base64Encode([1, 2, 3]));
        await sharedPreferences.setString(
            'fasq_cache_key2', base64Encode([4, 5, 6]));
        await sharedPreferences.setString(
            'fasq_cache_key3', base64Encode([7, 8, 9]));

        // Setup successful responses
        mockEncryptionService.decryptResponses = {
          'key1': [10, 11, 12],
          'key2': [13, 14, 15],
          'key3': [16, 17, 18],
        };
        mockEncryptionService.encryptResponses = {
          'key1': [20, 21, 22],
          'key2': [23, 24, 25],
          'key3': [26, 27, 28],
        };

        final progressCalls = <int, int>{};
        await persister.updateEncryptionKey(
          newKey,
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
        await persister.initialize();
        final newKey = 'new-valid-key';

        // No data in SharedPreferences (empty cache)

        await persister.updateEncryptionKey(newKey);

        // Verify key was updated
        expect(mockSecureStorage.storedKey, equals(newKey));

        // Verify no encryption operations occurred
        expect(mockEncryptionService.decryptCallCount, equals(0));
        expect(mockEncryptionService.encryptCallCount, equals(0));
      });

      test('handles null encrypted data gracefully', () async {
        await persister.initialize();
        final newKey = 'new-valid-key';

        // No data in SharedPreferences (null encrypted data)

        await persister.updateEncryptionKey(newKey);

        // Verify key was updated
        expect(mockSecureStorage.storedKey, equals(newKey));

        // Verify no encryption operations occurred
        expect(mockEncryptionService.decryptCallCount, equals(0));
        expect(mockEncryptionService.encryptCallCount, equals(0));
      });
    });
  });
}

/// Mock implementation of SecureStorage for testing
class MockSecureStorage extends SecureStorage {
  String? storedKey;
  bool shouldFailOnSetKey = false;
  bool rollbackAttempted = false;

  @override
  Future<String?> getEncryptionKey() async {
    return storedKey;
  }

  @override
  Future<void> setEncryptionKey(String key) async {
    if (shouldFailOnSetKey) {
      throw Exception('Simulated failure');
    }
    storedKey = key;
  }

  @override
  Future<String> generateAndStoreKey() async {
    storedKey = 'generated-key';
    return storedKey!;
  }

  @override
  bool get isSupported => true;

  Future<void> rollbackToKey(String key) async {
    rollbackAttempted = true;
    storedKey = key;
  }
}

/// Mock implementation of EncryptionService for testing
class MockEncryptionService extends EncryptionService {
  int decryptCallCount = 0;
  int encryptCallCount = 0;
  List<String> decryptedKeys = [];
  List<String> encryptedKeys = [];
  Map<String, List<int>> decryptResponses = {};
  Map<String, List<int>> encryptResponses = {};

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
    final keyName = _extractKeyName(data);
    encryptedKeys.add(keyName);
    return encryptResponses[keyName] ?? data;
  }

  @override
  bool isValidKey(String key) {
    return key.length > 5; // Simple validation for testing
  }

  String _extractKeyName(List<int> data) {
    // Simple heuristic to identify which key this data belongs to
    if (data.contains(1)) return 'key1';
    if (data.contains(4)) return 'key2';
    if (data.contains(7)) return 'key3';
    return 'unknown';
  }
}
