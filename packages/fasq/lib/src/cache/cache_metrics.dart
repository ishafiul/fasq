/// Metrics for monitoring cache performance.
///
/// Tracks cache hits, misses, timing, memory usage, and other statistics
/// useful for performance tuning and debugging.
class CacheMetrics {
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;

  // New timing metrics
  final List<Duration> _fetchTimes = [];
  final List<Duration> _cacheLookupTimes = [];
  int _totalFetches = 0;
  int _totalLookups = 0;

  // Memory tracking
  int _peakMemoryBytes = 0;
  int _currentMemoryBytes = 0;

  // Active subscriptions
  int _activeSubscriptions = 0;
  int _peakSubscriptions = 0;

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

  /// Average fetch time across all fetches
  Duration get averageFetchTime {
    if (_fetchTimes.isEmpty) return Duration.zero;
    final totalMicroseconds = _fetchTimes.fold<int>(
        0, (sum, duration) => sum + duration.inMicroseconds);
    return Duration(microseconds: totalMicroseconds ~/ _fetchTimes.length);
  }

  /// 95th percentile fetch time
  Duration get p95FetchTime {
    if (_fetchTimes.isEmpty) return Duration.zero;
    final sortedTimes = List<Duration>.from(_fetchTimes)..sort();
    final index = (sortedTimes.length * 0.95).floor();
    return sortedTimes[index];
  }

  /// Average cache lookup time
  Duration get averageLookupTime {
    if (_cacheLookupTimes.isEmpty) return Duration.zero;
    final totalMicroseconds = _cacheLookupTimes.fold<int>(
        0, (sum, duration) => sum + duration.inMicroseconds);
    return Duration(
        microseconds: totalMicroseconds ~/ _cacheLookupTimes.length);
  }

  /// Peak memory usage in bytes
  int get peakMemoryBytes => _peakMemoryBytes;

  /// Current memory usage in bytes
  int get currentMemoryBytes => _currentMemoryBytes;

  /// Number of active subscriptions
  int get activeSubscriptions => _activeSubscriptions;

  /// Peak number of subscriptions
  int get peakSubscriptions => _peakSubscriptions;

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

  /// Records a fetch operation timing
  void recordFetchTime(Duration duration) {
    _fetchTimes.add(duration);
    _totalFetches++;

    // Keep only last 1000 fetch times to prevent memory growth
    if (_fetchTimes.length > 1000) {
      _fetchTimes.removeAt(0);
    }
  }

  /// Records a cache lookup timing
  void recordLookupTime(Duration duration) {
    _cacheLookupTimes.add(duration);
    _totalLookups++;

    // Keep only last 1000 lookup times to prevent memory growth
    if (_cacheLookupTimes.length > 1000) {
      _cacheLookupTimes.removeAt(0);
    }
  }

  /// Records memory usage
  void recordMemoryUsage(int bytes) {
    _currentMemoryBytes = bytes;
    if (bytes > _peakMemoryBytes) {
      _peakMemoryBytes = bytes;
    }
  }

  /// Records subscription count change
  void recordSubscriptionChange(int delta) {
    _activeSubscriptions += delta;
    if (_activeSubscriptions > _peakSubscriptions) {
      _peakSubscriptions = _activeSubscriptions;
    }
  }

  /// Resets all metrics to zero.
  void reset() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _fetchTimes.clear();
    _cacheLookupTimes.clear();
    _totalFetches = 0;
    _totalLookups = 0;
    _peakMemoryBytes = 0;
    _currentMemoryBytes = 0;
    _activeSubscriptions = 0;
    _peakSubscriptions = 0;
  }

  /// Get detailed performance report
  PerformanceReport getReport() {
    return PerformanceReport(
      hitRate: hitRate,
      avgFetchTime: averageFetchTime,
      p95FetchTime: p95FetchTime,
      avgLookupTime: averageLookupTime,
      peakMemoryBytes: peakMemoryBytes,
      currentMemoryBytes: currentMemoryBytes,
      activeSubscriptions: activeSubscriptions,
      totalQueries: totalRequests,
      totalFetches: _totalFetches,
      totalLookups: _totalLookups,
    );
  }

  @override
  String toString() {
    return 'CacheMetrics('
        'hits: $_hits, '
        'misses: $_misses, '
        'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
        'evictions: $_evictions, '
        'avgFetch: ${averageFetchTime.inMilliseconds}ms, '
        'memory: ${currentMemoryBytes ~/ 1024}KB)';
  }
}

/// Detailed performance report with comprehensive metrics.
class PerformanceReport {
  final double hitRate;
  final Duration avgFetchTime;
  final Duration p95FetchTime;
  final Duration avgLookupTime;
  final int peakMemoryBytes;
  final int currentMemoryBytes;
  final int activeSubscriptions;
  final int totalQueries;
  final int totalFetches;
  final int totalLookups;

