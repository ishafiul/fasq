import 'package:fasq/src/security/encryption_provider.dart';

/// Abstract interface for encrypted data persistence operations.
///
/// Implementations should provide secure storage for encrypted cache data
/// with efficient querying and batch operations.
abstract class PersistenceProvider {
  /// Initializes the persistence provider.
  Future<void> initialize();

  /// Persists encrypted data for a key.
  ///
  /// [key] The cache key
  /// [encryptedData] The encrypted data to store
  Future<void> persist(
    String key,
    List<int> encryptedData, {
    DateTime? createdAt,
    DateTime? expiresAt,
  });

  /// Retrieves encrypted data for a key.
  ///
  /// [key] The cache key
  /// Returns the encrypted data if found, null otherwise
  Future<List<int>?> retrieve(String key);

  /// Removes persisted data for a key.
  ///
  /// [key] The cache key to remove
  Future<void> remove(String key);

  /// Clears all persisted data.
  Future<void> clear();

  /// Checks if data exists for a key.
  ///
  /// [key] The cache key to check
  /// Returns true if data exists, false otherwise
  Future<bool> exists(String key);

  /// Gets all persisted keys.
  ///
  /// Returns a list of all keys that have persisted data
  Future<List<String>> getAllKeys();

  /// Retrieves multiple encrypted data entries efficiently.
  ///
  /// [keys] List of cache keys to retrieve
  /// Returns a map of key to encrypted data for found entries
  Future<Map<String, List<int>>> retrieveMultiple(List<String> keys);

  /// Persists multiple encrypted data entries efficiently.
  ///
  /// [entries] Map of key to encrypted data to store
  Future<void> persistMultiple(
    Map<String, List<int>> entries, {
    Map<String, DateTime?>? createdAt,
    Map<String, DateTime?>? expiresAt,
  });

  /// Removes multiple keys efficiently.
  ///
  /// [keys] List of cache keys to remove
  Future<void> removeMultiple(List<String> keys);

  /// Releases resources held by the persistence provider.
  Future<void> dispose();

  /// Whether this provider supports encryption key rotation in-place.
  bool get supportsEncryptionKeyRotation;

  /// Re-encrypts all persisted entries from [oldKey] to [newKey].
  ///
  /// [encryptionProvider] is used to decrypt existing values and encrypt with
  /// the new key. [onProgress], when provided, receives progress updates as
  /// `(current, total)`.
  Future<void> rotateEncryptionKey(
    String oldKey,
    String newKey,
    EncryptionProvider encryptionProvider, {
    void Function(int current, int total)? onProgress,
  });
}
