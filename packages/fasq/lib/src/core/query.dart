import 'dart:async';

import '../cache/cache_entry.dart';
import '../cache/cache_metrics.dart';
import '../cache/query_cache.dart';
import '../circuit_breaker/circuit_breaker.dart';
import '../circuit_breaker/circuit_breaker_exceptions.dart';
import '../circuit_breaker/circuit_breaker_options.dart';
import '../circuit_breaker/circuit_breaker_registry.dart';
import 'cancellation_token.dart';
import 'query_client.dart';
import 'query_dependency_manager.dart';
import 'query_key.dart';
import 'query_options.dart';
import 'query_snapshot.dart';
import 'query_state.dart';
import 'query_status.dart';
import 'utils/fasq_time.dart';

/// A query represents an async operation with managed state and lifecycle.
///
/// Queries automatically manage loading, error, and success states for any
/// async operation. They support reference counting for automatic cleanup
/// and emit state changes through a stream for reactive updates.
///
/// Queries are typically not created directly. Instead, use [QueryBuilder]
/// widget or access them through [QueryClient].
///
/// Example:
/// ```dart
/// final query = Query<String>(
///   key: 'users',
///   queryFn: () => api.fetchUsers(),
/// );
///
/// query.stream.listen((state) {
///   print('State: ${state.status}');
/// });
///
/// await query.fetch();
/// ```
class Query<T> {
  /// Unique identifier for this query.
  final QueryKey queryKey;

  /// Unique identifier for this query (string representation).
  /// Kept for backward compatibility.
  final String key;

  /// The async function that fetches the data.
  ///
  /// // TODO(fasq): Deprecate in favor of queryFnWithToken in next major version
  final Future<T> Function()? queryFn;

  /// The async function that fetches data with cancellation support.
  ///
  /// Use this instead of [queryFn] to enable cooperative cancellation.
  /// The [CancellationToken] can be checked during long operations or passed
  /// to HTTP clients that support cancellation.
  final Future<T> Function(CancellationToken token)? queryFnWithToken;

  /// Optional configuration for this query.
  final QueryOptions? options;

  /// The cache instance for storing results.
  final QueryCache? cache;

  /// The query client instance for accessing isolate pool
  final QueryClient? client;

  /// Callback when query is disposed (for cleanup in QueryClient).
  final void Function()? onDispose;

  /// The circuit breaker registry for this query scope
  final CircuitBreakerRegistry? circuitBreakerRegistry;

  /// The dependency manager for parent-child query relationships
  final QueryDependencyManager? dependencyManager;

  /// Delay before a query is disposed after reaching zero subscribers.
  ///
  /// Can be modified for testing to avoid pending timers.
  static Duration disposalDelay = const Duration(seconds: 5);

  QueryState<T> _currentState;
  late final StreamController<QueryState<T>> _controller;
  final List<StreamSubscription<QueryState<T>>> _subscriptions = [];
  int _referenceCount = 0;
  Timer? _disposeTimer;
  bool _isDisposed = false;

  // Cancellation tracking
  CancellationToken? _currentFetchToken;

  // Performance tracking fields
  DateTime? _lastFetchStart;
  Duration? _lastFetchDuration;
  final List<Duration> _fetchHistory = [];

  Query({
    required this.queryKey,
    this.queryFn,
    this.queryFnWithToken,
    this.options,
    this.cache,
    this.client,
    this.circuitBreakerRegistry,
    this.dependencyManager,
    this.onDispose,
    CacheEntry<T>? initialEntry,
  })  : assert(
          queryFn != null || queryFnWithToken != null,
          'Either queryFn or queryFnWithToken must be provided',
        ),
        key = queryKey.key,
        _currentState = QueryState<T>.idle() {
    _controller = StreamController<QueryState<T>>.broadcast();

    // Set initial state based on cache snapshot and staleness
    _currentState = _createInitialState(initialEntry);
  }

