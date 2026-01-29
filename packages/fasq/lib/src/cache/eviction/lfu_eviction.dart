import 'package:fasq/src/cache/cache_entry.dart';

/// Least Frequently Used eviction: evicts cache entries that are rarely
/// accessed.
List<String> selectKeysToEvictLFU(
  Map<String, CacheEntry<Object?>> entries,
  int currentSize,
  int targetSize,
) {
  final evictableEntries = entries.entries
      .where((e) => e.value.referenceCount == 0)
      .toList()
    ..sort((a, b) => a.value.accessCount.compareTo(b.value.accessCount));

  final keysToEvict = <String>[];
  final sizeToEvict = currentSize - targetSize;
  var evictedSize = 0;

  for (final entry in evictableEntries) {
    if (evictedSize >= sizeToEvict) break;

    keysToEvict.add(entry.key);
    evictedSize += entry.value.estimateSize();
  }

  return keysToEvict;
}
