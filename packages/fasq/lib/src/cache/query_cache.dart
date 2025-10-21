import 'dart:async';

import 'async_lock.dart';
import 'cache_config.dart';
import 'cache_entry.dart';
import 'cache_metrics.dart';
import 'eviction_policy.dart';
import 'eviction/eviction_strategy.dart';
import 'eviction/fifo_eviction.dart';
import 'eviction/lfu_eviction.dart';
import 'eviction/lru_eviction.dart';
import '../persistence/persistence_options.dart';
import '../persistence/encrypted_cache_persister.dart';
import '../core/validation/input_validator.dart';

/// Core cache storage and management for queries.
///
/// Handles caching, staleness detection, eviction, and request deduplication.
class QueryCache {
  final CacheConfig config;
  final PersistenceOptions? persistenceOptions;
  final Map<String, CacheEntry> _entries = {};
  final Map<String, Future> _inFlightRequests = {};
  final Map<String, AsyncLock> _locks = {};
  final CacheMetrics _metrics = CacheMetrics();

  Timer? _gcTimer;
  Timer? _persistenceGcTimer;
  EncryptedCachePersister? _persister;

  QueryCache({
    CacheConfig? config,
    this.persistenceOptions,
  }) : config = config ?? const CacheConfig() {
    _startGarbageCollection();
    _initializePersistence();
  }

  /// Gets a cache entry if it exists.
  ///
  /// Updates access metadata and returns null if not found or expired.
  CacheEntry<T>? get<T>(String key) {
    InputValidator.validateQueryKey(key);

    final entry = _entries[key];
    if (entry == null) {
      _metrics.recordMiss();
      return null;
    }

    // Check if secure entry has expired
    if (entry.isSecure && entry.isExpired) {
      _entries.remove(key);
      _metrics.recordMiss();
      return null;
    }

    _metrics.recordHit();

    final updated = entry.withAccess();
    _entries[key] = updated;

    return updated as CacheEntry<T>;
  }

  /// Sets data in the cache.
  ///
  /// Creates or updates a cache entry. Triggers eviction if size limit exceeded.
  /// Secure entries are never persisted to disk.
  void set<T>(
    String key,
    T data, {
    Duration? staleTime,
    Duration? cacheTime,
    bool isSecure = false,
    Duration? maxAge,
  }) {
    InputValidator.validateQueryKey(key);
    InputValidator.validateCacheData(data);
    InputValidator.validateDuration(staleTime, 'staleTime');
    InputValidator.validateDuration(cacheTime, 'cacheTime');
    InputValidator.validateDuration(maxAge, 'maxAge');

    final entry = CacheEntry<T>.create(
      data: data,
      staleTime: staleTime ?? config.defaultStaleTime,
      cacheTime: cacheTime ?? config.defaultCacheTime,
      isSecure: isSecure,
      maxAge: maxAge,
    );

    _entries[key] = entry;

    // Persist non-secure entries if persistence is enabled
    if (persistenceOptions?.enabled == true &&
        !isSecure &&
        _persister != null) {
      _persistEntry(key, entry);
    }

    if (_shouldEvict()) {
      _evictIfNeeded();
    }
  }

  /// Removes a cache entry by key.
  void remove(String key) {
    InputValidator.validateQueryKey(key);
    _entries.remove(key);
  }

  /// Clears all cache entries.
  void clear() {
    _entries.clear();
    _inFlightRequests.clear();
    _metrics.reset();
  }

  /// Clears all secure cache entries.
  ///
  /// Removes only entries marked as secure, leaving non-secure entries intact.
  void clearSecureEntries() {
    final keysToRemove = _entries.entries
        .where((entry) => entry.value.isSecure)
        .map((entry) => entry.key)
        .toList();

    for (final key in keysToRemove) {
      _entries.remove(key);
    }
  }

  /// Invalidates a specific cache entry.
  ///
  /// Removes the entry, forcing a refetch on next access.
  void invalidate(String key) {
    InputValidator.validateQueryKey(key);
    remove(key);
  }

  /// Invalidates all cache entries with keys starting with the prefix.
  void invalidateWithPrefix(String prefix) {
    final keysToRemove =
        _entries.keys.where((key) => key.startsWith(prefix)).toList();

    for (final key in keysToRemove) {
      remove(key);
    }
  }

  /// Invalidates cache entries matching the predicate.
  void invalidateWhere(bool Function(String key) predicate) {
    final keysToRemove = _entries.keys.where(predicate).toList();

    for (final key in keysToRemove) {
      remove(key);
    }
  }

  /// Gets raw data from cache (for manual access).
  T? getData<T>(String key) {
    final entry = get<T>(key);
    return entry?.data;
  }

  /// Sets raw data in cache (for manual updates).
  void setData<T>(String key, T data,
      {bool isSecure = false, Duration? maxAge}) {
    set<T>(key, data, isSecure: isSecure, maxAge: maxAge);
  }

