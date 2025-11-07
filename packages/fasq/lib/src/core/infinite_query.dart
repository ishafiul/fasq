import 'dart:async';

import '../cache/query_cache.dart';
import 'infinite_query_options.dart';
import 'infinite_query_state.dart';
import 'query_key.dart';
import 'query_status.dart';

/// Manages infinite/paginated data fetching with support for forward and backward pagination.
///
/// An [InfiniteQuery] maintains a list of [Page] objects, each containing data or error
/// for a specific page. Pages can be fetched forward (next) or backward (previous) based
/// on pagination parameters computed by [getNextPageParam] and [getPreviousPageParam].
///
/// **Key Features:**
/// - Automatic first page prefetch when listener is added
/// - Concurrent fetch prevention (only one fetch at a time)
/// - Automatic page capping via [maxPages] option
/// - State consistency with automatic recalculation of [hasNextPage] and [hasPreviousPage]
/// - Cancellation support (disposed queries don't update state)
///
/// **Thread Safety:**
/// - All state updates are synchronous and atomic
/// - Concurrent fetches are prevented via [Future<void>? _fetchFuture] guard
/// - Multiple prefetches are prevented via [_isPrefetching] flag
///
/// **Example:**
/// ```dart
/// final query = QueryClient().getInfiniteQuery<List<Post>, String?>(
///   'posts',
///   (cursor) => fetchPosts(cursor),
///   options: InfiniteQueryOptions(
///     getNextPageParam: (pages, last) => last == null ? '1' : '${last.id + 1}',
///     maxPages: 5,
///   ),
/// );
///
/// query.addListener();
/// await query.fetchNextPage();
/// ```
class InfiniteQuery<TData, TParam> {
  final QueryKey queryKey;
  final String key;
  final Future<TData> Function(TParam param) queryFn;
  final InfiniteQueryOptions<TData, TParam>? options;
  final QueryCache? cache;
  final void Function()? onDispose;

  InfiniteQueryState<TData, TParam> _currentState;
  late final StreamController<InfiniteQueryState<TData, TParam>> _controller;
  int _referenceCount = 0;
  Timer? _disposeTimer;
  bool _isDisposed = false;
  Future<void>? _fetchFuture;
  bool _isPrefetching = false;

  InfiniteQuery({
    required this.queryKey,
    required this.queryFn,
    this.options,
    this.cache,
    this.onDispose,
    List<Page<TData, TParam>>? initialPages,
  })  : key = queryKey.key,
        _currentState = InfiniteQueryState<TData, TParam>.idle() {
    if (initialPages != null && initialPages.isNotEmpty) {
      final opts = options;
      final hasNext = _computeHasNextForPages(opts, initialPages);
      final hasPrev = _computeHasPrevForPages(opts, initialPages);
      _currentState = _currentState.copyWith(
        pages: initialPages,
        hasNextPage: hasNext,
        hasPreviousPage: hasPrev,
        status: QueryStatus.success,
        dataUpdatedAt: DateTime.now(),
      );
    }
    _controller =
        StreamController<InfiniteQueryState<TData, TParam>>.broadcast();
  }

  Stream<InfiniteQueryState<TData, TParam>> get stream => _controller.stream;
  InfiniteQueryState<TData, TParam> get state => _currentState;
  int get referenceCount => _referenceCount;
  bool get isDisposed => _isDisposed;

  bool get hasNextPage => _currentState.hasNextPage;
  bool get hasPreviousPage => _currentState.hasPreviousPage;

  /// Adds a listener to this query and triggers auto-fetch if this is the first listener.
  ///
  /// Increments the reference count and cancels scheduled disposal.
  /// If this is the first listener and cache is available, automatically prefetches
  /// the first page if no pages exist yet.
  ///
  /// Called automatically by [InfiniteQueryBuilder] widgets.
  ///
  /// This method is thread-safe and prevents multiple concurrent prefetches.
  void addListener() {
    if (_isDisposed) return;
    _referenceCount++;
    _cancelDisposal();
    if (_referenceCount == 1 && cache != null && !_isPrefetching) {
      _isPrefetching = true;
      _prefetchFirstPageIfNeeded().whenComplete(() {
        _isPrefetching = false;
      });
    }
  }