  /// Creates the initial state, checking cache staleness if cached data is provided
  QueryState<T> _createInitialState(CacheEntry<T>? initialEntry) {
    if (initialEntry != null) {
      return QueryState<T>.success(
        initialEntry.data,
        dataUpdatedAt: initialEntry.createdAt,
        isStale: initialEntry.isStale,
        hasValue: initialEntry.hasValue,
      );
    }

    if (cache != null) {
      return QueryState<T>.loading();
    }

    return QueryState<T>.idle();
  }

  /// Stream of state changes for this query.
  ///
  /// Subscribe to this stream to receive updates when the query state changes.
  /// Use [subscribe] method to ensure proper cleanup of subscriptions.
  Stream<QueryState<T>> get stream => _controller.stream;

  /// Subscribes to state changes with automatic tracking for proper cleanup.
  ///
  /// Tracked subscriptions are automatically cancelled when query is disposed.
  StreamSubscription<QueryState<T>> subscribe(
      void Function(QueryState<T>) listener) {
    final sub = _controller.stream.listen(listener);
    _subscriptions.add(sub);
    return sub;
  }

  /// The current state of this query.
  QueryState<T> get state => _currentState;

  /// Number of active subscribers to this query.
  ///
  /// Used for automatic cleanup when count reaches zero.
  int get referenceCount => _referenceCount;

  /// Whether this query has been disposed.
  bool get isDisposed => _isDisposed;

  /// Get performance metrics for this query
  QueryMetrics get metrics => QueryMetrics(
        fetchHistory: List.from(_fetchHistory),
        lastFetchDuration: _lastFetchDuration,
        referenceCount: _referenceCount,
      );

  /// Creates a query function that can be used with _executeFetch.
  ///
  /// Prefers queryFnWithToken if available, passing the token.
  /// Falls back to queryFn (without token) for backward compatibility.
  Future<T> Function() _createQueryFn(CancellationToken token) {
    final tokenFn = queryFnWithToken;
    if (tokenFn != null) {
      return () => tokenFn(token);
    }
    // Fallback to legacy queryFn without token
    return queryFn!;
  }

  Future<T> _maybeTransformData(T data) async {
    final performance = options?.performance;
    if (performance == null || !performance.enableDataTransform) {
      return data;
    }

    final transformer = performance.dataTransformer;
    if (transformer == null) {
      return data;
    }

    final autoIsolate = performance.autoIsolate && client != null;
    final threshold = performance.isolateThreshold;

    if (autoIsolate && threshold != null) {
      final estimatedSize = _estimateDataFootprint(data);
      if (estimatedSize >= threshold) {
        try {
          final transformed =
              await client!.isolatePool.execute<_TransformPayload<T>, T?>(
            _runDataTransformerTask,
            _TransformPayload<T>(data: data, transformer: transformer),
          );
          if (transformed != null) {
            return transformed;
          }
        } catch (_) {
          // Fallback to main thread execution on failure
        }
      }
    }

    try {
      final result = await Future.sync(() => transformer(data));
      if (result == null) {
        return data;
      }
      return result as T;
    } catch (_) {
      return data;
    }
  }

  /// Adds a subscriber to this query.
  ///
  /// Increments the reference count and triggers auto-fetch if this is
  /// the first subscriber and the query has no data yet.
  ///
  /// Called automatically by [QueryBuilder] widgets.
  void addListener() {
    if (_isDisposed) return;

    _referenceCount++;
    _cancelDisposal();

    if (_referenceCount == 1 && !state.hasValue) {
      fetch().catchError((_) {
        // Error is handled by state update and onError callback
      });
    }
  }

  /// Removes a subscriber from this query.
  ///
  /// Decrements the reference count and schedules disposal if count reaches zero.
  ///
  /// Called automatically by [QueryBuilder] widgets on disposal.
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

