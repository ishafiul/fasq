import 'dart:async';

import '../cache/cache_metrics.dart';
import '../cache/query_cache.dart';
import 'query_client.dart';
import 'query_key.dart';
import 'query_options.dart';
import 'query_snapshot.dart';
import 'query_state.dart';
import 'query_status.dart';

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
  final Future<T> Function() queryFn;

  /// Optional configuration for this query.
  final QueryOptions? options;

  /// The cache instance for storing results.
  final QueryCache? cache;

  /// The query client instance for accessing isolate pool
  final QueryClient? client;

  /// Callback when query is disposed (for cleanup in QueryClient).
  final void Function()? onDispose;

  QueryState<T> _currentState;
  late final StreamController<QueryState<T>> _controller;
  int _referenceCount = 0;
  Timer? _disposeTimer;
  bool _isDisposed = false;

  // Performance tracking fields
  DateTime? _lastFetchStart;
  Duration? _lastFetchDuration;
  final List<Duration> _fetchHistory = [];

  Query({
    required this.queryKey,
    required this.queryFn,
    this.options,
    this.cache,
    this.client,
    this.onDispose,
    T? initialData,
  })  : key = queryKey.key,
        _currentState = QueryState<T>.idle() {
    _controller = StreamController<QueryState<T>>.broadcast();

    // Set initial state based on initialData and cache staleness
    _currentState = _createInitialState(initialData);

    // If no initial data and no cached data, start in loading state
    if (initialData == null && cache != null && cache!.get<T>(key) == null) {
      _currentState = QueryState<T>.loading();
    }
  }

  /// Creates the initial state, checking cache staleness if initialData is provided
  QueryState<T> _createInitialState(T? initialData) {
    if (initialData == null) {
      return QueryState<T>.idle();
    }

    // If we have initialData, it came from cache, so we need to check staleness
    if (cache != null) {
      final cachedEntry = cache!.get<T>(key);
      if (cachedEntry != null) {
        return QueryState<T>.success(
          initialData,
          dataUpdatedAt: cachedEntry.createdAt,
          isStale: cachedEntry.isStale,
        );
      }
    }

    // Fallback to fresh data if no cache entry found
    return QueryState<T>.success(initialData);
  }

  /// Stream of state changes for this query.
  ///
  /// Subscribe to this stream to receive updates when the query state changes.
  Stream<QueryState<T>> get stream => _controller.stream;

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

  Future<T> _maybeTransformData(T data) async {
    final performance = options?.performance;
    if (performance == null || !performance.enableDataTransform) {
      return data;
    }

    final transformer = performance.dataTransformer;
    if (transformer == null) {
      return data;
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

    if (_referenceCount == 1 && !state.hasData) {
      fetch();
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
  Future<void> fetch() async {
    if (_isDisposed || options?.enabled == false) return;

    if (cache != null) {
      final cachedEntry = cache!.get<T>(key);

      if (cachedEntry != null && cachedEntry.isFresh) {
        final previous = _currentState;
        _updateState(QueryState.success(
          cachedEntry.data,
          dataUpdatedAt: cachedEntry.createdAt,
          isStale: false,
        ));
        _notifySuccess(previous);
        return;
      }

      if (cachedEntry != null && cachedEntry.isStale) {
        final previous = _currentState;
        _updateState(QueryState.success(
          cachedEntry.data,
          dataUpdatedAt: cachedEntry.createdAt,
          isFetching: true,
          isStale: true,
        ));
        _notifySuccess(previous);

        _fetchAndCache(isBackgroundRefetch: true);
        return;
      }
    }

    final previous = _currentState;
    _updateState(_currentState.copyWith(
      status: QueryStatus.loading,
      isFetching: false,
    ));
    _notifyLoading(previous);

    await _fetchAndCache(isBackgroundRefetch: false);
  }

  Future<void> _fetchAndCache({required bool isBackgroundRefetch}) async {
    if (cache != null) {
      try {
        // Emit state update for background refetch to show isFetching: true
        if (isBackgroundRefetch) {
          final previous = _currentState;
          _updateState(_currentState.copyWith(isFetching: true));
          _notifyLoading(previous);
        }

        // Start performance tracking
        _lastFetchStart = DateTime.now();

        var data = await cache!.deduplicate<T>(key, queryFn);
        data = await _maybeTransformData(data);

        // Record fetch timing
        if (_lastFetchStart != null) {
          _lastFetchDuration = DateTime.now().difference(_lastFetchStart!);
          _fetchHistory.add(_lastFetchDuration!);

          // Record timing in cache metrics if performance tracking is enabled
          if (options?.performance?.enableMetrics != false) {
            cache!.metrics.recordFetchTime(_lastFetchDuration!);
          }

          // Keep only last 100 fetch times to prevent memory growth
          if (_fetchHistory.length > 100) {
            _fetchHistory.removeAt(0);
          }
        }
        if (!_isDisposed) {
          final previous = _currentState;
          final now = DateTime.now();
          _updateState(QueryState.success(
            data,
            dataUpdatedAt: now,
            isFetching: false,
            isStale: false, // Fresh data after successful fetch
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
        if (!_isDisposed) {
          final previous = _currentState;
          if (!isBackgroundRefetch) {
            _updateState(QueryState.error(error, stackTrace));
            _notifyError(previous);
          } else {
            _updateState(_currentState.copyWith(isFetching: false));
          }
          options?.onError?.call(error);
        }
      }
    } else {
      try {
        // Start performance tracking for direct query execution
        _lastFetchStart = DateTime.now();

        var data = await queryFn();
        data = await _maybeTransformData(data);

        // Record fetch timing
        if (_lastFetchStart != null) {
          _lastFetchDuration = DateTime.now().difference(_lastFetchStart!);
          _fetchHistory.add(_lastFetchDuration!);

          // Keep only last 100 fetch times to prevent memory growth
          if (_fetchHistory.length > 100) {
            _fetchHistory.removeAt(0);
          }
        }
        if (!_isDisposed) {
          final previous = _currentState;
          _updateState(QueryState.success(
            data,
            dataUpdatedAt: DateTime.now(),
            isStale: false, // Fresh data after successful fetch
          ));
          options?.onSuccess?.call();
          _notifySuccess(previous);
        }
      } catch (error, stackTrace) {
        if (!_isDisposed) {
          final previous = _currentState;
          _updateState(QueryState.error(error, stackTrace));
          _notifyError(previous);
          options?.onError?.call(error);
        }
      }
    }
  }

  /// Updates query state from manually set cache data.
  ///
  /// Called by QueryClient when setQueryData is used.
  void updateFromCache(T data) {
    if (_isDisposed) return;
    _updateState(QueryState.success(data, isStale: false));
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
