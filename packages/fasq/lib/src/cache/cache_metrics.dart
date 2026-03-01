import 'dart:collection';

import 'package:fasq/src/performance/throughput_metrics.dart';

class _ThroughputRing {
  _ThroughputRing({required this.bucketCount})
      : assert(bucketCount > 0, 'bucketCount must be positive'),
        counts = List<int>.filled(bucketCount, 0),
        seconds = List<int>.filled(bucketCount, -1);

  final int bucketCount;
  final List<int> counts;
  final List<int> seconds;

  void record(DateTime now) {
    final s = now.millisecondsSinceEpoch ~/ 1000;
    final idx = s % bucketCount;
    if (seconds[idx] != s) {
      seconds[idx] = s;
      counts[idx] = 0;
    }
    counts[idx]++;
  }

  /// O(bucketCount) per call; only counts buckets whose
  /// second is in [start..end].
  /// Window is second-granularity ([Duration.inSeconds] truncates).
  int sumLast(Duration window, DateTime now) {
    final end = now.millisecondsSinceEpoch ~/ 1000;
    final windowSecs = window.inSeconds;
    if (windowSecs <= 0) return 0;
    final start = end - windowSecs + 1;
    var total = 0;
    for (var i = 0; i < bucketCount; i++) {
      final sec = seconds[i];
      if (sec >= start && sec <= end) {
        total += counts[i];
      }
    }
    return total;
  }
}

/// Metrics for monitoring cache performance.
///
/// Tracks cache hits, misses, timing, memory usage, and other statistics
/// useful for performance tuning and debugging.
class CacheMetrics {
  /// Creates cache metrics for tracking hits, misses, latency, and memory.
  ///
  /// If `now` is provided, it is used as the UTC clock source for
  /// time-dependent metrics, which is useful for deterministic tests.
  CacheMetrics({DateTime Function()? now})
      : _nowFn = now ?? (() => DateTime.now().toUtc());

  final DateTime Function() _nowFn;

  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _gcRemovals = 0;

  static const int _maxTimingSamples = 1000;

  final Queue<Duration> _fetchTimes = Queue<Duration>();
  final Queue<Duration> _cacheLookupTimes = Queue<Duration>();
  int _totalFetches = 0;
  int _totalLookups = 0;
  bool _p95FetchTimeDirty = true;
  Duration? _p95FetchTimeCached;

  // Memory tracking
  int _peakMemoryBytes = 0;
  int _currentMemoryBytes = 0;

  // Active subscriptions
  int _activeSubscriptions = 0;
  int _peakSubscriptions = 0;

  static const int _maxQueryKeysTracked = 10000;
  static const int _throughputWindowSeconds = 900;
  static const Duration _evictionInterval = Duration(minutes: 5);

  /// TTL for throughput key metadata (longer than ring window so inactive keys
  /// remain reportable briefly after traffic stops).
  static const Duration _throughputKeyTtl = Duration(minutes: 30);

  final Map<String, _ThroughputRing> _queryThroughputRings = {};
  final Map<String, DateTime> _queryLastSeen = {};
  DateTime _lastEviction = DateTime.fromMillisecondsSinceEpoch(0).toUtc();
  int _throughputKeyDrops = 0;

  /// Total number of cache hits (data found in cache).
  int get hits => _hits;

  /// Total number of cache misses (data not in cache).
  int get misses => _misses;

  /// Total number of cache evictions.
  int get evictions => _evictions;

  /// Total number of entries removed by garbage collection.
  int get gcRemovals => _gcRemovals;

  /// Total number of cache requests.
  int get totalRequests => _hits + _misses;

  /// Cache hit rate (0.0 to 1.0).
  ///
  /// Returns 0.0 if no requests have been made.
  double get hitRate {
    final total = totalRequests;
    if (total == 0) return 0;
    return _hits / total;
  }

  /// Average fetch time across all fetches
  Duration get averageFetchTime {
    if (_fetchTimes.isEmpty) return Duration.zero;
    final totalMicroseconds = _fetchTimes.fold<int>(
      0,
      (sum, duration) => sum + duration.inMicroseconds,
    );
    return Duration(microseconds: totalMicroseconds ~/ _fetchTimes.length);
  }

