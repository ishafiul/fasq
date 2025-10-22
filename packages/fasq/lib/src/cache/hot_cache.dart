/// A hot cache entry that tracks access patterns and frequency.
class _HotEntry<T> {
  final T value;
  DateTime lastAccess;
  int accessCount;
  final DateTime createdAt;

  _HotEntry({
    required this.value,
    required this.lastAccess,
    this.accessCount = 1,
  }) : createdAt = DateTime.now();

  /// Update access information
  void recordAccess() {
    lastAccess = DateTime.now();
    accessCount++;
  }

  /// Create a copy with updated access information
  _HotEntry<T> withAccess() {
    return _HotEntry<T>(
      value: value,
      lastAccess: DateTime.now(),
      accessCount: accessCount + 1,
    );
  }
}

/// A fast-access cache for frequently used items with LRU eviction.
///
/// Provides O(1) access time for hot items and automatically manages
/// promotion and eviction based on access patterns.
class HotCache<T> {
  final int maxSize;
  final Map<String, _HotEntry<T>> _entries = {};
  final List<String> _accessOrder = []; // LRU list (most recent at end)

  /// Create a hot cache with the specified maximum size
  HotCache({this.maxSize = 50}) {
    assert(maxSize > 0, 'maxSize must be greater than 0');
  }

  /// Get a value from the hot cache
  ///
  /// Returns null if the key is not found or if the entry has been evicted.
  T? get(String key) {
    final entry = _entries[key];
    if (entry == null) return null;

    // Update access information
    entry.recordAccess();
    _updateAccessOrder(key);

    return entry.value;
  }

  /// Put a value into the hot cache
  ///
  /// If the cache is full, the least recently used item will be evicted.
  void put(String key, T value) {
    if (_entries.containsKey(key)) {
      // Update existing entry
      _entries[key]!.recordAccess();
      _updateAccessOrder(key);
      return;
    }

    // Check if we need to evict
    if (_entries.length >= maxSize) {
      _evictLeastRecentlyUsed();
    }

    // Add new entry
    final entry = _HotEntry<T>(
      value: value,
      lastAccess: DateTime.now(),
    );

    _entries[key] = entry;
    _accessOrder.add(key);
  }

  /// Remove a specific key from the hot cache
  void remove(String key) {
    final entry = _entries.remove(key);
    if (entry != null) {
      _accessOrder.remove(key);
    }
  }

  /// Clear all entries from the hot cache
  void clear() {
    _entries.clear();
    _accessOrder.clear();
  }

  /// Check if the hot cache contains a key
  bool containsKey(String key) => _entries.containsKey(key);

  /// Get the number of entries in the hot cache
  int get length => _entries.length;

  /// Whether the hot cache is empty
  bool get isEmpty => _entries.isEmpty;

  /// Whether the hot cache is full
  bool get isFull => _entries.length >= maxSize;

  /// Get all keys in the hot cache
  Iterable<String> get keys => _entries.keys;

  /// Get all values in the hot cache
  Iterable<T> get values => _entries.values.map((e) => e.value);

  /// Get access statistics for a specific key
  HotCacheStats? getStats(String key) {
    final entry = _entries[key];
    if (entry == null) return null;

    return HotCacheStats(
      accessCount: entry.accessCount,
      lastAccess: entry.lastAccess,
      age: DateTime.now().difference(entry.createdAt),
    );
  }

  /// Get overall cache statistics
  HotCacheOverallStats getOverallStats() {
    if (_entries.isEmpty) {
      return HotCacheOverallStats(
        totalEntries: 0,
        averageAccessCount: 0.0,
        totalAccesses: 0,
        oldestEntry: null,
        newestEntry: null,
      );
    }

    final accessCounts = _entries.values.map((e) => e.accessCount).toList();
    final totalAccesses = accessCounts.fold(0, (sum, count) => sum + count);
    final averageAccessCount = totalAccesses / _entries.length;

    DateTime? oldestEntry;
    DateTime? newestEntry;

    for (final entry in _entries.values) {
      if (oldestEntry == null || entry.lastAccess.isBefore(oldestEntry)) {
        oldestEntry = entry.lastAccess;
      }
      if (newestEntry == null || entry.lastAccess.isAfter(newestEntry)) {
        newestEntry = entry.lastAccess;
      }
    }

    return HotCacheOverallStats(
      totalEntries: _entries.length,
      averageAccessCount: averageAccessCount,
      totalAccesses: totalAccesses,
      oldestEntry: oldestEntry,
      newestEntry: newestEntry,
    );
  }

  /// Update the access order for a key (move to end of LRU list)
  void _updateAccessOrder(String key) {
    _accessOrder.remove(key);
    _accessOrder.add(key);
  }

  /// Evict the least recently used item
  void _evictLeastRecentlyUsed() {
    if (_accessOrder.isNotEmpty) {
      final lruKey = _accessOrder.removeAt(0);
      _entries.remove(lruKey);
    }
  }

  /// Promote an item to the hot cache if it meets the criteria
  ///
  /// This method is called by the main cache when an item is accessed
  /// frequently enough to warrant promotion.
  bool shouldPromote(String key, int accessCount, {int threshold = 3}) {
    if (containsKey(key)) return false; // Already in hot cache
    if (accessCount < threshold) return false; // Not accessed enough
    if (isFull) return true; // Always promote if cache is full (will evict)

    return true;
  }
}

/// Statistics for a specific hot cache entry
class HotCacheStats {
  final int accessCount;
  final DateTime lastAccess;
  final Duration age;

  const HotCacheStats({
    required this.accessCount,
    required this.lastAccess,
    required this.age,
  });

  @override
  String toString() {
    return 'HotCacheStats(accesses: $accessCount, lastAccess: $lastAccess, age: ${age.inSeconds}s)';
  }
}

/// Overall statistics for the hot cache
class HotCacheOverallStats {
  final int totalEntries;
  final double averageAccessCount;
  final int totalAccesses;
  final DateTime? oldestEntry;
  final DateTime? newestEntry;

  const HotCacheOverallStats({
    required this.totalEntries,
    required this.averageAccessCount,
    required this.totalAccesses,
    required this.oldestEntry,
    required this.newestEntry,
  });

  /// Hit rate based on access patterns
  double get hitRate =>
      totalEntries > 0 ? averageAccessCount / totalEntries : 0.0;

  /// Cache utilization percentage
  double get utilizationPercentage =>
      (totalEntries / 50) * 100; // Assuming max size of 50

  @override
  String toString() {
    return 'HotCacheOverallStats('
        'entries: $totalEntries, '
        'avgAccesses: ${averageAccessCount.toStringAsFixed(1)}, '
        'totalAccesses: $totalAccesses, '
        'hitRate: ${hitRate.toStringAsFixed(2)})';
  }
}
