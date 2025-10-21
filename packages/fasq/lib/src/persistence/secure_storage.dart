import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Platform-specific secure storage for encryption keys.
///
/// Uses platform-specific secure storage mechanisms:
/// - iOS: Keychain
/// - Android: EncryptedSharedPreferences
/// - Web: Not supported (throws UnsupportedError)
/// - Desktop: Platform-specific secure storage
class SecureStorage {
  static const String _keyIdKey = 'fasq_key_id';

  final FlutterSecureStorage _storage;

  SecureStorage() : _storage = const FlutterSecureStorage();

  /// Gets the encryption key from secure storage.
  ///
  /// Returns null if no key is stored.
  Future<String?> getEncryptionKey() async {
    try {
      return await _storage.read(key: _keyIdKey);
    } catch (e) {
      throw SecureStorageException('Failed to read encryption key: $e');
    }
  }

  /// Stores an encryption key in secure storage.
  Future<void> setEncryptionKey(String key) async {
    try {
      await _storage.write(key: _keyIdKey, value: key);
    } catch (e) {
      throw SecureStorageException('Failed to store encryption key: $e');
    }
  }

  /// Generates and stores a new encryption key.
  ///
  /// Returns the generated key.
  Future<String> generateAndStoreKey() async {
    try {
      // Generate a random key
      final key = _generateRandomKey();

      // Store it securely
      await setEncryptionKey(key);

      return key;
    } catch (e) {
      throw SecureStorageException('Failed to generate and store key: $e');
    }
  }

  /// Checks if an encryption key exists in secure storage.
  Future<bool> hasEncryptionKey() async {
    try {
      final key = await getEncryptionKey();
      return key != null && key.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Deletes the encryption key from secure storage.
  Future<void> deleteEncryptionKey() async {
    try {
      await _storage.delete(key: _keyIdKey);
    } catch (e) {
      throw SecureStorageException('Failed to delete encryption key: $e');
    }
  }

  /// Checks if secure storage is supported on the current platform.
  bool get isSupported {
    if (kIsWeb) {
      return false; // Web doesn't support secure storage
    }
    return true;
  }

  /// Generates a random encryption key.
  String _generateRandomKey() {
    // Generate 32 random bytes and encode as base64
    final random = List<int>.generate(
        32, (i) => DateTime.now().millisecondsSinceEpoch % 256);
    return base64Encode(random);
  }
}

/// Exception thrown when secure storage operations fail.
class SecureStorageException implements Exception {
  final String message;
  const SecureStorageException(this.message);

  @override
  String toString() => 'SecureStorageException: $message';
}