  /// Executes the async operation and updates the query state.
  ///
  /// Checks cache first for fresh data. If stale, serves stale data and
  /// refetches in background. Uses request deduplication if cache is available.
  ///
  /// Transitions through loading state, then either success or error state.
  /// Does not fetch if query is disposed or if [QueryOptions.enabled] is false.
  ///
  /// Can be called manually to refetch data:
  /// ```dart
  /// final query = QueryClient().getQueryByKey<User>('user');
  /// await query?.fetch();
  /// ```
  Future<void> fetch({bool forceRefetch = false}) async {
    if (_isDisposed || options?.enabled == false) return;

    // Cancel any existing in-flight fetch
    _currentFetchToken?.cancel();
    final token = CancellationToken();
    _currentFetchToken = token;

    try {
      if (cache != null) {
        final cachedEntry = cache!.get<T>(key);

        if (cachedEntry != null && cachedEntry.isFresh && !forceRefetch) {
          final previous = _currentState;
          _updateState(QueryState.success(
            cachedEntry.data,
            dataUpdatedAt: cachedEntry.createdAt,
            isStale: false,
            hasValue: cachedEntry.hasValue,
          ));
          _notifySuccess(previous);
          return;
        }

        final shouldBackgroundRefetch =
            cachedEntry != null && (cachedEntry.isStale || forceRefetch);

        if (shouldBackgroundRefetch) {
          final previous = _currentState;
          _updateState(QueryState.success(
            cachedEntry.data,
            dataUpdatedAt: cachedEntry.createdAt,
            isFetching: true,
            isStale: !forceRefetch,
            hasValue: cachedEntry.hasValue,
          ));
          _notifySuccess(previous);

          await _fetchAndCache(
            isBackgroundRefetch: true,
            token: token,
          );
          return;
        }
      }

      final previous = _currentState;
      _updateState(_currentState.copyWith(
        status: QueryStatus.loading,
        isFetching: true,
      ));
      _notifyLoading(previous);

      await _fetchAndCache(isBackgroundRefetch: false, token: token);
    } on CancelledException {
      // Silently ignore cancellation - this is intentional
    } finally {
      // Only clear if this is still the current token
      if (_currentFetchToken == token) {
        _currentFetchToken = null;
      }
    }
  }

  Future<void> _fetchAndCache({
    required bool isBackgroundRefetch,
    required CancellationToken token,
  }) async {
    if (_isDisposed || token.isCancelled) return;

    if (cache != null) {
      try {
        if (isBackgroundRefetch) {
          final previous = _currentState;
          _updateState(_currentState.copyWith(isFetching: true));
          _notifyLoading(previous);
        }

        _lastFetchStart = FasqTime.now;

        var data = await cache!.deduplicate<T>(
          key,
          () => _executeFetch(_createQueryFn(token)),
        );
        data = await _maybeTransformData(data);

        if (_lastFetchStart != null) {
          _lastFetchDuration = FasqTime.now.difference(_lastFetchStart!);
          _fetchHistory.add(_lastFetchDuration!);

          if (options?.performance?.enableMetrics != false) {
            cache!.metrics.recordFetchTime(_lastFetchDuration!);
          }

          if (_fetchHistory.length > 100) {
            _fetchHistory.removeAt(0);
          }
        }

        if (!_isDisposed) {
          final previous = _currentState;
          final now = FasqTime.now;
          _updateState(QueryState.success(
            data,
            dataUpdatedAt: now,
            isFetching: false,
            isStale: false,
            hasValue: true,
          ));
          cache!.set<T>(
            key,
            data,
            staleTime: options?.staleTime,
            cacheTime: options?.cacheTime,
            isSecure: options?.isSecure ?? false,
            maxAge: options?.maxAge,
          );
          options?.onSuccess?.call();
          _notifySuccess(previous);
        }
      } catch (error, stackTrace) {
        // Check for cancellation
        if (error is CancelledException || token.isCancelled) {
          rethrow;
        }
        if (!_isDisposed) {
          final previous = _currentState;
          if (!isBackgroundRefetch) {
            _updateState(QueryState.error(error, stackTrace));
            _notifyError(previous);
          } else {
            _updateState(_currentState.copyWith(
              isFetching: false,
              error: error,
              stackTrace: stackTrace,
            ));
          }
          options?.onError?.call(error);
        }
        if (error is CircuitBreakerOpenException) rethrow;
      }
    } else {
      try {
        _lastFetchStart = FasqTime.now;

        var data = await _executeFetch(_createQueryFn(token));
        data = await _maybeTransformData(data);

        if (_lastFetchStart != null) {
          _lastFetchDuration = FasqTime.now.difference(_lastFetchStart!);
          _fetchHistory.add(_lastFetchDuration!);

          if (_fetchHistory.length > 100) {
            _fetchHistory.removeAt(0);
          }
        }

        if (!_isDisposed) {
          final previous = _currentState;
          _updateState(QueryState.success(
            data,
            dataUpdatedAt: FasqTime.now,
            isStale: false,
            hasValue: true,
          ));
          options?.onSuccess?.call();
          _notifySuccess(previous);
        }
      } catch (error, stackTrace) {
        // Check for cancellation
        if (error is CancelledException || token.isCancelled) {
          rethrow;
        }
        if (!_isDisposed) {
          final previous = _currentState;
          _updateState(QueryState.error(error, stackTrace));
          _notifyError(previous);
          options?.onError?.call(error);
        }
        if (error is CircuitBreakerOpenException) rethrow;
      }
    }
  }

