import 'dart:async';

import 'package:fasq/src/cache/cache_metrics.dart';
import 'package:fasq/src/cache/query_cache.dart';
import 'package:fasq/src/client/internal/query_client_registry.dart';
import 'package:fasq/src/internal/validation/input_validator.dart';
import 'package:fasq/src/query/keys/query_key.dart';
import 'package:fasq/src/query/prefetch/prefetch_config.dart';
import 'package:fasq/src/query/query.dart';
import 'package:fasq/src/query/query_options.dart';

/// Encapsulates cache-focused operations for `QueryClient`.
final class QueryClientCacheOps {
  /// Creates cache operations helper.
  QueryClientCacheOps({
    required QueryCache cache,
    required QueryClientRegistry registry,
  })  : _cache = cache,
        _registry = registry;

  final QueryCache _cache;
  final QueryClientRegistry _registry;

  /// Invalidates a single query by key.
  void invalidateQuery(QueryKey queryKey) {
    final key = queryKey.key;
    InputValidator.validateQueryKey(key);
    _cache.invalidate(key);
    _refetchActiveQueries(<String>[key]);
  }

  /// Invalidates multiple queries by keys.
  void invalidateQueries(List<QueryKey> queryKeys) {
    queryKeys.forEach(invalidateQuery);
  }

  /// Invalidates queries matching a key predicate.
  void invalidateQueriesWhere(bool Function(String key) predicate) {
    final keysToInvalidate = _registry.queries.keys
        .where(predicate)
        .map(StringQueryKey.new)
        .toList();
    invalidateQueries(keysToInvalidate);
  }

  /// Invalidates all queries with keys starting with [prefix].
  void invalidateQueriesWithPrefix(String prefix) {
    _cache.invalidateWithPrefix(prefix);
    final affectedKeys =
        _registry.queries.keys.where((key) => key.startsWith(prefix));
    _refetchActiveQueries(affectedKeys);
  }

  /// Invalidates queries matching [predicate].
  void invalidateQueriesWherePredicate(bool Function(String key) predicate) {
    _cache.invalidateWhere(predicate);
    final affectedKeys = _registry.queries.keys.where(predicate);
    _refetchActiveQueries(affectedKeys);
  }

  /// Prefetches a query and populates cache without persistent registration.
  Future<void> prefetchQuery<T>(
    QueryKey queryKey,
    Future<T> Function() queryFn, {
    QueryOptions? options,
  }) async {
    final key = queryKey.key;
    final cachedEntry = _cache.get<T>(key);
    if (cachedEntry != null && cachedEntry.isFresh) {
      return;
    }

    final query = Query<T>(
      queryKey: queryKey,
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
  Future<void> prefetchQueries<T>(
    List<PrefetchConfig<T>> configs,
  ) async {
    await Future.wait(
      configs.map(
        (config) => prefetchQuery(
          config.queryKey,
          config.queryFn,
          options: config.options,
        ),
      ),
    );
  }

  /// Sets data in cache and updates an active query state if present.
  void setQueryData<T>(
    QueryKey queryKey,
    T data, {
    bool isSecure = false,
    Duration? maxAge,
  }) {
    final key = queryKey.key;
    InputValidator.validateQueryKey(key);
    InputValidator.validateCacheData(data);
    if (maxAge != null) {
      InputValidator.validateDuration(maxAge, 'maxAge');
    }
    if (isSecure && maxAge == null) {
      throw ArgumentError(
        'Secure cache entries must specify maxAge for TTL enforcement',
      );
    }

    _cache.setData<T>(key, data, isSecure: isSecure, maxAge: maxAge);

    final query = _registry.queries[key];
    if (query != null) {
      query.updateFromCache(data);
    }
  }

  /// Returns cached data for a query key.
  T? getQueryData<T>(QueryKey queryKey) {
    final key = queryKey.key;
    return _cache.getData<T>(key);
  }

  /// Returns current cache information.
  CacheInfo getCacheInfo() {
    return _cache.getCacheInfo();
  }

  /// Returns all cache keys.
  List<String> getCacheKeys() {
    return _cache.getCacheKeys();
  }

  /// Clears all secure cache entries.
  void clearSecureCache() {
    _cache.clearSecureEntries();
  }

  void _refetchActiveQueries(Iterable<String> keys) {
    for (final key in keys) {
      final query = _registry.queries[key];
      if (query != null && query.referenceCount > 0) {
        unawaited(query.fetch());
      }
    }
  }
}
