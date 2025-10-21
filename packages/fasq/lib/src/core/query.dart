import 'dart:async';

import '../cache/query_cache.dart';
import 'query_options.dart';
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
  final String key;

  /// The async function that fetches the data.
  final Future<T> Function() queryFn;

  /// Optional configuration for this query.
  final QueryOptions? options;

  /// The cache instance for storing results.
  final QueryCache? cache;

  /// Callback when query is disposed (for cleanup in QueryClient).
  final void Function()? onDispose;

  QueryState<T> _currentState;
  late final StreamController<QueryState<T>> _controller;
  int _referenceCount = 0;
  Timer? _disposeTimer;
  bool _isDisposed = false;

  Query({
    required this.key,
    required this.queryFn,
    this.options,
    this.cache,
    this.onDispose,
    T? initialData,
  }) : _currentState = initialData != null
            ? QueryState<T>.success(initialData)
            : QueryState<T>.idle() {
    _controller = StreamController<QueryState<T>>.broadcast();
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

    if (_referenceCount == 1 && (cache != null || !state.hasData)) {
      print('🔍 [flutter_query] fetch() triggered on addListener for "$key"');
      print('   cache != null: ${cache != null}, hasData: ${state.hasData}');
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

    _referenceCount--;
    if (_referenceCount == 0) {
      _scheduleDisposal();
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
        print('✅ [flutter_query] Serving FRESH data for "$key"');
        _updateState(QueryState.success(
          cachedEntry.data,
          dataUpdatedAt: cachedEntry.createdAt,
        ));
        return;
      }

      if (cachedEntry != null && cachedEntry.isStale) {
        final age = DateTime.now().difference(cachedEntry.createdAt);
        print('🔄 [flutter_query] Serving STALE data for "$key"');
        print(
            '   Age: ${age.inSeconds}s, StaleTime: ${cachedEntry.staleTime.inSeconds}s');
        print('   Setting isFetching = true');
        _updateState(QueryState.success(
          cachedEntry.data,
          dataUpdatedAt: cachedEntry.createdAt,
          isFetching: true,
        ));

        _fetchAndCache(isBackgroundRefetch: true);
        return;
      }
    }

    print('⏳ [flutter_query] No cache, loading for "$key"');
    _updateState(_currentState.copyWith(
      status: QueryStatus.loading,
      isFetching: false,
    ));

    await _fetchAndCache(isBackgroundRefetch: false);
  }

  Future<void> _fetchAndCache({required bool isBackgroundRefetch}) async {
    if (cache != null) {
      try {
        final data = await cache!.deduplicate<T>(key, queryFn);
        if (!_isDisposed) {
          final now = DateTime.now();
          if (isBackgroundRefetch) {
            print('✨ [flutter_query] Background refetch complete for "$key"');
            print('   Setting isFetching = false');
          }
          _updateState(QueryState.success(
            data,
            dataUpdatedAt: now,
            isFetching: false,
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
        }
      } catch (error, stackTrace) {
        if (!_isDisposed) {
          if (!isBackgroundRefetch) {
            _updateState(QueryState.error(error, stackTrace));
          } else {
            print('❌ [flutter_query] Background refetch failed for "$key"');
            _updateState(_currentState.copyWith(isFetching: false));
          }
          options?.onError?.call(error);
        }
      }
    } else {
      try {
        final data = await queryFn();
        if (!_isDisposed) {
          _updateState(QueryState.success(
            data,
            dataUpdatedAt: DateTime.now(),
          ));
          options?.onSuccess?.call();
        }
      } catch (error, stackTrace) {
        if (!_isDisposed) {
          _updateState(QueryState.error(error, stackTrace));
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
    _updateState(QueryState.success(data));
  }

  void _updateState(QueryState<T> newState) {
    _currentState = newState;
    if (!_controller.isClosed) {
      _controller.add(newState);
    }
  }

  void _scheduleDisposal() {
    _disposeTimer = Timer(const Duration(seconds: 5), () {
      if (_referenceCount == 0) {
        print('🗑️ [flutter_query] Disposing query "$key" after 5s timeout');
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
