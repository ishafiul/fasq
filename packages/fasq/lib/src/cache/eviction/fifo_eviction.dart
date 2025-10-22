import '../cache_entry.dart';
import 'eviction_strategy.dart';

/// First In First Out eviction strategy.
///
/// Evicts the oldest cache entries first.
/// Simple but effective for time-based data.
class FIFOEviction implements EvictionStrategy {
  const FIFOEviction();

  @override
  List<String> selectKeysToEvict(
    Map<String, CacheEntry> entries,
    int currentSize,
    int targetSize,
  ) {
    final evictableEntries =
        entries.entries.where((e) => e.value.referenceCount == 0).toList();

    evictableEntries
        .sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));

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
