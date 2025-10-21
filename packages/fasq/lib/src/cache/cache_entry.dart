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

  /// Whether this entry contains sensitive data.
  final bool isSecure;

  /// When this secure entry expires (enforced TTL).
  final DateTime? expiresAt;

  const CacheEntry({
    required this.data,
    required this.createdAt,
    required this.lastAccessedAt,
    required this.accessCount,
    required this.staleTime,
    required this.cacheTime,
    this.referenceCount = 0,
    this.isSecure = false,
    this.expiresAt,
  });

  /// Creates a new cache entry with current timestamp.
  factory CacheEntry.create({
    required T data,
    required Duration staleTime,
    required Duration cacheTime,
    bool isSecure = false,
    Duration? maxAge,
  }) {
    final now = DateTime.now();
    return CacheEntry<T>(
      data: data,
      createdAt: now,
      lastAccessedAt: now,
      accessCount: 1,
      staleTime: staleTime,
      cacheTime: cacheTime,
      isSecure: isSecure,
      expiresAt: isSecure && maxAge != null ? now.add(maxAge) : null,
    );
  }

  /// The age of this cache entry.
  Duration get age => DateTime.now().difference(createdAt);

  /// Whether the data is still fresh.
  bool get isFresh => age < staleTime;

  /// Whether the data is stale.
  bool get isStale => !isFresh;

  /// Whether this secure entry has expired (TTL exceeded).
  bool get isExpired {
    if (!isSecure || expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  /// Whether the entry should be garbage collected.
  bool shouldGarbageCollect(DateTime now) {
    if (referenceCount > 0) return false;

    // Secure entries with TTL are strictly enforced
    if (isSecure && expiresAt != null) {
      return now.isAfter(expiresAt!);
    }

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
    bool? isSecure,
    DateTime? expiresAt,
  }) {
    return CacheEntry<T>(
      data: data ?? this.data,
      createdAt: createdAt ?? this.createdAt,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      accessCount: accessCount ?? this.accessCount,
      staleTime: staleTime ?? this.staleTime,
      cacheTime: cacheTime ?? this.cacheTime,
      referenceCount: referenceCount ?? this.referenceCount,
      isSecure: isSecure ?? this.isSecure,
      expiresAt: expiresAt ?? this.expiresAt,
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
        'isFresh: $isFresh, refCount: $referenceCount, '
        'isSecure: $isSecure, isExpired: $isExpired)';
  }
}
