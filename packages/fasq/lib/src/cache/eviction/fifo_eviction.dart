import 'package:fasq/src/cache/cache_entry.dart';

/// First In First Out eviction: evicts the oldest cache entries first.
List<String> selectKeysToEvictFIFO(
  Map<String, CacheEntry<Object?>> entries,
  int currentSize,
  int targetSize,
) {
  final evictableEntries = entries.entries
      .where((e) => e.value.referenceCount == 0)
      .toList()
    ..sort((a, b) => a.value.createdAt.compareTo(b.value.createdAt));

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
