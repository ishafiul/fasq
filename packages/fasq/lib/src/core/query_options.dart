import 'package:flutter/foundation.dart';
import 'validation/input_validator.dart';

/// Configuration options for a query.
///
/// Allows controlling query behavior, caching, and adding lifecycle callbacks.
///
/// Example:
/// ```dart
/// QueryOptions(
///   enabled: userId != null,
///   staleTime: Duration(minutes: 5),
///   cacheTime: Duration(minutes: 10),
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

  QueryOptions({
    this.enabled = true,
    this.staleTime,
    this.cacheTime,
    this.refetchOnMount = false,
    this.onSuccess,
    this.onError,
    this.isSecure = false,
    this.maxAge,
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
}
