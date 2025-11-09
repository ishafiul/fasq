import 'dart:async';
import 'dart:convert';
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
  CryptoEncryptionProvider({
    IsolatePool? isolatePool,
    void Function()? onDispose,
  })  : _isolatePool = isolatePool ?? IsolatePool(poolSize: 2),
        _onDispose = onDispose;

  static const int _largeDataThreshold = 50 * 1024; // 50KB
  final IsolatePool _isolatePool;
  bool _isDisposed = false;
  final void Function()? _onDispose;

  bool get isDisposed => _isDisposed;

  @override
  Future<List<int>> encrypt(List<int> data, String key) async {
    _ensureNotDisposed();
    if (data.length > _largeDataThreshold) {
      return await _encryptInIsolate(data, key);
    }
    return _encryptOnMainThread(data, key);
  }

  @override
  Future<List<int>> decrypt(List<int> data, String key) async {
    _ensureNotDisposed();
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

  @override
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;
    await _isolatePool.dispose();
    _onDispose?.call();
  }

  void _ensureNotDisposed() {
    if (_isDisposed) {
      throw const EncryptionException('Encryption provider is disposed');
    }
  }

  /// Encrypts data on the main thread using AES-GCM.
  List<int> _encryptOnMainThread(List<int> data, String key) {
    try {
      return _encryptBytes(data, key);
    } catch (e) {
      throw EncryptionException('Failed to encrypt data: $e');
    }
  }

  /// Decrypts data on the main thread using AES-GCM.
  List<int> _decryptOnMainThread(List<int> data, String key) {
    try {
      return _decryptBytes(data, key);
    } catch (e) {
      throw EncryptionException('Failed to decrypt data: $e');
    }
  }

  /// Encrypts data in a background isolate.
  Future<List<int>> _encryptInIsolate(List<int> data, String key) async {
    try {
      return await _isolatePool.execute<Map<String, Object?>, List<int>>(
        _encryptInPool,
        {
          'data': List<int>.from(data),
          'key': key,
        },
      );
    } catch (e) {
      throw EncryptionException('Failed to encrypt data in isolate: $e');
    }
  }

  /// Decrypts data in a background isolate.
  Future<List<int>> _decryptInIsolate(List<int> data, String key) async {
    try {
      return await _isolatePool.execute<Map<String, Object?>, List<int>>(
        _decryptInPool,
        {
          'data': List<int>.from(data),
          'key': key,
        },
      );
    } catch (e) {
      throw EncryptionException('Failed to decrypt data in isolate: $e');
    }
  }
}

List<int> _encryptBytes(List<int> data, String key) {
  final keyBytes = base64Decode(key);
  if (keyBytes.length != 32) {
    throw EncryptionException(
      'Invalid key length. Expected 32 bytes, got ${keyBytes.length}',
    );
  }

  final random = Random.secure();
  final iv = List<int>.generate(12, (i) => random.nextInt(256));

  final dataBytes = Uint8List.fromList(data);
  final keyUint8 = Uint8List.fromList(keyBytes);
  final ivUint8 = Uint8List.fromList(iv);

  final cipher = GCMBlockCipher(AESEngine());
  final keyParam = KeyParameter(keyUint8);
  final params = AEADParameters(keyParam, 128, ivUint8, Uint8List(0));

  cipher.init(true, params);

  final encrypted = cipher.process(dataBytes);

  return <int>[
    ...iv,
    ...encrypted,
  ];
}

List<int> _decryptBytes(List<int> data, String key) {
  final keyBytes = base64Decode(key);
  if (keyBytes.length != 32) {
    throw EncryptionException(
      'Invalid key length. Expected 32 bytes, got ${keyBytes.length}',
    );
  }

  if (data.length < 12) {
    throw const EncryptionException(
      'Invalid encrypted data. Too short to contain IV',
    );
  }

  final iv = data.take(12).toList();
  final encryptedData = data.skip(12).toList();

  final keyUint8 = Uint8List.fromList(keyBytes);
  final ivUint8 = Uint8List.fromList(iv);
  final encryptedUint8 = Uint8List.fromList(encryptedData);

  final cipher = GCMBlockCipher(AESEngine());
  final keyParam = KeyParameter(keyUint8);
  final params = AEADParameters(keyParam, 128, ivUint8, Uint8List(0));

  cipher.init(false, params);

  return cipher.process(encryptedUint8);
}

List<int> _encryptInPool(Map<String, Object?> payload) {
  final data = (payload['data'] as List).cast<int>();
  final key = payload['key'] as String;
  return _encryptBytes(data, key);
}

List<int> _decryptInPool(Map<String, Object?> payload) {
  final data = (payload['data'] as List).cast<int>();
  final key = payload['key'] as String;
  return _decryptBytes(data, key);
}
