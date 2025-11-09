import 'package:fasq/fasq.dart';

import '../exceptions/encryption_exception.dart';
import '../exceptions/security_exception.dart';
import '../providers/crypto_encryption_provider.dart';
import '../providers/drift_persistence_provider.dart';
import '../providers/secure_storage_provider.dart';

/// Default security plugin providing production-ready security.
///
/// Uses:
/// - Crypto package for encryption (Dart SDK)
/// - flutter_secure_storage for key storage
/// - Drift for SQLite persistence
class DefaultSecurityPlugin implements SecurityPlugin {
  DefaultSecurityPlugin({
    SecurityProvider? storageProvider,
    EncryptionProvider? encryptionProvider,
    PersistenceProvider? persistenceProvider,
  })  : _ownsEncryptionProvider = encryptionProvider == null,
        _ownsPersistenceProvider = persistenceProvider == null {
    _storageFactory = storageProvider != null
        ? (() => storageProvider)
        : (() => SecureStorageProvider());
    _encryptionFactory = encryptionProvider != null
        ? (() => encryptionProvider)
        : (() =>
            CryptoEncryptionProvider(onDispose: _handleEncryptionDisposed));
    _persistenceFactory = persistenceProvider != null
        ? (() => persistenceProvider)
        : (() =>
            DriftPersistenceProvider(onDispose: _handlePersistenceDisposed));

    if (storageProvider != null) {
      _storageProvider = storageProvider;
    }
    if (encryptionProvider != null) {
      _encryptionProvider = encryptionProvider;
    }
    if (persistenceProvider != null) {
      _persistenceProvider = persistenceProvider;
    }
  }

  late final SecurityProvider Function() _storageFactory;
  late final EncryptionProvider Function() _encryptionFactory;
  late final PersistenceProvider Function() _persistenceFactory;

  SecurityProvider? _storageProvider;
  EncryptionProvider? _encryptionProvider;
  PersistenceProvider? _persistenceProvider;

  final bool _ownsEncryptionProvider;
  final bool _ownsPersistenceProvider;

  bool _initialized = false;

  @override
  String get name => 'Default Security Plugin';

  @override
  String get version => '1.0.0';

  @override
  bool get isSupported => _ensureStorageProvider().isSupported;

  @override
  bool get initializesProviders => true;

  @override
  SecurityProvider createStorageProvider() => _ensureStorageProvider();

  @override
  EncryptionProvider createEncryptionProvider() => _ensureEncryptionProvider();

  @override
  PersistenceProvider createPersistenceProvider() =>
      _ensurePersistenceProvider();

  @override
  Future<void> initialize() async {
    final requiresRefresh = _requiresRefresh();
    if (_initialized && !requiresRefresh) {
      return;
    }

    final storage = _ensureStorageProvider();
    final persistence = _ensurePersistenceProvider();
    _ensureEncryptionProvider();

    if (!isSupported) {
      throw const SecureStorageException('Secure storage is not supported');
    }

    try {
      await storage.initialize();
      await persistence.initialize();
      _initialized = true;
    } catch (error, stackTrace) {
      _initialized = false;
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  /// Gets the storage provider instance.
  SecurityProvider get storageProvider {
    if (!_initialized) {
      throw Exception('Plugin not initialized. Call initialize() first.');
    }
    return _ensureStorageProvider();
  }

  /// Gets the encryption provider instance.
  EncryptionProvider get encryptionProvider {
    if (!_initialized) {
      throw Exception('Plugin not initialized. Call initialize() first.');
    }
    return _ensureEncryptionProvider();
  }

  /// Gets the persistence provider instance.
  PersistenceProvider get persistenceProvider {
    if (!_initialized) {
      throw Exception('Plugin not initialized. Call initialize() first.');
    }
    return _ensurePersistenceProvider();
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

    final encryption = _ensureEncryptionProvider();
    final persistence = _ensurePersistenceProvider();
    final storage = _ensureStorageProvider();

    if (!encryption.isValidKey(newKey)) {
      throw const EncryptionException('Invalid encryption key');
    }

    final oldKey = await storage.getEncryptionKey();
    if (oldKey == null) {
      throw Exception('No existing encryption key found');
    }

    if (!persistence.supportsEncryptionKeyRotation) {
      throw UnsupportedError(
        'Persistence provider ${persistence.runtimeType} '
        'does not support encryption key rotation',
      );
    }

    await persistence.rotateEncryptionKey(
      oldKey,
      newKey,
      encryption,
      onProgress: onProgress,
    );

    await storage.setEncryptionKey(newKey);
  }

  SecurityProvider _ensureStorageProvider() {
    _storageProvider ??= _storageFactory();
    return _storageProvider!;
  }

  EncryptionProvider _ensureEncryptionProvider() {
    final current = _encryptionProvider;
    if (current is CryptoEncryptionProvider &&
        _ownsEncryptionProvider &&
        current.isDisposed) {
      _encryptionProvider = _encryptionFactory();
    } else if (current == null) {
      _encryptionProvider = _encryptionFactory();
    }
    return _encryptionProvider!;
  }

  PersistenceProvider _ensurePersistenceProvider() {
    final current = _persistenceProvider;
    if (current is DriftPersistenceProvider &&
        _ownsPersistenceProvider &&
        current.isDisposed) {
      _persistenceProvider = _persistenceFactory();
    } else if (current == null) {
      _persistenceProvider = _persistenceFactory();
    }
    return _persistenceProvider!;
  }

  void _handleEncryptionDisposed() {
    if (_ownsEncryptionProvider) {
      _encryptionProvider = null;
    }
  }

  void _handlePersistenceDisposed() {
    if (_ownsPersistenceProvider) {
      _persistenceProvider = null;
    }
  }

  bool _requiresRefresh() {
    if (!_initialized) {
      return false;
    }

    final encryption = _encryptionProvider;
    if (_ownsEncryptionProvider &&
        encryption is CryptoEncryptionProvider &&
        encryption.isDisposed) {
      return true;
    }

    final persistence = _persistenceProvider;
    if (_ownsPersistenceProvider &&
        persistence is DriftPersistenceProvider &&
        persistence.isDisposed) {
      return true;
    }

    return false;
  }
}
