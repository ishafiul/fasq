typedef GetNextPageParam<TData> = int? Function(
    TData lastPageData, int pageCount);
typedef GetPrevPageParam<TData> = int? Function(
    TData firstPageData, int pageCount);

class PageNumberPagination<TData> {
  final int startAt;
  final int pageSize;
  final bool hasPrevious;

  const PageNumberPagination(
      {this.startAt = 1, required this.pageSize, this.hasPrevious = false});

  GetNextPageParam<TData> get getNextPageParam => (lastPageData, pageCount) {
        return startAt + pageCount;
      };

  GetPrevPageParam<TData> get getPreviousPageParam =>
      (firstPageData, pageCount) {
        if (!hasPrevious) return null;
        final prev = (startAt + (pageCount - 1)) - 1;
        return prev >= startAt ? prev : null;
      };
}
