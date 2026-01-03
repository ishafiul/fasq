import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import '../core/typed_query_key.dart';
import '../core/validation/input_validator.dart';
import '../memory/index.dart'; // Add import
import '../persistence/cache_data_codec.dart';
import '../persistence/persistence_options.dart';
import '../security/encryption_provider.dart';
import '../security/persistence_provider.dart';
import '../security/security_plugin.dart';
import '../security/security_provider.dart';
import 'async_lock.dart';
import 'cache_config.dart';
import 'cache_entry.dart';
import 'cache_metrics.dart';
import 'eviction/eviction_strategy.dart';
import 'eviction/fifo_eviction.dart';
import 'eviction/lfu_eviction.dart';
import 'eviction/lru_eviction.dart';
import 'eviction_policy.dart';
import 'hot_cache.dart';

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
  Future<void>? _globalPersistenceOperation;
  final Map<String, Future<void>> _persistOperations = {};
  final Map<String, int> _entryVersions = {};
  final Map<String, Type> _keyTypes = {};
  int _versionCounter = 0;
  bool _isGcPaused = false;
  final bool _enableMemoryPressure;

  bool _isInitialized = false;
  SecurityProvider? _securityProvider;
  EncryptionProvider? _encryptionProvider;
  PersistenceProvider? _persistenceProvider;
  Future<void>? _persistenceInitFuture;

  Timer? _gcTimer;
  Timer? _persistenceGcTimer;

  static Duration gcInterval = const Duration(seconds: 30);
  static Duration? persistenceGcInterval;

  final CacheDataCodecRegistry _codecRegistry;
  final AsyncLock _encryptionKeyLock = AsyncLock();

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
    bool enableMemoryPressure = true,
  })  : config = config ?? const CacheConfig(),
        _enableMemoryPressure = enableMemoryPressure,
        _codecRegistry = (persistenceOptions?.codecRegistry ??
            const CacheDataCodecRegistry()) {
    _hotCache =
        HotCache<CacheEntry>(maxSize: this.config.performance.hotCacheSize);
    _startGarbageCollection();
    _persistenceInitFuture = _initializePersistence();

    if (_enableMemoryPressure) {
      try {
        MemoryPressureHandler().addListener(_onMemoryPressure);
      } catch (_) {
        // Ignore errors if running in non-flutter environment
      }
    }
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
      hasValue: entry.hasValue,
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
    if (isSecure && maxAge == null) {
      throw ArgumentError(
        'Secure cache entries require maxAge for TTL enforcement',
      );
    }

    final entry = CacheEntry<T>.create(
      data: data,
      staleTime: staleTime ?? config.defaultStaleTime,
      cacheTime: cacheTime ?? config.defaultCacheTime,
      isSecure: isSecure,
      maxAge: maxAge,
      hasValue: true,
    );

    _entries[key] = entry;
    final version = _nextEntryVersion();
    _entryVersions[key] = version;
    _keyTypes[key] = T;

    // Update memory metrics
    _updateMemoryMetrics();

    // Remove from hot cache to force re-promotion
    _hotCache.remove(key);

    // Queue persistence without blocking
    if (persistenceOptions?.enabled == true &&
        !isSecure &&
        securityPlugin != null) {
      _queuePersistence(key, entry, version);
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
      _entryVersions.remove(key);
      _persistOperations.remove(key);
      _keyTypes.remove(key);
      _updateMemoryMetrics();
      if (_persistenceReady) {
        _removePersistenceAsync(key);
      }
    }
  }

  void _clearInMemory() {
    _entries.clear();
    _hotCache.clear();
    _inFlightRequests.clear();
    _metrics.reset();
    _entryVersions.clear();
    _persistOperations.clear();
    _keyTypes.clear();
    _globalPersistenceOperation = null;
    _versionCounter = 0;
  }

  /// Clears all cache entries.
  void clear() {
    _clearInMemory();

    // Clear persistence if enabled
    if (_persistenceReady) {
      _clearPersistenceAsync();
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
      _entryVersions.remove(key);
      _persistOperations.remove(key);
      _keyTypes.remove(key);
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

    final existing = _inFlightRequests[key];
    if (existing != null) {
      return existing as Future<T>;
    }

    // Get or create lock for this key to prevent race conditions
    final lock = _locks.putIfAbsent(key, () => AsyncLock());

    await lock.acquire();
    try {
      // Double-check after acquiring lock
      final existingUnderLock = _inFlightRequests[key];
      if (existingUnderLock != null) {
        return existingUnderLock as Future<T>;
      }

      final future = fn().whenComplete(() {
        // Always clean up the in-flight request
        _inFlightRequests.remove(key);
        // Clean up lock if no longer needed
        _locks.remove(key);
      });

      _inFlightRequests[key] = future;
      return future;
    } finally {
      lock.release();
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

  /// Records a query execution for throughput tracking.
  ///
  /// This should be called when a query successfully executes to track
  /// requests per minute and requests per second.
  void recordQueryExecution(String queryKey) {
    _metrics.recordQueryExecution(queryKey);
  }

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
      _hotCache.remove(key);
      _entryVersions.remove(key);
      _persistOperations.remove(key);
      _keyTypes.remove(key);
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

  int _nextEntryVersion() {
    _versionCounter += 1;
    return _versionCounter;
  }

  /// Updates memory metrics based on current cache size.
  void _updateMemoryMetrics() {
    _metrics.recordMemoryUsage(currentSize);
  }

  void _startGarbageCollection() {
    if (gcInterval == Duration.zero) return;
    _gcTimer = Timer.periodic(gcInterval, (_) {
      if (!_isGcPaused) {
        _runGarbageCollection();
      }
    });
  }

  /// Pauses garbage collection.
  ///
  /// Useful when the app is in the background or performing critical tasks.
  void pauseGarbageCollection() {
    _isGcPaused = true;
  }

  /// Resumes garbage collection.
  void resumeGarbageCollection() {
    _isGcPaused = false;
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

  /// Trims the cache to release memory.
  ///
  /// [critical] - If true, performs a more aggressive cleanup by removing all
  /// inactive entries (referenceCount == 0), regardless of freshness.
  /// If false (default), removes only inactive entries that are stale.
  ///
  /// Active entries (referenceCount > 0) are never removed to prevent UI issues.
  void trim({bool critical = false}) {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final entry in _entries.entries) {
      // Never remove active entries
      if (entry.value.referenceCount > 0) continue;

      if (critical) {
        // Critical: Remove all inactive entries
        keysToRemove.add(entry.key);
      } else {
        // Normal: Remove only stale inactive entries
        if (entry.value.staleTime != Duration.zero &&
            now.difference(entry.value.createdAt) > entry.value.staleTime) {
          keysToRemove.add(entry.key);
        }
      }
    }

    if (keysToRemove.isNotEmpty) {
      invalidateMultiple(keysToRemove);
    }
  }

  /// Disposes the cache and cleans up all resources.
  Future<void> dispose() async {
    if (_enableMemoryPressure) {
      try {
        MemoryPressureHandler().removeListener(_onMemoryPressure);
      } catch (_) {
        // Ignore
      }
    }
    _gcTimer?.cancel();
    _gcTimer = null;
    _persistenceGcTimer?.cancel();
    _persistenceGcTimer = null;

    // Clean up all locks
    _locks.clear();

    _clearInMemory();
    await _disposePersistenceResources();
  }

  void _onMemoryPressure(bool critical) {
    // If system warns us, we should assume it's important.
    // We pass the critical flag along.
    trim(critical: critical);
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

      if (securityPlugin!.initializesProviders != true) {
        await _securityProvider!.initialize();
        await _persistenceProvider!.initialize();
      }

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
      Error.throwWithStackTrace(e, stackTrace);
    }
  }

  /// Starts garbage collection for persisted data.
  void _startPersistenceGarbageCollection() {
    if (!_persistenceReady) return;
    final interval = persistenceGcInterval ??
        persistenceOptions?.gcInterval ??
        const Duration(minutes: 5);

    if (interval == Duration.zero) return;

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

      final entriesSnapshot = Map<String, CacheEntry>.from(_entries);
      final now = DateTime.now();

      for (final key in allKeys) {
        final entry = entriesSnapshot[key];
        if (entry == null || entry.shouldGarbageCollect(now)) {
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

  Map<String, dynamic>? _buildPersistedEntryPayload(
    String key,
    CacheEntry entry,
    Type? expectedType,
  ) {
    try {
      final encoded = _codecRegistry.serialize(entry.data);
      if (encoded == null) {
        _logPersistenceError(
          'Skipping persistence for key $key: unsupported data type ${entry.data.runtimeType}',
          UnsupportedError('No serializer for ${entry.data.runtimeType}'),
        );
        return null;
      }

      final payload = <String, dynamic>{
        'data': encoded.payload,
        'dataType': encoded.typeKey,
        'createdAt': entry.createdAt.toIso8601String(),
        'lastAccessedAt': entry.lastAccessedAt.toIso8601String(),
        'accessCount': entry.accessCount,
        'staleTime': entry.staleTime.inMilliseconds,
        'cacheTime': entry.cacheTime.inMilliseconds,
        'referenceCount': entry.referenceCount,
        'isSecure': entry.isSecure,
        'expiresAt': entry.expiresAt?.toIso8601String(),
        'hasValue': entry.hasValue,
      };

      if (expectedType != null) {
        payload['queryKeyType'] = expectedType.toString();
      }

      return payload;
    } catch (error, stackTrace) {
      _logPersistenceError(
        'Failed to serialize cache entry for key $key',
        error,
        stackTrace,
      );
      return null;
    }
  }

  CacheEntry<dynamic>? _decodePersistedEntry(
    String key,
    Map<String, dynamic> json,
  ) {
    try {
      final typeKey = json['dataType'] as String?;
      final rawData = json['data'];
      final queryKeyTypeString = json['queryKeyType'] as String?;

      Type? queryKeyType;
      if (queryKeyTypeString != null) {
        try {
          queryKeyType = _parseTypeFromString(queryKeyTypeString);
        } catch (e) {
          _logPersistenceError(
            'Failed to parse queryKeyType $queryKeyTypeString for key $key',
            e,
          );
        }
      }

      final expectedType = _keyTypes[key] ?? queryKeyType;

      Object? data = _codecRegistry.deserialize(typeKey, rawData);

      if (data == null) {
        return null;
      }

      if (expectedType != null) {
        if (!_isTypeCompatible(data, expectedType)) {
          _logPersistenceError(
            'Type mismatch for key $key: expected $expectedType, got ${data.runtimeType}',
            ArgumentError('Type mismatch'),
          );
        }

        if (!_keyTypes.containsKey(key)) {
          _keyTypes[key] = expectedType;
        }
      } else if (queryKeyType != null && !_keyTypes.containsKey(key)) {
        _keyTypes[key] = queryKeyType;
      }

      final createdAt = DateTime.parse(json['createdAt'] as String);
      final lastAccessRaw = json['lastAccessedAt'] as String?;
      final lastAccessedAt =
          lastAccessRaw != null ? DateTime.parse(lastAccessRaw) : createdAt;
      final accessCountRaw = json['accessCount'];
      final accessCount = accessCountRaw is num ? accessCountRaw.toInt() : 0;
      final staleTimeRaw = json['staleTime'];
      final cacheTimeRaw = json['cacheTime'];
      final referenceCountRaw = json['referenceCount'];
      final hasValueRaw =
          json.containsKey('hasValue') ? json['hasValue'] : true;

      return CacheEntry<dynamic>(
        data: data,
        createdAt: createdAt,
        lastAccessedAt: lastAccessedAt,
        accessCount: accessCount,
        staleTime: staleTimeRaw is num
            ? Duration(milliseconds: staleTimeRaw.toInt())
            : config.defaultStaleTime,
        cacheTime: cacheTimeRaw is num
            ? Duration(milliseconds: cacheTimeRaw.toInt())
            : config.defaultCacheTime,
        referenceCount:
            referenceCountRaw is num ? referenceCountRaw.toInt() : 0,
        isSecure: json['isSecure'] as bool? ?? false,
        expiresAt: json['expiresAt'] != null
            ? DateTime.parse(json['expiresAt'] as String)
            : null,
        hasValue: hasValueRaw is bool ? hasValueRaw : true,
      );
    } catch (error, stackTrace) {
      _logPersistenceError(
        'Failed to deserialize cache entry for key $key',
        error,
        stackTrace,
      );
      return null;
    }
  }

  /// Persists a cache entry to disk.
  Future<void> _persistEntry(
    String key,
    CacheEntry entry,
    int version,
  ) async {
    if (!await _ensurePersistenceReady()) {
      return;
    }

    if (_entryVersions[key] != version) {
      return;
    }

    final expectedType = _keyTypes[key];
    final payload = _buildPersistedEntryPayload(key, entry, expectedType);
    if (payload == null) {
      return;
    }

    final encryptionKey = await _getValidEncryptionKey();

    final entryJson = jsonEncode(payload);
    final entryBytes = utf8.encode(entryJson);

    final encryptedData =
        await _encryptionProvider!.encrypt(entryBytes, encryptionKey);

    if (_entryVersions[key] != version) {
      return;
    }

    final persistenceExpiresAt =
        entry.expiresAt ?? entry.createdAt.add(entry.cacheTime);

    await _persistenceProvider!.persist(
      key,
      encryptedData,
      createdAt: entry.createdAt,
      expiresAt: persistenceExpiresAt,
    );
  }

  /// Removes an entry from persistence.
  Future<void> _removeFromPersistence(String key) async {
    if (!await _ensurePersistenceReady()) {
      return;
    }

    await _persistenceProvider!.remove(key);
  }

  /// Removes multiple entries from persistence.
  /// Clears all persisted data.
  Future<void> _clearPersistence() async {
    if (!await _ensurePersistenceReady()) {
      return;
    }

    await _persistenceProvider!.clear();
  }

  Future<String> _getValidEncryptionKey() async {
    return _encryptionKeyLock.synchronized(() async {
      try {
        var key = await _securityProvider!.getEncryptionKey();

        if (key == null || key.isEmpty) {
          key = await _securityProvider!.generateAndStoreKey();
        }

        if (!_encryptionProvider!.isValidKey(key)) {
          key = await _securityProvider!.generateAndStoreKey();
          if (!_encryptionProvider!.isValidKey(key)) {
            throw Exception('Generated encryption key is invalid');
          }
        }

        return key;
      } catch (error, stackTrace) {
        Error.throwWithStackTrace(error, stackTrace);
      }
    });
  }

  /// Loads persisted entries on initialization.
  Future<void> _loadPersistedEntries() async {
    if (!_persistenceReady) {
      return;
    }

    try {
      final encryptionKey = await _securityProvider!.getEncryptionKey();
      if (encryptionKey == null) {
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

            final entry = _decodePersistedEntry(key, entryMap);
            if (entry == null) {
              await _persistenceProvider!.remove(key);
              continue;
            }

            if (!entry.isExpired) {
              _entries[key] = entry;
              _entryVersions[key] = _nextEntryVersion();
            } else {
              await _persistenceProvider!.remove(key);
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

  void _queuePersistence(String key, CacheEntry entry, int version) {
    _enqueuePersistenceOperation(
      key,
      () => _persistEntry(key, entry, version),
      'Failed to persist cache entry for key $key',
    );
  }

  void _removePersistenceAsync(String key) {
    _enqueuePersistenceOperation(
      key,
      () => _removeFromPersistence(key),
      'Failed to remove persisted cache entry for key $key',
    );
  }

  void _clearPersistenceAsync() {
    _enqueueGlobalPersistenceOperation(
      () => _clearPersistence(),
      'Failed to clear persisted cache entries',
    );
  }

  void _enqueuePersistenceOperation(
    String key,
    Future<void> Function() task,
    String errorMessage,
  ) {
    final previous = _persistOperations[key];
    final base = (previous ?? Future<void>.value()).catchError((_) {});
    final operation = base.then((_) => task());
    final handled = operation.catchError((error, stackTrace) {
      _logPersistenceError(
        errorMessage,
        error,
        stackTrace,
      );
    });

    _persistOperations[key] = handled.whenComplete(() {
      if (_persistOperations[key] == handled) {
        _persistOperations.remove(key);
      }
    });
  }

  void _enqueueGlobalPersistenceOperation(
    Future<void> Function() task,
    String errorMessage,
  ) {
    final previous = _globalPersistenceOperation;
    final base = (previous ?? Future<void>.value()).catchError((_) {});
    final operation = base.then((_) => task());
    _globalPersistenceOperation = operation.catchError((error, stackTrace) {
      _logPersistenceError(
        errorMessage,
        error,
        stackTrace,
      );
    });
  }

  Future<bool> _ensurePersistenceReady() async {
    final initFuture = _persistenceInitFuture;
    if (initFuture != null) {
      try {
        await initFuture;
      } catch (_) {
        return false;
      }
    }
    return _persistenceReady;
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

  Type? _parseTypeFromString(String typeString) {
    try {
      final parts = typeString.split('<');
      final baseTypeName = parts[0].trim();

      final typeMap = <String, Type>{
        'String': String,
        'int': int,
        'double': double,
        'bool': bool,
        'List': List,
        'Map': Map,
        'Set': Set,
      };

      if (typeMap.containsKey(baseTypeName)) {
        return typeMap[baseTypeName];
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isTypeCompatible(Object data, Type expectedType) {
    if (expectedType == dynamic || expectedType == Object) {
      return true;
    }

    if (data.runtimeType == expectedType) {
      return true;
    }

    if (expectedType == num && (data is num)) {
      return true;
    }

    if (expectedType == List && (data is List)) {
      return true;
    }

    if (expectedType == Map && (data is Map)) {
      return true;
    }

    if (expectedType == Set && (data is Set)) {
      return true;
    }

    return false;
  }

  /// Extracts type information from a QueryKey if it's a TypedQueryKey.
  ///
  /// Returns the type stored in the TypedQueryKey, or null for non-typed keys.
  /// This method is available for future enhancements or type validation scenarios.
  // ignore: unused_element
  Type? _extractTypeFromQueryKey(dynamic queryKey) {
    if (queryKey is TypedQueryKey) {
      return queryKey.type;
    }
    return null;
  }

  Future<void> _disposePersistenceResources() async {
    final initFuture = _persistenceInitFuture;
    if (initFuture != null) {
      try {
        await initFuture;
      } catch (_) {}
    }

    final tasks = <Future<void>>[];

    final persistence = _persistenceProvider;
    if (persistence != null) {
      tasks.add(persistence.dispose());
    }

    final encryption = _encryptionProvider;
    if (encryption != null) {
      tasks.add(encryption.dispose());
    }

    if (tasks.isNotEmpty) {
      await Future.wait(tasks);
    }

    _persistenceProvider = null;
    _encryptionProvider = null;
    _securityProvider = null;
    _isInitialized = false;
  }
}
