import 'package:fasq/fasq.dart';
import '../providers/crypto_encryption_provider.dart';
import '../providers/secure_storage_provider.dart';
import '../providers/drift_persistence_provider.dart';

/// Default security plugin providing production-ready security.
///
/// Uses:
/// - Crypto package for encryption (Dart SDK)
/// - flutter_secure_storage for key storage
/// - Drift for SQLite persistence
class DefaultSecurityPlugin implements SecurityPlugin {
  late SecurityProvider _storageProvider;
  late EncryptionProvider _encryptionProvider;
  late PersistenceProvider _persistenceProvider;
  bool _initialized = false;

  @override
  String get name => 'Default Security Plugin';

  @override
  String get version => '1.0.0';

  @override
  bool get isSupported => true;

  @override
  SecurityProvider createStorageProvider() {
    return SecureStorageProvider();
  }

  @override
  EncryptionProvider createEncryptionProvider() {
    return CryptoEncryptionProvider();
  }

  @override
  PersistenceProvider createPersistenceProvider() {
    return DriftPersistenceProvider();
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      _storageProvider = createStorageProvider();
      _encryptionProvider = createEncryptionProvider();
      _persistenceProvider = createPersistenceProvider();

      // Initialize all providers
      await _storageProvider.initialize();
      await _persistenceProvider.initialize();

      _initialized = true;
    } catch (e) {
      throw Exception('Failed to initialize DefaultSecurityPlugin: $e');
    }
  }

  /// Gets the storage provider instance.
  SecurityProvider get storageProvider {
    if (!_initialized) {
      throw Exception('Plugin not initialized. Call initialize() first.');
    }
    return _storageProvider;
  }

  /// Gets the encryption provider instance.
  EncryptionProvider get encryptionProvider {
    if (!_initialized) {
      throw Exception('Plugin not initialized. Call initialize() first.');
    }
    return _encryptionProvider;
  }

  /// Gets the persistence provider instance.
  PersistenceProvider get persistenceProvider {
    if (!_initialized) {
      throw Exception('Plugin not initialized. Call initialize() first.');
    }
    return _persistenceProvider;
  }

  /// Updates the encryption key across all providers.
  ///
  /// This re-encrypts all existing data with the new key and updates
  /// the secure storage with the new key.
  Future<void> updateEncryptionKey(
    String newKey, {
    void Function(int current, int total)? onProgress,
  }) async {
    if (!_initialized) {
      throw Exception('Plugin not initialized. Call initialize() first.');
    }

    final oldKey = await _storageProvider.getEncryptionKey();
    if (oldKey == null) {
      throw Exception('No existing encryption key found');
    }

    // Update the persistence provider with the new key
    if (_persistenceProvider is DriftPersistenceProvider) {
      final driftProvider = _persistenceProvider as DriftPersistenceProvider;
      await driftProvider.updateEncryptionKey(
        oldKey,
        newKey,
        _encryptionProvider,
        onProgress: onProgress,
      );
    }

    // Update the secure storage with the new key
    await _storageProvider.setEncryptionKey(newKey);
  }
}
