/// Stable categories for durable outbox failures.
enum DurableOutboxErrorCode {
  /// The store could not read or write its files.
  storage,

  /// Encryption or key management failed.
  encryption,

  /// The stored schema cannot be executed by this version of Fasq.
  migrationRequired,

  /// The primary and last-known-good copies failed validation.
  storageCorrupt,

  /// Another owner currently holds the store lease.
  ownership,

  /// A caller attempted to commit against an old generation.
  generationConflict,

  /// The requested mutation would exceed configured limits.
  queueCapacityExceeded,

  /// A credential-like field was found in durable data.
  credentialRejected,
}

/// Safe, inspectable state left after a store cannot be opened.
class DurableOutboxRecovery {
  /// Creates a recovery state without retaining payloads or exception details.
  const DurableOutboxRecovery(this.code, this.message);

  /// Stable failure category suitable for application logic.
  final DurableOutboxErrorCode code;

  /// Redacted guidance key/message for UI and telemetry.
  final String message;
}

/// Base exception for durable outbox operations.
class DurableOutboxException implements Exception {
  /// Creates a safe, public-facing outbox exception.
  const DurableOutboxException(this.code, this.message);

  /// Stable error category suitable for application logic.
  final DurableOutboxErrorCode code;

  /// Redacted diagnostic message. It never contains variables or secrets.
  final String message;

  @override
  String toString() => 'DurableOutboxException($code): $message';
}

/// Raised when the store is owned by another process or isolate.
class OutboxOwnershipException extends DurableOutboxException {
  /// Creates an ownership failure.
  const OutboxOwnershipException()
    : super(
        DurableOutboxErrorCode.ownership,
        'The durable outbox is owned by another worker',
      );
}

/// Raised when a generation compare-and-swap check fails.
class OutboxGenerationConflictException extends DurableOutboxException {
  /// Creates a stale-writer failure.
  const OutboxGenerationConflictException()
    : super(
        DurableOutboxErrorCode.generationConflict,
        'The durable outbox changed before this transaction committed',
      );
}

/// Raised when the stored data requires a newer or unavailable migration.
class OutboxMigrationRequiredException extends DurableOutboxException {
  /// Creates a migration-required failure.
  const OutboxMigrationRequiredException()
    : super(
        DurableOutboxErrorCode.migrationRequired,
        'The durable outbox requires an unavailable schema migration',
      );
}

/// Raised when no validated store copy remains available.
class OutboxCorruptException extends DurableOutboxException {
  /// Creates a corruption failure.
  const OutboxCorruptException()
    : super(
        DurableOutboxErrorCode.storageCorrupt,
        'The durable outbox is corrupt and requires explicit recovery',
      );
}

/// Raised when encryption cannot safely protect or recover the store.
class OutboxEncryptionException extends DurableOutboxException {
  /// Creates an encryption failure.
  const OutboxEncryptionException()
    : super(
        DurableOutboxErrorCode.encryption,
        'The durable outbox encryption key is unavailable or invalid',
      );
}

/// Raised when a configured capacity limit would be exceeded.
class OutboxCapacityExceededException extends DurableOutboxException {
  /// Creates a capacity rejection.
  const OutboxCapacityExceededException()
    : super(
        DurableOutboxErrorCode.queueCapacityExceeded,
        'The durable outbox capacity limit would be exceeded',
      );
}

/// Raised when durable data contains a credential-like field.
class OutboxCredentialRejectedException extends DurableOutboxException {
  /// Creates a credential rejection.
  const OutboxCredentialRejectedException()
    : super(
        DurableOutboxErrorCode.credentialRejected,
        'Credential-like data cannot be persisted in the durable outbox',
      );
}
