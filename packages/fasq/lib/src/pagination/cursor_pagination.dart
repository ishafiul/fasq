typedef CursorSelector<TData, TCursor> = TCursor? Function(TData pageData);

class CursorPagination<TData, TCursor> {
  final CursorSelector<TData, TCursor> nextSelector;
  final CursorSelector<TData, TCursor>? prevSelector;

  const CursorPagination({required this.nextSelector, this.prevSelector});

  TCursor? getNextPageParam(TData lastPageData) => nextSelector(lastPageData);
  TCursor? getPreviousPageParam(TData firstPageData) =>
      prevSelector?.call(firstPageData);
}
