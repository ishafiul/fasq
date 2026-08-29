import 'dart:async';

import 'package:fasq_bloc/fasq_bloc.dart';

/// Base cubit that manages a paginated FASQ [InfiniteQuery].
///
/// Subclasses declare the query key, page function, and optional pagination
/// options. The cubit keeps the core query alive while it is open and exposes
/// the core page, cache, invalidation, and reconfiguration operations.
abstract class InfiniteQueryCubit<TData, TParam>
    extends Cubit<InfiniteQueryState<TData, TParam>>
    with FasqSubscriptionMixin<InfiniteQueryState<TData, TParam>> {
  InfiniteQueryCubit({QueryClient? client, FasqRuntime? runtime})
    : _providedClient = client,
      _providedRuntime = runtime,
      super(InfiniteQueryState<TData, TParam>.idle()) {
    _currentQueryKey = queryKey;
    _currentQueryFn = queryFn;
    _currentOptions = options;
    _initialize();
  }

  final QueryClient? _providedClient;
  final FasqRuntime? _providedRuntime;

  InfiniteQuery<TData, TParam>? _query;
  late QueryKey _currentQueryKey;
  late Future<TData> Function(TParam param) _currentQueryFn;
  InfiniteQueryOptions<TData, TParam>? _currentOptions;
  QueryClient? _queryClient;
  StreamSubscription<InfiniteQueryState<TData, TParam>>? _querySubscription;
  Future<void>? _ready;
  var _queryReferenceAttached = false;
  var _generation = 0;

  /// Key used by the infinite query.
  QueryKey get queryKey;

  /// Fetches one page using [TParam].
  Future<TData> Function(TParam param) get queryFn;

  /// Infinite-query behavior and pagination configuration.
  InfiniteQueryOptions<TData, TParam>? get options => null;

  /// Explicit client used by this cubit.
  QueryClient? get client => _providedClient ?? _providedRuntime?.queryClient;

  /// Optional runtime used for client resolution.
  FasqRuntime? get runtime => _providedRuntime;

  /// The resolved client that owns this infinite query.
  QueryClient get queryClient => _resolvedClient;

  /// The underlying core infinite query.
  InfiniteQuery<TData, TParam> get query {
    final value = _query;
    if (value == null) {
      throw StateError('The InfiniteQueryCubit has not been initialized.');
    }
    return value;
  }

  /// Whether another forward page is available.
  bool get hasNextPage => state.hasNextPage;

  /// Whether another backward page is available.
  bool get hasPreviousPage => state.hasPreviousPage;

  /// Whether a forward page fetch is currently running.
  bool get isFetchingNextPage => state.isFetchingNextPage;

  /// Whether a backward page fetch is currently running.
  bool get isFetchingPreviousPage => state.isFetchingPreviousPage;

  /// Whether the infinite query has loaded at least one page.
  bool get hasPages => state.pages.isNotEmpty;

  /// Number of active cubit references held on the core query.
  int get referenceCount => query.referenceCount;

  /// Whether the underlying core query has been disposed.
  bool get isDisposed => query.isDisposed;

  /// Completes after persistence initialization and reference activation.
  Future<void> get ready => _ready ?? Future<void>.value();

  QueryClient get _resolvedClient {
    final existing = _queryClient;
    if (existing != null) return existing;
    final resolved = client ?? runtime?.queryClient ?? QueryClient();
    _queryClient = resolved;
    return resolved;
  }

  void _initialize() {
    final configuredQuery = _resolvedClient
        .reconfigureInfiniteQuery<TData, TParam>(
          _currentQueryKey,
          _currentQueryFn,
          options: _currentOptions,
        );
    _query = configuredQuery;

    emit(configuredQuery.state);
    _querySubscription = subscribeToInfiniteQuery<TData, TParam>(
      configuredQuery,
      (newState) {
        if (!isClosed &&
            _queryReferenceAttached &&
            identical(_query, configuredQuery)) {
          emit(newState);
        }
      },
      addListener: false,
    );

    final generation = _generation;
    _ready = _activateQuery(configuredQuery, generation);
  }

  Future<void> _activateQuery(
    InfiniteQuery<TData, TParam> configuredQuery,
    int generation, {
    bool shouldRefetch = false,
  }) async {
    var attached = false;
    var hadPagesBeforeActivation = false;
    try {
      await _resolvedClient.persistenceInitialization;
      if (isClosed ||
          generation != _generation ||
          !identical(_query, configuredQuery)) {
        return;
      }
      hadPagesBeforeActivation = configuredQuery.state.pages.isNotEmpty;
      // addListener() can throw after incrementing the reference count when
      // the initial page parameter callback fails. Mark ownership first so
      // the error path can release that reference.
      _queryReferenceAttached = true;
      attached = true;
      await configuredQuery.addListener();
    } on Object catch (error, _) {
      if (attached && identical(_query, configuredQuery)) {
        configuredQuery.removeListener();
        _queryReferenceAttached = false;
      }
      if (!isClosed && generation == _generation) {
        emit(
          configuredQuery.state.copyWith(
            status: QueryStatus.error,
            error: error,
          ),
        );
      }
      return;
    }

    if (isClosed ||
        generation != _generation ||
        !identical(_query, configuredQuery)) {
      return;
    }
    emit(configuredQuery.state);

    final forceRefetch =
        shouldRefetch || _currentOptions?.refetchOnMount == true;
    if (forceRefetch && hadPagesBeforeActivation) {
      final pageCount = configuredQuery.state.pages.length;
      for (var index = 0; index < pageCount; index++) {
        await configuredQuery.refetchPage(index);
      }
    }
  }

  /// Fetches the next page, optionally overriding the computed page parameter.
  Future<void> fetchNextPage([TParam? param]) {
    if (isClosed) return Future<void>.value();
    return query.fetchNextPage(param);
  }

  /// Fetches the previous page when a previous-page parameter is available.
  Future<void> fetchPreviousPage() {
    if (isClosed) return Future<void>.value();
    return query.fetchPreviousPage();
  }

  /// Refetches one page without disturbing the other pages.
  Future<void> refetchPage(int index) {
    if (isClosed) return Future<void>.value();
    return query.refetchPage(index);
  }

  /// Resets the pages and suppresses stale in-flight page results.
  void reset() {
    if (isClosed) return;
    query.reset();
  }

  /// Restores paginated state from an already available cache value.
  void updateFromCache(List<Page<TData, TParam>> pages) {
    if (isClosed) return;
    query.updateFromCache(pages);
  }

  /// Invalidates this infinite query in its owning client.
  void invalidate() {
    if (isClosed) return;
    _resolvedClient.invalidateQuery(_currentQueryKey);
  }

  /// Removes this infinite query from the owning client.
  void remove() {
    if (isClosed) return;
    _generation++;
    _detachCurrentQuery();
    _resolvedClient.removeInfiniteQuery(_currentQueryKey);
    emit(InfiniteQueryState<TData, TParam>.idle());
  }

  /// Reconfigures this query while preserving pages when its key is unchanged.
  void updateOptions({
    QueryKey? newQueryKey,
    Future<TData> Function(TParam param)? newQueryFn,
    InfiniteQueryOptions<TData, TParam>? newOptions,
    bool clearOptions = false,
  }) {
    if (isClosed) return;

    final nextQueryKey = newQueryKey ?? _currentQueryKey;
    final nextQueryFn = newQueryFn ?? _currentQueryFn;
    final nextOptions = clearOptions ? null : (newOptions ?? _currentOptions);
    final keyChanged = nextQueryKey.key != _currentQueryKey.key;
    final changed =
        keyChanged ||
        !identical(nextQueryFn, _currentQueryFn) ||
        !identical(nextOptions, _currentOptions);
    if (!changed) return;

    _generation++;
    if (keyChanged) {
      _detachCurrentQuery();
    }

    _currentQueryKey = nextQueryKey;
    _currentQueryFn = nextQueryFn;
    _currentOptions = nextOptions;

    final configuredQuery = _resolvedClient
        .reconfigureInfiniteQuery<TData, TParam>(
          _currentQueryKey,
          _currentQueryFn,
          options: _currentOptions,
        );
    final queryChanged = !identical(configuredQuery, _query);
    if (queryChanged) {
      _detachCurrentQuery();
      _query = configuredQuery;
      emit(configuredQuery.state);
      _querySubscription = subscribeToInfiniteQuery<TData, TParam>(
        configuredQuery,
        (newState) {
          if (!isClosed &&
              _queryReferenceAttached &&
              identical(_query, configuredQuery)) {
            emit(newState);
          }
        },
        addListener: false,
      );
    } else {
      emit(configuredQuery.state);
    }

    final activationGeneration = _generation;
    if (!_queryReferenceAttached || queryChanged) {
      _ready = _activateQuery(
        configuredQuery,
        activationGeneration,
        shouldRefetch: true,
      );
    } else {
      // Core reconfiguration preserves pages and emits the recalculated
      // pagination flags. Keep that state intact; callers can explicitly
      // refetch a page when a new fetch function should replace its data.
      _ready = Future<void>.value();
    }
  }

  void _detachCurrentQuery() {
    unsubscribe(_querySubscription);
    _querySubscription = null;
    if (_queryReferenceAttached) {
      _query?.removeListener();
      _queryReferenceAttached = false;
    }
  }

  @override
  Future<void> close() {
    _generation++;
    _detachCurrentQuery();
    return super.close();
  }
}
