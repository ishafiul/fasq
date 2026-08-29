import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/client_provider.dart';

/// Riverpod-native adapter for a core [InfiniteQuery].
///
/// Pagination remains owned by FASQ. Riverpod observes the complete
/// [InfiniteQueryState], including page errors, pagination flags, and
/// background page fetches.
class InfiniteQueryNotifier<TData, TParam>
    extends AutoDisposeAsyncNotifier<InfiniteQueryState<TData, TParam>> {
  QueryKey? _queryKey;
  Future<TData> Function(TParam param)? _queryFn;
  InfiniteQueryOptions<TData, TParam>? _options;
  QueryClient? _providedClient;
  FasqRuntime? _providedRuntime;

  InfiniteQuery<TData, TParam>? _query;
  QueryClient? _resolvedQueryClient;
  FasqRuntime? _resolvedRuntime;
  StreamSubscription<InfiniteQueryState<TData, TParam>>? _subscription;
  StreamSubscription<InfiniteQueryState<TData, TParam>>?
  _completionSubscription;
  Future<void>? _ready;
  var _queryReferenceAttached = false;
  var _generation = 0;
  var _cleanedUp = false;

  /// Initializes the notifier with its pagination and ownership configuration.
  void configure({
    required QueryKey queryKey,
    required Future<TData> Function(TParam param) queryFn,
    InfiniteQueryOptions<TData, TParam>? options,
    QueryClient? client,
    FasqRuntime? runtime,
  }) {
    _queryKey = queryKey;
    _queryFn = queryFn;
    _options = options;
    _providedClient = client;
    _providedRuntime = runtime;
  }

  /// The client that owns this infinite query.
  QueryClient get queryClient {
    final existing = _resolvedQueryClient;
    if (existing != null) return existing;
    final resolved =
        _providedClient ??
        _providedRuntime?.queryClient ??
        _resolvedRuntime?.queryClient ??
        ref.read(fasqClientProvider);
    _resolvedQueryClient = resolved;
    return resolved!;
  }

  /// Explicit client supplied to this provider, if any.
  QueryClient? get client => _providedClient ?? _providedRuntime?.queryClient;

  /// The runtime explicitly or implicitly supplied to this adapter.
  FasqRuntime? get runtime => _resolvedRuntime ?? _providedRuntime;

  /// The underlying core infinite query.
  InfiniteQuery<TData, TParam> get query {
    final value = _query;
    if (value == null) {
      throw StateError('The InfiniteQueryNotifier has not been initialized.');
    }
    return value;
  }

  /// Completes after persistence initialization and reference activation.
  Future<void> get ready => _ready ?? Future<void>.value();

  /// Whether at least one page is retained.
  bool get hasPages => query.state.pages.isNotEmpty;

  /// Whether another forward page can be fetched.
  bool get hasNextPage => query.state.hasNextPage;

  /// Whether another backward page can be fetched.
  bool get hasPreviousPage => query.state.hasPreviousPage;

  /// Whether a forward page is currently being fetched.
  bool get isFetchingNextPage => query.state.isFetchingNextPage;

  /// Whether a backward page is currently being fetched.
  bool get isFetchingPreviousPage => query.state.isFetchingPreviousPage;

  /// Number of Riverpod/core references holding this query alive.
  int get referenceCount => query.referenceCount;

  /// Whether the underlying query has been disposed.
  bool get isDisposed => query.isDisposed;

  @override
  FutureOr<InfiniteQueryState<TData, TParam>> build() {
    _detachCurrentQuery();
    _cleanedUp = false;
    final generation = ++_generation;
    final keepAlive = ref.keepAlive();
    ref.onCancel(keepAlive.close);

    final configuredRuntime =
        _providedRuntime ?? ref.watch(fasqRuntimeProvider);
    final QueryClient configuredClient =
        _providedClient ??
        configuredRuntime?.queryClient ??
        ref.watch(fasqClientProvider);
    _resolvedRuntime = configuredRuntime;
    _resolvedQueryClient = configuredClient;

    final queryKey = _queryKey;
    final queryFn = _queryFn;
    if (queryKey == null || queryFn == null) {
      throw StateError(
        'InfiniteQueryNotifier requires a query key and query function.',
      );
    }

    final configuredQuery = configuredClient
        .reconfigureInfiniteQuery<TData, TParam>(
          queryKey,
          queryFn,
          options: _options,
        );
    _query = configuredQuery;
    ref.onDispose(_cleanup);
    _listenToQuery(configuredQuery);

    final hadPagesBeforeActivation = configuredQuery.state.pages.isNotEmpty;
    final currentState = configuredQuery.state;
    _emitQueryState(currentState);
    _ready = _activateQuery(
      configuredQuery,
      generation,
      hadPagesBeforeActivation,
    );

    if (_hasSuccessfulPage(currentState)) return currentState;
    final pageError = _pageError(currentState);
    if (pageError != null) {
      Error.throwWithStackTrace(
        pageError.error!,
        pageError.stackTrace ?? StackTrace.current,
      );
    }
    return _waitForData(configuredQuery);
  }

  Future<void> _activateQuery(
    InfiniteQuery<TData, TParam> configuredQuery,
    int generation,
    bool hadPagesBeforeActivation,
  ) async {
    var attached = false;
    try {
      // addListener may throw after incrementing its reference count when a
      // page parameter callback fails. Mark ownership before awaiting it.
      _queryReferenceAttached = true;
      attached = true;
      await configuredQuery.addListener();
      if (_cleanedUp ||
          generation != _generation ||
          !identical(_query, configuredQuery)) {
        return;
      }
      await queryClient.persistenceInitialization;
    } on Object catch (error, stackTrace) {
      if (attached && identical(_query, configuredQuery)) {
        configuredQuery.removeListener();
        _queryReferenceAttached = false;
      }
      if (!_cleanedUp && generation == _generation) {
        state = AsyncError<InfiniteQueryState<TData, TParam>>(
          error,
          stackTrace,
        );
      }
      return;
    }
    if (_cleanedUp ||
        generation != _generation ||
        !identical(_query, configuredQuery)) {
      return;
    }
    _emitQueryState(configuredQuery.state);
    if (hadPagesBeforeActivation && _options?.refetchOnMount == true) {
      await _refetchPages(configuredQuery);
    }
  }

  void _listenToQuery(InfiniteQuery<TData, TParam> configuredQuery) {
    _subscription = configuredQuery.stream.listen((nextState) {
      if (_cleanedUp || !identical(_query, configuredQuery)) return;
      _emitQueryState(nextState);
    });
  }

  void _emitQueryState(InfiniteQueryState<TData, TParam> queryState) {
    if (_cleanedUp) return;
    state = _mapToAsyncValue(queryState);
  }

  Future<InfiniteQueryState<TData, TParam>> _waitForData(
    InfiniteQuery<TData, TParam> configuredQuery,
  ) {
    final completer = Completer<InfiniteQueryState<TData, TParam>>();
    late final StreamSubscription<InfiniteQueryState<TData, TParam>>
    subscription;

    void finishWithState(InfiniteQueryState<TData, TParam> nextState) {
      if (completer.isCompleted) return;
      if (_hasSuccessfulPage(nextState)) {
        completer.complete(nextState);
      } else {
        final error = _pageError(nextState);
        if (error == null) return;
        completer.completeError(
          error.error!,
          error.stackTrace ?? StackTrace.current,
        );
      }
      unawaited(subscription.cancel());
      if (identical(_completionSubscription, subscription)) {
        _completionSubscription = null;
      }
    }

    subscription = configuredQuery.stream.listen(finishWithState);
    _completionSubscription = subscription;
    finishWithState(configuredQuery.state);
    return completer.future;
  }

  AsyncValue<InfiniteQueryState<TData, TParam>> _mapToAsyncValue(
    InfiniteQueryState<TData, TParam> queryState,
  ) {
    final pageError = _pageError(queryState);
    final dataState = AsyncData<InfiniteQueryState<TData, TParam>>(queryState);

    if (pageError != null) {
      final errorState = AsyncError<InfiniteQueryState<TData, TParam>>(
        pageError.error!,
        pageError.stackTrace ?? StackTrace.current,
      );
      if (_hasSuccessfulPage(queryState)) {
        return errorState.copyWithPrevious(dataState);
      }
      return errorState;
    }
    if (_hasSuccessfulPage(queryState)) {
      if (queryState.isFetchingNextPage || queryState.isFetchingPreviousPage) {
        return AsyncLoading<InfiniteQueryState<TData, TParam>>()
            .copyWithPrevious(dataState);
      }
      return dataState;
    }
    if (queryState.error != null) {
      return AsyncError<InfiniteQueryState<TData, TParam>>(
        queryState.error!,
        StackTrace.current,
      );
    }
    return const AsyncLoading<Never>()
        as AsyncValue<InfiniteQueryState<TData, TParam>>;
  }

  bool _hasSuccessfulPage(InfiniteQueryState<TData, TParam> queryState) {
    return queryState.pages.any((page) => page.error == null);
  }

  Page<TData, TParam>? _pageError(
    InfiniteQueryState<TData, TParam> queryState,
  ) {
    for (final page in queryState.pages.reversed) {
      if (page.error != null) return page;
    }
    return null;
  }

  Future<void> _refetchPages(
    InfiniteQuery<TData, TParam> configuredQuery,
  ) async {
    final pageCount = configuredQuery.state.pages.length;
    for (var index = 0; index < pageCount; index++) {
      await configuredQuery.refetchPage(index);
    }
  }

  /// Fetches the next page, optionally overriding its computed parameter.
  Future<void> fetchNextPage([TParam? param]) {
    return query.fetchNextPage(param);
  }

  /// Fetches the previous page.
  Future<void> fetchPreviousPage() {
    return query.fetchPreviousPage();
  }

  /// Refetches one existing page.
  Future<void> refetchPage(int index) {
    return query.refetchPage(index);
  }

  /// Clears all pages and returns the core query to idle.
  void reset() {
    query.reset();
  }

  /// Restores pages from an already available cache value.
  void updateFromCache(List<Page<TData, TParam>> pages) {
    query.updateFromCache(pages);
  }

  /// Resets this query and starts a fresh first-page fetch when configured.
  void invalidate() {
    query.reset();
    if (_options?.enabled != false) {
      unawaited(query.fetchNextPage());
    }
  }

  /// Removes this infinite query from the owning client.
  void remove() {
    final currentQuery = _query;
    final currentKey = _queryKey;
    if (currentQuery == null || currentKey == null) return;
    _generation++;
    _detachCurrentQuery();
    queryClient.removeInfiniteQuery(currentKey);
    _query = null;
    state =
        const AsyncLoading<Never>()
            as AsyncValue<InfiniteQueryState<TData, TParam>>;
  }

  /// Reconfigures this query while preserving pages when the key is unchanged.
  void updateOptions({
    QueryKey? newQueryKey,
    Future<TData> Function(TParam param)? newQueryFn,
    InfiniteQueryOptions<TData, TParam>? newOptions,
    bool clearOptions = false,
  }) {
    final currentQuery = _query;
    if (currentQuery == null) return;

    final nextQueryKey = newQueryKey ?? _queryKey;
    final nextQueryFn = newQueryFn ?? _queryFn;
    final nextOptions = clearOptions ? null : (newOptions ?? _options);
    if (nextQueryKey == null || nextQueryFn == null) {
      throw ArgumentError('A query key and query function are required.');
    }
    final keyChanged = nextQueryKey.key != _queryKey?.key;
    final changed =
        keyChanged ||
        !identical(nextQueryFn, _queryFn) ||
        !identical(nextOptions, _options);
    if (!changed) return;

    _generation++;
    if (keyChanged) _detachCurrentQuery();
    _queryKey = nextQueryKey;
    _queryFn = nextQueryFn;
    _options = nextOptions;

    final configuredQuery = queryClient.reconfigureInfiniteQuery<TData, TParam>(
      nextQueryKey,
      nextQueryFn,
      options: nextOptions,
    );
    final queryChanged = !identical(configuredQuery, currentQuery);
    if (queryChanged) {
      _detachCurrentQuery();
      _query = configuredQuery;
      _listenToQuery(configuredQuery);
      _emitQueryState(configuredQuery.state);
    } else {
      _query = configuredQuery;
      _emitQueryState(configuredQuery.state);
    }

    final activationGeneration = _generation;
    if (!_queryReferenceAttached || queryChanged) {
      _ready = _activateReconfiguredQuery(
        configuredQuery,
        activationGeneration,
      );
    }
  }

  Future<void> _activateReconfiguredQuery(
    InfiniteQuery<TData, TParam> configuredQuery,
    int generation,
  ) async {
    var attached = false;
    try {
      _queryReferenceAttached = true;
      attached = true;
      await configuredQuery.addListener();
      await queryClient.persistenceInitialization;
    } on Object catch (error, stackTrace) {
      if (attached && identical(_query, configuredQuery)) {
        configuredQuery.removeListener();
        _queryReferenceAttached = false;
      }
      if (!_cleanedUp && generation == _generation) {
        state = AsyncError<InfiniteQueryState<TData, TParam>>(
          error,
          stackTrace,
        );
      }
      return;
    }
    if (_cleanedUp ||
        generation != _generation ||
        !identical(_query, configuredQuery)) {
      return;
    }
    _emitQueryState(configuredQuery.state);
  }

  void _detachCurrentQuery() {
    unawaited(_subscription?.cancel());
    _subscription = null;
    unawaited(_completionSubscription?.cancel());
    _completionSubscription = null;
    if (_queryReferenceAttached) {
      _query?.removeListener();
      _queryReferenceAttached = false;
    }
  }

  void _cleanup() {
    if (_cleanedUp) return;
    _cleanedUp = true;
    _generation++;
    _detachCurrentQuery();
  }
}
