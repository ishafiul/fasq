/// Represents a cached data entry with metadata for staleness and eviction.
///
/// Each cache entry stores the data along with timestamps and access counts
/// used for staleness detection and cache eviction policies.
class CacheEntry<T> {
  /// The cached data.
  final T data;

  /// When this data was fetched.
  final DateTime createdAt;

  /// When this data was last accessed.
  final DateTime lastAccessedAt;

  /// How many times this data has been accessed.
  final int accessCount;

  /// How long this data stays fresh.
  final Duration staleTime;

  /// How long inactive data stays in cache.
  final Duration cacheTime;

  /// Reference count for active queries using this data.
  final int referenceCount;

  const CacheEntry({
    required this.data,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.accessCount,
    required this.staleTime,
    required this.cacheTime,
    this.referenceCount = 0,
  });

  /// Creates a new cache entry with current timestamp.
  factory CacheEntry.create({
    required T data,
    required Duration staleTime,
    required Duration cacheTime,
  }) {
    final now = DateTime.now();
    return CacheEntry<T>(
      data: data,
      createdAt: now,
      lastAccessedAt: now,
      accessCount: 1,
      staleTime: staleTime,
      cacheTime: cacheTime,
    );
  }

  /// The age of this cache entry.
  Duration get age => DateTime.now().difference(createdAt);

  /// Whether the data is still fresh.
  bool get isFresh => age < staleTime;

  /// Whether the data is stale.
  bool get isStale => !isFresh;

  /// Whether the entry should be garbage collected.
  bool shouldGarbageCollect(DateTime now) {
    if (referenceCount > 0) return false;
    final inactiveTime = now.difference(lastAccessedAt);
    return inactiveTime > cacheTime;
  }

  /// Estimates the size of this entry in bytes.
  int estimateSize() {
    return _estimateDataSize(data);
  }

  int _estimateDataSize(dynamic value) {
    if (value == null) return 8;

    if (value is String) return value.length * 2;
    if (value is num) return 8;
    if (value is bool) return 1;

    if (value is List) {
      int size = 8;
      for (final item in value) {
        size += _estimateDataSize(item);
      }
      return size;
    }

    if (value is Map) {
      int size = 16;
      for (final entry in value.entries) {
        size += _estimateDataSize(entry.key);
        size += _estimateDataSize(entry.value);
      }
      return size;
    }

    return 64;
  }

  /// Creates a copy with updated metadata.
  CacheEntry<T> copyWith({
    T? data,
    DateTime? createdAt,
    DateTime? lastAccessedAt,
    int? accessCount,
    Duration? staleTime,
    Duration? cacheTime,
    int? referenceCount,
  }) {
    return CacheEntry<T>(
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      accessCount: accessCount ?? this.accessCount,
      staleTime: staleTime ?? this.staleTime,
      cacheTime: cacheTime ?? this.cacheTime,
      referenceCount: referenceCount ?? this.referenceCount,
    );
  }

  /// Creates a copy with updated access metadata.
  CacheEntry<T> withAccess() {
    return copyWith(
      lastAccessedAt: DateTime.now(),
      accessCount: accessCount + 1,
    );
  }

  @override
  String toString() {
    return 'CacheEntry<$T>(age: $age, accessCount: $accessCount, '
        'isFresh: $isFresh, refCount: $referenceCount)';
  }
}

