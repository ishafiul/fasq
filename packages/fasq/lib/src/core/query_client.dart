import 'dart:async';

import 'package:flutter/widgets.dart';

import '../cache/cache_config.dart';
import '../cache/cache_metrics.dart';
import '../cache/query_cache.dart';
import '../performance/isolate_pool.dart';
import '../persistence/persistence_options.dart';
import 'query.dart';
import 'query_options.dart';
import 'infinite_query.dart';
import 'infinite_query_options.dart';
import 'prefetch_config.dart';
import 'validation/input_validator.dart';

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
class QueryClient with WidgetsBindingObserver {
  static QueryClient? _instance;

  /// Returns the singleton instance of [QueryClient].
  factory QueryClient({
    CacheConfig? config,
    PersistenceOptions? persistenceOptions,
  }) {
    _instance ??= QueryClient._internal(
      config: config,
      persistenceOptions: persistenceOptions,
    );
    return _instance!;
  }

  QueryClient._internal({
    CacheConfig? config,
    PersistenceOptions? persistenceOptions,
  }) : _cache = QueryCache(
          config: config,
          persistenceOptions: persistenceOptions,
        ) {
    WidgetsBinding.instance.addObserver(this);
    _isolatePool =
        IsolatePool(poolSize: config?.performance.isolatePoolSize ?? 2);
  }

  final Map<String, Query> _queries = {};
  final Map<String, InfiniteQuery> _infiniteQueries = {};
  final QueryCache _cache;
  late final IsolatePool _isolatePool;

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
    InputValidator.validateQueryKey(key);
    if (options != null) {
      InputValidator.validateOptions(options);
    }

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
      client: this,
      onDispose: () {
        _queries.remove(key);
        // Don't clear cache on disposal - let cacheTime handle cleanup
      },
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
      onDispose: () {
        _infiniteQueries.remove(key);
        // Don't clear cache on disposal - let cacheTime handle cleanup
      },
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
    InputValidator.validateQueryKey(key);
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
    InputValidator.validateQueryKey(key);
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

  /// The isolate pool for heavy computation tasks.
  IsolatePool get isolatePool => _isolatePool;

  /// Invalidates a single query by key.
  ///
  /// Removes the cache entry and triggers refetch if the query is active.
  void invalidateQuery(String key) {
    InputValidator.validateQueryKey(key);
    _cache.invalidate(key);
    final query = _queries[key];
    if (query != null && query.referenceCount > 0) {
      query.fetch();
    }
  }

  /// Invalidates multiple queries atomically
  void invalidateQueries(List<String> keys) {
    for (final key in keys) {
      invalidateQuery(key);
    }
  }

  /// Invalidates queries matching condition
  void invalidateQueriesWhere(bool Function(String key) predicate) {
    final keysToInvalidate = _queries.keys.where(predicate).toList();
    invalidateQueries(keysToInvalidate);
  }

  /// Invalidates multiple queries by keys.

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
  void invalidateQueriesWherePredicate(bool Function(String key) predicate) {
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
  void setQueryData<T>(String key, T data,
      {bool isSecure = false, Duration? maxAge}) {
    InputValidator.validateQueryKey(key);
    InputValidator.validateCacheData(data);
    if (maxAge != null) {
      InputValidator.validateDuration(maxAge, 'maxAge');
    }

    _cache.setData<T>(key, data, isSecure: isSecure, maxAge: maxAge);

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

  /// Clears all secure cache entries.
  ///
  /// Removes only entries marked as secure, leaving non-secure entries intact.
  /// Useful for security-sensitive scenarios like logout or app backgrounding.
  void clearSecureCache() {
    _cache.clearSecureEntries();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        // Clear secure entries when app goes to background or is terminated
        clearSecureCache();
        break;
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        // No action needed for these states
        break;
    }
  }

  /// Disposes the query client and cache.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    clear();
    _cache.dispose();
    _isolatePool.dispose();
  }

  /// Resets the singleton instance for testing.
  ///
  /// Only use this in tests to get a fresh instance.
  static void resetForTesting() {
    _instance?.dispose();
    _instance = null;
  }
}
