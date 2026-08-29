import 'dart:async';

import 'package:fasq_bloc/fasq_bloc.dart';

/// Base cubit that mirrors a FASQ [Query] lifecycle.
///
/// Subclasses provide the [queryKey] and either [queryFn] or
/// [queryFnWithToken]. They may also provide [dependsOn], [options], a
/// [client], or a [runtime]. The cubit exposes the same imperative query
/// operations as the core reactive adapters while retaining a Bloc-friendly
/// [state] stream.
abstract class QueryCubit<T> extends Cubit<QueryState<T>>
    with FasqSubscriptionMixin<QueryState<T>> {
  QueryCubit({QueryClient? client, FasqRuntime? runtime})
    : _providedClient = client,
      _providedRuntime = runtime,
      super(QueryState<T>.idle()) {
    _currentQueryKey = queryKey;
    _currentQueryFn = queryFn;
    _currentQueryFnWithToken = queryFnWithToken;
    _currentDependsOn = dependsOn;
    _currentOptions = options;
    _initialize();
  }

  final QueryClient? _providedClient;
  final FasqRuntime? _providedRuntime;

  Query<T>? _query;
  late QueryKey _currentQueryKey;
  Future<T> Function()? _currentQueryFn;
  Future<T> Function(CancellationToken token)? _currentQueryFnWithToken;
  QueryKey? _currentDependsOn;
  QueryOptions? _currentOptions;
  QueryClient? _queryClient;
  StreamSubscription<QueryState<T>>? _querySubscription;
  Future<void>? _ready;
  var _queryReferenceAttached = false;
  var _generation = 0;

  /// Query key used by this cubit.
  QueryKey get queryKey;

  /// Legacy query function used when [queryFnWithToken] is not provided.
  Future<T> Function()? get queryFn => null;

  /// Cancellation-aware query function.
  ///
  /// When present, the core query passes a [CancellationToken] to this
  /// function and prefers it over [queryFn].
  Future<T> Function(CancellationToken token)? get queryFnWithToken => null;

  /// Parent query whose disposal should cancel this query.
  QueryKey? get dependsOn => null;

  /// Query behavior configuration.
  QueryOptions? get options => null;

  /// Explicit client used by this cubit.
  QueryClient? get client => _providedClient ?? _providedRuntime?.queryClient;

  /// Optional runtime used for client resolution and future runtime-backed
  /// adapter features.
  FasqRuntime? get runtime => _providedRuntime;

  /// The resolved client that owns this cubit's query.
  QueryClient get queryClient => _resolvedClient;

  /// The underlying core query.
  Query<T> get query {
    final value = _query;
    if (value == null) {
      throw StateError('The QueryCubit has not been initialized.');
    }
    return value;
  }

  /// Whether this query currently has a value, including a nullable value.
  bool get hasData => state.hasValue;

  /// Whether the initial query fetch is running.
  bool get isLoading => state.isLoading;

  /// Whether a background refetch is running.
  bool get isFetching => state.isFetching;

  /// Whether the latest query state is successful.
  bool get isSuccess => state.isSuccess;

  /// Whether the query is idle.
  bool get isIdle => state.isIdle;

  /// Whether the latest query state contains an error.
  bool get hasError => state.hasError;

  /// Current query data.
  T? get data => state.data;

  /// Current query error.
  Object? get error => state.error;

  /// Current query error stack trace.
  StackTrace? get stackTrace => state.stackTrace;

  /// Whether the cached query data is stale.
  bool get isStale => state.isStale;

  /// Number of active references held on the core query.
  int get referenceCount => query.referenceCount;

  /// Whether the underlying core query has been disposed.
  bool get isDisposed => query.isDisposed;

  /// Completes after the owning client's persistence initialization and query
  /// reference activation have completed.
  Future<void> get ready => _ready ?? Future<void>.value();

  QueryClient get _resolvedClient {
    final existing = _queryClient;
    if (existing != null) return existing;
    final resolved = client ?? runtime?.queryClient ?? QueryClient();
    _queryClient = resolved;
    return resolved;
  }

  void _initialize() {
    final queryClient = _resolvedClient;
    if (_currentQueryFn == null && _currentQueryFnWithToken == null) {
      throw StateError('QueryCubit requires queryFn or queryFnWithToken.');
    }
    final configuredQuery = queryClient.reconfigureQuery<T>(
      _currentQueryKey,
      queryFn: _currentQueryFn,
      queryFnWithToken: _currentQueryFnWithToken,
      options: _currentOptions,
      dependsOn: _currentDependsOn,
    );
    _query = configuredQuery;

    _emitQueryState(configuredQuery);
    _querySubscription = subscribeToQuery<T>(configuredQuery, (newState) {
      if (!isClosed &&
          _queryReferenceAttached &&
          identical(_query, configuredQuery) &&
          _currentOptions?.enabled != false) {
        emit(newState);
      }
    }, addListener: false);

    final generation = _generation;
    _ready = _activateQuery(configuredQuery, generation);
  }

  Future<void> _activateQuery(
    Query<T> configuredQuery,
    int generation, {
    bool shouldRefetch = false,
  }) async {
    try {
      await _resolvedClient.persistenceInitialization;
    } on Object catch (error, stackTrace) {
      if (!isClosed && generation == _generation) {
        emit(QueryState<T>.error(error, stackTrace));
      }
      return;
    }

    if (isClosed ||
        generation != _generation ||
        !identical(_query, configuredQuery)) {
      return;
    }

    final hadStaleData =
        configuredQuery.state.hasValue && configuredQuery.state.isStale;
    configuredQuery.addListener();
    _queryReferenceAttached = true;
    _emitQueryState(configuredQuery);

    final forceRefetch =
        shouldRefetch || _currentOptions?.refetchOnMount == true;
    final isFirstSubscriber =
        configuredQuery.referenceCount == 1 && !configuredQuery.state.hasValue;
    if (!isFirstSubscriber && (forceRefetch || hadStaleData)) {
      await _fetchQuery(configuredQuery, forceRefetch: forceRefetch);
    }
  }

  Future<void> _fetchQuery(
    Query<T> configuredQuery, {
    required bool forceRefetch,
  }) async {
    try {
      await configuredQuery.fetch(forceRefetch: forceRefetch);
    } on Object {
      // The query already emitted its error state and invoked its configured
      // error callback, if any.
    }
  }

  void _emitQueryState(Query<T> configuredQuery) {
    if (isClosed) return;
    if (_currentOptions?.enabled == false) {
      emit(QueryState<T>.idle());
      return;
    }
    emit(configuredQuery.state);
  }

  /// Refetches the query, bypassing fresh cache data by default.
  ///
  /// Query failures are represented in [state]. They are consumed here so a
  /// fire-and-forget UI callback cannot create an uncaught asynchronous error.
  Future<void> refetch({bool forceRefetch = true}) async {
    if (isClosed) return;
    try {
      await query.fetch(forceRefetch: forceRefetch);
    } on Object {
      // The query already emitted its error state. Bloc actions should remain
      // safe when invoked without awaiting the returned future.
    }
  }

  /// Invalidates this query in its owning client.
  void invalidate() {
    if (isClosed) return;
    _resolvedClient.invalidateQuery(_currentQueryKey);
  }

  /// Cancels any cooperative fetch currently running for this query.
  void cancel() {
    if (isClosed) return;
    query.cancel();
  }

  /// Manually updates the cached data for this query.
  void setData(T data, {bool isSecure = false, Duration? maxAge}) {
    if (isClosed) return;
    _resolvedClient.setQueryData<T>(
      _currentQueryKey,
      data,
      isSecure: isSecure,
      maxAge: maxAge,
    );
  }

  /// Replaces the query state from an already available cache value.
  void updateFromCache(T data) {
    if (isClosed) return;
    query.updateFromCache(data);
  }

  /// Removes this query and its retained cache entry from the owning client.
  void remove() {
    if (isClosed) return;
    _generation++;
    _detachCurrentQuery();
    _resolvedClient.removeQuery(_currentQueryKey);
    emit(QueryState<T>.idle());
  }

  /// Query-specific performance metrics.
  QueryMetrics get metrics => query.metrics;

  /// Query debug information, when available in a debug build.
  QueryDebugInfo? get debugInfo => query.debugInfo;

  /// Updates the query configuration without replacing the query instance
  /// when the key remains the same.
  ///
  /// The optional clear flags make it possible to switch between ordinary and
  /// token-aware functions, remove a dependency, or clear options while the
  /// original [updateOptions] behavior remains source-compatible.
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
    if (isClosed) return;

    final nextQueryKey = newQueryKey ?? _currentQueryKey;
    final nextOptions = clearOptions ? null : (newOptions ?? _currentOptions);
    final nextQueryFn = clearQueryFn ? null : (newQueryFn ?? _currentQueryFn);
    final nextQueryFnWithToken = clearQueryFnWithToken
        ? null
        : (newQueryFnWithToken ?? _currentQueryFnWithToken);
    final nextDependsOn = clearDependsOn
        ? null
        : (newDependsOn ?? _currentDependsOn);

    if (nextQueryFn == null && nextQueryFnWithToken == null) {
      throw ArgumentError(
        'Either newQueryFn or newQueryFnWithToken must be provided.',
      );
    }

    final keyChanged = nextQueryKey.key != _currentQueryKey.key;
    final changed =
        keyChanged ||
        !identical(nextOptions, _currentOptions) ||
        !identical(nextQueryFn, _currentQueryFn) ||
        !identical(nextQueryFnWithToken, _currentQueryFnWithToken) ||
        nextDependsOn?.key != _currentDependsOn?.key;
    if (!changed) return;

    _generation++;
    if (keyChanged) {
      _detachCurrentQuery();
    }

    _currentQueryKey = nextQueryKey;
    _currentOptions = nextOptions;
    _currentQueryFn = nextQueryFn;
    _currentQueryFnWithToken = nextQueryFnWithToken;
    _currentDependsOn = nextDependsOn;

    final configuredQuery = _resolvedClient.reconfigureQuery<T>(
      _currentQueryKey,
      queryFn: _currentQueryFn,
      queryFnWithToken: _currentQueryFnWithToken,
      options: _currentOptions,
      dependsOn: _currentDependsOn,
    );
    final queryChanged = !identical(configuredQuery, _query);
    if (queryChanged) {
      _detachCurrentQuery();
      _query = configuredQuery;
      _emitQueryState(configuredQuery);
      _querySubscription = subscribeToQuery<T>(configuredQuery, (newState) {
        if (!isClosed &&
            _queryReferenceAttached &&
            identical(_query, configuredQuery) &&
            _currentOptions?.enabled != false) {
          emit(newState);
        }
      }, addListener: false);
    } else {
      _emitQueryState(configuredQuery);
    }

    final activationGeneration = _generation;
    if (!_queryReferenceAttached || queryChanged) {
      _ready = _activateQuery(
        configuredQuery,
        activationGeneration,
        shouldRefetch: true,
      );
    } else {
      _ready = _fetchQuery(configuredQuery, forceRefetch: true);
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
