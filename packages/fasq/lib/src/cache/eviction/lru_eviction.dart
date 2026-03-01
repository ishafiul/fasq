import 'package:fasq/src/cache/cache_entry.dart';

/// Least Recently Used eviction: evicts entries that haven't been accessed
/// recently.
List<String> selectKeysToEvictLRU(
  Map<String, CacheEntry<Object?>> entries,
  int currentSize,
  int targetSize,
) {
  final evictableEntries =
      entries.entries.where((e) => e.value.referenceCount == 0).toList()
        ..sort(
          (a, b) => a.value.lastAccessedAt.compareTo(b.value.lastAccessedAt),
        );

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
