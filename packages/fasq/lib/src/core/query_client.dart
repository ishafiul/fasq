import '../cache/cache_config.dart';
import '../cache/cache_metrics.dart';
import '../cache/query_cache.dart';
import 'query.dart';
import 'query_options.dart';
import 'infinite_query.dart';
import 'infinite_query_options.dart';
import 'prefetch_config.dart';

/// Global registry for all queries in the application.
///
/// [QueryClient] is a singleton that manages the lifecycle of all queries.
/// It creates queries on-demand, ensures queries with the same key are shared,
/// handles cleanup, and manages the cache.
///
/// Access the singleton instance using `QueryClient()`.
///
/// Example:
/// ```dart
/// final client = QueryClient();
/// final query = client.getQuery<User>('user', () => fetchUser());
///
/// // Later, retrieve the same query
/// final sameQuery = client.getQueryByKey<User>('user');
/// ```
class QueryClient {
  static QueryClient? _instance;

  /// Returns the singleton instance of [QueryClient].
  factory QueryClient({CacheConfig? config}) {
    _instance ??= QueryClient._internal(config: config);
    return _instance!;
  }

  QueryClient._internal({CacheConfig? config})
      : _cache = QueryCache(config: config);

  final Map<String, Query> _queries = {};
  final Map<String, InfiniteQuery> _infiniteQueries = {};
  final QueryCache _cache;

  /// Gets an existing query or creates a new one.
  ///
  /// If a query with the given [key] already exists, returns that query.
  /// Otherwise, creates a new query with the provided [queryFn] and [options].
  ///
  /// Multiple calls with the same [key] return the same [Query] instance,
  /// enabling query sharing across widgets.
  ///
  /// Example:
  /// ```dart
  /// final query = client.getQuery<List<User>>(
  ///   'users',
  ///   () => api.fetchUsers(),
  ///   options: QueryOptions(enabled: true),
  /// );
  /// ```
  Query<T> getQuery<T>(
    String key,
    Future<T> Function() queryFn, {
    QueryOptions? options,
  }) {
    if (_queries.containsKey(key)) {
      final existing = _queries[key]! as Query<T>;
      if (!existing.isDisposed) {
        return existing;
      }
      _queries.remove(key);
    }

    final cachedEntry = _cache.get<T>(key);

    final query = Query<T>(
      key: key,
      queryFn: queryFn,
      options: options,
      cache: _cache,
      onDispose: () => _queries.remove(key),
      initialData: cachedEntry?.data,
    );

    _queries[key] = query;
    return query;
  }

  InfiniteQuery<TData, TParam> getInfiniteQuery<TData, TParam>(
    String key,
    Future<TData> Function(TParam param) queryFn, {
    InfiniteQueryOptions<TData, TParam>? options,
  }) {
    if (_infiniteQueries.containsKey(key)) {
      final existing = _infiniteQueries[key]! as InfiniteQuery<TData, TParam>;
      if (!existing.isDisposed) {
        return existing;
      }
      _infiniteQueries.remove(key);
    }

    final infinite = InfiniteQuery<TData, TParam>(
      key: key,
      queryFn: queryFn,
      options: options,
      cache: _cache,
      onDispose: () => _infiniteQueries.remove(key),
    );

    _infiniteQueries[key] = infinite;
    return infinite;
  }

  /// Retrieves an existing query by its key, or null if not found.
  ///
  /// Unlike [getQuery], this does not create a new query if one doesn't exist.
  ///
  /// Example:
  /// ```dart
  /// final query = client.getQueryByKey<User>('user');
  /// if (query != null) {
  ///   await query.fetch();
  /// }
  /// ```
  Query<T>? getQueryByKey<T>(String key) {
    return _queries[key] as Query<T>?;
  }

  InfiniteQuery<TData, TParam>? getInfiniteQueryByKey<TData, TParam>(
      String key) {
    return _infiniteQueries[key] as InfiniteQuery<TData, TParam>?;
  }

  /// Removes and disposes a query by its key.
  ///
  /// The query is immediately disposed and removed from the registry.
  void removeQuery(String key) {
    final query = _queries.remove(key);
    query?.dispose();
  }

  void removeInfiniteQuery(String key) {
    final query = _infiniteQueries.remove(key);
    query?.dispose();
  }

  /// Removes and disposes all queries.
  ///
  /// All queries are immediately disposed and the registry is cleared.
  /// Useful for cleanup or testing.
  void clear() {
    final queriesToDispose = _queries.values.toList();
    final infiniteToDispose = _infiniteQueries.values.toList();
    _queries.clear();
    _infiniteQueries.clear();
    for (final query in queriesToDispose) {
      query.dispose();
    }
    for (final iq in infiniteToDispose) {
      iq.dispose();
    }
    _cache.clear();
  }

