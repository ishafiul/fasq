import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:fasq/fasq.dart';
import '../exceptions/security_exception.dart';

/// Implementation of SecurityProvider using flutter_secure_storage.
///
/// Uses platform-specific secure storage mechanisms:
/// - iOS: Keychain
/// - Android: EncryptedSharedPreferences
/// - Web: Not supported (throws UnsupportedError)
/// - Desktop: Platform-specific secure storage
class SecureStorageProvider implements SecurityProvider {
  static const String _keyIdKey = 'fasq_key_id';

  final FlutterSecureStorage _storage;

  SecureStorageProvider() : _storage = const FlutterSecureStorage();

  @override
  Future<void> initialize() async {
    // No initialization needed for flutter_secure_storage
  }

  @override
  Future<String?> getEncryptionKey() async {
    try {
      return await _storage.read(key: _keyIdKey);
    } catch (e) {
      throw SecureStorageException('Failed to read encryption key: $e');
    }
  }

  @override
  Future<void> setEncryptionKey(String key) async {
    try {
      await _storage.write(key: _keyIdKey, value: key);
    } catch (e) {
      throw SecureStorageException('Failed to store encryption key: $e');
    }
  }

  @override
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

  @override
  Future<bool> hasEncryptionKey() async {
    try {
      final key = await getEncryptionKey();
      return key != null && key.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> deleteEncryptionKey() async {
    try {
      await _storage.delete(key: _keyIdKey);
    } catch (e) {
      throw SecureStorageException('Failed to delete encryption key: $e');
    }
  }

  @override
  bool get isSupported {
    if (kIsWeb) {
      return false; // Web doesn't support secure storage
    }
    return true;
  }

  /// Generates a random encryption key.
  String _generateRandomKey() {
    // Generate 32 random bytes and encode as base64
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }
}
