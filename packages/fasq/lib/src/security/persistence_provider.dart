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
  Future<void> persist(String key, List<int> encryptedData);

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
  Future<void> persistMultiple(Map<String, List<int>> entries);

  /// Removes multiple keys efficiently.
  ///
  /// [keys] List of cache keys to remove
  Future<void> removeMultiple(List<String> keys);
}
