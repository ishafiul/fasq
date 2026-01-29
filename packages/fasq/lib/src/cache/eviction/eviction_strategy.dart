import 'package:fasq/src/cache/cache_entry.dart';

/// Strategy for selecting which cache entries to evict.
///
/// Different strategies implement different algorithms for choosing
/// which entries to remove when the cache is full.
typedef EvictionStrategy = List<String> Function(
  Map<String, CacheEntry<Object?>> entries,
  int currentSize,
  int targetSize,
);
