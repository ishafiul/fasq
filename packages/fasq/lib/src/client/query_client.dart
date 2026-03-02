import 'dart:async';

import 'package:fasq/src/cache/cache_config.dart';
import 'package:fasq/src/cache/cache_metrics.dart';
import 'package:fasq/src/cache/query_cache.dart';
import 'package:fasq/src/circuit_breaker/circuit_breaker_registry.dart';
import 'package:fasq/src/client/internal/query_client_cache_ops.dart';
import 'package:fasq/src/client/internal/query_client_config_guard.dart';
import 'package:fasq/src/client/internal/query_client_events.dart';
import 'package:fasq/src/client/internal/query_client_metrics.dart';
import 'package:fasq/src/client/internal/query_client_registry.dart';
import 'package:fasq/src/client/query_client_observer.dart';
import 'package:fasq/src/mutation/mutation_meta.dart';
import 'package:fasq/src/mutation/mutation_snapshot.dart';
import 'package:fasq/src/observability/error/error_context.dart';
import 'package:fasq/src/observability/error/error_reporter.dart';
import 'package:fasq/src/observability/performance/isolate_pool.dart';
import 'package:fasq/src/observability/performance/metrics_config.dart';
import 'package:fasq/src/persistence/persistence_options.dart';
import 'package:fasq/src/query/cancellation/cancellation_token.dart';
import 'package:fasq/src/query/infinite/infinite_query.dart';
import 'package:fasq/src/query/infinite/infinite_query_options.dart';
import 'package:fasq/src/query/keys/query_key.dart';
import 'package:fasq/src/query/prefetch/prefetch_config.dart';
import 'package:fasq/src/query/query.dart';
import 'package:fasq/src/query/query_meta.dart';
import 'package:fasq/src/query/query_options.dart';
import 'package:fasq/src/query/query_snapshot.dart';
import 'package:fasq/src/security/security_plugin.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Global registry for all queries in the application.
///
/// [QueryClient] is a singleton that manages the lifecycle of all queries.
/// It creates queries on-demand, ensures queries with the same key are shared,
/// handles cleanup, and manages the cache.
class QueryClient with WidgetsBindingObserver {
  /// Returns the singleton instance of [QueryClient].
  factory QueryClient({
    CacheConfig? config,
    PersistenceOptions? persistenceOptions,
    SecurityPlugin? securityPlugin,
    CircuitBreakerRegistry? circuitBreakerRegistry,
  }) {
    final existing = _instance;
    if (existing != null) {
      if (QueryClientConfigGuard.hasConfigurationConflict(
        existingConfigSnapshot: existing._configSnapshot,
        existingPersistenceSnapshot: existing._persistenceSnapshot,
        existingSecurityPluginType: existing._securityPluginType,
        existingCircuitBreakerRegistry: existing._circuitBreakerRegistry,
        requestedConfig: config,
        requestedPersistenceOptions: persistenceOptions,
        requestedSecurityPlugin: securityPlugin,
        requestedCircuitBreakerRegistry: circuitBreakerRegistry,
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
    if (BindingBase.debugBindingType() != null) {
      _binding = WidgetsBinding.instance;
      _binding?.addObserver(this);
    } else {
      _binding = null;
    }

    _events = QueryClientEvents();
    _registry = QueryClientRegistry(
      cache: _cache,
      queryFactory: <T>({
        required queryKey,
        required dependencyManager,
        required onDispose,
        queryFn,
        queryFnWithToken,
        options,
        initialEntry,
      }) {
        return Query<T>(
          queryKey: queryKey,
          queryFn: queryFn,
          queryFnWithToken: queryFnWithToken,
          options: options,
          cache: _cache,
          client: this,
          circuitBreakerRegistry: _circuitBreakerRegistry,
          dependencyManager: dependencyManager,
          onDispose: onDispose,
          initialEntry: initialEntry,
        );
      },
    );
    _cacheOps = QueryClientCacheOps(
      cache: _cache,
      registry: _registry,
    );
    _metrics = QueryClientMetrics(
      cache: _cache,
      queries: _registry.queries,
    );
    _isolatePool =
        IsolatePool(poolSize: config?.performance.isolatePoolSize ?? 2);
  }

  static QueryClient? _instance;

  /// Returns the current singleton instance if already initialized, else null.
  static QueryClient? get maybeInstance => _instance;

  final QueryCache _cache;
  final CacheConfig _configSnapshot;
  final PersistenceOptions? _persistenceSnapshot;
  final Type? _securityPluginType;
  final CircuitBreakerRegistry? _circuitBreakerRegistry;
  late final QueryClientEvents _events;
  late final QueryClientRegistry _registry;
  late final QueryClientCacheOps _cacheOps;
  late final QueryClientMetrics _metrics;
  late final IsolatePool _isolatePool;
  WidgetsBinding? _binding;

  /// Registers an observer for query/mutation lifecycle notifications.
  ///
  /// Duplicate registrations are ignored.
  void addObserver(QueryClientObserver observer) {
    _events.addObserver(observer);
  }

  /// Unregisters a previously added observer.
  void removeObserver(QueryClientObserver observer) {
    _events.removeObserver(observer);
  }

  /// Removes all registered observers.
  void clearObservers() {
    _events.clearObservers();
  }

  /// Registers an error reporter to receive query error notifications.
  void addErrorReporter(FasqErrorReporter reporter) {
    _events.addErrorReporter(reporter);
  }

  /// Unregisters an error reporter.
  void removeErrorReporter(FasqErrorReporter reporter) {
    _events.removeErrorReporter(reporter);
  }

  /// Dispatches an error context to all registered error reporters.
  ///
  /// Internal use only - not part of the public API.
  @internal
  void dispatchError(FasqErrorContext context) {
    _events.dispatchError(context);
  }

  /// Notifies observers that a mutation entered the loading state.
  void notifyMutationLoading(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    _events.notifyMutationLoading(snapshot, meta, context);
  }

  /// Notifies observers that a mutation completed successfully.
  void notifyMutationSuccess(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    _events.notifyMutationSuccess(snapshot, meta, context);
  }

  /// Notifies observers that a mutation failed.
  void notifyMutationError(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    _events.notifyMutationError(snapshot, meta, context);
  }

  /// Notifies observers that a mutation has settled (success or error).
  void notifyMutationSettled(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    _events.notifyMutationSettled(snapshot, meta, context);
  }

  /// Notifies observers that a query entered the loading state.
  void notifyQueryLoading(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    _events.notifyQueryLoading(snapshot, meta, context);
  }

  /// Notifies observers that a query completed successfully.
  void notifyQuerySuccess(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    _events.notifyQuerySuccess(snapshot, meta, context);
  }

  /// Notifies observers that a query failed.
  void notifyQueryError(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    _events.notifyQueryError(snapshot, meta, context);
  }

  /// Notifies observers that a query has settled (success or error).
  void notifyQuerySettled(
    QuerySnapshot<dynamic> snapshot,
    QueryMeta? meta,
    BuildContext? context,
  ) {
    _events.notifyQuerySettled(snapshot, meta, context);
  }

  /// Gets an existing query or creates a new one.
  Query<T> getQuery<T>(
    QueryKey queryKey, {
    Future<T> Function()? queryFn,
    Future<T> Function(CancellationToken token)? queryFnWithToken,
    QueryOptions? options,
    QueryKey? dependsOn,
  }) {
    return _registry.getQuery<T>(
      queryKey,
      queryFn: queryFn,
      queryFnWithToken: queryFnWithToken,
      options: options,
      dependsOn: dependsOn,
    );
  }

  /// Gets an existing infinite query or creates a new one.
  InfiniteQuery<TData, TParam> getInfiniteQuery<TData, TParam>(
    QueryKey queryKey,
    Future<TData> Function(TParam param) queryFn, {
    InfiniteQueryOptions<TData, TParam>? options,
  }) {
    return _registry.getInfiniteQuery<TData, TParam>(
      queryKey,
      queryFn,
      options: options,
    );
  }

  /// Retrieves an existing query by its key, or null if not found.
  Query<T>? getQueryByKey<T>(QueryKey queryKey) {
    return _registry.getQueryByKey<T>(queryKey);
  }

  /// Retrieves an existing infinite query by its key, or null if not found.
  InfiniteQuery<TData, TParam>? getInfiniteQueryByKey<TData, TParam>(
    QueryKey queryKey,
  ) {
    return _registry.getInfiniteQueryByKey<TData, TParam>(queryKey);
  }

  /// Removes and disposes a query by its key.
  void removeQuery(QueryKey queryKey) {
    _registry.removeQuery(queryKey);
  }

  /// Removes and disposes an infinite query by its key.
  void removeInfiniteQuery(QueryKey queryKey) {
    _registry.removeInfiniteQuery(queryKey);
  }

  /// Removes and disposes all queries.
  void clear() {
    _registry.clear();
  }

  /// The number of queries currently in the registry.
  int get queryCount => _registry.queryCount;

  /// Whether a query with the given [queryKey] exists.
  bool hasQuery(QueryKey queryKey) {
    return _registry.hasQuery(queryKey);
  }

  /// Gets the underlying query cache instance.
  QueryCache get cache => _cache;

  /// Gets the persistence initialization future.
  Future<void> get persistenceInitialization =>
      _cache.persistenceInitialization;

  /// The isolate pool for heavy computation tasks.
  IsolatePool get isolatePool => _isolatePool;

  /// The circuit breaker registry for managing circuit breakers.
  CircuitBreakerRegistry? get circuitBreakerRegistry => _circuitBreakerRegistry;

  /// Returns debug information for all active queries (debug mode only).
  Iterable<QueryDebugInfo> get activeQueryDebugInfo =>
      _registry.activeQueryDebugInfo;

  /// Returns a map of query keys to their debug information.
  Map<String, QueryDebugInfo> get activeQueryDebugInfoMap =>
      _registry.activeQueryDebugInfoMap;

  /// Invalidates a single query by key.
  void invalidateQuery(QueryKey queryKey) {
    _cacheOps.invalidateQuery(queryKey);
  }

  /// Invalidates multiple queries atomically.
  void invalidateQueries(List<QueryKey> queryKeys) {
    _cacheOps.invalidateQueries(queryKeys);
  }

  /// Invalidates queries matching condition.
  void invalidateQueriesWhere(bool Function(String key) predicate) {
    _cacheOps.invalidateQueriesWhere(predicate);
  }

  /// Invalidates all queries with keys starting with the prefix.
  void invalidateQueriesWithPrefix(String prefix) {
    _cacheOps.invalidateQueriesWithPrefix(prefix);
  }

  /// Prefetches a query and populates the cache.
  Future<void> prefetchQuery<T>(
    QueryKey queryKey,
    Future<T> Function() queryFn, {
    QueryOptions? options,
  }) async {
    await _cacheOps.prefetchQuery(queryKey, queryFn, options: options);
  }

  /// Prefetches multiple queries in parallel.
  Future<void> prefetchQueries<T>(
    List<PrefetchConfig<T>> configs,
  ) async {
    await _cacheOps.prefetchQueries(configs);
  }

  /// Invalidates queries matching the predicate.
  void invalidateQueriesWherePredicate(bool Function(String key) predicate) {
    _cacheOps.invalidateQueriesWherePredicate(predicate);
  }

  /// Manually sets data in the cache.
  void setQueryData<T>(
    QueryKey queryKey,
    T data, {
    bool isSecure = false,
    Duration? maxAge,
  }) {
    _cacheOps.setQueryData(
      queryKey,
      data,
      isSecure: isSecure,
      maxAge: maxAge,
    );
  }

  /// Gets cached data for a query key.
  T? getQueryData<T>(QueryKey queryKey) {
    return _cacheOps.getQueryData<T>(queryKey);
  }

  /// Gets cache information for monitoring and debugging.
  CacheInfo getCacheInfo() {
    return _cacheOps.getCacheInfo();
  }

  /// Returns a snapshot of global performance metrics.
  PerformanceSnapshot getMetrics({
    Duration throughputWindow = const Duration(minutes: 1),
  }) {
    return _metrics.getMetrics(throughputWindow: throughputWindow);
  }

  /// Returns performance metrics for a specific query key.
  QueryMetrics? getQueryMetrics(
    QueryKey queryKey, {
    Duration throughputWindow = const Duration(minutes: 1),
  }) {
    return _metrics.getQueryMetrics(
      queryKey,
      throughputWindow: throughputWindow,
    );
  }

  /// Gets all cache keys.
  List<String> getCacheKeys() {
    return _cacheOps.getCacheKeys();
  }

  /// Configures the metrics exporters and auto-export schedule.
  void configureMetricsExporters(MetricsConfig config) {
    _metrics.configureMetricsExporters(config);
  }

  /// Manually triggers an immediate export of current performance metrics.
  Future<void> exportMetricsManually() async {
    await _metrics.exportMetricsManually();
  }

  /// Clears all secure cache entries.
  void clearSecureCache() {
    _cacheOps.clearSecureCache();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        clearSecureCache();
      case AppLifecycleState.resumed:
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        break;
    }
  }

  /// Disposes the query client and cache.
  Future<void> dispose() async {
    _metrics.dispose();
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
}
