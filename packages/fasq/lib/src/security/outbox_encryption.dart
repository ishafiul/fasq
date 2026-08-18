import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';
import 'package:fasq/src/security/encryption_provider.dart';
import 'package:fasq/src/security/security_provider.dart';

/// Encryption boundary used by durable outbox backends.
abstract class OutboxEncryption {
  /// Prepares key material before the store is read or created.
  Future<void> prepare({required bool allowCreateKey});

  /// Encrypts a logical payload before it reaches disk.
  Future<List<int>> encrypt(List<int> plaintext);

  /// Decrypts a logical payload recovered from disk.
  Future<List<int>> decrypt(List<int> ciphertext);
}

/// Adapter that connects Fasq's security providers to the durable outbox.
class SecurityProviderOutboxEncryption implements OutboxEncryption {
  /// Creates an adapter around platform key storage and crypto providers.
  SecurityProviderOutboxEncryption({
    required this.securityProvider,
    required this.encryptionProvider,
  });

  /// Platform-backed key provider.
  final SecurityProvider securityProvider;

  /// Application-selected encryption implementation.
  final EncryptionProvider encryptionProvider;

  String? _key;

  @override
  Future<void> prepare({required bool allowCreateKey}) async {
    await securityProvider.initialize();
    var key = await securityProvider.getEncryptionKey();
    if (key == null && allowCreateKey) {
      key = await securityProvider.generateAndStoreKey();
    }
    if (key == null || !encryptionProvider.isValidKey(key)) {
      throw const OutboxEncryptionException();
    }
    _key = key;
  }

  @override
  Future<List<int>> encrypt(List<int> plaintext) async {
    final key = _key;
    if (key == null) throw const OutboxEncryptionException();
    try {
      return await encryptionProvider.encrypt(plaintext, key);
    } on Exception {
      throw const OutboxEncryptionException();
    }
  }

  @override
  Future<List<int>> decrypt(List<int> ciphertext) async {
    final key = _key;
    if (key == null) throw const OutboxEncryptionException();
    try {
      return await encryptionProvider.decrypt(ciphertext, key);
    } on Exception {
      throw const OutboxEncryptionException();
    }
  }
}
