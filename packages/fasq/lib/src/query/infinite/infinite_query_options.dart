import 'package:flutter/foundation.dart';

/// Configuration options for infinite queries.
///
/// Controls cache behavior, callbacks, pagination cursors, and page retention.
class InfiniteQueryOptions<TData, TParam> {
  /// Creates infinite query options.
  ///
  /// If [maxPages] is provided, it must be greater than zero.
  const InfiniteQueryOptions({
    this.enabled = true,
    this.staleTime,
    this.cacheTime,
    this.refetchOnMount = false,
    this.onSuccess,
    this.onError,
    this.getNextPageParam,
    this.getPreviousPageParam,
    this.maxPages,
  }) : assert(maxPages == null || maxPages > 0, 'maxPages must be positive');

  /// Whether the query is allowed to run.
  final bool enabled;

  /// Duration for which fetched data is considered fresh.
  final Duration? staleTime;

  /// How long inactive query data is kept in cache.
  final Duration? cacheTime;

  /// Whether to refetch when the query mounts.
  final bool refetchOnMount;

  /// Callback invoked after a successful fetch.
  final VoidCallback? onSuccess;

  /// Callback invoked when a fetch fails.
  final void Function(Object error)? onError;

  /// Computes the next page parameter from current pages and last page data.
  final TParam? Function(List<Page<TData, TParam>> pages, TData? lastPageData)?
      getNextPageParam;

  /// Computes the previous page parameter from current pages and first page
  /// data.
  final TParam? Function(List<Page<TData, TParam>> pages, TData? firstPageData)?
      getPreviousPageParam;

  /// Maximum number of pages to keep in memory.
  final int? maxPages;
}

/// Snapshot of a single page in an infinite query.
class Page<TData, TParam> {
  /// Creates a page snapshot.
  ///
  /// When [fetchedAt] is not provided, it defaults to Unix epoch.
  Page({
    required this.param,
    this.data,
    this.error,
    this.stackTrace,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  /// Page payload when fetch succeeds.
  final TData? data;

  /// Error value when fetch fails.
  final Object? error;

  /// Stack trace associated with [error], if available.
  final StackTrace? stackTrace;

  /// Parameter used to fetch this page.
  final TParam param;

  /// Time this page was fetched.
  final DateTime fetchedAt;

  /// Returns a copy containing successful [value] data and current timestamp.
  Page<TData, TParam> withData(TData value) {
    return Page<TData, TParam>(
      param: param,
      data: value,
      fetchedAt: DateTime.now(),
    );
  }

  /// Returns a copy containing error details and current timestamp.
  Page<TData, TParam> withError(Object e, [StackTrace? s]) {
    return Page<TData, TParam>(
      param: param,
      error: e,
      stackTrace: s,
      fetchedAt: DateTime.now(),
    );
  }
}
