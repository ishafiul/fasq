import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../cache/cache_config.dart';
import '../cache/cache_metrics.dart';
import '../cache/query_cache.dart';
import '../circuit_breaker/circuit_breaker_registry.dart';
import '../performance/isolate_pool.dart';
import '../performance/metrics_config.dart';
import '../performance/performance_monitor.dart';
import '../persistence/persistence_options.dart';
import '../security/security_plugin.dart';
import 'cancellation_token.dart';
import 'infinite_query.dart';
import 'infinite_query_options.dart';
import 'mutation_meta.dart';
import 'mutation_snapshot.dart';
import 'prefetch_config.dart';
import 'query.dart';
import 'query_client_observer.dart';
import 'query_dependency_manager.dart';
import 'query_key.dart';
import 'query_meta.dart';
import 'query_options.dart';
import 'query_snapshot.dart';
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

  static QueryClient? get maybeInstance => _instance;

  /// Returns the singleton instance of [QueryClient].
  factory QueryClient({
    CacheConfig? config,
    PersistenceOptions? persistenceOptions,
    SecurityPlugin? securityPlugin,
    CircuitBreakerRegistry? circuitBreakerRegistry,
  }) {
    final existing = _instance;
    if (existing != null) {
      if (_hasConfigurationConflict(
        existing,
        config,
        persistenceOptions,
        securityPlugin,
        circuitBreakerRegistry,
      )) {
        throw StateError(
          'QueryClient already initialized with a different configuration. '
          'Call QueryClient.resetForTesting() before reconfiguring.',
        );
      }
      return existing;
    }

    _instance = QueryClient._internal(
      config: config,
      persistenceOptions: persistenceOptions,
      securityPlugin: securityPlugin,
      circuitBreakerRegistry: circuitBreakerRegistry,
    );
    return _instance!;
  }

  QueryClient._internal({
    CacheConfig? config,
    PersistenceOptions? persistenceOptions,
    SecurityPlugin? securityPlugin,
    CircuitBreakerRegistry? circuitBreakerRegistry,
  })  : _configSnapshot = config ?? const CacheConfig(),
        _persistenceSnapshot = persistenceOptions,
        _securityPluginType = securityPlugin?.runtimeType,
        _circuitBreakerRegistry = circuitBreakerRegistry,
        _cache = QueryCache(
          config: config ?? const CacheConfig(),
          persistenceOptions: persistenceOptions,
          securityPlugin: securityPlugin,
        ) {
    try {
      _binding = WidgetsBinding.instance;
      _binding?.addObserver(this);
    } on FlutterError {
      _binding = null;
    }
    _isolatePool =
        IsolatePool(poolSize: config?.performance.isolatePoolSize ?? 2);
    _performanceMonitor = PerformanceMonitor(
      cache: _cache,
      queries: _queries,
    );
  }

  final Map<String, Query> _queries = {};
  final Map<String, InfiniteQuery> _infiniteQueries = {};
  final QueryCache _cache;
  final CacheConfig _configSnapshot;
  final PersistenceOptions? _persistenceSnapshot;
  final Type? _securityPluginType;
  final CircuitBreakerRegistry? _circuitBreakerRegistry;
  final QueryDependencyManager _dependencyManager = QueryDependencyManager();
  late final IsolatePool _isolatePool;
  late final PerformanceMonitor _performanceMonitor;
  MetricsConfig _metricsConfig = MetricsConfig();
  Timer? _exportTimer;
  final List<QueryClientObserver> _observers = [];
  WidgetsBinding? _binding;

  String _extractKey(QueryKey queryKey) => queryKey.key;

  void addObserver(QueryClientObserver observer) {
    if (_observers.contains(observer)) return;
    _observers.add(observer);
  }

  void removeObserver(QueryClientObserver observer) {
    _observers.remove(observer);
  }

  void clearObservers() {
    _observers.clear();
  }

  void notifyMutationLoading(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onMutationLoading(snapshot, meta, context);
    }
  }

  void notifyMutationSuccess(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onMutationSuccess(snapshot, meta, context);
    }
  }

  void notifyMutationError(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onMutationError(snapshot, meta, context);
    }
  }

  void notifyMutationSettled(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onMutationSettled(snapshot, meta, context);
    }
  }

  void notifyQueryLoading(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onQueryLoading(snapshot, meta, context);
    }
  }

  void notifyQuerySuccess(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onQuerySuccess(snapshot, meta, context);
    }
  }

  void notifyQueryError(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onQueryError(snapshot, meta, context);
    }
  }

  void notifyQuerySettled(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    for (final observer in _observers) {
      observer.onQuerySettled(snapshot, meta, context);
    }
  }

  /// Gets an existing query or creates a new one.
  ///
  /// If a query with the given [key] already exists, returns that query.
  /// Otherwise, creates a new query with the provided [queryFn] and [options].
  ///
  /// Multiple calls with the same [key] return the same [Query] instance,
  /// enabling query sharing across widgets.
  ///
  /// [dependsOn] establishes a parent-child relationship. When the parent
  /// query is disposed, this query's in-flight fetch will be cancelled.
  ///
  /// Example:
  /// ```dart
  /// // Parent query
  /// final userQuery = client.getQuery<User>(
  ///   QueryKeys.user(123),
  ///   queryFn: () => api.fetchUser(123),
  /// );
  ///
  /// // Child query that depends on parent
  /// final postsQuery = client.getQuery<List<Post>>(
  ///   QueryKeys.userPosts(123),
  ///   queryFn: () => api.fetchPosts(123),
  ///   dependsOn: QueryKeys.user(123), // Cancelled when parent is disposed
  /// );
  /// ```
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

    final key = _extractKey(queryKey);
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

    // Register dependency relationship
    if (dependsOn != null) {
      final parentKey = _extractKey(dependsOn);
      _dependencyManager.registerDependency(key, parentKey);
    }

    final cachedEntry = _cache.get<T>(key);

    final query = Query<T>(
      queryKey: queryKey,
      queryFn: queryFn,
      queryFnWithToken: queryFnWithToken,
      options: options,
      cache: _cache,
      client: this,
      circuitBreakerRegistry: _circuitBreakerRegistry,
      dependencyManager: _dependencyManager,
      onDispose: () {
        _queries.remove(key);
        _dependencyManager.unregister(key);
      },
      initialEntry: cachedEntry,
    );

    _queries[key] = query;
    return query;
  }

  InfiniteQuery<TData, TParam> getInfiniteQuery<TData, TParam>(
    QueryKey queryKey,
    Future<TData> Function(TParam param) queryFn, {
    InfiniteQueryOptions<TData, TParam>? options,
  }) {
    final key = _extractKey(queryKey);
    if (_infiniteQueries.containsKey(key)) {
      final existing = _infiniteQueries[key]! as InfiniteQuery<TData, TParam>;
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
  Query<T>? getQueryByKey<T>(QueryKey queryKey) {
    final key = _extractKey(queryKey);
    InputValidator.validateQueryKey(key);
    return _queries[key] as Query<T>?;
  }

  InfiniteQuery<TData, TParam>? getInfiniteQueryByKey<TData, TParam>(
      QueryKey queryKey) {
    final key = _extractKey(queryKey);
    return _infiniteQueries[key] as InfiniteQuery<TData, TParam>?;
  }

  /// Removes and disposes a query by its key.
  ///
  /// The query is immediately disposed and removed from the registry.
  void removeQuery(QueryKey queryKey) {
    final key = _extractKey(queryKey);
    InputValidator.validateQueryKey(key);
    final query = _queries.remove(key);
    query?.dispose();
  }

  void removeInfiniteQuery(QueryKey queryKey) {
    final key = _extractKey(queryKey);
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
  bool hasQuery(QueryKey queryKey) {
    final key = _extractKey(queryKey);
    return _queries.containsKey(key);
  }

  /// Gets the underlying query cache instance.
  ///
  /// Useful for direct cache access in tests or advanced use cases.
  QueryCache get cache => _cache;

  /// Gets the persistence initialization future.
  ///
  /// Use this to wait for persisted cache entries to be loaded
  /// before creating queries. This ensures queries can use cached
  /// data immediately instead of making unnecessary network requests.
  Future<void> get persistenceInitialization =>
      _cache.persistenceInitialization;

  /// The isolate pool for heavy computation tasks.
  IsolatePool get isolatePool => _isolatePool;

  /// The circuit breaker registry for managing circuit breakers.
  ///
  /// Returns the registry instance if one was provided during initialization,
  /// or `null` if circuit breaker functionality is disabled.
  CircuitBreakerRegistry? get circuitBreakerRegistry => _circuitBreakerRegistry;

  /// Returns debug information for all active queries (debug mode only).
  ///
  /// Iterates through the QueryClient's internal registry of active queries
  /// and returns an iterable of their [QueryDebugInfo] objects. This is used
  /// by leak detection tools to identify queries that are still alive but
  /// should have been disposed.
  ///
  /// Returns an empty iterable in release builds.
  ///
  /// Example:
  /// ```dart
  /// final debugInfos = client.activeQueryDebugInfo;
  /// for (final info in debugInfos) {
  ///   print('Query created at: ${info.creationStack}');
  ///   print('Held by: ${info.referenceHolders.keys}');
  /// }
  /// ```
  Iterable<QueryDebugInfo> get activeQueryDebugInfo {
    if (!kDebugMode) return const <QueryDebugInfo>[];
    return _queries.values
        .map((query) => query.debugInfo)
        .whereType<QueryDebugInfo>();
  }

  /// Returns a map of query keys to their debug information (debug mode only).
  ///
  /// This is useful for leak detection tools that need to know which query
  /// keys are associated with each debug info object.
  ///
  /// Returns an empty map in release builds.
  ///
  /// Example:
  /// ```dart
  /// final debugInfoMap = client.activeQueryDebugInfoMap;
  /// for (final entry in debugInfoMap.entries) {
  ///   print('Query ${entry.key} created at: ${entry.value.creationStack}');
  /// }
  /// ```
  Map<String, QueryDebugInfo> get activeQueryDebugInfoMap {
    if (!kDebugMode) return const <String, QueryDebugInfo>{};
    final map = <String, QueryDebugInfo>{};
    for (final entry in _queries.entries) {
      final debugInfo = entry.value.debugInfo;
      if (debugInfo != null) {
        map[entry.key] = debugInfo;
      }
    }
    return map;
  }

  /// Invalidates a single query by key.
  ///
  /// Removes the cache entry and triggers refetch if the query is active.
  void invalidateQuery(QueryKey queryKey) {
    final key = _extractKey(queryKey);
    InputValidator.validateQueryKey(key);
    _cache.invalidate(key);
    final query = _queries[key];
    if (query != null && query.referenceCount > 0) {
      query.fetch();
    }
  }

  /// Invalidates multiple queries atomically
  void invalidateQueries(List<QueryKey> queryKeys) {
    for (final queryKey in queryKeys) {
      invalidateQuery(queryKey);
    }
  }

  /// Invalidates queries matching condition
  void invalidateQueriesWhere(bool Function(String key) predicate) {
    final keysToInvalidate = _queries.keys
        .where(predicate)
        .map((key) => StringQueryKey(key))
        .toList();
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
    QueryKey queryKey,
    Future<T> Function() queryFn, {
    QueryOptions? options,
  }) async {
    final key = _extractKey(queryKey);
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
            config.queryKey,
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
  void setQueryData<T>(QueryKey queryKey, T data,
      {bool isSecure = false, Duration? maxAge}) {
    final key = _extractKey(queryKey);
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

    final query = _queries[key];
    if (query != null) {
      query.updateFromCache(data);
    }
  }

  /// Gets cached data for a query key.
  ///
  /// Returns null if not cached.
  T? getQueryData<T>(QueryKey queryKey) {
    final key = _extractKey(queryKey);
    return _cache.getData<T>(key);
  }

  /// Gets cache information for monitoring and debugging.
  CacheInfo getCacheInfo() {
    return _cache.getCacheInfo();
  }

  /// Returns a snapshot of global performance metrics.
  ///
  /// Provides comprehensive performance data including cache metrics,
  /// query metrics, memory usage, and throughput information for all
  /// active queries.
  ///
  /// Example:
  /// ```dart
  /// final client = QueryClient();
  /// final snapshot = client.getMetrics();
  /// print('Cache hit rate: ${snapshot.cacheMetrics.hitRate}');
  /// print('Active queries: ${snapshot.activeQueries}');
  /// ```
  PerformanceSnapshot getMetrics(
      {Duration throughputWindow = const Duration(minutes: 1)}) {
    return _performanceMonitor.getSnapshot(throughputWindow: throughputWindow);
  }

  /// Returns performance metrics for a specific query key.
  ///
  /// Returns `null` if the query key doesn't exist or has no metrics.
  ///
  /// Example:
  /// ```dart
  /// final client = QueryClient();
  /// final metrics = client.getQueryMetrics('user');
  /// if (metrics != null) {
  ///   print('Fetch count: ${metrics.fetchCount}');
  ///   print('Avg fetch time: ${metrics.averageFetchTime?.inMilliseconds}ms');
  /// }
  /// ```
  QueryMetrics? getQueryMetrics(QueryKey queryKey,
      {Duration throughputWindow = const Duration(minutes: 1)}) {
    final key = _extractKey(queryKey);
    final snapshot =
        _performanceMonitor.getSnapshot(throughputWindow: throughputWindow);
    return snapshot.queryMetrics[key];
  }

  /// Gets all cache keys.
  List<String> getCacheKeys() {
    return _cache.getCacheKeys();
  }

  /// Configures the metrics exporters and enables/disables auto-export.
  ///
  /// This method allows you to configure one or more [MetricsExporter] instances
  /// and optionally enable automatic periodic export of performance metrics.
  ///
  /// Example:
  /// ```dart
  /// final client = QueryClient();
  /// final consoleExporter = ConsoleExporter();
  /// final jsonExporter = JsonExporter();
  ///
  /// client.configureMetricsExporters(
  ///   MetricsConfig(
  ///     exporters: [consoleExporter, jsonExporter],
  ///     exportInterval: Duration(minutes: 1),
  ///     enableAutoExport: true,
  ///   ),
  /// );
  /// ```
  ///
  /// If [enableAutoExport] is true, metrics will be automatically exported
  /// at the specified [exportInterval]. Any previously configured auto-export
  /// timer will be cancelled.
  void configureMetricsExporters(MetricsConfig config) {
    _metricsConfig = config;
    _exportTimer?.cancel();
    _exportTimer = null;

    // Apply global configuration to all exporters
    _metricsConfig.applyConfigurationToExporters({});

    if (_metricsConfig.enableAutoExport &&
        _metricsConfig.exporters.isNotEmpty) {
      _exportTimer =
          Timer.periodic(_metricsConfig.exportInterval, (timer) async {
        final snapshot = _performanceMonitor.getSnapshot();
        for (final exporter in _metricsConfig.exporters) {
          try {
            await exporter.export(snapshot);
          } catch (e) {
            // Error logging is handled by individual exporters
            // This catch prevents one exporter failure from stopping others
          }
        }
      });
    }
  }

  /// Manually triggers an immediate export of current performance metrics.
  ///
  /// This method exports the current performance snapshot to all configured
  /// exporters, regardless of the auto-export setting. Useful for on-demand
  /// metric export or testing.
  ///
  /// Example:
  /// ```dart
  /// final client = QueryClient();
  /// // ... configure exporters ...
  /// await client.exportMetricsManually();
  /// ```
  ///
  /// Returns a [Future] that completes when all exporters have finished
  /// exporting (or failed). Errors from individual exporters are caught
  /// and do not prevent other exporters from running.
  Future<void> exportMetricsManually() async {
    final snapshot = _performanceMonitor.getSnapshot();
    for (final exporter in _metricsConfig.exporters) {
      try {
        await exporter.export(snapshot);
      } catch (e) {
        // Error logging is handled by individual exporters
        // This catch prevents one exporter failure from stopping others
      }
    }
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
  Future<void> dispose() async {
    _exportTimer?.cancel();
    _exportTimer = null;
    _binding?.removeObserver(this);
    _binding = null;
    clear();
    await _cache.dispose();
    await _isolatePool.dispose();
  }

  /// Resets the singleton instance for testing.
  ///
  /// Only use this in tests to get a fresh instance.
  static Future<void> resetForTesting() async {
    Query.disposalDelay = Duration.zero;
    QueryCache.gcInterval = Duration.zero;
    QueryCache.persistenceGcInterval = Duration.zero;
    final existing = _instance;
    if (existing != null) {
      existing.clearObservers();
      await existing.dispose();
    }
    _instance = null;
  }

  static bool _hasConfigurationConflict(
    QueryClient existing,
    CacheConfig? config,
    PersistenceOptions? persistenceOptions,
    SecurityPlugin? securityPlugin,
    CircuitBreakerRegistry? circuitBreakerRegistry,
  ) {
    if (config != null &&
        _cacheConfigDiffers(existing._configSnapshot, config)) {
      return true;
    }

    if (persistenceOptions != null &&
        existing._persistenceSnapshot != null &&
        existing._persistenceSnapshot != persistenceOptions) {
      return true;
    }

    if (securityPlugin != null &&
        existing._securityPluginType != securityPlugin.runtimeType) {
      return true;
    }

    if (circuitBreakerRegistry != null &&
        existing._circuitBreakerRegistry != circuitBreakerRegistry) {
      return true;
    }

    return false;
  }

  static bool _cacheConfigDiffers(CacheConfig a, CacheConfig b) {
    if (a.maxCacheSize != b.maxCacheSize) return true;
    if (a.maxEntries != b.maxEntries) return true;
    if (a.defaultStaleTime != b.defaultStaleTime) return true;
    if (a.defaultCacheTime != b.defaultCacheTime) return true;
    if (a.evictionPolicy != b.evictionPolicy) return true;
    if (a.enableMemoryPressure != b.enableMemoryPressure) return true;
    if (_performanceConfigDiffers(a.performance, b.performance)) return true;
    return false;
  }

  static bool _performanceConfigDiffers(
    GlobalPerformanceConfig a,
    GlobalPerformanceConfig b,
  ) {
    if (a.enableTracking != b.enableTracking) return true;
    if (a.hotCacheSize != b.hotCacheSize) return true;
    if (a.enableWarnings != b.enableWarnings) return true;
    if (a.slowQueryThresholdMs != b.slowQueryThresholdMs) return true;
    if (a.memoryWarningThreshold != b.memoryWarningThreshold) return true;
    if (a.isolatePoolSize != b.isolatePoolSize) return true;
    if (a.defaultIsolateThreshold != b.defaultIsolateThreshold) return true;
    return false;
  }
}
