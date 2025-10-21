import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart';

/// Service for encrypting and decrypting cache data using AES-GCM.
///
/// Handles both main thread encryption for small data and isolate-based
/// encryption for large data to prevent UI blocking.
class EncryptionService {
  static const int _largeDataThreshold = 50 * 1024; // 50KB

  /// Encrypts data using AES-GCM.
  ///
  /// For data larger than [_largeDataThreshold], encryption is performed
  /// in a background isolate to prevent UI blocking.
  Future<List<int>> encrypt(List<int> data, String key) async {
    if (data.length > _largeDataThreshold) {
      return await _encryptInIsolate(data, key);
    }
    return _encryptOnMainThread(data, key);
  }

  /// Decrypts data using AES-GCM.
  ///
  /// For data larger than [_largeDataThreshold], decryption is performed
  /// in a background isolate to prevent UI blocking.
  Future<List<int>> decrypt(List<int> data, String key) async {
    if (data.length > _largeDataThreshold) {
      return await _decryptInIsolate(data, key);
    }
    return _decryptOnMainThread(data, key);
  }

  /// Encrypts data on the main thread.
  List<int> _encryptOnMainThread(List<int> data, String key) {
    try {
      final encrypter = Encrypter(AES(Key.fromBase64(key)));
      final iv = IV.fromSecureRandom(16); // Generate random IV for GCM
      final encrypted =
          encrypter.encryptBytes(Uint8List.fromList(data), iv: iv);
      // Prepend IV to encrypted data
      return [...iv.bytes, ...encrypted.bytes];
    } catch (e) {
      throw EncryptionException('Failed to encrypt data: $e');
    }
  }

  /// Decrypts data on the main thread.
  List<int> _decryptOnMainThread(List<int> data, String key) {
    try {
      final encrypter = Encrypter(AES(Key.fromBase64(key)));
      // Extract IV from the beginning of the data
      final iv = IV(Uint8List.fromList(data.take(16).toList()));
      final encryptedData = Uint8List.fromList(data.skip(16).toList());
      final encrypted = Encrypted(encryptedData);
      final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
      return decrypted;
    } catch (e) {
      throw EncryptionException('Failed to decrypt data: $e');
    }
  }

  /// Encrypts data in a background isolate.
  Future<List<int>> _encryptInIsolate(List<int> data, String key) async {
    try {
      final result = await Isolate.run(() {
        final encrypter = Encrypter(AES(Key.fromBase64(key)));
        final iv = IV.fromSecureRandom(16); // Generate random IV for GCM
        final encrypted =
            encrypter.encryptBytes(Uint8List.fromList(data), iv: iv);
        // Prepend IV to encrypted data
        return [...iv.bytes, ...encrypted.bytes];
      });
      return result;
    } catch (e) {
      throw EncryptionException('Failed to encrypt data in isolate: $e');
    }
  }

  /// Decrypts data in a background isolate.
  Future<List<int>> _decryptInIsolate(List<int> data, String key) async {
    try {
      final result = await Isolate.run(() {
        final encrypter = Encrypter(AES(Key.fromBase64(key)));
        // Extract IV from the beginning of the data
        final iv = IV(Uint8List.fromList(data.take(16).toList()));
        final encryptedData = Uint8List.fromList(data.skip(16).toList());
        final encrypted = Encrypted(encryptedData);
        final decrypted = encrypter.decryptBytes(encrypted, iv: iv);
        return decrypted;
      });
      return result;
    } catch (e) {
      throw EncryptionException('Failed to decrypt data in isolate: $e');
    }
  }

  /// Generates a new encryption key.
  String generateKey() {
    final key = Key.fromSecureRandom(32);
    return key.base64;
  }

  /// Validates that a key is properly formatted.
  bool isValidKey(String key) {
    try {
      Key.fromBase64(key);
      return true;
    } catch (e) {
      return false;
    }
  }
}

/// Exception thrown when encryption/decryption fails.
class EncryptionException implements Exception {
  final String message;
  const EncryptionException(this.message);

  @override
  String toString() => 'EncryptionException: $message';
}
