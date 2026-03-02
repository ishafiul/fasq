import 'package:fasq/src/cache/cache_entry.dart';
import 'package:fasq/src/cache/query_cache.dart';
import 'package:fasq/src/internal/validation/input_validator.dart';
import 'package:fasq/src/query/cancellation/cancellation_token.dart';
import 'package:fasq/src/query/dependency/query_dependency_manager.dart';
import 'package:fasq/src/query/infinite/infinite_query.dart';
import 'package:fasq/src/query/infinite/infinite_query_options.dart';
import 'package:fasq/src/query/keys/query_key.dart';
import 'package:fasq/src/query/query.dart';
import 'package:fasq/src/query/query_options.dart';
import 'package:flutter/foundation.dart';

/// Factory used by [QueryClientRegistry] to create [Query] instances.
typedef QueryClientQueryFactory = Query<T> Function<T>({
  required QueryKey queryKey,
  required QueryDependencyManager dependencyManager,
  required void Function() onDispose,
  Future<T> Function()? queryFn,
  Future<T> Function(CancellationToken token)? queryFnWithToken,
  QueryOptions? options,
  CacheEntry<T>? initialEntry,
});

/// Owns in-memory query registries and related lifecycle operations.
final class QueryClientRegistry {
  /// Creates a query registry.
  QueryClientRegistry({
    required QueryCache cache,
    required QueryClientQueryFactory queryFactory,
  })  : _cache = cache,
        _queryFactory = queryFactory;

  final QueryCache _cache;
  final QueryClientQueryFactory _queryFactory;
  final QueryDependencyManager _dependencyManager = QueryDependencyManager();
  final Map<String, Query<Object?>> _queries = <String, Query<Object?>>{};
  final Map<String, InfiniteQuery<Object?, Object?>> _infiniteQueries =
      <String, InfiniteQuery<Object?, Object?>>{};

  /// Returns registered standard queries keyed by query key string.
  Map<String, Query<Object?>> get queries => _queries;

  /// Returns registered infinite queries keyed by query key string.
  Map<String, InfiniteQuery<Object?, Object?>> get infiniteQueries =>
      _infiniteQueries;

  /// Gets an existing query or creates a new one.
  Query<T> getQuery<T>(
    QueryKey queryKey, {
    Future<T> Function()? queryFn,
    Future<T> Function(CancellationToken token)? queryFnWithToken,
    QueryOptions? options,
    QueryKey? dependsOn,
  }) {
    assert(
      queryFn != null || queryFnWithToken != null,
      'Either queryFn or queryFnWithToken must be provided',
    );

    final key = queryKey.key;
    InputValidator.validateQueryKey(key);
    if (options != null) {
      InputValidator.validateOptions(options);
    }

    final existingQuery = _queries[key];
    if (existingQuery != null) {
      final existing = existingQuery as Query<T>;
      if (!existing.isDisposed) {
        return existing;
      }
      _queries.remove(key);
    }

    if (dependsOn != null) {
      final parentKey = dependsOn.key;
      _dependencyManager.registerDependency(key, parentKey);
    }

    final cachedEntry = _cache.get<T>(key);

    final query = _queryFactory<T>(
      queryKey: queryKey,
      queryFn: queryFn,
      queryFnWithToken: queryFnWithToken,
      options: options,
      dependencyManager: _dependencyManager,
      onDispose: () {
        _queries.remove(key);
        _dependencyManager.unregister(key);
      },
      initialEntry: cachedEntry,
    );

    _queries[key] = query as Query<Object?>;
    return query;
  }

  /// Gets an existing infinite query or creates a new one.
  InfiniteQuery<TData, TParam> getInfiniteQuery<TData, TParam>(
    QueryKey queryKey,
    Future<TData> Function(TParam param) queryFn, {
    InfiniteQueryOptions<TData, TParam>? options,
  }) {
    final key = queryKey.key;
    final existingQuery = _infiniteQueries[key];
    if (existingQuery != null) {
      final existing = existingQuery as InfiniteQuery<TData, TParam>;
      if (!existing.isDisposed) {
        return existing;
      }
      _infiniteQueries.remove(key);
    }

    final infinite = InfiniteQuery<TData, TParam>(
      queryKey: queryKey,
      queryFn: queryFn,
      options: options,
      cache: _cache,
      onDispose: () {
        _infiniteQueries.remove(key);
      },
    );

    _infiniteQueries[key] = infinite as InfiniteQuery<Object?, Object?>;
    return infinite;
  }

  /// Retrieves an existing query by key.
  Query<T>? getQueryByKey<T>(QueryKey queryKey) {
    final key = queryKey.key;
    InputValidator.validateQueryKey(key);
    return _queries[key] as Query<T>?;
  }

  /// Retrieves an existing infinite query by key.
  InfiniteQuery<TData, TParam>? getInfiniteQueryByKey<TData, TParam>(
    QueryKey queryKey,
  ) {
    final key = queryKey.key;
    return _infiniteQueries[key] as InfiniteQuery<TData, TParam>?;
  }

  /// Removes and disposes a query by key.
  void removeQuery(QueryKey queryKey) {
    final key = queryKey.key;
    InputValidator.validateQueryKey(key);
    final query = _queries.remove(key);
    query?.dispose();
  }

  /// Removes and disposes an infinite query by key.
  void removeInfiniteQuery(QueryKey queryKey) {
    final key = queryKey.key;
    final query = _infiniteQueries.remove(key);
    query?.dispose();
  }

  /// Removes and disposes all queries and clears the cache.
  void clear() {
    final queriesToDispose = _queries.values.toList();
    final infiniteToDispose = _infiniteQueries.values.toList();
    _queries.clear();
    _infiniteQueries.clear();

    for (final query in queriesToDispose) {
      query.dispose();
    }
    for (final query in infiniteToDispose) {
      query.dispose();
    }

    _cache.clear();
  }

  /// Returns current count of registered standard queries.
  int get queryCount => _queries.length;

  /// Returns whether a standard query with [queryKey] exists.
  bool hasQuery(QueryKey queryKey) {
    final key = queryKey.key;
    return _queries.containsKey(key);
  }

  /// Returns debug info for active queries in debug mode.
  Iterable<QueryDebugInfo> get activeQueryDebugInfo {
    if (!kDebugMode) {
      return const <QueryDebugInfo>[];
    }
    return _queries.values
        .map((query) => query.debugInfo)
        .whereType<QueryDebugInfo>();
  }

  /// Returns debug info map for active queries in debug mode.
  Map<String, QueryDebugInfo> get activeQueryDebugInfoMap {
    if (!kDebugMode) {
      return const <String, QueryDebugInfo>{};
    }
    final map = <String, QueryDebugInfo>{};
    for (final entry in _queries.entries) {
      final debugInfo = entry.value.debugInfo;
      if (debugInfo != null) {
        map[entry.key] = debugInfo;
      }
    }
    return map;
  }
}
