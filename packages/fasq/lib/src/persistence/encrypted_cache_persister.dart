import 'dart:async';
import 'dart:convert';

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

  EncryptedCachePersister({
    EncryptionService? encryptionService,
    SecureStorage? secureStorage,
  })  : _encryptionService = encryptionService ?? EncryptionService(),
        _secureStorage = secureStorage ?? SecureStorage();

  /// Initializes the persister and ensures an encryption key is available.
  ///
  /// If no key exists, generates and stores a new one.
  Future<void> initialize() async {
    if (!_secureStorage.isSupported) {
      throw UnsupportedError('Secure storage not supported on this platform');
    }

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
  /// This would require re-encrypting all existing data with the new key.
  Future<void> updateEncryptionKey(String newKey) async {
    if (!_encryptionService.isValidKey(newKey)) {
      throw EncryptionException('Invalid encryption key format');
    }

    // In a real implementation, this would:
    // 1. Retrieve all existing data
    // 2. Decrypt with old key
    // 3. Encrypt with new key
    // 4. Store encrypted data
    // 5. Update stored key

    await _secureStorage.setEncryptionKey(newKey);
    _encryptionKey = newKey;
  }

  /// Placeholder methods that would integrate with actual persistence layer
  /// In a real implementation, these would use SharedPreferences, SQLite, etc.

  Future<void> _persistEncryptedData(
      String key, List<int> encryptedData) async {
    // This would integrate with actual persistence layer
    // For now, we'll just simulate the operation
    await Future.delayed(Duration(milliseconds: 1));
  }

  Future<List<int>?> _retrieveEncryptedData(String key) async {
    // This would integrate with actual persistence layer
    // For now, we'll just simulate the operation
    await Future.delayed(Duration(milliseconds: 1));
    return null;
  }

  Future<void> _removePersistedData(String key) async {
    // This would integrate with actual persistence layer
    await Future.delayed(Duration(milliseconds: 1));
  }

  Future<void> _clearAllPersistedData() async {
    // This would integrate with actual persistence layer
    await Future.delayed(Duration(milliseconds: 1));
  }

  Future<bool> _persistedDataExists(String key) async {
    // This would integrate with actual persistence layer
    await Future.delayed(Duration(milliseconds: 1));
    return false;
  }

  Future<List<String>> _getAllPersistedKeys() async {
    // This would integrate with actual persistence layer
    await Future.delayed(Duration(milliseconds: 1));
    return [];
  }
}

/// Exception thrown when persistence operations fail.
class PersistenceException implements Exception {
  final String message;
  const PersistenceException(this.message);

  @override
  String toString() => 'PersistenceException: $message';
}
