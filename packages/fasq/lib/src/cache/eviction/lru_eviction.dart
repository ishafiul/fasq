import '../cache_entry.dart';
import 'eviction_strategy.dart';

/// Least Recently Used eviction strategy.
///
/// Evicts cache entries that haven't been accessed recently.
/// Best for general use where recent data is more likely to be needed again.
class LRUEviction implements EvictionStrategy {
  const LRUEviction();

  @override
  List<String> selectKeysToEvict(
    Map<String, CacheEntry> entries,
    int currentSize,
    int targetSize,
  ) {
    final evictableEntries =
        entries.entries.where((e) => e.value.referenceCount == 0).toList();

    evictableEntries.sort(
        (a, b) => a.value.lastAccessedAt.compareTo(b.value.lastAccessedAt));

    final keysToEvict = <String>[];
    int sizeToEvict = currentSize - targetSize;
    int evictedSize = 0;

    for (final entry in evictableEntries) {
      if (evictedSize >= sizeToEvict) break;

      keysToEvict.add(entry.key);
      evictedSize += entry.value.estimateSize();
    }

    return keysToEvict;
  }
}
