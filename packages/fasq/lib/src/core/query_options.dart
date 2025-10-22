import 'package:flutter/foundation.dart';
import 'validation/input_validator.dart';

/// Performance configuration options for a query.
///
/// Controls performance-related features like isolate usage, retry behavior,
/// and performance tracking for individual queries.
class PerformanceOptions {
  /// Enable detailed performance tracking for this query
  final bool enableMetrics;

  /// Maximum fetch time before warning (milliseconds)
  final int? fetchTimeoutMs;

  /// Enable automatic isolate usage based on threshold
  final bool autoIsolate;

  /// Custom isolate threshold for this query (overrides global)
  final int? isolateThreshold;

  /// Enable hot cache for this query
  final bool enableHotCache;

  /// Maximum number of fetch retries
  final int maxRetries;

  /// Initial retry delay
  final Duration initialRetryDelay;

  /// Backoff multiplier for retries
  final double retryBackoffMultiplier;

  const PerformanceOptions({
    this.enableMetrics = true,
    this.fetchTimeoutMs,
    this.autoIsolate = false,
    this.isolateThreshold,
    this.enableHotCache = true,
    this.maxRetries = 3,
    this.initialRetryDelay = const Duration(seconds: 1),
    this.retryBackoffMultiplier = 2.0,
  })  : assert(fetchTimeoutMs == null || fetchTimeoutMs > 0,
            'fetchTimeoutMs must be positive'),
        assert(isolateThreshold == null || isolateThreshold > 0,
            'isolateThreshold must be positive'),
        assert(maxRetries >= 0, 'maxRetries must be non-negative'),
        assert(retryBackoffMultiplier > 0,
            'retryBackoffMultiplier must be positive');

  /// Create a copy with some fields changed
  PerformanceOptions copyWith({
    bool? enableMetrics,
    int? fetchTimeoutMs,
    bool? autoIsolate,
    int? isolateThreshold,
    bool? enableHotCache,
    int? maxRetries,
    Duration? initialRetryDelay,
    double? retryBackoffMultiplier,
  }) {
    return PerformanceOptions(
      enableMetrics: enableMetrics ?? this.enableMetrics,
      fetchTimeoutMs: fetchTimeoutMs ?? this.fetchTimeoutMs,
      autoIsolate: autoIsolate ?? this.autoIsolate,
      isolateThreshold: isolateThreshold ?? this.isolateThreshold,
      enableHotCache: enableHotCache ?? this.enableHotCache,
      maxRetries: maxRetries ?? this.maxRetries,
      initialRetryDelay: initialRetryDelay ?? this.initialRetryDelay,
      retryBackoffMultiplier:
          retryBackoffMultiplier ?? this.retryBackoffMultiplier,
    );
  }

  @override
  String toString() {
    return 'PerformanceOptions('
        'metrics: $enableMetrics, '
        'autoIsolate: $autoIsolate, '
        'hotCache: $enableHotCache, '
        'retries: $maxRetries)';
  }
}

/// Configuration options for a query.
///
/// Allows controlling query behavior, caching, performance, and adding lifecycle callbacks.
///
/// Example:
/// ```dart
/// QueryOptions(
///   enabled: userId != null,
///   staleTime: Duration(minutes: 5),
///   cacheTime: Duration(minutes: 10),
///   performance: PerformanceOptions(
///     enableMetrics: true,
///     autoIsolate: true,
///     maxRetries: 3,
///   ),
///   onSuccess: () => print('Data loaded!'),
///   onError: (error) => print('Failed: $error'),
/// )
/// ```
class QueryOptions {
  /// Whether the query should execute. Defaults to true.
  ///
  /// Set to false to prevent a query from fetching. Useful for
  /// dependent queries that should wait for prerequisite data.
  final bool enabled;

  /// How long data is considered fresh.
  ///
  /// Fresh data is served from cache without refetching.
  /// Defaults to Duration.zero (always stale, always refetch).
  ///
  /// Example: `Duration(minutes: 5)` means data is fresh for 5 minutes.
  final Duration? staleTime;

  /// How long inactive data stays in cache before garbage collection.
  ///
  /// When a query has no active subscribers, its cache entry remains
  /// for this duration before being removed.
  /// Defaults to 5 minutes.
  ///
  /// Example: `Duration(minutes: 10)` keeps unused data for 10 minutes.
  final Duration? cacheTime;

  /// Whether to refetch data when the query mounts.
  ///
  /// If true, data is refetched every time a widget with this query mounts,
  /// even if fresh data exists in cache.
  /// Defaults to false.
  final bool refetchOnMount;

  /// Callback invoked when the query completes successfully.
  final VoidCallback? onSuccess;

  /// Callback invoked when the query fails with an error.
  final void Function(Object error)? onError;

  /// Whether this query contains sensitive data that should be secured.
  ///
  /// Secure queries:
  /// - Never persisted to disk (even if persistence enabled)
  /// - Excluded from logs in production
  /// - Redacted in DevTools unless explicitly enabled
  /// - Auto-cleared on app background/terminate
  /// - Enforced TTL (can't disable)
  final bool isSecure;

  /// Maximum age for secure entries (enforced TTL).
  ///
  /// Secure entries are automatically removed after this duration,
  /// regardless of cache settings. Required when isSecure is true.
  final Duration? maxAge;

  /// Performance configuration for this query
  final PerformanceOptions? performance;

  QueryOptions({
    this.enabled = true,
    this.staleTime,
    this.cacheTime,
    this.refetchOnMount = false,
    this.onSuccess,
    this.onError,
    this.isSecure = false,
    this.maxAge,
    this.performance,
  }) {
    // Validate durations
    InputValidator.validateDuration(staleTime, 'staleTime');
    InputValidator.validateDuration(cacheTime, 'cacheTime');
    InputValidator.validateDuration(maxAge, 'maxAge');

    // Validate secure options
    if (isSecure && maxAge == null) {
      throw ArgumentError(
        'Secure queries must specify maxAge for TTL enforcement',
      );
    }
  }

  /// Create a copy with some fields changed
  QueryOptions copyWith({
    bool? enabled,
    Duration? staleTime,
    Duration? cacheTime,
    bool? refetchOnMount,
    VoidCallback? onSuccess,
    void Function(Object error)? onError,
    bool? isSecure,
    Duration? maxAge,
    PerformanceOptions? performance,
  }) {
    return QueryOptions(
      enabled: enabled ?? this.enabled,
      staleTime: staleTime ?? this.staleTime,
      cacheTime: cacheTime ?? this.cacheTime,
      refetchOnMount: refetchOnMount ?? this.refetchOnMount,
      onSuccess: onSuccess ?? this.onSuccess,
      onError: onError ?? this.onError,
      isSecure: isSecure ?? this.isSecure,
      maxAge: maxAge ?? this.maxAge,
      performance: performance ?? this.performance,
    );
  }
}
