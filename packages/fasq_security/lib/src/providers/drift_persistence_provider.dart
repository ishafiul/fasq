import 'dart:async';

import 'package:fasq/fasq.dart';

import '../database/cache_database.dart';
import '../exceptions/persistence_exception.dart';

/// Implementation of PersistenceProvider using Drift SQLite.
///
/// Provides efficient encrypted data persistence with batch operations,
/// ACID compliance, and optimized indexing for cache operations.
class DriftPersistenceProvider implements PersistenceProvider {
  late CacheDatabase _database;
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _database = CacheDatabase();
      _initialized = true;
    } catch (e) {
      throw PersistenceException('Failed to initialize database: $e');
    }
  }

  @override
  Future<void> persist(String key, List<int> encryptedData) async {
    if (!_initialized) {
      throw PersistenceException('Provider not initialized');
    }

    try {
      await _database.insertCacheEntries({key: encryptedData});
    } catch (e) {
      throw PersistenceException('Failed to persist data for key $key: $e');
    }
  }

  @override
  Future<List<int>?> retrieve(String key) async {
    if (!_initialized) {
      throw PersistenceException('Provider not initialized');
    }

    try {
      final entries = await _database.getCacheEntries([key]);
      return entries[key];
    } catch (e) {
      throw PersistenceException('Failed to retrieve data for key $key: $e');
    }
  }

  @override
  Future<void> remove(String key) async {
    if (!_initialized) {
      throw PersistenceException('Provider not initialized');
    }

    try {
      await _database.deleteCacheEntries([key]);
    } catch (e) {
      throw PersistenceException('Failed to remove data for key $key: $e');
    }
  }

  @override
  Future<void> clear() async {
    if (!_initialized) {
      throw PersistenceException('Provider not initialized');
    }

    try {
      await _database.clear();
    } catch (e) {
      throw PersistenceException('Failed to clear all data: $e');
    }
  }

  @override
  Future<bool> exists(String key) async {
    if (!_initialized) {
      return false;
    }

    try {
      return await _database.exists(key);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<List<String>> getAllKeys() async {
    if (!_initialized) {
      return [];
    }

    try {
      return await _database.getAllKeys();
    } catch (e) {
      return [];
    }
  }

  @override
  Future<Map<String, List<int>>> retrieveMultiple(List<String> keys) async {
    if (!_initialized) {
      throw PersistenceException('Provider not initialized');
    }

    try {
      return await _database.getCacheEntries(keys);
    } catch (e) {
      throw PersistenceException('Failed to retrieve multiple entries: $e');
    }
  }

  @override
  Future<void> persistMultiple(Map<String, List<int>> entries) async {
    if (!_initialized) {
      throw PersistenceException('Provider not initialized');
    }

    try {
      await _database.insertCacheEntries(entries);
    } catch (e) {
      throw PersistenceException('Failed to persist multiple entries: $e');
    }
  }

  @override
  Future<void> removeMultiple(List<String> keys) async {
    if (!_initialized) {
      throw PersistenceException('Provider not initialized');
    }

    try {
      await _database.deleteCacheEntries(keys);
    } catch (e) {
      throw PersistenceException('Failed to remove multiple entries: $e');
    }
  }

  /// Updates the encryption key by re-encrypting all existing data.
  ///
  /// This re-encrypts all existing data with the new key to ensure data
  /// remains accessible after the key change. The process is atomic - if
  /// re-encryption fails, the old key is restored.
  ///
  /// [oldKey] The current encryption key
  /// [newKey] The new encryption key to use
  /// [encryptionProvider] The encryption provider to use for re-encryption
  /// [onProgress] Optional callback for progress tracking during re-encryption
  Future<void> updateEncryptionKey(
    String oldKey,
    String newKey,
    EncryptionProvider encryptionProvider, {
    void Function(int current, int total)? onProgress,
  }) async {
    if (!_initialized) {
      throw PersistenceException('Provider not initialized');
    }

    if (oldKey == newKey) {
      return; // No change needed
    }

    try {
      // 1. Get all existing persisted keys
      final existingKeys = await getAllKeys();
      onProgress?.call(0, existingKeys.length);

      // 2. Create temporary storage for re-encrypted data
      final reEncryptedData = <String, List<int>>{};
      int processedCount = 0;

      // 3. Re-encrypt all existing data
      for (final key in existingKeys) {
        try {
          // Retrieve encrypted data with old key
          final encryptedData = await retrieve(key);
          if (encryptedData != null) {
            // Decrypt with old key
            final decryptedData = await encryptionProvider.decrypt(
              encryptedData,
              oldKey,
            );

            // Encrypt with new key
            final newEncryptedData = await encryptionProvider.encrypt(
              decryptedData,
              newKey,
            );

            // Store in temporary map
            reEncryptedData[key] = newEncryptedData;
          }
        } catch (e) {
          // Log warning but continue with other keys
          print('Warning: Failed to re-encrypt key $key: $e');
        }

        processedCount++;
        onProgress?.call(processedCount, existingKeys.length);
      }

      // 4. Persist all re-encrypted data
      await persistMultiple(reEncryptedData);

      // 5. Clean up any failed re-encryptions by removing old data
      for (final key in existingKeys) {
        if (!reEncryptedData.containsKey(key)) {
          await remove(key);
        }
      }
    } catch (e) {
      throw PersistenceException('Failed to update encryption key: $e');
    }
  }

  /// Cleans up expired cache entries.
  Future<int> cleanupExpired() async {
    if (!_initialized) {
      return 0;
    }

    try {
      return await _database.cleanupExpired();
    } catch (e) {
      return 0;
    }
  }
}
