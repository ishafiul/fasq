/// Simple in-memory storage for now (will be replaced with proper Drift later)
class CacheDatabase {
  final Map<String, CacheEntry> _cache = {};

  /// Efficiently retrieves multiple cache entries by keys.
  Future<Map<String, List<int>>> getCacheEntries(List<String> keys) async {
    if (keys.isEmpty) return {};

    final result = <String, List<int>>{};
    for (final key in keys) {
      final entry = _cache[key];
      if (entry != null && entry.expiresAt.isAfter(DateTime.now())) {
        result[key] = entry.encryptedData;
      }
    }
    return result;
  }

  /// Efficiently inserts multiple cache entries.
  Future<void> insertCacheEntries(Map<String, List<int>> entries) async {
    if (entries.isEmpty) return;

    for (final entry in entries.entries) {
      _cache[entry.key] = CacheEntry(
        key: entry.key,
        encryptedData: entry.value,
        createdAt: DateTime.now(),
        expiresAt: DateTime.now().add(const Duration(days: 7)),
      );
    }
  }

  /// Efficiently deletes multiple cache entries by keys.
  Future<void> deleteCacheEntries(List<String> keys) async {
    if (keys.isEmpty) return;

    for (final key in keys) {
      _cache.remove(key);
    }
  }

  /// Gets all cache entry keys.
  Future<List<String>> getAllKeys() async {
    final now = DateTime.now();
    return _cache.entries
        .where((entry) => entry.value.expiresAt.isAfter(now))
        .map((entry) => entry.key)
        .toList();
  }

  /// Checks if a cache entry exists.
  Future<bool> exists(String key) async {
    final entry = _cache[key];
    return entry != null && entry.expiresAt.isAfter(DateTime.now());
  }

  /// Clears all cache entries.
  Future<void> clear() async {
    _cache.clear();
  }

  /// Cleans up expired cache entries.
  Future<int> cleanupExpired() async {
    final now = DateTime.now();
    final expiredKeys = _cache.entries
        .where((entry) => entry.value.expiresAt.isBefore(now))
        .map((entry) => entry.key)
        .toList();

    for (final key in expiredKeys) {
      _cache.remove(key);
    }

    return expiredKeys.length;
  }
}

/// Simple cache entry class
class CacheEntry {
  final String key;
  final List<int> encryptedData;
  final DateTime createdAt;
  final DateTime expiresAt;

  CacheEntry({
    required this.key,
    required this.encryptedData,
    required this.createdAt,
    required this.expiresAt,
  });
}
