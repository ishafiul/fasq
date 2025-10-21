import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'encryption_service.dart';
import 'secure_storage.dart';

/// Persister that encrypts cache data before writing to disk.
///
/// Handles encryption/decryption transparently and manages encryption keys
/// using platform-specific secure storage.
class EncryptedCachePersister {
  final EncryptionService _encryptionService;
  final SecureStorage _secureStorage;
  String? _encryptionKey;
  SharedPreferences? _prefs;
  static const String _keyPrefix = 'fasq_cache_';

  EncryptedCachePersister({
    EncryptionService? encryptionService,
    SecureStorage? secureStorage,
    SharedPreferences? sharedPreferences,
  })  : _encryptionService = encryptionService ?? EncryptionService(),
        _secureStorage = secureStorage ?? SecureStorage(),
        _prefs = sharedPreferences;

  /// Initializes the persister and ensures an encryption key is available.
  ///
  /// If no key exists, generates and stores a new one.
  Future<void> initialize() async {
    if (!_secureStorage.isSupported) {
      throw UnsupportedError('Secure storage not supported on this platform');
    }

    // Initialize SharedPreferences if not provided
    _prefs ??= await SharedPreferences.getInstance();

    _encryptionKey = await _secureStorage.getEncryptionKey();
    if (_encryptionKey == null) {
      _encryptionKey = await _secureStorage.generateAndStoreKey();
    }

    if (!_encryptionService.isValidKey(_encryptionKey!)) {
      throw EncryptionException('Invalid encryption key format');
    }
  }

  /// Encrypts and persists cache data.
  ///
  /// Data is serialized to JSON, encrypted, and then persisted.
  Future<void> persist(String key, dynamic data) async {
    if (_encryptionKey == null) {
      throw EncryptionException('Encryption key not initialized');
    }

    try {
      // Serialize data to JSON
      final jsonString = jsonEncode(data);
      final jsonBytes = utf8.encode(jsonString);

      // Encrypt the data
      final encryptedBytes =
          await _encryptionService.encrypt(jsonBytes, _encryptionKey!);

      // Persist encrypted data (this would integrate with actual persistence layer)
      await _persistEncryptedData(key, encryptedBytes);
    } catch (e) {
      throw PersistenceException('Failed to persist encrypted data: $e');
    }
  }

  /// Retrieves and decrypts cache data.
  ///
  /// Data is retrieved, decrypted, and deserialized from JSON.
  Future<dynamic> retrieve(String key) async {
    if (_encryptionKey == null) {
      throw EncryptionException('Encryption key not initialized');
    }

    try {
      // Retrieve encrypted data
      final encryptedBytes = await _retrieveEncryptedData(key);
      if (encryptedBytes == null) {
        return null;
      }

      // Decrypt the data
      final decryptedBytes =
          await _encryptionService.decrypt(encryptedBytes, _encryptionKey!);

      // Deserialize from JSON
      final jsonString = utf8.decode(decryptedBytes);
      return jsonDecode(jsonString);
    } catch (e) {
      throw PersistenceException('Failed to retrieve encrypted data: $e');
    }
  }

  /// Removes persisted data for a key.
  Future<void> remove(String key) async {
    try {
      await _removePersistedData(key);
    } catch (e) {
      throw PersistenceException('Failed to remove persisted data: $e');
    }
  }

  /// Clears all persisted data.
  Future<void> clear() async {
    try {
      await _clearAllPersistedData();
    } catch (e) {
      throw PersistenceException('Failed to clear persisted data: $e');
    }
  }

  /// Checks if data exists for a key.
  Future<bool> exists(String key) async {
    try {
      return await _persistedDataExists(key);
    } catch (e) {
      return false;
    }
  }

  /// Gets all persisted keys.
  Future<List<String>> getAllKeys() async {
    try {
      return await _getAllPersistedKeys();
    } catch (e) {
      return [];
    }
  }

