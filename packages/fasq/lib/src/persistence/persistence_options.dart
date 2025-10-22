/// Configuration options for cache persistence.
///
/// Controls whether and how cache data is persisted to disk,
/// including encryption settings and garbage collection intervals.
class PersistenceOptions {
  /// Whether persistence is enabled.
  ///
  /// When false, cache data is only stored in memory.
  final bool enabled;

  /// Whether persisted data should be encrypted.
  ///
  /// When true, data is encrypted using AES-GCM before being written to disk.
  /// Requires [encryptionKey] to be provided or auto-generated.
  ///
  /// @deprecated Use SecurityPlugin instead. This will be removed in a future version.
  @Deprecated(
      'Use SecurityPlugin instead. This will be removed in a future version.')
  final bool encrypt;

  /// The encryption key for encrypting/decrypting persisted data.
  ///
  /// If null and [encrypt] is true, a key will be auto-generated and stored
  /// securely using platform-specific secure storage.
  ///
  /// @deprecated Use SecurityPlugin instead. This will be removed in a future version.
  @Deprecated(
      'Use SecurityPlugin instead. This will be removed in a future version.')
  final String? encryptionKey;

  /// How often to run garbage collection on persisted data.
  ///
  /// Defaults to 5 minutes if not specified.
  final Duration? gcInterval;

  const PersistenceOptions({
    this.enabled = false,
    this.encrypt = false,
    this.encryptionKey,
    this.gcInterval,
  });

  /// Creates a copy with updated values.
  PersistenceOptions copyWith({
    bool? enabled,
    bool? encrypt,
    String? encryptionKey,
    Duration? gcInterval,
  }) {
    return PersistenceOptions(
      enabled: enabled ?? this.enabled,
      encrypt: encrypt ?? this.encrypt,
      encryptionKey: encryptionKey ?? this.encryptionKey,
      gcInterval: gcInterval ?? this.gcInterval,
    );
  }

  @override
  String toString() {
    return 'PersistenceOptions(enabled: $enabled, encrypt: $encrypt, '
        'hasEncryptionKey: ${encryptionKey != null}, gcInterval: $gcInterval)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PersistenceOptions &&
        other.enabled == enabled &&
        other.encrypt == encrypt &&
        other.encryptionKey == encryptionKey &&
        other.gcInterval == gcInterval;
  }

  @override
  int get hashCode {
    return Object.hash(enabled, encrypt, encryptionKey, gcInterval);
  }
}
