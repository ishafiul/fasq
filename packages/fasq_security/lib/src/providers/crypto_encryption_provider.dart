import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';

import 'package:fasq/fasq.dart';
import 'package:pointycastle/export.dart';

import '../exceptions/encryption_exception.dart';

/// Implementation of EncryptionProvider using Dart SDK crypto package.
///
/// Provides AES-GCM encryption with isolate support for large data
/// to prevent UI blocking during encryption/decryption operations.
class CryptoEncryptionProvider implements EncryptionProvider {
  static const int _largeDataThreshold = 50 * 1024; // 50KB

  @override
  Future<List<int>> encrypt(List<int> data, String key) async {
    if (data.length > _largeDataThreshold) {
      return await _encryptInIsolate(data, key);
    }
    return _encryptOnMainThread(data, key);
  }

  @override
  Future<List<int>> decrypt(List<int> data, String key) async {
    if (data.length > _largeDataThreshold) {
      return await _decryptInIsolate(data, key);
    }
    return _decryptOnMainThread(data, key);
  }

  @override
  String generateKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Encode(bytes);
  }

  @override
  bool isValidKey(String key) {
    try {
      base64Decode(key);
      return key.length >= 32; // Ensure minimum key length
    } catch (e) {
      return false;
    }
  }

  /// Encrypts data on the main thread using AES-GCM.
  List<int> _encryptOnMainThread(List<int> data, String key) {
    try {
      final keyBytes = base64Decode(key);
      if (keyBytes.length != 32) {
        throw EncryptionException(
          'Invalid key length. Expected 32 bytes, got ${keyBytes.length}',
        );
      }

      // Generate random IV (12 bytes for GCM)
      final random = Random.secure();
      final iv = List<int>.generate(12, (i) => random.nextInt(256));

      // Convert data to Uint8List for crypto operations
      final dataBytes = Uint8List.fromList(data);
      final keyUint8 = Uint8List.fromList(keyBytes);
      final ivUint8 = Uint8List.fromList(iv);

      // Create AES-GCM cipher
      final cipher = GCMBlockCipher(AESEngine());
      final keyParam = KeyParameter(keyUint8);
      final params = AEADParameters(keyParam, 128, ivUint8, Uint8List(0));

      cipher.init(true, params);

      // Encrypt the data
      final encrypted = cipher.process(dataBytes);

      // Combine IV + encrypted data
      final result = <int>[];
      result.addAll(iv); // 12 bytes IV
      result.addAll(encrypted); // encrypted data

      return result;
    } catch (e) {
      throw EncryptionException('Failed to encrypt data: $e');
    }
  }

  /// Decrypts data on the main thread using AES-GCM.
  List<int> _decryptOnMainThread(List<int> data, String key) {
    try {
      final keyBytes = base64Decode(key);
      if (keyBytes.length != 32) {
        throw EncryptionException(
          'Invalid key length. Expected 32 bytes, got ${keyBytes.length}',
        );
      }

      if (data.length < 12) {
        throw EncryptionException(
          'Invalid encrypted data. Too short to contain IV',
        );
      }

      // Extract IV (first 12 bytes) and encrypted data
      final iv = data.take(12).toList();
      final encryptedData = data.skip(12).toList();

      // Convert to Uint8List for crypto operations
      final keyUint8 = Uint8List.fromList(keyBytes);
      final ivUint8 = Uint8List.fromList(iv);
      final encryptedUint8 = Uint8List.fromList(encryptedData);

      // Create AES-GCM cipher
      final cipher = GCMBlockCipher(AESEngine());
      final keyParam = KeyParameter(keyUint8);
      final params = AEADParameters(keyParam, 128, ivUint8, Uint8List(0));

      cipher.init(false, params);

      // Decrypt the data
      final decrypted = cipher.process(encryptedUint8);

      return decrypted;
    } catch (e) {
      throw EncryptionException('Failed to decrypt data: $e');
    }
  }

  /// Encrypts data in a background isolate.
  Future<List<int>> _encryptInIsolate(List<int> data, String key) async {
    try {
      final result = await Isolate.run(() {
        final keyBytes = base64Decode(key);
        if (keyBytes.length != 32) {
          throw EncryptionException(
            'Invalid key length. Expected 32 bytes, got ${keyBytes.length}',
          );
        }

        // Generate random IV (12 bytes for GCM)
        final random = Random.secure();
        final iv = List<int>.generate(12, (i) => random.nextInt(256));

        // Convert data to Uint8List for crypto operations
        final dataBytes = Uint8List.fromList(data);
        final keyUint8 = Uint8List.fromList(keyBytes);
        final ivUint8 = Uint8List.fromList(iv);

        // Create AES-GCM cipher
        final cipher = GCMBlockCipher(AESEngine());
        final keyParam = KeyParameter(keyUint8);
        final params = AEADParameters(keyParam, 128, ivUint8, Uint8List(0));

        cipher.init(true, params);

        // Encrypt the data
        final encrypted = cipher.process(dataBytes);

        // Combine IV + encrypted data
        final result = <int>[];
        result.addAll(iv); // 12 bytes IV
        result.addAll(encrypted); // encrypted data

        return result;
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
        final keyBytes = base64Decode(key);
        if (keyBytes.length != 32) {
          throw EncryptionException(
            'Invalid key length. Expected 32 bytes, got ${keyBytes.length}',
          );
        }

        if (data.length < 12) {
          throw EncryptionException(
            'Invalid encrypted data. Too short to contain IV',
          );
        }

        // Extract IV (first 12 bytes) and encrypted data
        final iv = data.take(12).toList();
        final encryptedData = data.skip(12).toList();

        // Convert to Uint8List for crypto operations
        final keyUint8 = Uint8List.fromList(keyBytes);
        final ivUint8 = Uint8List.fromList(iv);
        final encryptedUint8 = Uint8List.fromList(encryptedData);

        // Create AES-GCM cipher
        final cipher = GCMBlockCipher(AESEngine());
        final keyParam = KeyParameter(keyUint8);
        final params = AEADParameters(keyParam, 128, ivUint8, Uint8List(0));

        cipher.init(false, params);

        // Decrypt the data
        final decrypted = cipher.process(encryptedUint8);

        return decrypted;
      });
      return result;
    } catch (e) {
      throw EncryptionException('Failed to decrypt data in isolate: $e');
    }
  }
}
