/// Metrics for monitoring cache performance.
///
/// Tracks cache hits, misses, and other statistics useful for
/// performance tuning and debugging.
class CacheMetrics {
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  /// Total number of cache hits (data found in cache).
  int get hits => _hits;

  /// Total number of cache misses (data not in cache).
  int get misses => _misses;

  /// Total number of cache evictions.
  int get evictions => _evictions;

  /// Total number of cache requests.
  int get totalRequests => _hits + _misses;

  /// Cache hit rate (0.0 to 1.0).
  ///
  /// Returns 0.0 if no requests have been made.
  double get hitRate {
    final total = totalRequests;
    if (total == 0) return 0.0;
    return _hits / total;
  }

  /// Records a cache hit.
  void recordHit() {
    _hits++;
  }

  /// Records a cache miss.
  void recordMiss() {
    _misses++;
  }

  /// Records a cache eviction.
  void recordEviction() {
    _evictions++;
  }

  /// Resets all metrics to zero.
  void reset() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
  }

  @override
  String toString() {
    return 'CacheMetrics('
        'hits: $_hits, '
        'misses: $_misses, '
        'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
        'evictions: $_evictions)';
  }
}

/// Snapshot of cache state for inspection.
class CacheInfo {
  /// Number of entries in cache.
  final int entryCount;

  /// Total cache size in bytes.
  final int sizeBytes;

  /// Cache metrics.
  final CacheMetrics metrics;

  /// Maximum cache size in bytes.
  final int maxCacheSize;

  const CacheInfo({
    required this.entryCount,
    required this.sizeBytes,
    required this.metrics,
    required this.maxCacheSize,
  });

  /// Cache usage as a percentage (0.0 to 1.0).
  double get usagePercentage => sizeBytes / maxCacheSize;

  @override
  String toString() {
    return 'CacheInfo('
        'entries: $entryCount, '
        'size: ${sizeBytes ~/ 1024}KB / ${maxCacheSize ~/ 1024}KB, '
        'usage: ${(usagePercentage * 100).toStringAsFixed(1)}%, '
        'metrics: $metrics)';
  }
}

