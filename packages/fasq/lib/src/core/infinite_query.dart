import 'dart:async';

import '../cache/query_cache.dart';
import 'infinite_query_options.dart';
import 'infinite_query_state.dart';
import 'query_status.dart';

class InfiniteQuery<TData, TParam> {
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

  InfiniteQuery({
    required this.key,
    required this.queryFn,
    this.options,
    this.cache,
    this.onDispose,
    List<Page<TData, TParam>>? initialPages,
  }) : _currentState = InfiniteQueryState<TData, TParam>.idle() {
    if (initialPages != null && initialPages.isNotEmpty) {
      _currentState = _currentState.copyWith(
        pages: initialPages,
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

  void addListener() {
    if (_isDisposed) return;
    _referenceCount++;
    _cancelDisposal();
    if (_referenceCount == 1 && (cache != null)) {
      _prefetchFirstPageIfNeeded();
    }
  }

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
    final initialParam = options?.getNextPageParam == null
        ? null
        : options!.getNextPageParam!(const [], (null as dynamic));
    if (initialParam == null) return;
    await fetchNextPage(initialParam as TParam);
  }

  Future<void> fetchNextPage([TParam? overrideParam]) async {
    if (_isDisposed || options?.enabled == false) return;
    if (_currentState.isFetchingNextPage) return;
    final pages = _currentState.pages;
    final nextParam = overrideParam ?? _computeNextParam(pages);
    if (nextParam == null) {
      _updateState(_currentState.copyWith(hasNextPage: false));
      return;
    }
    _updateState(_currentState.copyWith(
      isFetchingNextPage: true,
      status: _currentState.pages.isEmpty
          ? QueryStatus.loading
          : _currentState.status,
    ));
    try {
      final data = await queryFn(nextParam);
      final newPage = Page<TData, TParam>(param: nextParam).withData(data);
      final newPages = [...pages, newPage];
      final hasNext = _computeHasNext(newPages);
      final capped = _applyMaxPages(newPages, dropFromStart: true);
      _updateState(_currentState.copyWith(
        pages: capped,
        isFetchingNextPage: false,
        hasNextPage: hasNext,
        status: QueryStatus.success,
        dataUpdatedAt: DateTime.now(),
      ));
      options?.onSuccess?.call();
    } catch (e, s) {
      final errorPage = Page<TData, TParam>(param: nextParam).withError(e, s);
      _updateState(_currentState.copyWith(
        pages: [...pages, errorPage],
        isFetchingNextPage: false,
        status: _currentState.pages.isEmpty
            ? QueryStatus.error
            : _currentState.status,
      ));
      options?.onError?.call(e);
    }
  }

  Future<void> fetchPreviousPage() async {
    if (_isDisposed || options?.enabled == false) return;
    if (_currentState.isFetchingPreviousPage) return;
    final pages = _currentState.pages;
    final prevParam = _computePreviousParam(pages);
    if (prevParam == null) {
      _updateState(_currentState.copyWith(hasPreviousPage: false));
      return;
    }
    _updateState(_currentState.copyWith(isFetchingPreviousPage: true));
    try {
      final data = await queryFn(prevParam);
      final newPage = Page<TData, TParam>(param: prevParam).withData(data);
      final newPages = [newPage, ...pages];
      final hasPrev = _computeHasPrev(newPages);
      final capped = _applyMaxPages(newPages, dropFromStart: false);
      _updateState(_currentState.copyWith(
        pages: capped,
        isFetchingPreviousPage: false,
        hasPreviousPage: hasPrev,
        status: QueryStatus.success,
        dataUpdatedAt: DateTime.now(),
      ));
      options?.onSuccess?.call();
    } catch (e, s) {
      final errorPage = Page<TData, TParam>(param: prevParam).withError(e, s);
      _updateState(_currentState.copyWith(
        pages: [errorPage, ...pages],
        isFetchingPreviousPage: false,
      ));
      options?.onError?.call(e);
    }
  }

  Future<void> refetchPage(int index) async {
    if (_isDisposed || options?.enabled == false) return;
    if (index < 0 || index >= _currentState.pages.length) return;
    final page = _currentState.pages[index];
    try {
      final data = await queryFn(page.param);
      final updated = page.withData(data);
      final newPages = [..._currentState.pages];
      newPages[index] = updated;
      _updateState(_currentState.copyWith(
        pages: newPages,
        status: QueryStatus.success,
        dataUpdatedAt: DateTime.now(),
      ));
      options?.onSuccess?.call();
    } catch (e, s) {
      final updated = page.withError(e, s);
      final newPages = [..._currentState.pages];
      newPages[index] = updated;
      _updateState(_currentState.copyWith(pages: newPages));
      options?.onError?.call(e);
    }
  }

  void reset() {
    _updateState(InfiniteQueryState<TData, TParam>.idle());
  }

  void updateFromCache(List<Page<TData, TParam>> pages) {
    if (_isDisposed) return;
    _updateState(_currentState.copyWith(
      pages: pages,
      status: QueryStatus.success,
      dataUpdatedAt: DateTime.now(),
    ));
  }

  void _updateState(InfiniteQueryState<TData, TParam> newState) {
    _currentState = newState;
    if (!_controller.isClosed) {
      _controller.add(newState);
    }
  }

  TParam? _computeNextParam(List<Page<TData, TParam>> pages) {
    if (options?.getNextPageParam == null) return null;
    if (pages.isEmpty) {
      return options!.getNextPageParam!(const [], (null as dynamic));
    }
    final lastWithData = pages.lastWhere(
      (p) => p.data != null,
      orElse: () => pages.last,
    );
    if (lastWithData.data == null) return null;
    return options!.getNextPageParam!(pages, lastWithData.data as TData);
  }

  TParam? _computePreviousParam(List<Page<TData, TParam>> pages) {
    if (options?.getPreviousPageParam == null) return null;
    if (pages.isEmpty) return null;
    final firstWithData = pages.firstWhere(
      (p) => p.data != null,
      orElse: () => pages.first,
    );
    if (firstWithData.data == null) return null;
    return options!.getPreviousPageParam!(pages, firstWithData.data as TData);
  }

  bool _computeHasNext(List<Page<TData, TParam>> pages) {
    if (options?.getNextPageParam == null) return false;
    final lastWithData = pages.lastWhere(
      (p) => p.data != null,
      orElse: () => pages.last,
    );
    if (lastWithData.data == null) return false;
    return options!.getNextPageParam!(pages, lastWithData.data as TData) !=
        null;
  }

  bool _computeHasPrev(List<Page<TData, TParam>> pages) {
    if (options?.getPreviousPageParam == null) return false;
    final firstWithData = pages.firstWhere(
      (p) => p.data != null,
      orElse: () => pages.first,
    );
    if (firstWithData.data == null) return false;
    return options!.getPreviousPageParam!(pages, firstWithData.data as TData) !=
        null;
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
    _disposeTimer?.cancel();
    _controller.close();
    onDispose?.call();
  }
}