  /// 95th percentile fetch time
  Duration get p95FetchTime {
    if (_fetchTimes.isEmpty) return Duration.zero;
    if (!_p95FetchTimeDirty && _p95FetchTimeCached != null) {
      return _p95FetchTimeCached!;
    }
    final sortedTimes = List<Duration>.from(_fetchTimes)..sort();
    final i = ((sortedTimes.length - 1) * 0.95).floor();
    final value = sortedTimes[i.clamp(0, sortedTimes.length - 1)];
    _p95FetchTimeCached = value;
    _p95FetchTimeDirty = false;
    return value;
  }

  /// Average cache lookup time
  Duration get averageLookupTime {
    if (_cacheLookupTimes.isEmpty) return Duration.zero;
    final totalMicroseconds = _cacheLookupTimes.fold<int>(
      0,
      (sum, duration) => sum + duration.inMicroseconds,
    );
    return Duration(
      microseconds: totalMicroseconds ~/ _cacheLookupTimes.length,
    );
  }

  /// Peak memory usage in bytes
  int get peakMemoryBytes => _peakMemoryBytes;

  /// Current memory usage in bytes
  int get currentMemoryBytes => _currentMemoryBytes;

  /// Number of active subscriptions
  int get activeSubscriptions => _activeSubscriptions;

  /// Peak number of subscriptions
  int get peakSubscriptions => _peakSubscriptions;

  /// Number of query keys dropped because throughput tracking was at capacity.
  int get throughputKeyDrops => _throughputKeyDrops;

  /// Number of query keys currently tracked for throughput.
  int get trackedQueryKeys => _queryThroughputRings.length;

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

  /// Records entries removed by garbage collection.
  void recordGcRemoval(int count) {
    final sanitizedCount = count < 0 ? 0 : count;
    _gcRemovals += sanitizedCount;
  }

  /// Records a fetch operation timing
  void recordFetchTime(Duration duration) {
    _fetchTimes.addLast(duration);
    _totalFetches++;
    if (_fetchTimes.length > _maxTimingSamples) {
      _fetchTimes.removeFirst();
    }
    _p95FetchTimeDirty = true;
  }

  /// Records a cache lookup timing
  void recordLookupTime(Duration duration) {
    _cacheLookupTimes.addLast(duration);
    _totalLookups++;
    if (_cacheLookupTimes.length > _maxTimingSamples) {
      _cacheLookupTimes.removeFirst();
    }
  }

  /// Records memory usage
  void recordMemoryUsage(int bytes) {
    final sanitizedBytes = bytes < 0 ? 0 : bytes;
    _currentMemoryBytes = sanitizedBytes;
    if (sanitizedBytes > _peakMemoryBytes) {
      _peakMemoryBytes = sanitizedBytes;
    }
  }

  /// Records subscription count change
  void recordSubscriptionChange(int delta) {
    _activeSubscriptions += delta;
    if (_activeSubscriptions < 0) _activeSubscriptions = 0;
    if (_activeSubscriptions > _peakSubscriptions) {
      _peakSubscriptions = _activeSubscriptions;
    }
  }

  DateTime _now() => _nowFn();

  void _evictStaleKeys(DateTime now) {
    final cutoff = now.subtract(_throughputKeyTtl);
    final keysToRemove = <String>[];
    _queryLastSeen.forEach((k, ts) {
      if (ts.isBefore(cutoff)) keysToRemove.add(k);
    });
    for (final k in keysToRemove) {
      _queryLastSeen.remove(k);
      _queryThroughputRings.remove(k);
    }
  }

  bool _maybeEvict(DateTime now) {
    if (now.difference(_lastEviction) < _evictionInterval) return false;
    _lastEviction = now;
    _evictStaleKeys(now);
    return true;
  }

  /// Records a query execution for throughput tracking.
  ///
  /// When at capacity: evict TTL-stale keys first; if still full, drop the
  /// new key and increment [throughputKeyDrops] (prefer existing keys).
  void recordQueryExecution(String queryKey) {
    final now = _now();
    final evicted = _maybeEvict(now);
    if (_queryThroughputRings.length >= _maxQueryKeysTracked &&
        !_queryThroughputRings.containsKey(queryKey)) {
      if (!evicted) _evictStaleKeys(now);
      if (_queryThroughputRings.length >= _maxQueryKeysTracked) {
        _throughputKeyDrops++;
        return;
      }
    }
    _queryThroughputRings
        .putIfAbsent(
          queryKey,
          () => _ThroughputRing(bucketCount: _throughputWindowSeconds),
        )
        .record(now);
    _queryLastSeen[queryKey] = now;
  }

