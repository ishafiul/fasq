/// Abstract interface for secure key storage operations.
///
/// Implementations should use platform-specific secure storage
/// mechanisms like iOS Keychain or Android Keystore.
abstract class SecurityProvider {
  /// Initializes the security provider.
  Future<void> initialize();

  /// Retrieves the encryption key from secure storage.
  ///
  /// Returns null if no key is stored.
  Future<String?> getEncryptionKey();

  /// Stores an encryption key in secure storage.
  Future<void> setEncryptionKey(String key);

  /// Generates and stores a new encryption key.
  ///
  /// Returns the generated key.
  Future<String> generateAndStoreKey();

  /// Deletes the encryption key from secure storage.
  Future<void> deleteEncryptionKey();

  /// Checks if an encryption key exists in secure storage.
  Future<bool> hasEncryptionKey();

  /// Whether secure storage is supported on the current platform.
  bool get isSupported;
}

