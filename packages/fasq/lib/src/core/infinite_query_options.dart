import 'package:flutter/foundation.dart';

class InfiniteQueryOptions<TData, TParam> {
  final bool enabled;
  final Duration? staleTime;
  final Duration? cacheTime;
  final bool refetchOnMount;
  final VoidCallback? onSuccess;
  final void Function(Object error)? onError;

  final TParam? Function(List<Page<TData, TParam>> pages, TData? lastPageData)?
      getNextPageParam;
  final TParam? Function(List<Page<TData, TParam>> pages, TData? firstPageData)?
      getPreviousPageParam;
  final int? maxPages;

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
}

class Page<TData, TParam> {
  final TData? data;
  final Object? error;
  final StackTrace? stackTrace;
  final TParam param;
  final DateTime fetchedAt;

  Page({
    required this.param,
    this.data,
    this.error,
    this.stackTrace,
    DateTime? fetchedAt,
  }) : fetchedAt = fetchedAt ?? DateTime.fromMillisecondsSinceEpoch(0);

  Page<TData, TParam> withData(TData value) {
    return Page<TData, TParam>(
      param: param,
      data: value,
      fetchedAt: DateTime.now(),
    );
  }

  Page<TData, TParam> withError(Object e, [StackTrace? s]) {
    return Page<TData, TParam>(
      param: param,
      error: e,
      stackTrace: s,
      fetchedAt: DateTime.now(),
    );
  }
}
