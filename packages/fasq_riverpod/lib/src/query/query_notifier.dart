import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/client_provider.dart';

/// Riverpod-native adapter for one core [Query].
///
/// The notifier owns one reference-counted core query for the lifetime of the
/// Riverpod provider. It keeps the core cache, cancellation, observers,
/// metrics, and dependency behavior intact while exposing [AsyncValue].
class QueryNotifier<T> extends AutoDisposeAsyncNotifier<T> {
  QueryKey? _queryKey;
  Future<T> Function()? _queryFn;
  Future<T> Function(CancellationToken token)? _queryFnWithToken;
  QueryOptions? _options;
  QueryKey? _dependsOn;
  QueryClient? _providedClient;
  FasqRuntime? _providedRuntime;

  Query<T>? _query;
  QueryClient? _resolvedQueryClient;
  FasqRuntime? _resolvedRuntime;
  StreamSubscription<QueryState<T>>? _subscription;
  StreamSubscription<QueryState<T>>? _completionSubscription;
  Future<void>? _ready;
  var _queryReferenceAttached = false;
  var _generation = 0;
  var _cleanedUp = false;

  /// Initializes the notifier with its query and ownership configuration.
  void configure({
    required QueryKey queryKey,
    Future<T> Function()? queryFn,
    Future<T> Function(CancellationToken token)? queryFnWithToken,
    QueryOptions? options,
    QueryKey? dependsOn,
    QueryClient? client,
    FasqRuntime? runtime,
  }) {
    _queryKey = queryKey;
    _queryFn = queryFn;
    _queryFnWithToken = queryFnWithToken;
    _options = options;
    _dependsOn = dependsOn;
    _providedClient = client;
    _providedRuntime = runtime;
  }

  /// The client that owns the query.
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

  /// The underlying core query.
  Query<T> get query {
    final value = _query;
    if (value == null) {
      throw StateError('The QueryNotifier has not been initialized.');
    }
    return value;
  }

  /// Completes after persistence initialization and reference activation.
  Future<void> get ready => _ready ?? Future<void>.value();

  /// Whether this query currently contains a value, including nullable data.
  bool get hasData => query.state.hasValue;

  /// Whether the initial fetch is running.
  bool get isLoading => query.state.isLoading;

  /// Whether a background fetch is running.
  bool get isFetching => query.state.isFetching;

  /// Whether the latest query state is successful.
  bool get isSuccess => query.state.isSuccess;

  /// Whether the query is idle.
  bool get isIdle => query.state.isIdle;

  /// Whether the query has an error.
  bool get hasError => query.state.hasError;

  /// Whether the cached value is stale.
  bool get isStale => query.state.isStale;

  /// Current query data.
  T? get data => query.state.data;

  /// Current query error.
  Object? get error => query.state.error;

  /// Current query error stack trace.
  StackTrace? get stackTrace => query.state.stackTrace;

  /// Number of Riverpod/core references holding this query alive.
  int get referenceCount => query.referenceCount;

  /// Whether the underlying query has been disposed.
  bool get isDisposed => query.isDisposed;

  /// Query-specific performance metrics.
  QueryMetrics get metrics => query.metrics;

  /// Debug lifecycle information, when available.
  QueryDebugInfo? get debugInfo => query.debugInfo;

  @override
  FutureOr<T> build() {
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
    final queryFnWithToken = _queryFnWithToken;
    if (queryKey == null || (queryFn == null && queryFnWithToken == null)) {
      throw StateError(
        'QueryNotifier requires a query key and query function.',
      );
    }

    final configuredQuery = configuredClient.reconfigureQuery<T>(
      queryKey,
      queryFn: queryFn,
      queryFnWithToken: queryFnWithToken,
      options: _options,
      dependsOn: _dependsOn,
    );
    _query = configuredQuery;
    ref.onDispose(_cleanup);
    _listenToQuery(configuredQuery);

    final stateBeforeActivation = configuredQuery.state;
    configuredQuery.addListener();
    _queryReferenceAttached = true;

    final currentState = configuredQuery.state;
    _emitQueryState(currentState);
    _ready = _finishActivation(
      configuredQuery,
      generation,
      stateBeforeActivation,
    );

    if (stateBeforeActivation.hasValue || currentState.hasValue) {
      return currentState.data as T;
    }

    // Adding a reference automatically starts an enabled initial fetch in the
    // core Query. A disabled query intentionally remains loading/pending until
    // its options are reconfigured or it is enabled by its owner.
    if (stateBeforeActivation.hasError && !currentState.isLoading) {
      Error.throwWithStackTrace(
        stateBeforeActivation.error!,
        stateBeforeActivation.stackTrace ?? StackTrace.current,
      );
    }
    return _waitForData(configuredQuery);
  }

