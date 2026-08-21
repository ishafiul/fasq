/// Base error for unified Fasq bootstrap failures.
class FasqException implements Exception {
  /// Creates a bootstrap error.
  const FasqException(this.message, [this.cause]);

  /// Safe, actionable description.
  final String message;

  /// Original failure, when available.
  final Object? cause;

  @override
  String toString() => 'FasqException: $message';
}

/// Invalid or conflicting bootstrap configuration.
class FasqConfigurationException extends FasqException {
  /// Creates a configuration error.
  const FasqConfigurationException(super.message);
}

/// Security or persistence startup failed.
class FasqInitializationException extends FasqException {
  /// Creates an initialization error.
  const FasqInitializationException(super.message, [super.cause]);
}

/// A required local storage operation failed.
class FasqStorageException extends FasqException {
  /// Creates a storage error.
  const FasqStorageException(super.message, [super.cause]);
}

/// A resource could not be acquired because another owner is active.
class FasqOwnershipException extends FasqException {
  /// Creates an ownership error.
  const FasqOwnershipException(super.message, [super.cause]);
}

/// Mutation registration failed before replay could start.
class FasqMutationRegistrationException extends FasqException {
  /// Creates a registration error.
  const FasqMutationRegistrationException(super.message, [super.cause]);
}

/// A durable store could not be opened or recovered.
class FasqRecoveryException extends FasqException {
  /// Creates a recovery error.
  const FasqRecoveryException(super.message, [super.cause]);
}

/// An operation was requested after the Fasq instance closed.
class FasqDisposedException extends FasqException {
  /// Creates a disposed-instance error.
  const FasqDisposedException()
    : super('Fasq instance has already been disposed');
}

/// Key rotation cannot proceed while durable work is pending.
class FasqKeyRotationBlockedException extends FasqException {
  /// Creates a key-rotation guard error.
  const FasqKeyRotationBlockedException()
    : super('Encryption key rotation is blocked while mutations are pending');
}
