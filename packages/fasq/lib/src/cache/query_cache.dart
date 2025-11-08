import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'async_lock.dart';
import 'cache_config.dart';
import 'cache_entry.dart';
import 'cache_metrics.dart';
import 'eviction_policy.dart';
import 'eviction/eviction_strategy.dart';
import 'eviction/fifo_eviction.dart';
import 'eviction/lfu_eviction.dart';
import 'eviction/lru_eviction.dart';
import 'hot_cache.dart';
import '../persistence/persistence_options.dart';
import '../security/encryption_provider.dart';
import '../security/persistence_provider.dart';
import '../security/security_plugin.dart';
import '../security/security_provider.dart';
import '../core/validation/input_validator.dart';

/// Core cache storage and management for queries.
///
/// Handles caching, staleness detection, eviction, and request deduplication.
class QueryCache {
  final CacheConfig config;
  final PersistenceOptions? persistenceOptions;
  final SecurityPlugin? securityPlugin;
  final Map<String, CacheEntry> _entries = {};
  final Map<String, Future> _inFlightRequests = {};
  final Map<String, AsyncLock> _locks = {};
  final CacheMetrics _metrics = CacheMetrics();
  late final HotCache<CacheEntry> _hotCache;

  bool _isInitialized = false;
  SecurityProvider? _securityProvider;
  EncryptionProvider? _encryptionProvider;
  PersistenceProvider? _persistenceProvider;
  Future<void>? _persistenceInitFuture;

  Timer? _gcTimer;
  Timer? _persistenceGcTimer;

  bool get _persistenceReady =>
      _isInitialized &&
      _securityProvider != null &&
      _encryptionProvider != null &&
      _persistenceProvider != null;

  Future<void> get persistenceInitialization =>
      _persistenceInitFuture ?? Future.value();

  QueryCache({
    CacheConfig? config,
    this.persistenceOptions,
    this.securityPlugin,
  }) : config = config ?? const CacheConfig() {
    _hotCache =
        HotCache<CacheEntry>(maxSize: this.config.performance.hotCacheSize);
    _startGarbageCollection();
    _persistenceInitFuture = _initializePersistence();
  }

  /// Gets a cache entry if it exists.
  ///
  /// Updates access metadata and returns null if not found or expired.
  CacheEntry<T>? get<T>(String key) {
    InputValidator.validateQueryKey(key);

    // Check hot cache first
    final hotEntry = _hotCache.get(key);
    if (hotEntry != null) {
      _metrics.recordHit();
      final updated = hotEntry.withAccess();
      _entries[key] = updated;
      return _reconstructEntry<T>(updated);
    }

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

    // Promote to hot cache if accessed frequently enough
    if (_hotCache.shouldPromote(key, updated.accessCount)) {
      _hotCache.put(key, updated);
    }

    return _reconstructEntry<T>(updated);
  }

  /// Reconstructs a CacheEntry with type T from a CacheEntry (any type).
  ///
  /// Preserves all metadata while ensuring type safety by reconstructing
  /// with explicit type parameter instead of unsafe casting.
  CacheEntry<T> _reconstructEntry<T>(CacheEntry entry) {
    return CacheEntry<T>(
      data: entry.data as T,
      createdAt: entry.createdAt,
      lastAccessedAt: entry.lastAccessedAt,
      accessCount: entry.accessCount,
      staleTime: entry.staleTime,
      cacheTime: entry.cacheTime,
      referenceCount: entry.referenceCount,
      isSecure: entry.isSecure,
      expiresAt: entry.expiresAt,
    );
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

    // Remove from hot cache to force re-promotion
    _hotCache.remove(key);

    // Persist non-secure entries if persistence is enabled
    if (persistenceOptions?.enabled == true &&
        !isSecure &&
        securityPlugin != null) {
      unawaited(_persistEntry(key, entry));
    }

    if (_shouldEvict()) {
      _evictIfNeeded();
    }
  }

