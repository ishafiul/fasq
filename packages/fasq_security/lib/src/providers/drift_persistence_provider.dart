import 'dart:async';

import 'package:fasq/fasq.dart';

import '../database/cache_database.dart';
import '../exceptions/persistence_exception.dart';

/// Implementation of PersistenceProvider using Drift SQLite.
///
/// Provides efficient encrypted data persistence with batch operations,
/// ACID compliance, and optimized indexing for cache operations.
class DriftPersistenceProvider implements PersistenceProvider {
  DriftPersistenceProvider({void Function()? onDispose})
      : _onDispose = onDispose;

  late CacheDatabase _database;
  bool _initialized = false;
  bool _isDisposed = false;
  final _initLock = _AsyncLock();
  final void Function()? _onDispose;

  bool get isInitialized => _initialized;
  bool get isDisposed => _isDisposed;

  @override
  bool get supportsEncryptionKeyRotation => true;

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    await _initLock.synchronized(() async {
      if (_initialized) return;

      try {
        _database = await CacheDatabase.open();

        _initialized = true;
        _isDisposed = false;
      } catch (e) {
        throw PersistenceException('Failed to initialize database: $e');
      }
    });
  }

  @override
  Future<void> persist(
    String key,
    List<int> encryptedData, {
    DateTime? createdAt,
    DateTime? expiresAt,
  }) async {
    if (!_initialized) {
      throw PersistenceException('DriftPersistenceProvider not initialized');
    }

    try {
      await _database.insertCacheEntries(
        {key: encryptedData},
        createdAt: createdAt != null ? {key: createdAt} : null,
        expiresAt: {key: expiresAt},
      );
    } catch (e) {
      throw PersistenceException('Failed to persist data for key $key: $e');
    }
  }

  @override
  Future<List<int>?> retrieve(String key) async {
    if (!_initialized) {
      throw PersistenceException('DriftPersistenceProvider not initialized');
    }

    try {
      final entries = await _database.getCacheEntries([key]);

      if (entries.containsKey(key)) {
        final data = entries[key];

        return data;
      }

      return null;
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
  Future<void> persistMultiple(
    Map<String, List<int>> entries, {
    Map<String, DateTime?>? createdAt,
    Map<String, DateTime?>? expiresAt,
  }) async {
    if (!_initialized) {
      throw PersistenceException('Provider not initialized');
    }

    try {
      await _database.insertCacheEntries(
        entries,
        createdAt: createdAt,
        expiresAt: expiresAt,
      );
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

  @override
  Future<void> rotateEncryptionKey(
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
      final existingKeys = await getAllKeys();
      onProgress?.call(0, existingKeys.length);

      final reEncryptedData = <String, List<int>>{};
      final createdAtMap = <String, DateTime?>{};
      final expiresAtMap = <String, DateTime?>{};
      final failedKeys = <String>[];
      int processedCount = 0;
      const batchSize = 50;

      Future<void> flushBatch() async {
        if (reEncryptedData.isEmpty) {
          return;
        }
        await persistMultiple(
          Map<String, List<int>>.from(reEncryptedData),
          createdAt: Map<String, DateTime?>.from(createdAtMap),
          expiresAt: Map<String, DateTime?>.from(expiresAtMap),
        );
        reEncryptedData.clear();
        createdAtMap.clear();
        expiresAtMap.clear();
        await Future<void>.delayed(Duration.zero);
      }

      for (final key in existingKeys) {
        try {
          final encryptedData = await retrieve(key);
          if (encryptedData == null) {
            continue;
          }

          final metadata = await _database.getMetadata(key);
          if (metadata == null) {
            failedKeys.add(key);
            continue;
          }

          final decryptedData = await encryptionProvider.decrypt(
            encryptedData,
            oldKey,
          );
          final newEncryptedData = await encryptionProvider.encrypt(
            decryptedData,
            newKey,
          );

          reEncryptedData[key] = newEncryptedData;
          createdAtMap[key] = metadata.createdAt;
          expiresAtMap[key] = metadata.expiresAt;

          if (reEncryptedData.length >= batchSize) {
            await flushBatch();
          }
        } catch (_) {
          failedKeys.add(key);
        }

        processedCount++;
        onProgress?.call(processedCount, existingKeys.length);

        if (processedCount % batchSize == 0) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      await flushBatch();

      if (failedKeys.isNotEmpty) {
        throw PersistenceException(
          'Failed to re-encrypt keys: ${failedKeys.join(', ')}',
        );
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

  @override
  Future<void> dispose() async {
    if (_isDisposed) {
      return;
    }

    await _initLock.synchronized(() async {
      if (_isDisposed) return;

      if (_initialized) {
        await _database.close();
        _initialized = false;
      }

      _isDisposed = true;
      _onDispose?.call();
    });
  }
}

class _AsyncLock {
  final _queue = <Completer<void>>[];
  bool _locked = false;

  Future<void> acquire() async {
    final completer = Completer<void>();

    if (!_locked) {
      _locked = true;
      completer.complete();
      return completer.future;
    }

    _queue.add(completer);

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _queue.remove(completer);
        throw TimeoutException('Lock acquisition timed out after 30 seconds');
      },
    );
  }

  void release() {
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      next.complete();
    } else {
      _locked = false;
    }
  }

  Future<T> synchronized<T>(Future<T> Function() fn) async {
    await acquire();
    try {
      return await fn();
    } finally {
      release();
    }
  }
}
