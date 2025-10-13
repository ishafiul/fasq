import '../cache_entry.dart';

/// Strategy for selecting which cache entries to evict.
///
/// Different strategies implement different algorithms for choosing
/// which entries to remove when the cache is full.
abstract class EvictionStrategy {
  /// Selects cache keys to evict to reach the target size.
  ///
  /// Returns a list of keys to remove from the cache.
  /// Should skip entries where referenceCount > 0 (actively in use).
  ///
  /// [entries] - The current cache entries
  /// [currentSize] - Current total cache size in bytes
  /// [targetSize] - Target size to reach after eviction
  List<String> selectKeysToEvict(
    Map<String, CacheEntry> entries,
    int currentSize,
    int targetSize,
  );
}