  /// Deduplicates a request by key.
  ///
  /// If a request with the same key is in flight, returns the existing future.
  /// Otherwise, executes and tracks the new request.
  Future<T> deduplicate<T>(
    String key,
    Future<T> Function() fn,
  ) async {
    if (_inFlightRequests.containsKey(key)) {
      return _inFlightRequests[key] as Future<T>;
    }

    final future = fn();
    _inFlightRequests[key] = future;

    try {
      final result = await future;
      return result;
    } finally {
      _inFlightRequests.remove(key);
    }
  }

  /// Executes a function with a lock on the given key.
  ///
  /// Ensures thread-safe access to cache entries.
  Future<T> withLock<T>(String key, Future<T> Function() fn) async {
    final lock = _locks.putIfAbsent(key, () => AsyncLock());
    return await lock.synchronized(fn);
  }

  /// Current total cache size in bytes.
  int get currentSize {
    int total = 0;
    for (final entry in _entries.values) {
      total += entry.estimateSize();
    }
    return total;
  }

  /// Current number of cache entries.
  int get entryCount => _entries.length;

  /// Cache metrics for monitoring.
  CacheMetrics get metrics => _metrics;

  /// Gets a snapshot of cache state.
  CacheInfo getCacheInfo() {
    return CacheInfo(
      entryCount: entryCount,
      sizeBytes: currentSize,
      metrics: _metrics,
      maxCacheSize: config.maxCacheSize,
    );
  }

  /// Gets all cache keys.
  List<String> getCacheKeys() {
    return _entries.keys.toList();
  }

  /// Inspects a specific cache entry.
  CacheEntry? inspectEntry(String key) {
    return _entries[key];
  }

  bool _shouldEvict() {
    return currentSize > config.maxCacheSize || entryCount > config.maxEntries;
  }

  void _evictIfNeeded() {
    if (!_shouldEvict()) return;

    final targetSize = (config.maxCacheSize * 0.9).toInt();
    final strategy = _getEvictionStrategy();

    final keysToEvict = strategy.selectKeysToEvict(
      _entries,
      currentSize,
      targetSize,
    );

    for (final key in keysToEvict) {
      _entries.remove(key);
      _metrics.recordEviction();
    }
  }

  EvictionStrategy _getEvictionStrategy() {
    switch (config.evictionPolicy) {
      case EvictionPolicy.lru:
        return const LRUEviction();
      case EvictionPolicy.lfu:
        return const LFUEviction();
      case EvictionPolicy.fifo:
        return const FIFOEviction();
    }
  }

  void _startGarbageCollection() {
    _gcTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _runGarbageCollection();
    });
  }

  void _runGarbageCollection() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final entry in _entries.entries) {
      if (entry.value.shouldGarbageCollect(now)) {
        keysToRemove.add(entry.key);
      }
    }

    for (final key in keysToRemove) {
      _entries.remove(key);
    }
  }

  /// Disposes the cache and stops garbage collection.
  void dispose() {
    _gcTimer?.cancel();
    _gcTimer = null;
    _persistenceGcTimer?.cancel();
    _persistenceGcTimer = null;
    clearSecureEntries(); // Clear secure data before full clear
    clear();
  }

  /// Initializes persistence if enabled.
  Future<void> _initializePersistence() async {
    if (persistenceOptions?.enabled != true) return;

    try {
      _persister = EncryptedCachePersister();
      await _persister!.initialize();
      _startPersistenceGarbageCollection();
    } catch (e) {
      // Log error but don't fail initialization
      print('Warning: Failed to initialize persistence: $e');
    }
  }

  /// Starts garbage collection for persisted data.
  void _startPersistenceGarbageCollection() {
    final interval =
        persistenceOptions?.gcInterval ?? const Duration(minutes: 5);
    _persistenceGcTimer = Timer.periodic(interval, (_) {
      _runPersistenceGarbageCollection();
    });
  }

  /// Runs garbage collection on persisted data.
  Future<void> _runPersistenceGarbageCollection() async {
    if (_persister == null) return;

    try {
      final keys = await _persister!.getAllKeys();
      final now = DateTime.now();

      for (final key in keys) {
        // Check if entry should be garbage collected
        final entry = _entries[key];
        if (entry != null && entry.shouldGarbageCollect(now)) {
          await _persister!.remove(key);
        }
      }
    } catch (e) {
      // Log error but don't fail GC
      print('Warning: Persistence garbage collection failed: $e');
    }
  }

  /// Persists a cache entry to disk.
  Future<void> _persistEntry(String key, CacheEntry entry) async {
    if (_persister == null) return;

    try {
      await _persister!.persist(key, entry.data);
    } catch (e) {
      // Log error but don't fail cache operation
      print('Warning: Failed to persist entry $key: $e');
    }
  }
}
