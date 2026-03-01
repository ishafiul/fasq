/// Computes the next page number from page data and loaded page count.
typedef GetNextPageParam<TData> = int? Function(
  TData lastPageData,
  int pageCount,
);

/// Computes the previous page number from page data and loaded page count.
typedef GetPrevPageParam<TData> = int? Function(
  TData firstPageData,
  int pageCount,
);

/// Page-number based pagination configuration.
class PageNumberPagination<TData> {
  /// Creates page-number pagination behavior.
  const PageNumberPagination({
    required this.pageSize,
    this.startAt = 1,
    this.hasPrevious = false,
  });

  /// The first page number used by this pagination strategy.
  final int startAt;

  /// The page size used by the data source.
  final int pageSize;

  /// Whether previous-page navigation is enabled.
  final bool hasPrevious;

  /// Returns a function that computes the next page number.
  GetNextPageParam<TData> get getNextPageParam => (lastPageData, pageCount) {
        return startAt + pageCount;
      };

  /// Returns a function that computes the previous page number.
  GetPrevPageParam<TData> get getPreviousPageParam =>
      (firstPageData, pageCount) {
        if (!hasPrevious) return null;
        final prev = (startAt + (pageCount - 1)) - 1;
        return prev >= startAt ? prev : null;
      };
}
