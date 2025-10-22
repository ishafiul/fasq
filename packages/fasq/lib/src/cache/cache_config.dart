import 'eviction_policy.dart';

/// Global performance configuration for the cache system.
///
/// Controls performance-related features across all queries and the cache system.
class GlobalPerformanceConfig {
  /// Enable performance tracking globally
  final bool enableTracking;

  /// Hot cache size (number of frequently accessed entries)
  final int hotCacheSize;

  /// Enable automatic performance warnings
  final bool enableWarnings;

  /// Slow query threshold (milliseconds)
  final int slowQueryThresholdMs;

  /// Memory warning threshold (bytes)
  final int memoryWarningThreshold;

  /// Size of the isolate pool for heavy computation
  final int isolatePoolSize;

  /// Default threshold for automatic isolate usage (bytes)
  final int defaultIsolateThreshold;

  const GlobalPerformanceConfig({
    this.enableTracking = true,
    this.hotCacheSize = 50,
    this.enableWarnings = true,
    this.slowQueryThresholdMs = 1000,
    this.memoryWarningThreshold = 10 * 1024 * 1024, // 10MB
    this.isolatePoolSize = 2,
    this.defaultIsolateThreshold = 100 * 1024, // 100KB
  });

  /// Create a copy with some fields changed
  GlobalPerformanceConfig copyWith({
    bool? enableTracking,
    int? hotCacheSize,
    bool? enableWarnings,
    int? slowQueryThresholdMs,
    int? memoryWarningThreshold,
    int? isolatePoolSize,
    int? defaultIsolateThreshold,
  }) {
    return GlobalPerformanceConfig(
      enableTracking: enableTracking ?? this.enableTracking,
      hotCacheSize: hotCacheSize ?? this.hotCacheSize,
      enableWarnings: enableWarnings ?? this.enableWarnings,
      slowQueryThresholdMs: slowQueryThresholdMs ?? this.slowQueryThresholdMs,
      memoryWarningThreshold:
          memoryWarningThreshold ?? this.memoryWarningThreshold,
      isolatePoolSize: isolatePoolSize ?? this.isolatePoolSize,
      defaultIsolateThreshold:
          defaultIsolateThreshold ?? this.defaultIsolateThreshold,
    );
  }

  @override
  String toString() {
    return 'GlobalPerformanceConfig('
        'tracking: $enableTracking, '
        'hotCache: $hotCacheSize, '
        'isolatePool: $isolatePoolSize, '
        'threshold: ${defaultIsolateThreshold ~/ 1024}KB)';
  }
}

/// Configuration for the query cache.
///
/// Defines global defaults and limits for caching behavior.
///
/// Example:
/// ```dart
/// final config = CacheConfig(
///   maxCacheSize: 100 * 1024 * 1024, // 100MB
///   defaultStaleTime: Duration(minutes: 5),
///   evictionPolicy: EvictionPolicy.lru,
///   performance: GlobalPerformanceConfig(
///     enableTracking: true,
///     hotCacheSize: 100,
///     isolatePoolSize: 3,
///   ),
/// );
/// ```
class CacheConfig {
  /// Maximum cache size in bytes. Default: 50MB.
  final int maxCacheSize;

  /// Maximum number of cache entries. Default: 1000.
  final int maxEntries;

  /// Default stale time for queries. Default: Duration.zero (always stale).
  final Duration defaultStaleTime;

  /// Default cache time for inactive queries. Default: 5 minutes.
  final Duration defaultCacheTime;

  /// Eviction policy to use when cache is full. Default: LRU.
  final EvictionPolicy evictionPolicy;

  /// Whether to enable memory pressure handling. Default: true.
  final bool enableMemoryPressure;

  /// Global performance configuration
  final GlobalPerformanceConfig performance;

  const CacheConfig({
    this.maxCacheSize = 50 * 1024 * 1024,
    this.maxEntries = 1000,
    this.defaultStaleTime = Duration.zero,
    this.defaultCacheTime = const Duration(minutes: 5),
    this.evictionPolicy = EvictionPolicy.lru,
    this.enableMemoryPressure = true,
    this.performance = const GlobalPerformanceConfig(),
  })  : assert(maxCacheSize > 0, 'maxCacheSize must be positive'),
        assert(maxEntries > 0, 'maxEntries must be positive');

  @override
  String toString() {
    return 'CacheConfig('
        'maxSize: ${maxCacheSize ~/ 1024 ~/ 1024}MB, '
        'maxEntries: $maxEntries, '
        'policy: $evictionPolicy, '
        'performance: $performance)';
  }
}
