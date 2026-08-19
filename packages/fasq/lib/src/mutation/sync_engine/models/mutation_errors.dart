/// Categories used to classify expected mutation outcomes.
enum MutationFailureCategory {
  /// Network or local connectivity failure.
  connectivity,

  /// Request or operation exceeded its time budget.
  timeout,

  /// Adapter or service rate limit was reached.
  rateLimit,

  /// Credentials are missing, expired, or invalid.
  authentication,

  /// Current identity lacks permission for the operation.
  authorization,

  /// Server or local state conflicts with the operation.
  conflict,

  /// Variables or result payload failed validation.
  payload,

  /// Domain operation rejected the requested business action.
  business,

  /// Runtime executor could not be invoked.
  executor,

  /// Durable storage operation failed.
  storage,

  /// Stored contract needs migration before execution.
  migration,

  /// Failure has no more specific normalized category.
  unknown,
}

/// Safe, transport-agnostic failure metadata for durable operation state.
class MutationFailure {
  /// Creates normalized failure metadata.
  const MutationFailure({
    required this.category,
    required this.messageKey,
    required this.retryable,
    required this.repairable,
  });

  /// Normalized failure category.
  final MutationFailureCategory category;

  /// Stable safe message key for application presentation.
  final String messageKey;

  /// Whether the adapter permits automatic retry.
  final bool retryable;

  /// Whether an explicit repair action is permitted.
  final bool repairable;
}

/// Base error for invalid or unavailable durable mutation contracts.
class MutationContractException implements Exception {
  /// Creates a contract exception.
  const MutationContractException(this.message);

  /// Safe diagnostic message.
  final String message;

  @override
  String toString() => 'MutationContractException: $message';
}

/// Raised when a mutation payload is not JSON-safe or cannot be decoded.
class InvalidMutationPayloadException extends MutationContractException {
  /// Creates an invalid-payload exception.
  const InvalidMutationPayloadException(super.message);
}

/// Raised when an executor result cannot be durably encoded.
class InvalidMutationResultException extends MutationContractException {
  /// Creates an invalid-result exception.
  const InvalidMutationResultException()
    : super('Mutation result could not be encoded safely');
}

/// Raised when a persisted key has no registered codec or executor.
class UnknownMutationKeyException extends MutationContractException {
  /// Creates an unknown-key exception.
  const UnknownMutationKeyException(String key)
    : super('No mutation registration exists for $key');
}

/// Raised when a duplicate registration would make replay ambiguous.
class DuplicateMutationRegistrationException extends MutationContractException {
  /// Creates a duplicate-registration exception.
  const DuplicateMutationRegistrationException(String key)
    : super('A mutation registration already exists for $key');
}

/// Raised when persisted operation state contains an unknown value.
class UnknownMutationStateException extends MutationContractException {
  /// Creates an unknown-state exception.
  const UnknownMutationStateException(String state)
    : super('Unknown mutation operation state: $state');
}