  static Duration _clampWindow(Duration window) {
    const max = Duration(seconds: _throughputWindowSeconds);
    if (window <= Duration.zero) return Duration.zero;
    return window > max ? max : window;
  }

  /// Calculates throughput metrics for a given query key within a rolling
  /// window.
  ///
  /// [window] is clamped to at most [_throughputWindowSeconds] (15 minutes);
  /// the returned [ThroughputMetrics.windowStart] and
  /// [ThroughputMetrics.windowEnd] reflect the effective window used. Window
  /// and rates are second-granularity to match
  /// bucket counts. Returns null if no executions in that window.
  ///
  /// O(bucketCount) per call; fine for debug/inspection — avoid calling
  /// in hot paths (e.g. every UI frame).
  ThroughputMetrics? calculateThroughput(
    String queryKey, {
    Duration window = const Duration(minutes: 1),
  }) {
    final ring = _queryThroughputRings[queryKey];
    if (ring == null) return null;

    final now = _now();
    final effectiveWindow = _clampWindow(window);
    if (effectiveWindow == Duration.zero) return null;

    final requestsInWindow = ring.sumLast(effectiveWindow, now);
    if (requestsInWindow == 0) return null;

    final seconds = effectiveWindow.inSeconds.toDouble();
    final minutes = seconds / 60.0;
    final requestsPerMinute = minutes > 0 ? requestsInWindow / minutes : 0.0;
    final requestsPerSecond = seconds > 0 ? requestsInWindow / seconds : 0.0;

    return ThroughputMetrics(
      requestsPerMinute: requestsPerMinute,
      requestsPerSecond: requestsPerSecond,
      totalRequests: requestsInWindow,
      windowStart: now.subtract(effectiveWindow),
      windowEnd: now,
    );
  }

  /// Resets all metrics to zero.
  void reset() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _gcRemovals = 0;
    _fetchTimes.clear();
    _cacheLookupTimes.clear();
    _totalFetches = 0;
    _totalLookups = 0;
    _peakMemoryBytes = 0;
    _currentMemoryBytes = 0;
    _activeSubscriptions = 0;
    _peakSubscriptions = 0;
    _queryThroughputRings.clear();
    _queryLastSeen.clear();
    _lastEviction = DateTime.fromMillisecondsSinceEpoch(0).toUtc();
    _throughputKeyDrops = 0;
    _p95FetchTimeDirty = true;
    _p95FetchTimeCached = null;
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
        'evictions: $_evictions, gcRemovals: $_gcRemovals, '
        'avgFetch: ${averageFetchTime.inMilliseconds}ms, '
        'memory: ${currentMemoryBytes ~/ 1024}KB)';
  }
}

/// Detailed performance report with comprehensive metrics.
class PerformanceReport {
  /// Creates a [PerformanceReport] with the given metrics.
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

  /// Creates a [PerformanceReport] instance from a JSON map.
  ///
  /// The given map contains serialized performance report data. Returns a new
  /// [PerformanceReport] instance with data from it.
  ///
  /// Throws [FormatException] if the JSON structure is invalid or required
  /// fields are missing.
  factory PerformanceReport.fromJson(Map<String, dynamic> json) {
    return PerformanceReport(
      hitRate: (json['hitRate'] as num).toDouble(),
      avgFetchTime: Duration(milliseconds: json['avgFetchTimeMs'] as int),
      p95FetchTime: Duration(milliseconds: json['p95FetchTimeMs'] as int),
      avgLookupTime: Duration(microseconds: json['avgLookupTimeMicros'] as int),
      peakMemoryBytes: json['peakMemoryBytes'] as int,
      currentMemoryBytes: json['currentMemoryBytes'] as int,
      activeSubscriptions: json['activeSubscriptions'] as int,
      totalQueries: json['totalQueries'] as int,
      totalFetches: json['totalFetches'] as int,
      totalLookups: json['totalLookups'] as int,
    );
  }

  /// Cache hit rate (0.0 to 1.0).
  final double hitRate;

  /// Average fetch duration.
  final Duration avgFetchTime;

  /// 95th percentile fetch duration.
  final Duration p95FetchTime;