  /// Updates query state from manually set cache data.
  ///
  /// Called by QueryClient when setQueryData is used.
  void updateFromCache(T data) {
    if (_isDisposed) return;
    _updateState(
      QueryState.success(
        data,
        isStale: false,
        hasValue: true,
      ),
    );
  }

  void _updateState(QueryState<T> newState) {
    _currentState = newState;
    if (!_controller.isClosed) {
      _controller.add(newState);
    }
  }

  QuerySnapshot<T> _snapshot(QueryState<T> previousState) {
    return QuerySnapshot<T>(
      queryKey: queryKey,
      previousState: previousState,
      currentState: _currentState,
      options: options,
    );
  }

  void _notifyLoading(QueryState<T> previousState) {
    client?.notifyQueryLoading(_snapshot(previousState), options?.meta, null);
  }

  void _notifySuccess(QueryState<T> previousState) {
    final snapshot = _snapshot(previousState);
    client?.notifyQuerySuccess(snapshot, options?.meta, null);
    client?.notifyQuerySettled(snapshot, options?.meta, null);
  }

  void _notifyError(QueryState<T> previousState) {
    final snapshot = _snapshot(previousState);
    client?.notifyQueryError(snapshot, options?.meta, null);
    client?.notifyQuerySettled(snapshot, options?.meta, null);
  }

  void _scheduleDisposal() {
    if (disposalDelay == Duration.zero) {
      if (_referenceCount == 0) {
        dispose();
      }
      return;
    }
    _disposeTimer = Timer(disposalDelay, () {
      if (_referenceCount == 0) {
        dispose();
      }
    });
  }

  void _cancelDisposal() {
    _disposeTimer?.cancel();
    _disposeTimer = null;
  }

  /// Cancels any in-flight fetch operation.
  ///
  /// This signals the query function to abort via [CancellationToken].
  /// The actual cancellation is cooperative - the query function must
  /// check [CancellationToken.isCancelled] or use [CancellationToken.onCancel]
  /// to respond to cancellation requests.
  ///
  /// Example:
  /// ```dart
  /// final query = QueryClient().getQueryByKey<User>('user');
  /// query?.cancel(); // Cancel in-flight fetch
  /// ```
  void cancel() {
    _currentFetchToken?.cancel();
    _currentFetchToken = null;
  }

  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    _disposeTimer?.cancel();
    _disposeTimer = null;

    // Cancel any in-flight fetch
    cancel();

    // Cancel all child queries (cascading cancellation)
    _cancelChildQueries();

    for (final sub in _subscriptions) {
      sub.cancel();
    }
    _subscriptions.clear();

    cache?.remove(key);