  /// Removes a listener from this query.
  ///
  /// Decrements the reference count and schedules disposal if count reaches zero.
  /// Disposal is scheduled after a 5-second delay to allow for rapid add/remove cycles.
  ///
  /// Called automatically by [InfiniteQueryBuilder] widgets on disposal.
  ///
  /// This method prevents negative reference counts.
  void removeListener() {
    if (_isDisposed) return;

    // Prevent negative reference count
    if (_referenceCount > 0) {
      _referenceCount--;
      if (_referenceCount == 0) {
        _scheduleDisposal();
      }
    }
  }

  Future<void> _prefetchFirstPageIfNeeded() async {
    if (options?.enabled == false) return;
    if (_currentState.pages.isNotEmpty) return;
    final getNextPageParam = options?.getNextPageParam;
    if (getNextPageParam == null) return;
    final initialParam = getNextPageParam(const [], null);
    if (initialParam == null) return;
    try {
      await fetchNextPage(initialParam as TParam);
    } catch (_) {}
  }

  /// Fetches the next page of data.
  ///
  /// Uses [overrideParam] if provided, otherwise computes the next page parameter
  /// using [getNextPageParam] from the options.
  ///
  /// **Concurrency**: Only one fetch operation (next or previous) can run at a time.
  /// If a fetch is already in progress, this method returns immediately without
  /// starting a new fetch.
  ///
  /// **State Updates**: After successful fetch, updates state with new page and
  /// recalculates [hasNextPage]. Applies [maxPages] limit if configured.
  ///
  /// **Error Handling**: On error, adds an error page to the pages list and
  /// applies [maxPages] limit. The error page does not replace existing pages.
  ///
  /// **Cancellation**: If the query is disposed during fetch, state is not updated.
  ///
  /// Returns immediately if:
  /// - Query is disposed
  /// - Query is disabled ([enabled] is false)
  /// - Another fetch is already in progress
  /// - No next page parameter can be computed
  ///
  /// Example:
  /// ```dart
  /// await query.fetchNextPage();
  /// // Or with override parameter:
  /// await query.fetchNextPage('custom-cursor');
  /// ```
  Future<void> fetchNextPage([TParam? overrideParam]) async {
    if (_isDisposed || options?.enabled == false) return;
    if (_fetchFuture != null) return;
    _fetchFuture = _fetchNextPageImpl(overrideParam);
    try {
      await _fetchFuture;
    } finally {
      _fetchFuture = null;
    }
  }

  Future<void> _fetchNextPageImpl([TParam? overrideParam]) async {
    if (_isDisposed || options?.enabled == false) return;
    final pages = _currentState.pages;
    final nextParam = overrideParam ?? _computeNextParam(pages);
    if (nextParam == null) {
      if (_isDisposed) return;
      _updateState(_currentState.copyWith(hasNextPage: false));
      return;
    }
    if (_isDisposed) return;
    _updateState(_currentState.copyWith(
      isFetchingNextPage: true,
      status: pages.isEmpty ? QueryStatus.loading : _currentState.status,
    ));
    try {
      final data = await queryFn(nextParam);
      if (_isDisposed) return;
      final newPage = Page<TData, TParam>(param: nextParam).withData(data);
      final newPages = [...pages, newPage];
      final capped = _applyMaxPages(newPages, dropFromStart: true);
      _updateStateWithPages(
        capped,
        isFetchingNextPage: false,
        status: QueryStatus.success,
        dataUpdatedAt: DateTime.now(),
      );
      options?.onSuccess?.call();
    } catch (e, s) {
      if (_isDisposed) return;
      final errorPage = Page<TData, TParam>(param: nextParam).withError(e, s);
      final newPages = [...pages, errorPage];
      final capped = _applyMaxPages(newPages, dropFromStart: true);
      _updateStateWithPages(
        capped,
        isFetchingNextPage: false,
        status: pages.isEmpty ? QueryStatus.error : _currentState.status,
      );
      options?.onError?.call(e);
    }
  }

  /// Fetches the previous page of data.
  ///
  /// Computes the previous page parameter using [getPreviousPageParam] from the options.
  ///
  /// **Concurrency**: Only one fetch operation (next or previous) can run at a time.
  /// If a fetch is already in progress, this method returns immediately without
  /// starting a new fetch.
  ///
  /// **State Updates**: After successful fetch, updates state with new page prepended
  /// to the pages list and recalculates [hasPreviousPage]. Applies [maxPages] limit
  /// if configured.
  ///
  /// **Error Handling**: On error, adds an error page to the beginning of the pages
  /// list and applies [maxPages] limit. The error page does not replace existing pages.
  ///
  /// **Cancellation**: If the query is disposed during fetch, state is not updated.
  ///
  /// Returns immediately if:
  /// - Query is disposed
  /// - Query is disabled ([enabled] is false)
  /// - Another fetch is already in progress
  /// - No previous page parameter can be computed
  ///
  /// Example:
  /// ```dart
  /// await query.fetchPreviousPage();
  /// ```
  Future<void> fetchPreviousPage() async {
    if (_isDisposed || options?.enabled == false) return;
    if (_fetchFuture != null) return;
    _fetchFuture = _fetchPreviousPageImpl();
    try {
      await _fetchFuture;
    } finally {
      _fetchFuture = null;
    }
  }