  const PerformanceReport({
    required this.hitRate,
    required this.avgFetchTime,
    required this.p95FetchTime,
    required this.avgLookupTime,
    required this.peakMemoryBytes,
    required this.currentMemoryBytes,
    required this.activeSubscriptions,
    required this.totalQueries,
    required this.totalFetches,
    required this.totalLookups,
  });

  /// Convert to detailed string representation
  String toDetailedString() {
    return 'PerformanceReport(\n'
        '  Hit Rate: ${(hitRate * 100).toStringAsFixed(1)}%\n'
        '  Average Fetch Time: ${avgFetchTime.inMilliseconds}ms\n'
        '  95th Percentile Fetch Time: ${p95FetchTime.inMilliseconds}ms\n'
        '  Average Lookup Time: ${avgLookupTime.inMicroseconds}μs\n'
        '  Peak Memory: ${peakMemoryBytes ~/ 1024}KB\n'
        '  Current Memory: ${currentMemoryBytes ~/ 1024}KB\n'
        '  Active Subscriptions: $activeSubscriptions\n'
        '  Total Queries: $totalQueries\n'
        '  Total Fetches: $totalFetches\n'
        '  Total Lookups: $totalLookups\n'
        ')';
  }

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'hitRate': hitRate,
      'avgFetchTimeMs': avgFetchTime.inMilliseconds,
      'p95FetchTimeMs': p95FetchTime.inMilliseconds,
      'avgLookupTimeMicros': avgLookupTime.inMicroseconds,
      'peakMemoryBytes': peakMemoryBytes,
      'currentMemoryBytes': currentMemoryBytes,
      'activeSubscriptions': activeSubscriptions,
      'totalQueries': totalQueries,
      'totalFetches': totalFetches,
      'totalLookups': totalLookups,
    };
  }

  @override
  String toString() {
    return 'PerformanceReport('
        'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
        'avgFetch: ${avgFetchTime.inMilliseconds}ms, '
        'memory: ${currentMemoryBytes ~/ 1024}KB)';
  }
}

/// Snapshot of performance state at a specific point in time.
class PerformanceSnapshot {
  final DateTime timestamp;
  final CacheMetrics cacheMetrics;
  final Map<String, QueryMetrics> queryMetrics;
  final int totalQueries;
  final int activeQueries;
  final int memoryUsageBytes;

  const PerformanceSnapshot({
    required this.timestamp,
    required this.cacheMetrics,
    required this.queryMetrics,
    required this.totalQueries,
    required this.activeQueries,
    required this.memoryUsageBytes,
  });

  /// Get overall performance report
  PerformanceReport get report => cacheMetrics.getReport();

  /// Get query-specific metrics
  QueryMetrics? getQueryMetrics(String key) => queryMetrics[key];

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'cacheMetrics': cacheMetrics.getReport().toJson(),
      'queryMetrics':
          queryMetrics.map((key, value) => MapEntry(key, value.toJson())),
      'totalQueries': totalQueries,
      'activeQueries': activeQueries,
      'memoryUsageBytes': memoryUsageBytes,
    };
  }

  @override
  String toString() {
    return 'PerformanceSnapshot('
        'timestamp: $timestamp, '
        'queries: $activeQueries/$totalQueries, '
        'memory: ${memoryUsageBytes ~/ 1024}KB)';
  }
}

/// Metrics for a specific query's performance.
class QueryMetrics {
  final List<Duration> fetchHistory;
  final Duration? lastFetchDuration;
  final int referenceCount;

  const QueryMetrics({
    required this.fetchHistory,
    this.lastFetchDuration,
    required this.referenceCount,
  });

  /// Average fetch time for this query
  Duration? get averageFetchTime {
    if (fetchHistory.isEmpty) return null;
    final totalMicroseconds = fetchHistory.fold<int>(
        0, (sum, duration) => sum + duration.inMicroseconds);
    return Duration(microseconds: totalMicroseconds ~/ fetchHistory.length);
  }

  /// Maximum fetch time for this query
  Duration? get maxFetchTime {
    if (fetchHistory.isEmpty) return null;
    return fetchHistory.reduce((a, b) => a > b ? a : b);
  }

  /// Number of times this query has been fetched
  int get fetchCount => fetchHistory.length;

  /// Convert to JSON map
  Map<String, dynamic> toJson() {
    return {
      'fetchHistory': fetchHistory.map((d) => d.inMilliseconds).toList(),
      'lastFetchDurationMs': lastFetchDuration?.inMilliseconds,
      'referenceCount': referenceCount,
      'averageFetchTimeMs': averageFetchTime?.inMilliseconds,
      'maxFetchTimeMs': maxFetchTime?.inMilliseconds,
      'fetchCount': fetchCount,
    };
  }

  @override
  String toString() {
    return 'QueryMetrics('
        'fetches: $fetchCount, '
        'avgTime: ${averageFetchTime?.inMilliseconds ?? 0}ms, '
        'refs: $referenceCount)';
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