  /// The number of queries currently in the registry.
  int get queryCount => _queries.length;

  /// Whether a query with the given [key] exists.
  bool hasQuery(String key) => _queries.containsKey(key);

  /// Gets the underlying query cache instance.
  ///
  /// Useful for direct cache access in tests or advanced use cases.
  QueryCache get cache => _cache;

  /// Invalidates a single query by key.
  ///
  /// Removes the cache entry and triggers refetch if the query is active.
  void invalidateQuery(String key) {
    _cache.invalidate(key);
    final query = _queries[key];
    if (query != null && query.referenceCount > 0) {
      query.fetch();
    }
  }

  /// Invalidates multiple queries by keys.
  void invalidateQueries(List<String> keys) {
    for (final key in keys) {
      invalidateQuery(key);
    }
  }

  /// Invalidates all queries with keys starting with the prefix.
  ///
  /// Example: `invalidateQueriesWithPrefix('user:')` invalidates
  /// 'user:123', 'user:456', etc.
  void invalidateQueriesWithPrefix(String prefix) {
    _cache.invalidateWithPrefix(prefix);

    final affectedKeys =
        _queries.keys.where((key) => key.startsWith(prefix)).toList();

    for (final key in affectedKeys) {
      final query = _queries[key];
      if (query != null && query.referenceCount > 0) {
        query.fetch();
      }
    }
  }

  /// Prefetches a query and populates the cache without creating a persistent query.
  ///
  /// Useful for warming the cache before navigation or when hovering over links.
  /// The query executes in the background and the result is cached but no
  /// loading state is exposed to the UI.
  ///
  /// If the cache already contains fresh data for the given key, the prefetch
  /// is skipped to avoid unnecessary network requests.
  ///
  /// Example:
  /// ```dart
  /// await queryClient.prefetchQuery('users', () => api.fetchUsers());
  /// // Later when the actual query mounts, it uses cached data
  /// ```
  Future<void> prefetchQuery<T>(
    String key,
    Future<T> Function() queryFn, {
    QueryOptions? options,
  }) async {
    final cachedEntry = _cache.get<T>(key);

    if (cachedEntry != null && cachedEntry.isFresh) {
      return;
    }

    final query = Query<T>(
      key: key,
      queryFn: queryFn,
      options: options,
      cache: _cache,
    );

    try {
      await query.fetch();
    } finally {
      query.dispose();
    }
  }

  /// Prefetches multiple queries in parallel.
  ///
  /// Executes all prefetch operations concurrently for better performance.
  /// Each query is prefetched independently, and failures in one query
  /// do not affect others.
  ///
  /// Example:
  /// ```dart
  /// await queryClient.prefetchQueries([
  ///   PrefetchConfig(key: 'users', queryFn: () => api.fetchUsers()),
  ///   PrefetchConfig(key: 'posts', queryFn: () => api.fetchPosts()),
  ///   PrefetchConfig(key: 'comments', queryFn: () => api.fetchComments()),
  /// ]);
  /// ```
  Future<void> prefetchQueries(
    List<PrefetchConfig> configs,
  ) async {
    await Future.wait(
      configs.map((config) => prefetchQuery(
            config.key,
            config.queryFn,
            options: config.options,
          )),
    );
  }

  /// Invalidates queries matching the predicate.
  ///
  /// Example: `invalidateQueriesWhere((key) => key.contains('stale'))`
  void invalidateQueriesWhere(bool Function(String key) predicate) {
    _cache.invalidateWhere(predicate);

    final affectedKeys = _queries.keys.where(predicate).toList();

    for (final key in affectedKeys) {
      final query = _queries[key];
      if (query != null && query.referenceCount > 0) {
        query.fetch();
      }
    }
  }

  /// Manually sets data in the cache.
  ///
  /// Useful for optimistic updates or pre-populating cache.
  void setQueryData<T>(String key, T data) {
    _cache.setData<T>(key, data);

    final query = _queries[key];
    if (query != null) {
      query.updateFromCache(data);
    }
  }

  /// Gets cached data for a query key.
  ///
  /// Returns null if not cached.
  T? getQueryData<T>(String key) {
    return _cache.getData<T>(key);
  }

  /// Gets cache information for monitoring and debugging.
  CacheInfo getCacheInfo() {
    return _cache.getCacheInfo();
  }

  /// Gets all cache keys.
  List<String> getCacheKeys() {
    return _cache.getCacheKeys();
  }

  /// Disposes the query client and cache.
  void dispose() {
    clear();
    _cache.dispose();
  }

  /// Resets the singleton instance for testing.
  ///
  /// Only use this in tests to get a fresh instance.
  static void resetForTesting() {
    _instance?.dispose();
    _instance = null;
  }
}
