import 'package:meta/meta.dart';

import '../core/network_status.dart';
import '../core/query.dart';
import '../core/query_options.dart';

/// Context information captured when a query fails.
///
/// This class encapsulates all relevant information about a query failure,
/// including the query key, retry count, network status, and sanitized query
/// options. It is used by error reporters to provide detailed context when
/// reporting errors to external systems like Sentry or Crashlytics.
///
/// Example:
/// ```dart
/// final context = FasqErrorContext.fromQueryFailure(
///   query,
///   options,
///   error,
///   stackTrace,
/// );
/// reporter.report(context);
/// ```
@immutable
class FasqErrorContext {
  /// The query key that failed, represented as a list of objects.
  ///
  /// This allows for hierarchical query keys (e.g., ['users', userId]).
  /// For simple string keys, this will be a single-element list.
  final List<Object> queryKey;

  /// Number of retry attempts made before the final failure.
  ///
  /// This indicates how many times the query was retried before giving up.
  /// A value of 0 means no retries were attempted.
  final int retryCount;

  /// How long data is considered fresh (stale time).
  ///
  /// This helps determine if the failure occurred while serving stale data
  /// or during a fresh fetch.
  final Duration staleTime;

  /// Whether the device was online when the error occurred.
  ///
  /// True if the network was available, false if offline.
  final bool networkStatus;

  /// The error that occurred.
  final Object error;

  /// The stack trace associated with the error.
  final StackTrace stackTrace;

  /// Sanitized query options with sensitive data removed.
  ///
  /// This map contains only safe, non-sensitive fields from the original
  /// QueryOptions. Sensitive fields like Authorization headers are redacted
  /// or omitted to prevent PII leaks in error reports.
  final Map<String, dynamic> sanitizedQueryOptions;

  /// Creates a new [FasqErrorContext] instance.
  ///
  /// All parameters are required. Use [fromQueryFailure] factory constructor
  /// for convenient creation from a Query instance.
  const FasqErrorContext({
    required this.queryKey,
    required this.retryCount,
    required this.staleTime,
    required this.networkStatus,
    required this.error,
    required this.stackTrace,
    required this.sanitizedQueryOptions,
  });

  /// Creates a [FasqErrorContext] from a failed query.
  ///
  /// Extracts all relevant information from the [Query] instance and
  /// [QueryOptions] to build a complete error context. Automatically
  /// sanitizes query options to prevent PII leaks.
  ///
  /// [query] - The query that failed.
  /// [options] - The query options used for this query.
  /// [error] - The error that occurred.
  /// [stackTrace] - The stack trace associated with the error.
  factory FasqErrorContext.fromQueryFailure(
    Query query,
    QueryOptions? options,
    Object error,
    StackTrace stackTrace,
  ) {
    // Convert QueryKey to List<Object>
    // For simple string keys, this will be [key]
    // For hierarchical keys, this could be expanded in the future
    final queryKeyList = [query.queryKey.key];

    // Get retry count (currently not tracked in Query, default to 0)
    // TODO: Track retry count in Query class for accurate reporting
    const retryCount = 0;

    // Get stale time from options or default to zero
    final staleTime = options?.staleTime ?? Duration.zero;

    // Get network status
    final networkStatus = NetworkStatus.instance.isOnline;

    // Sanitize query options (implementation in task 42)
    final sanitizedOptions = _sanitizeQueryOptions(options);

    return FasqErrorContext(
      queryKey: queryKeyList,
      retryCount: retryCount,
      staleTime: staleTime,
      networkStatus: networkStatus,
      error: error,
      stackTrace: stackTrace,
      sanitizedQueryOptions: sanitizedOptions,
    );
  }

  /// Sanitizes query options to remove sensitive data.
  ///
  /// This is a strict allowlist approach: only explicitly safe fields
  /// are included. Sensitive fields are omitted to prevent PII leaks.
  ///
  /// **Included (Safe Fields):**
  /// - `enabled`, `refetchOnMount`, `isSecure` - boolean flags
  /// - `staleTime`, `cacheTime`, `maxAge` - duration values (in milliseconds)
  /// - `performance` - sanitized performance options (excluding callbacks)
  ///
  /// **Excluded (Sensitive Fields):**
  /// - `meta` - may contain user-specific messages or data
  /// - `onSuccess`/`onError` - callbacks may contain closures with sensitive data
  /// - `circuitBreaker`/`circuitBreakerScope` - internal implementation details
  /// - `performance.dataTransformer` - callback may contain sensitive logic
  static Map<String, dynamic> _sanitizeQueryOptions(QueryOptions? options) {
    if (options == null) {
      return {};
    }

    final sanitized = <String, dynamic>{};

    // Safe boolean flags
    sanitized['enabled'] = options.enabled;
    sanitized['refetchOnMount'] = options.refetchOnMount;
    sanitized['isSecure'] = options.isSecure;

    // Safe duration fields (convert to milliseconds for consistency)
    if (options.staleTime != null) {
      sanitized['staleTime'] = options.staleTime!.inMilliseconds;
    }

    if (options.cacheTime != null) {
      sanitized['cacheTime'] = options.cacheTime!.inMilliseconds;
    }

    if (options.maxAge != null) {
      sanitized['maxAge'] = options.maxAge!.inMilliseconds;
    }

    // Sanitize performance options (exclude callbacks)
    if (options.performance != null) {
      final perf = options.performance!;
      sanitized['performance'] = {
        'enableMetrics': perf.enableMetrics,
        'maxRetries': perf.maxRetries,
        'autoIsolate': perf.autoIsolate,
        'enableHotCache': perf.enableHotCache,
        if (perf.fetchTimeoutMs != null) 'fetchTimeoutMs': perf.fetchTimeoutMs,
        if (perf.isolateThreshold != null)
          'isolateThreshold': perf.isolateThreshold,
        'initialRetryDelay': perf.initialRetryDelay.inMilliseconds,
        'retryBackoffMultiplier': perf.retryBackoffMultiplier,
        'enableDataTransform': perf.enableDataTransform,
        // Explicitly exclude dataTransformer callback
      };
    }

    // Explicitly excluded fields (not included in sanitized output):
    // - meta: may contain user-specific successMessage/errorMessage
    // - onSuccess: callback may contain closures with sensitive data
    // - onError: callback may contain closures with sensitive data
    // - circuitBreaker: internal implementation details
    // - circuitBreakerScope: internal implementation details
    // - performance.dataTransformer: callback may contain sensitive logic

    return sanitized;
  }

  @override
  String toString() {
    return 'FasqErrorContext('
        'queryKey: $queryKey, '
        'retryCount: $retryCount, '
        'staleTime: ${staleTime.inMilliseconds}ms, '
        'networkStatus: ${networkStatus ? "online" : "offline"}, '
        'error: ${error.runtimeType})';
  }
}