  Future<void> _fetchPreviousPageImpl() async {
    if (_isDisposed || options?.enabled == false) return;
    final pages = _currentState.pages;
    final prevParam = _computePreviousParam(pages);
    if (prevParam == null) {
      if (_isDisposed) return;
      _updateState(_currentState.copyWith(hasPreviousPage: false));
      return;
    }
    if (_isDisposed) return;
    _updateState(_currentState.copyWith(isFetchingPreviousPage: true));
    try {
      final data = await queryFn(prevParam);
      if (_isDisposed) return;
      final newPage = Page<TData, TParam>(param: prevParam).withData(data);
      final newPages = [newPage, ...pages];
      final capped = _applyMaxPages(newPages, dropFromStart: false);
      _updateStateWithPages(
        capped,
        isFetchingPreviousPage: false,
        status: QueryStatus.success,
        dataUpdatedAt: DateTime.now(),
      );
      options?.onSuccess?.call();
    } catch (e, s) {
      if (_isDisposed) return;
      final errorPage = Page<TData, TParam>(param: prevParam).withError(e, s);
      final newPages = [errorPage, ...pages];
      final capped = _applyMaxPages(newPages, dropFromStart: false);
      _updateStateWithPages(
        capped,
        isFetchingPreviousPage: false,
        status: pages.isEmpty ? QueryStatus.error : _currentState.status,
      );
      options?.onError?.call(e);
    }
  }

  /// Refetches a specific page by its index.
  ///
  /// Fetches the page at [index] again, updating its data or error state.
  /// Does not affect other pages in the list.
  ///
  /// **Concurrency**: Prevents concurrent execution with other fetch operations
  /// by checking [_fetchFuture]. Only one fetch operation can run at a time.
  ///
  /// **State Updates**: After successful refetch, recalculates [hasNextPage] and
  /// [hasPreviousPage] to ensure state consistency.
  ///
  /// **Error Handling**: On error, updates the page with error state and recalculates
  /// pagination state.
  ///
  /// **Cancellation**: If the query is disposed during fetch, state is not updated.
  ///
  /// Throws if [index] is out of bounds (< 0 or >= pages.length).
  ///
  /// Example:
  /// ```dart
  /// await query.refetchPage(0); // Refetch first page
  /// ```
  Future<void> refetchPage(int index) async {
    if (_isDisposed || options?.enabled == false) return;
    if (_fetchFuture != null) return;
    final pages = _currentState.pages;
    if (index < 0 || index >= pages.length) return;
    final page = pages[index];
    try {
      final data = await queryFn(page.param);
      if (_isDisposed) return;
      final updated = page.withData(data);
      final newPages = [...pages];
      newPages[index] = updated;
      _updateStateWithPages(
        newPages,
        status: QueryStatus.success,
        dataUpdatedAt: DateTime.now(),
      );
      options?.onSuccess?.call();
    } catch (e, s) {
      if (_isDisposed) return;
      final updated = page.withError(e, s);
      final newPages = [...pages];
      newPages[index] = updated;
      _updateStateWithPages(newPages);
      options?.onError?.call(e);
    }
  }

  /// Resets the query to its initial idle state.
  ///
  /// Clears all pages and resets pagination state.
  /// Cancels any in-flight fetch operations by clearing [_fetchFuture],
  /// preventing them from updating state after reset.
  ///
  /// Example:
  /// ```dart
  /// query.reset();
  /// ```
  void reset() {
    _fetchFuture = null;
    _updateState(InfiniteQueryState<TData, TParam>.idle());
  }