  void _listenToQuery(Query<T> configuredQuery) {
    _subscription = configuredQuery.stream.listen((nextState) {
      if (_cleanedUp || !identical(_query, configuredQuery)) return;
      _emitQueryState(nextState);
    });
  }

  void _emitQueryState(QueryState<T> queryState) {
    if (_cleanedUp) return;
    if (_options?.enabled == false && !queryState.hasData) {
      state = const AsyncLoading<Never>() as AsyncValue<T>;
      return;
    }
    state = _mapQueryStateToAsyncValue(queryState);
  }

  /// Waits for the first successful or failed result of [configuredQuery].
  Future<T> _waitForData(Query<T> configuredQuery) {
    final completer = Completer<T>();
    late final StreamSubscription<QueryState<T>> subscription;

    void finishWithState(QueryState<T> nextState) {
      if (completer.isCompleted) return;
      if (nextState.hasData) {
        completer.complete(nextState.data as T);
      } else if (nextState.hasError) {
        completer.completeError(
          nextState.error!,
          nextState.stackTrace ?? StackTrace.current,
        );
      } else {
        return;
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

  AsyncValue<T> _mapQueryStateToAsyncValue(QueryState<T> queryState) {
    if (queryState.hasError) {
      final errorState = AsyncError<T>(
        queryState.error!,
        queryState.stackTrace ?? StackTrace.current,
      );
      if (queryState.hasData) {
        return errorState.copyWithPrevious(AsyncData<T>(queryState.data as T));
      }
      return errorState;
    }
    if (queryState.hasData) {
      final dataState = AsyncData<T>(queryState.data as T);
      if (queryState.isFetching) {
        return AsyncLoading<T>().copyWithPrevious(dataState);
      }
      return dataState;
    }
    return const AsyncLoading<Never>() as AsyncValue<T>;
  }

  Future<void> _safeFetch(
    Query<T> configuredQuery, {
    required bool forceRefetch,
  }) async {
    try {
      await configuredQuery.fetch(forceRefetch: forceRefetch);
    } on Object {
      // Core Query has already emitted the error state. Riverpod consumers
      // observe it through AsyncValue instead of an uncaught action error.
    }
  }

  Future<void> _finishActivation(
    Query<T> configuredQuery,
    int generation,
    QueryState<T> stateBeforeActivation,
  ) async {
    try {
      await queryClient.persistenceInitialization;
    } on Object catch (error, stackTrace) {
      if (!_cleanedUp && generation == _generation) {
        state = AsyncError<T>(error, stackTrace);
      }
      return;
    }
    if (_cleanedUp ||
        generation != _generation ||
        !identical(_query, configuredQuery)) {
      return;
    }
    if (stateBeforeActivation.hasValue &&
        (stateBeforeActivation.isStale || _options?.refetchOnMount == true)) {
      await _safeFetch(
        configuredQuery,
        forceRefetch: _options?.refetchOnMount == true,
      );
    }
  }

  /// Refetches the query, bypassing fresh cache data by default.
  Future<void> refetch({bool forceRefetch = true}) {
    return _safeFetch(query, forceRefetch: forceRefetch);
  }

  /// Invalidates this query and lets the core client refetch active listeners.
  void invalidate() {
    queryClient.invalidateQuery(query.queryKey);
  }

  /// Cancels the current cooperative fetch.
  void cancel() {
    query.cancel();
  }

  /// Writes data through the owning client's cache.
  void setData(T data, {bool isSecure = false, Duration? maxAge}) {
    queryClient.setQueryData<T>(
      query.queryKey,
      data,
      isSecure: isSecure,
      maxAge: maxAge,
    );
  }

  /// Updates the active query state from an already available cache value.
  void updateFromCache(T data) {
    query.updateFromCache(data);
  }

  /// Removes this query from the owning client and resets this provider state.
  void remove() {
    final currentQuery = _query;
    final currentKey = _queryKey;
    if (currentQuery == null || currentKey == null) return;
    _generation++;
    _detachCurrentQuery();
    queryClient.removeQuery(currentKey);
    _query = null;
    state = const AsyncLoading<Never>() as AsyncValue<T>;
  }

  /// Reconfigures the core query while preserving its identity when possible.
  ///
  /// Clear flags allow switching between ordinary and token-aware query
  /// functions, removing dependencies, or clearing options.
  void updateOptions({
    QueryKey? newQueryKey,
    QueryOptions? newOptions,
    Future<T> Function()? newQueryFn,
    Future<T> Function(CancellationToken token)? newQueryFnWithToken,
    QueryKey? newDependsOn,
    bool clearOptions = false,
    bool clearQueryFn = false,
    bool clearQueryFnWithToken = false,
    bool clearDependsOn = false,
  }) {
    final currentQuery = _query;
    if (currentQuery == null) return;

    final nextQueryKey = newQueryKey ?? _queryKey;
    final nextOptions = clearOptions ? null : (newOptions ?? _options);
    final nextQueryFn = clearQueryFn ? null : (newQueryFn ?? _queryFn);
    final nextQueryFnWithToken = clearQueryFnWithToken
        ? null
        : (newQueryFnWithToken ?? _queryFnWithToken);
    final nextDependsOn = clearDependsOn ? null : (newDependsOn ?? _dependsOn);
    if (nextQueryKey == null ||
        (nextQueryFn == null && nextQueryFnWithToken == null)) {
      throw ArgumentError(
        'A query key and either newQueryFn or newQueryFnWithToken are required.',
      );
    }

    final keyChanged = nextQueryKey.key != _queryKey?.key;
    final changed =
        keyChanged ||
        !identical(nextOptions, _options) ||
        !identical(nextQueryFn, _queryFn) ||
        !identical(nextQueryFnWithToken, _queryFnWithToken) ||
        nextDependsOn?.key != _dependsOn?.key;
    if (!changed) return;

    _generation++;
    if (keyChanged) _detachCurrentQuery();

    _queryKey = nextQueryKey;
    _options = nextOptions;
    _queryFn = nextQueryFn;
    _queryFnWithToken = nextQueryFnWithToken;
    _dependsOn = nextDependsOn;

    final configuredQuery = queryClient.reconfigureQuery<T>(
      nextQueryKey,
      queryFn: nextQueryFn,
      queryFnWithToken: nextQueryFnWithToken,
      options: nextOptions,
      dependsOn: nextDependsOn,
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
    } else {
      _ready = _safeFetch(configuredQuery, forceRefetch: true);
    }
  }

  Future<void> _activateReconfiguredQuery(
    Query<T> configuredQuery,
    int generation,
  ) async {
    configuredQuery.addListener();
    _queryReferenceAttached = true;
    _emitQueryState(configuredQuery.state);
    try {
      await queryClient.persistenceInitialization;
    } on Object catch (error, stackTrace) {
      if (!_cleanedUp && generation == _generation) {
        state = AsyncError<T>(error, stackTrace);
      }
      return;
    }
    if (_cleanedUp ||
        generation != _generation ||
        !identical(_query, configuredQuery)) {
      return;
    }
    if (configuredQuery.state.hasData &&
        (_options?.refetchOnMount == true || configuredQuery.state.isStale)) {
      unawaited(
        _safeFetch(
          configuredQuery,
          forceRefetch: _options?.refetchOnMount == true,
        ),
      );
    }
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