  /// Average cache lookup duration.
  final Duration avgLookupTime;

  /// Peak memory usage in bytes.
  final int peakMemoryBytes;

  /// Current memory usage in bytes.
  final int currentMemoryBytes;

  /// Number of active subscriptions.
  final int activeSubscriptions;

  /// Total number of queries.
  final int totalQueries;

  /// Total number of fetches.
  final int totalFetches;

  /// Total number of lookups.
  final int totalLookups;

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

  /// Converts this instance to a JSON-serializable map.
  ///
  /// Returns a map containing all performance report metrics with durations
  /// converted to milliseconds/microseconds for serialization.
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
///
/// Forward-compatible: readers should ignore unknown fields when parsing.
class PerformanceSnapshot {
  /// Creates a [PerformanceSnapshot] with the given state.
  ///
  /// [cacheReport] may be provided when deserializing; otherwise it is derived
  /// from [cacheMetrics]. Use [report] for the full cache report (preserved
  /// across JSON round-trip).
  PerformanceSnapshot({
    required this.timestamp,
    required this.cacheMetrics,
    required this.queryMetrics,
    required this.totalQueries,
    required this.activeQueries,
    required this.memoryUsageBytes,
    PerformanceReport? cacheReport,
  }) : _cacheReport = cacheReport ?? cacheMetrics.getReport();