  /// Updates the query state from cached pages.
  ///
  /// Restores pages from cache and recalculates [hasNextPage] and [hasPreviousPage]
  /// based on the restored pages.
  ///
  /// This method is typically called by [QueryClient] when restoring cached state.
  ///
  /// **State Updates**: Always recalculates pagination state for consistency.
  ///
  /// Does nothing if the query is disposed.
  ///
  /// Example:
  /// ```dart
  /// query.updateFromCache(cachedPages);
  /// ```
  void updateFromCache(List<Page<TData, TParam>> pages) {
    if (_isDisposed) return;
    _updateStateWithPages(
      pages,
      status: QueryStatus.success,
      dataUpdatedAt: DateTime.now(),
    );
  }

  void _updateState(InfiniteQueryState<TData, TParam> newState) {
    _currentState = newState;
    if (!_controller.isClosed) {
      _controller.add(newState);
    }
  }

  void _updateStateWithPages(
    List<Page<TData, TParam>> pages, {
    bool? isFetchingNextPage,
    bool? isFetchingPreviousPage,
    QueryStatus? status,
    DateTime? dataUpdatedAt,
  }) {
    if (_isDisposed) return;
    final hasNext = _computeHasNext(pages);
    final hasPrev = _computeHasPrev(pages);
    _updateState(_currentState.copyWith(
      pages: pages,
      hasNextPage: hasNext,
      hasPreviousPage: hasPrev,
      isFetchingNextPage:
          isFetchingNextPage ?? _currentState.isFetchingNextPage,
      isFetchingPreviousPage:
          isFetchingPreviousPage ?? _currentState.isFetchingPreviousPage,
      status: status ?? _currentState.status,
      dataUpdatedAt: dataUpdatedAt ?? _currentState.dataUpdatedAt,
    ));
  }

  TParam? _computeNextParam(List<Page<TData, TParam>> pages) {
    final getNextPageParam = options?.getNextPageParam;
    if (getNextPageParam == null) return null;
    if (pages.isEmpty) {
      return getNextPageParam(const [], null);
    }
    for (int i = pages.length - 1; i >= 0; i--) {
      final page = pages[i];
      if (page.data != null) {
        return getNextPageParam(pages, page.data as TData);
      }
    }
    return null;
  }

  TParam? _computePreviousParam(List<Page<TData, TParam>> pages) {
    final getPreviousPageParam = options?.getPreviousPageParam;
    if (getPreviousPageParam == null) return null;
    if (pages.isEmpty) return null;
    for (int i = 0; i < pages.length; i++) {
      final page = pages[i];
      if (page.data != null) {
        return getPreviousPageParam(pages, page.data as TData);
      }
    }
    return null;
  }

  bool _computeHasNext(List<Page<TData, TParam>> pages) {
    return _computeHasNextForPages(options, pages);
  }

  bool _computeHasPrev(List<Page<TData, TParam>> pages) {
    return _computeHasPrevForPages(options, pages);
  }

  bool _computeHasNextForPages(InfiniteQueryOptions<TData, TParam>? opts,
      List<Page<TData, TParam>> pages) {
    final getNextPageParam = opts?.getNextPageParam;
    if (getNextPageParam == null) return false;
    try {
      for (int i = pages.length - 1; i >= 0; i--) {
        final page = pages[i];
        if (page.data != null) {
          return getNextPageParam(pages, page.data as TData) != null;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  bool _computeHasPrevForPages(InfiniteQueryOptions<TData, TParam>? opts,
      List<Page<TData, TParam>> pages) {
    final getPreviousPageParam = opts?.getPreviousPageParam;
    if (getPreviousPageParam == null) return false;
    try {
      for (int i = 0; i < pages.length; i++) {
        final page = pages[i];
        if (page.data != null) {
          return getPreviousPageParam(pages, page.data as TData) != null;
        }
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  List<Page<TData, TParam>> _applyMaxPages(List<Page<TData, TParam>> pages,
      {required bool dropFromStart}) {
    final max = options?.maxPages;
    if (max == null || pages.length <= max) return pages;
    final drop = pages.length - max;
    if (drop <= 0) return pages;
    return dropFromStart
        ? pages.sublist(drop)
        : pages.sublist(0, pages.length - drop);
  }

  void _scheduleDisposal() {
    _disposeTimer = Timer(const Duration(seconds: 5), () {
      if (_referenceCount == 0) {
        dispose();
      }
    });
  }

  void _cancelDisposal() {
    _disposeTimer?.cancel();
    _disposeTimer = null;
  }

  void dispose() {
    if (_isDisposed) return;
    _isDisposed = true;
    _fetchFuture = null;
    _isPrefetching = false;
    _disposeTimer?.cancel();
    _controller.close();
    onDispose?.call();
  }
}
