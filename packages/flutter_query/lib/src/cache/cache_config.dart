import 'eviction_policy.dart';

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

  const CacheConfig({
    this.maxCacheSize = 50 * 1024 * 1024,
    this.maxEntries = 1000,
    this.defaultStaleTime = Duration.zero,
    this.defaultCacheTime = const Duration(minutes: 5),
    this.evictionPolicy = EvictionPolicy.lru,
    this.enableMemoryPressure = true,
  }) : assert(maxCacheSize > 0, 'maxCacheSize must be positive'),
       assert(maxEntries > 0, 'maxEntries must be positive');

  @override
  String toString() {
    return 'CacheConfig('
        'maxSize: ${maxCacheSize ~/ 1024 ~/ 1024}MB, '
        'maxEntries: $maxEntries, '
        'policy: $evictionPolicy)';
  }
}

