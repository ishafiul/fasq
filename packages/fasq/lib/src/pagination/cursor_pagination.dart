/// Extracts a pagination cursor from page data.
///
/// Return `null` when there is no next or previous page.
typedef CursorSelector<TData, TCursor> = TCursor? Function(TData pageData);

/// Cursor-based pagination configuration.
///
/// Provides selector callbacks for obtaining cursors from page payloads.
class CursorPagination<TData, TCursor> {
  /// Creates cursor pagination selectors for next/previous page navigation.
  const CursorPagination({required this.nextSelector, this.prevSelector});

  /// Selector used to determine the cursor for loading the next page.
  final CursorSelector<TData, TCursor> nextSelector;

  /// Selector used to determine the cursor for loading the previous page.
  final CursorSelector<TData, TCursor>? prevSelector;

  /// Returns the cursor for the next page from [lastPageData].
  TCursor? getNextPageParam(TData lastPageData) => nextSelector(lastPageData);

  /// Returns the cursor for the previous page from [firstPageData].
  TCursor? getPreviousPageParam(TData firstPageData) =>
      prevSelector?.call(firstPageData);
}
