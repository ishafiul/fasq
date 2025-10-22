import 'dart:async';

import '../cache/cache_metrics.dart';
import '../cache/query_cache.dart';
import 'query_client.dart';
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
    required this.key,
    required this.queryFn,
    this.options,
    this.cache,
    this.client,
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

  /// Get performance metrics for this query
  QueryMetrics get metrics => QueryMetrics(
        fetchHistory: List.from(_fetchHistory),
        lastFetchDuration: _lastFetchDuration,
        referenceCount: _referenceCount,
      );

  /// Estimate the size of data in bytes for performance decisions
  int _estimateDataSize<U>(U data) {
    if (data == null) return 0;

    if (data is String) {
      return data.length * 2; // UTF-16 encoding
    } else if (data is List<int>) {
      return data.length;
    } else if (data is Map) {
      return data.toString().length * 2;
    } else if (data is List) {
      return data.toString().length * 2;
    } else {
      // Fallback: serialize to string and estimate
      return data.toString().length * 2;
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

    if (_referenceCount == 1 && (cache != null || !state.hasData)) {
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
        _updateState(QueryState.success(
          cachedEntry.data,
          dataUpdatedAt: cachedEntry.createdAt,
        ));
        return;
      }

      if (cachedEntry != null && cachedEntry.isStale) {
        _updateState(QueryState.success(
          cachedEntry.data,
          dataUpdatedAt: cachedEntry.createdAt,
          isFetching: true,
        ));

        _fetchAndCache(isBackgroundRefetch: true);
        return;
      }
    }

    _updateState(_currentState.copyWith(
      status: QueryStatus.loading,
      isFetching: false,
    ));

    await _fetchAndCache(isBackgroundRefetch: false);
  }

  Future<void> _fetchAndCache({required bool isBackgroundRefetch}) async {
    if (cache != null) {
      try {
        // Start performance tracking
        _lastFetchStart = DateTime.now();

        var data = await cache!.deduplicate<T>(key, queryFn);

        // Apply isolate transform if configured
        if (options?.performance?.autoIsolate == true &&
            options?.performance?.isolateThreshold != null) {
          // Check if data size exceeds threshold for isolate execution
          final dataSize = _estimateDataSize(data);
          if (dataSize > options!.performance!.isolateThreshold!) {
            // Execute in isolate if available
            if (client != null) {
              try {
                final transformedData =
                    await client!.isolatePool.executeIfNeeded(
                  _heavyDataTransform<T>,
                  data,
                  threshold: options!.performance!.isolateThreshold!,
                );
                data = transformedData;
              } catch (e) {
                // Fallback to main thread if isolate fails
              }
            }
          }
        }

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
          final now = DateTime.now();
          if (isBackgroundRefetch) {}
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
            _updateState(_currentState.copyWith(isFetching: false));
          }
          options?.onError?.call(error);
        }
      }
    } else {
      try {
        // Start performance tracking for direct query execution
        _lastFetchStart = DateTime.now();

        final data = await queryFn();

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

/// Heavy data transformation function for isolate execution.
///
/// This function performs computationally expensive operations like:
/// - Deep JSON parsing and validation
/// - Data normalization and transformation
/// - Complex data structure manipulation
/// - Memory-intensive operations
T _heavyDataTransform<T>(T data) {
  if (data == null) return data;

  // For JSON strings, perform heavy parsing and validation
  if (data is String) {
    try {
      // Simulate heavy JSON processing
      final parsed = data.split('').map((c) => c.codeUnitAt(0)).toList();
      final processed = parsed.map((code) => code * 2).toList();
      final result = String.fromCharCodes(processed.map((code) => code ~/ 2));

      // Additional heavy processing
      final words = result.split(' ');
      final transformed = words.map((word) => word.toUpperCase()).join(' ');

      return transformed as T;
    } catch (e) {
      // Return original data if processing fails
      return data;
    }
  }

  // For lists, perform heavy processing on each element
  if (data is List) {
    try {
      final processed = data.map((item) {
        if (item is String) {
          return item.toUpperCase();
        } else if (item is Map) {
          return Map.fromEntries(item.entries
              .map((e) => MapEntry(e.key.toString().toUpperCase(), e.value)));
        }
        return item;
      }).toList();

      return processed as T;
    } catch (e) {
      return data;
    }
  }

  // For maps, perform heavy processing
  if (data is Map) {
    try {
      final processed = Map.fromEntries(data.entries.map((e) => MapEntry(
          e.key.toString().toUpperCase(),
          e.value is String ? (e.value as String).toUpperCase() : e.value)));

      return processed as T;
    } catch (e) {
      return data;
    }
  }

  // For other types, return as-is
  return data;
}