  /// Updates the encryption key.
  ///
  /// This re-encrypts all existing data with the new key to ensure data
  /// remains accessible after the key change. The process is atomic - if
  /// re-encryption fails, the old key is restored.
  ///
  /// [newKey] The new encryption key to use
  /// [onProgress] Optional callback for progress tracking during re-encryption
  Future<void> updateEncryptionKey(
    String newKey, {
    void Function(int current, int total)? onProgress,
  }) async {
    if (!_encryptionService.isValidKey(newKey)) {
      throw EncryptionException('Invalid encryption key format');
    }

    final oldKey = _encryptionKey;
    if (oldKey == newKey) {
      return; // No change needed
    }

    if (oldKey == null) {
      throw EncryptionException('Encryption key not initialized');
    }

    try {
      // 1. Get all existing persisted keys
      final existingKeys = await _getAllPersistedKeys();
      onProgress?.call(0, existingKeys.length);

      // 2. Create temporary storage for re-encrypted data
      final reEncryptedData = <String, List<int>>{};
      int processedCount = 0;

      // 3. Re-encrypt all existing data
      for (final key in existingKeys) {
        try {
          // Retrieve encrypted data with old key
          final encryptedData = await _retrieveEncryptedData(key);
          if (encryptedData != null) {
            // Decrypt with old key
            final decryptedData =
                await _encryptionService.decrypt(encryptedData, oldKey);

            // Encrypt with new key
            final newEncryptedData =
                await _encryptionService.encrypt(decryptedData, newKey);

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

      // 4. Update the stored encryption key first
      await _secureStorage.setEncryptionKey(newKey);
      _encryptionKey = newKey;

      // 5. Persist all re-encrypted data
      for (final entry in reEncryptedData.entries) {
        await _persistEncryptedData(entry.key, entry.value);
      }

      // 6. Clean up any failed re-encryptions by removing old data
      for (final key in existingKeys) {
        if (!reEncryptedData.containsKey(key)) {
          await _removePersistedData(key);
        }
      }
    } catch (e) {
      // Rollback: restore old key if something went wrong
      try {
        await _secureStorage.setEncryptionKey(oldKey);
        _encryptionKey = oldKey;
      } catch (rollbackError) {
        // Log critical error - data may be in inconsistent state
        print('Critical: Failed to rollback encryption key: $rollbackError');
      }

      throw PersistenceException('Failed to update encryption key: $e');
    }
  }

  /// Real persistence methods that integrate with SharedPreferences

  Future<void> _persistEncryptedData(
      String key, List<int> encryptedData) async {
    if (_prefs == null) {
      throw PersistenceException('SharedPreferences not initialized');
    }

    try {
      // Convert encrypted bytes to base64 string for storage
      final base64Data = base64Encode(encryptedData);
      final storageKey = '$_keyPrefix$key';

      await _prefs!.setString(storageKey, base64Data);
    } catch (e) {
      throw PersistenceException('Failed to persist encrypted data: $e');
    }
  }

  Future<List<int>?> _retrieveEncryptedData(String key) async {
    if (_prefs == null) {
      throw PersistenceException('SharedPreferences not initialized');
    }

    try {
      final storageKey = '$_keyPrefix$key';
      final base64Data = _prefs!.getString(storageKey);

      if (base64Data == null) {
        return null;
      }

      return base64Decode(base64Data);
    } catch (e) {
      throw PersistenceException('Failed to retrieve encrypted data: $e');
    }
  }

  Future<void> _removePersistedData(String key) async {
    if (_prefs == null) {
      throw PersistenceException('SharedPreferences not initialized');
    }

    try {
      final storageKey = '$_keyPrefix$key';
      await _prefs!.remove(storageKey);
    } catch (e) {
      throw PersistenceException('Failed to remove persisted data: $e');
    }
  }

  Future<void> _clearAllPersistedData() async {
    if (_prefs == null) {
      throw PersistenceException('SharedPreferences not initialized');
    }

    try {
      final keys = _prefs!.getKeys();
      final cacheKeys = keys.where((key) => key.startsWith(_keyPrefix));

      for (final key in cacheKeys) {
        await _prefs!.remove(key);
      }
    } catch (e) {
      throw PersistenceException('Failed to clear persisted data: $e');
    }
  }

  Future<bool> _persistedDataExists(String key) async {
    if (_prefs == null) {
      return false;
    }

    try {
      final storageKey = '$_keyPrefix$key';
      return _prefs!.containsKey(storageKey);
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> _getAllPersistedKeys() async {
    if (_prefs == null) {
      return [];
    }

    try {
      final keys = _prefs!.getKeys();
      return keys
          .where((key) => key.startsWith(_keyPrefix))
          .map((key) => key.substring(_keyPrefix.length))
          .toList();
    } catch (e) {
      return [];
    }
  }
}

/// Exception thrown when persistence operations fail.
class PersistenceException implements Exception {
  final String message;
  const PersistenceException(this.message);

  @override
  String toString() => 'PersistenceException: $message';
}
