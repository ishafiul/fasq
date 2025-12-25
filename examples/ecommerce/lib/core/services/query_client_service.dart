import 'package:fasq/fasq.dart';
import 'package:fasq_security/fasq_security.dart';
import 'package:injectable/injectable.dart';

/// Service for managing QueryClient with security features.
///
/// This service configures QueryClient with:
/// - [SecureStorageProvider]: Secure key storage using flutter_secure_storage
/// - [CryptoEncryptionProvider]: Encryption using Dart crypto package
/// - [DriftPersistenceProvider]: SQLite persistence using Drift
@singleton
class QueryClientService {
  late final QueryClient _client;
  late final DefaultSecurityPlugin _securityPlugin;
  late final SecureStorageProvider _storageProvider;
  late final CryptoEncryptionProvider _encryptionProvider;
  late final DriftPersistenceProvider _persistenceProvider;

  QueryClientService() {
    // Initialize security providers
    _storageProvider = SecureStorageProvider();
    _encryptionProvider = CryptoEncryptionProvider();
    _persistenceProvider = DriftPersistenceProvider();

    // Configure security plugin with all providers
    _securityPlugin = DefaultSecurityPlugin(
      storageProvider: _storageProvider,
      encryptionProvider: _encryptionProvider,
      persistenceProvider: _persistenceProvider,
    );

    // Configure QueryClient with security plugin and persistence enabled
    _client = QueryClient(
      config: const CacheConfig(
        defaultStaleTime: Duration(minutes: 5),
        defaultCacheTime: Duration(minutes: 30),
        maxCacheSize: 100 * 1024 * 1024, // 100MB
      ),
      persistenceOptions: const PersistenceOptions(
        enabled: true,
      ),
      securityPlugin: _securityPlugin,
    );
  }

  /// Initializes the security plugin and all providers.
  ///
  /// This must be called before using the QueryClient.
  Future<void> initialize() async {
    await _securityPlugin.initialize();
  }

  /// Gets the QueryClient instance.
  QueryClient get client => _client;

  /// Gets the security plugin instance.
  DefaultSecurityPlugin get securityPlugin => _securityPlugin;

  /// Gets the secure storage provider.
  SecureStorageProvider get storageProvider => _storageProvider;

  /// Gets the encryption provider.
  CryptoEncryptionProvider get encryptionProvider => _encryptionProvider;

  /// Gets the persistence provider.
  DriftPersistenceProvider get persistenceProvider => _persistenceProvider;
}