  /// Removes a cache entry by key.
  void remove(String key) {
    InputValidator.validateQueryKey(key);
    final removed = _entries.remove(key);
    if (removed != null) {
      _hotCache.remove(key);
      if (_persistenceReady) {
        unawaited(_removeFromPersistence(key));
      }
    }
  }

  void _clearInMemory() {
    _entries.clear();
    _hotCache.clear();
    _inFlightRequests.clear();
    _metrics.reset();
  }

  /// Clears all cache entries.
  void clear() {
    _clearInMemory();

    // Clear persistence if enabled
    if (_persistenceReady) {
      unawaited(_clearPersistence());
    }
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
      _hotCache.remove(key);
    }
  }

  /// Invalidates a specific cache entry.
  ///
  /// Removes the entry, forcing a refetch on next access.
  void invalidate(String key) {
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

  /// Invalidates multiple queries in a single operation
  void invalidateMultiple(List<String> keys) {
    for (final key in keys) {
      remove(key);
    }
    if (keys.isNotEmpty) {
      _metrics.recordEviction();
    }
  }

  /// Invalidates queries matching predicate with single notification
  void invalidateWhereDetailed(
      bool Function(String key, CacheEntry entry) predicate) {
    final keysToRemove = <String>[];

    _entries.forEach((key, entry) {
      if (predicate(key, entry)) {
        keysToRemove.add(key);
      }
    });

    invalidateMultiple(keysToRemove);
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
    InputValidator.validateQueryKey(key);

    if (_inFlightRequests.containsKey(key)) {
      return _inFlightRequests[key] as Future<T>;
    }

    // Get or create lock for this key to prevent race conditions
    final lock = _locks.putIfAbsent(key, () => AsyncLock());

    return await lock.synchronized(() async {
      // Double-check after acquiring lock
      if (_inFlightRequests.containsKey(key)) {
        return _inFlightRequests[key] as Future<T>;
      }

      final future = fn();
      _inFlightRequests[key] = future;

      try {
        final result = await future;
        return result;
      } finally {
        // Always clean up the in-flight request
        _inFlightRequests.remove(key);
        // Clean up lock if no longer needed
        _locks.remove(key);
      }
    });
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

  /// Disposes the cache and cleans up all resources.
  void dispose() {
    _gcTimer?.cancel();
    _gcTimer = null;
    _persistenceGcTimer?.cancel();
    _persistenceGcTimer = null;

    // Clean up all locks
    _locks.clear();

    _clearInMemory();
  }

  /// Initializes persistence if enabled.
  Future<void> _initializePersistence() async {
    if (persistenceOptions?.enabled != true || securityPlugin == null) return;

    try {
      if (!securityPlugin!.isSupported) {
        _logPersistenceError(
          'Security plugin ${securityPlugin!.name} is not supported on this platform',
          UnsupportedError('Security plugin not supported'),
        );
        return;
      }

      await securityPlugin!.initialize();
      _securityProvider = securityPlugin!.createStorageProvider();
      _encryptionProvider = securityPlugin!.createEncryptionProvider();
      _persistenceProvider = securityPlugin!.createPersistenceProvider();

      await _securityProvider!.initialize();
      await _persistenceProvider!.initialize();

      _isInitialized = true;
      _startPersistenceGarbageCollection();
      await _loadPersistedEntries();
    } catch (e, stackTrace) {
      _isInitialized = false;
      _securityProvider = null;
      _encryptionProvider = null;
      _persistenceProvider = null;
      _logPersistenceError(
        'Failed to initialize persistence',
        e,
        stackTrace,
      );
    }
  }

  /// Starts garbage collection for persisted data.
  void _startPersistenceGarbageCollection() {
    if (!_persistenceReady) return;
    final interval =
        persistenceOptions?.gcInterval ?? const Duration(minutes: 5);
    _persistenceGcTimer = Timer.periodic(interval, (_) {
      _runPersistenceGarbageCollection();
    });
  }

  /// Runs garbage collection on persisted data.
  Future<void> _runPersistenceGarbageCollection() async {
    if (!_persistenceReady) return;

    try {
      final allKeys = await _persistenceProvider!.getAllKeys();
      final keysToRemove = <String>[];

      for (final key in allKeys) {
        // Check if the entry should be garbage collected
        final entry = _entries[key];
        if (entry == null || entry.shouldGarbageCollect(DateTime.now())) {
          keysToRemove.add(key);
        }
      }

      if (keysToRemove.isNotEmpty) {
        await _persistenceProvider!.removeMultiple(keysToRemove);
      }
    } catch (e, stackTrace) {
      _logPersistenceError(
        'Failed to run persistence garbage collection',
        e,
        stackTrace,
      );
    }
  }

  /// Persists a cache entry to disk.
  Future<void> _persistEntry(String key, CacheEntry entry) async {
    if (_persistenceInitFuture != null) {
      await _persistenceInitFuture;
    }
    if (!_persistenceReady) return;

    try {
      // Get or generate encryption key
      String? encryptionKey = await _securityProvider!.getEncryptionKey();
      encryptionKey ??= await _securityProvider!.generateAndStoreKey();

      // Serialize the entry to JSON
      final entryJson = jsonEncode(entry.toJson());
      final entryBytes = utf8.encode(entryJson);

      // Encrypt the data
      final encryptedData =
          await _encryptionProvider!.encrypt(entryBytes, encryptionKey);

      // Persist the encrypted data
      await _persistenceProvider!.persist(key, encryptedData);
    } catch (e, stackTrace) {
      _logPersistenceError(
        'Failed to persist cache entry for key $key',
        e,
        stackTrace,
      );
    }
  }

  /// Removes an entry from persistence.
  Future<void> _removeFromPersistence(String key) async {
    if (_persistenceInitFuture != null) {
      await _persistenceInitFuture;
    }
    if (!_persistenceReady) return;

    try {
      await _persistenceProvider!.remove(key);
    } catch (e, stackTrace) {
      _logPersistenceError(
        'Failed to remove persisted cache entry for key $key',
        e,
        stackTrace,
      );
    }
  }

  /// Removes multiple entries from persistence.
  /// Clears all persisted data.
  Future<void> _clearPersistence() async {
    if (!_persistenceReady) return;

    try {
      await _persistenceProvider!.clear();
    } catch (e, stackTrace) {
      _logPersistenceError(
        'Failed to clear persisted cache entries',
        e,
        stackTrace,
      );
    }
  }

  /// Loads persisted entries on initialization.
  Future<void> _loadPersistedEntries() async {
    if (!_persistenceReady) return;

    try {
      final encryptionKey = await _securityProvider!.getEncryptionKey();
      if (encryptionKey == null) {
        // No key means no persisted data
        return;
      }

      final allKeys = await _persistenceProvider!.getAllKeys();

      for (final key in allKeys) {
        final encryptedData = await _persistenceProvider!.retrieve(key);
        if (encryptedData != null) {
          try {
            // Decrypt the data
            final decryptedBytes = await _encryptionProvider!
                .decrypt(encryptedData, encryptionKey);
            final entryJson = utf8.decode(decryptedBytes);
            final entryMap = jsonDecode(entryJson) as Map<String, dynamic>;

            // Recreate the cache entry
            final entry = CacheEntry.fromJson(entryMap);

            // Only load if not expired
            if (!entry.isExpired) {
              _entries[key] = entry;
            }
          } catch (e, stackTrace) {
            try {
              await _persistenceProvider!.remove(key);
            } catch (removeError, removeStack) {
              _logPersistenceError(
                'Failed to remove corrupted cache entry for key $key',
                removeError,
                removeStack,
              );
            }
            _logPersistenceError(
              'Failed to load persisted cache entry for key $key',
              e,
              stackTrace,
            );
          }
        }
      }
    } catch (e, stackTrace) {
      _logPersistenceError(
        'Failed to load persisted cache entries',
        e,
        stackTrace,
      );
    }
  }

  void _logPersistenceError(
    String message,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    developer.log(
      message,
      name: 'FASQ.QueryCache',
      error: error,
      stackTrace: stackTrace,
    );
  }
}