    _controller.close();
    onDispose?.call();
  }

  /// Cancels in-flight fetches of all child queries.
  ///
  /// Called during disposal to prevent dependent queries from continuing
  /// to fetch data after this parent query is no longer needed.
  void _cancelChildQueries() {
    final manager = dependencyManager;
    final queryClient = client;
    if (manager == null || queryClient == null) return;

    manager.notifyParentDisposed(key, (childKey) {
      final childQuery =
          queryClient.getQueryByKey<Object>(StringQueryKey(childKey));
      childQuery?.cancel();
    });
  }

  Future<R> _executeFetch<R>(Future<R> Function() fn) async {
    final registry = circuitBreakerRegistry ?? client?.circuitBreakerRegistry;
    CircuitBreaker? circuitBreaker;

    if (registry != null) {
      final scopeKey = options?.circuitBreakerScope ?? key;
      final breakerOptions =
          options?.circuitBreaker ?? const CircuitBreakerOptions();
      circuitBreaker = registry.getOrCreate(scopeKey, breakerOptions);

      if (!circuitBreaker.allowRequest()) {
        throw CircuitBreakerOpenException(
          'Circuit breaker is open for scope: $scopeKey',
          circuitScope: scopeKey,
        );
      }
    }

    final performance = options?.performance;
    final retries = performance?.maxRetries ?? 0;

    try {
      R result;
      if (retries <= 0) {
        result = await _runWithTimeout(fn);
      } else {
        int attempt = 0;
        Duration delay =
            performance?.initialRetryDelay ?? const Duration(seconds: 1);
        final backoff = performance?.retryBackoffMultiplier ?? 2.0;

        while (true) {
          attempt++;
          try {
            result = await _runWithTimeout(fn);
            break;
          } catch (error) {
            if (attempt > retries) {
              rethrow;
            }
            await Future.delayed(delay);
            final nextDelayMicros = (delay.inMicroseconds * backoff).round();
            delay = Duration(
              microseconds: nextDelayMicros <= 0 ? 1 : nextDelayMicros,
            );
          }
        }
      }

      if (circuitBreaker != null) {
        circuitBreaker.recordSuccess();
      }

      return result;
    } catch (error) {
      if (circuitBreaker != null) {
        final breakerOptions =
            options?.circuitBreaker ?? const CircuitBreakerOptions();
        if (!breakerOptions.isIgnored(error)) {
          circuitBreaker.recordFailure();
        }
      }
      rethrow;
    }
  }

  Future<R> _runWithTimeout<R>(Future<R> Function() fn) {
    final timeoutMs = options?.performance?.fetchTimeoutMs;
    final future = Future<R>.sync(fn);
    if (timeoutMs == null) {
      return future;
    }
    return future.timeout(
      Duration(milliseconds: timeoutMs),
      onTimeout: () {
        // Cancel the in-flight fetch on timeout
        _currentFetchToken?.cancel();
        throw TimeoutException(
          'Query fetch timed out after $timeoutMs ms',
          Duration(milliseconds: timeoutMs),
        );
      },
    );
  }

  int _estimateDataFootprint(dynamic value) {
    if (value == null) return 0;
    if (value is String) return value.length * 2;
    if (value is num) return 8;
    if (value is bool) return 1;
    if (value is List) {
      var size = 8;
      for (final item in value) {
        size += _estimateDataFootprint(item);
      }
      return size;
    }
    if (value is Map) {
      var size = 16;
      for (final entry in value.entries) {
        size += _estimateDataFootprint(entry.key);
        size += _estimateDataFootprint(entry.value);
      }
      return size;
    }
    return 64;
  }
}

class _TransformPayload<T> {
  const _TransformPayload({
    required this.data,
    required this.transformer,
  });

  final T data;
  final FutureOr<dynamic> Function(dynamic data) transformer;
}

Future<T?> _runDataTransformerTask<T>(_TransformPayload<T> payload) async {
  var result = payload.transformer(payload.data);
  if (result is Future) {
    result = await result;
  }
  if (result == null) {
    return null;
  }
  return result as T?;
}