  /// Creates a [PerformanceSnapshot] instance from a JSON map.
  ///
  /// The given map contains serialized performance snapshot data. Returns a new
  /// [PerformanceSnapshot] with data from it. Cache report is restored from
  /// JSON; [PerformanceSnapshot.report] reflects the full stored state. Accepts
  /// both `cacheReport` (canonical) and `cacheMetrics` (legacy) keys.
  /// `schemaVersion`, if present, is informational only and may be used for
  /// future migrations when fields change.
  ///
  /// Throws [FormatException] if the JSON structure is invalid or required
  /// fields are missing.
  factory PerformanceSnapshot.fromJson(Map<String, dynamic> json) {
    final raw = json['cacheReport'] ?? json['cacheMetrics'];
    if (raw == null) {
      throw const FormatException(
          'Missing cacheReport or cacheMetrics in JSON');
    }
    final cacheReport = PerformanceReport.fromJson(raw as Map<String, dynamic>);
    final queryMetricsMap = (json['queryMetrics'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(
        key,
        QueryMetrics.fromJson(value as Map<String, dynamic>),
      ),
    );

    final cacheMetrics = CacheMetrics()
      ..recordMemoryUsage(cacheReport.currentMemoryBytes);

    return PerformanceSnapshot(
      timestamp: DateTime.parse(json['timestamp'] as String),
      cacheMetrics: cacheMetrics,
      queryMetrics: queryMetricsMap,
      totalQueries: json['totalQueries'] as int,
      activeQueries: json['activeQueries'] as int,
      memoryUsageBytes: json['memoryUsageBytes'] as int,
      cacheReport: cacheReport,
    );
  }

  final PerformanceReport _cacheReport;

  /// Time at which the snapshot was taken.
  final DateTime timestamp;

  /// Cache metrics at snapshot time.
  final CacheMetrics cacheMetrics;

  /// Per-query metrics at snapshot time.
  final Map<String, QueryMetrics> queryMetrics;

  /// Total number of queries.
  final int totalQueries;

  /// Number of active queries.
  final int activeQueries;

  /// Memory usage in bytes at snapshot time.
  final int memoryUsageBytes;

  /// Overall performance report (hits, timings, memory). Preserved across
  /// JSON round-trip; use this instead of [CacheMetrics.getReport] when
  /// working with deserialized snapshots.
  PerformanceReport get report => _cacheReport;

  /// Get query-specific metrics
  QueryMetrics? getQueryMetrics(String key) => queryMetrics[key];

  /// Converts this instance to a JSON-serializable map.
  ///
  /// `schemaVersion` is written for future migrations;
  /// [PerformanceSnapshot.fromJson] accepts legacy shapes (e.g.
  /// `cacheMetrics`) and does not yet branch on version.
  /// Forward-compatible: readers should ignore unknown fields.
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'cacheReport': _cacheReport.toJson(),
      'queryMetrics': queryMetrics.map((k, v) => MapEntry(k, v.toJson())),
      'totalQueries': totalQueries,
      'activeQueries': activeQueries,
      'memoryUsageBytes': memoryUsageBytes,
      'schemaVersion': 1,
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
  /// Creates a [QueryMetrics] with the given fetch history and ref count.
  const QueryMetrics({
    required this.fetchHistory,
    required this.referenceCount,
    this.lastFetchDuration,
    this.throughputMetrics,
  });

  /// Creates a [QueryMetrics] instance from a JSON map.
  ///
  /// The given map contains serialized query metrics data. Returns a new
  /// [QueryMetrics] with data from it. Fetch history durations
  /// are reconstructed from millisecond values.
  ///
  /// Throws [FormatException] if the JSON structure is invalid or required
  /// fields are missing.
  factory QueryMetrics.fromJson(Map<String, dynamic> json) {
    final fetchHistory = (json['fetchHistory'] as List<dynamic>?)
            ?.map((d) => Duration(milliseconds: d as int))
            .toList() ??
        [];
    final lastFetchDuration = json['lastFetchDurationMs'] != null
        ? Duration(milliseconds: json['lastFetchDurationMs'] as int)
        : null;
    final throughputMetrics = json['throughputMetrics'] != null
        ? ThroughputMetrics.fromJson(
            json['throughputMetrics'] as Map<String, dynamic>,
          )
        : null;

    return QueryMetrics(
      fetchHistory: fetchHistory,
      lastFetchDuration: lastFetchDuration,
      referenceCount: json['referenceCount'] as int,
      throughputMetrics: throughputMetrics,
    );
  }

  /// History of fetch durations for this query.
  final List<Duration> fetchHistory;

  /// Duration of the last fetch, if any.
  final Duration? lastFetchDuration;

  /// Number of active references to this query's data.
  final int referenceCount;

  /// Throughput metrics for this query, if available.
  final ThroughputMetrics? throughputMetrics;

  /// Average fetch time for this query
  Duration? get averageFetchTime {
    if (fetchHistory.isEmpty) return null;
    final totalMicroseconds = fetchHistory.fold<int>(
      0,
      (sum, duration) => sum + duration.inMicroseconds,
    );
    return Duration(microseconds: totalMicroseconds ~/ fetchHistory.length);
  }

  /// Maximum fetch time for this query
  Duration? get maxFetchTime {
    if (fetchHistory.isEmpty) return null;
    return fetchHistory.reduce((a, b) => a > b ? a : b);
  }

  /// Number of times this query has been fetched
  int get fetchCount => fetchHistory.length;

  /// Converts this instance to a JSON-serializable map.
  ///
  /// Returns a map containing fetch history, timing metrics, reference count,
  /// and optional throughput metrics. Durations are converted to milliseconds
  /// for serialization.
  Map<String, dynamic> toJson() {
    return {
      'fetchHistory': fetchHistory.map((d) => d.inMilliseconds).toList(),
      'lastFetchDurationMs': lastFetchDuration?.inMilliseconds,
      'referenceCount': referenceCount,
      'averageFetchTimeMs': averageFetchTime?.inMilliseconds,
      'maxFetchTimeMs': maxFetchTime?.inMilliseconds,
      'fetchCount': fetchCount,
      if (throughputMetrics != null)
        'throughputMetrics': throughputMetrics!.toJson(),
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
  /// Creates a [CacheInfo] with the given cache state.
  const CacheInfo({
    required this.entryCount,
    required this.sizeBytes,
    required this.metrics,
    required this.maxCacheSize,
  });

  /// Number of entries in cache.
  final int entryCount;

  /// Total cache size in bytes.
  final int sizeBytes;

  /// Cache metrics.
  final CacheMetrics metrics;

  /// Maximum cache size in bytes.
  final int maxCacheSize;

  /// Cache usage as a percentage (0.0 to 1.0).
  double get usagePercentage {
    if (maxCacheSize <= 0) return 0;
    return (sizeBytes / maxCacheSize).clamp(0.0, 1.0);
  }

  @override
  String toString() {
    return 'CacheInfo('
        'entries: $entryCount, '
        'size: ${sizeBytes ~/ 1024}KB / ${maxCacheSize ~/ 1024}KB, '
        'usage: ${(usagePercentage * 100).toStringAsFixed(1)}%, '
        'metrics: $metrics)';
  }
}
