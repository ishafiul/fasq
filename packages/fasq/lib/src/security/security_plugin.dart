import 'security_provider.dart';
import 'encryption_provider.dart';
import 'persistence_provider.dart';

/// Abstract interface for security plugins.
///
/// Security plugins provide implementations for secure storage, encryption,
/// and persistence operations. This allows the core FASQ package to remain
/// dependency-free while providing flexible security options.
abstract class SecurityPlugin {
  /// Creates a secure storage provider for managing encryption keys.
  SecurityProvider createStorageProvider();

  /// Creates an encryption provider for encrypting/decrypting data.
  EncryptionProvider createEncryptionProvider();

  /// Creates a persistence provider for storing encrypted data.
  PersistenceProvider createPersistenceProvider();

  /// Human-readable name of this security plugin.
  String get name;

  /// Version of this security plugin.
  String get version;

  /// Whether this plugin is supported on the current platform.
  bool get isSupported;

  /// Initializes the security plugin and all its providers.
  Future<void> initialize();
}
