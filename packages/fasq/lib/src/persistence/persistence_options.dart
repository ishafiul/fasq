import 'cache_data_codec.dart';

/// Configuration options for cache persistence.
///
/// Controls whether and how cache data is persisted to disk,
/// including encryption settings and garbage collection intervals.
class PersistenceOptions {
  /// Whether persistence is enabled.
  ///
  /// When false, cache data is only stored in memory.
  final bool enabled;

  /// How often to run garbage collection on persisted data.
  ///
  /// Defaults to 5 minutes if not specified.
  final Duration? gcInterval;

  final CacheDataCodecRegistry codecRegistry;

  const PersistenceOptions({
    this.enabled = false,
    this.gcInterval,
    CacheDataCodecRegistry? codecRegistry,
  }) : codecRegistry = codecRegistry ?? const CacheDataCodecRegistry();

  /// Creates a copy with updated values.
  PersistenceOptions copyWith({
    bool? enabled,
    Duration? gcInterval,
    CacheDataCodecRegistry? codecRegistry,
  }) {
    return PersistenceOptions(
      enabled: enabled ?? this.enabled,
      gcInterval: gcInterval ?? this.gcInterval,
      codecRegistry: codecRegistry ?? this.codecRegistry,
    );
  }

  @override
  String toString() {
    return 'PersistenceOptions(enabled: $enabled, gcInterval: $gcInterval, codecs: ${codecRegistry.serializers.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PersistenceOptions &&
        other.enabled == enabled &&
        other.gcInterval == gcInterval &&
        other.codecRegistry == codecRegistry;
  }

  @override
  int get hashCode {
    return Object.hash(enabled, gcInterval, codecRegistry);
  }
}
