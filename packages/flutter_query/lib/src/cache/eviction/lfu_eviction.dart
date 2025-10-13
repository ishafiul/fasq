import '../cache_entry.dart';
import 'eviction_strategy.dart';

/// Least Frequently Used eviction strategy.
///
/// Evicts cache entries that are rarely accessed.
/// Best when some data is frequently reused while other data is accessed once.
class LFUEviction implements EvictionStrategy {
  const LFUEviction();

  @override
  List<String> selectKeysToEvict(
    Map<String, CacheEntry> entries,
    int currentSize,
    int targetSize,
  ) {
    final evictableEntries = entries.entries
        .where((e) => e.value.referenceCount == 0)
        .toList();

    evictableEntries.sort((a, b) =>
        a.value.accessCount.compareTo(b.value.accessCount));

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

