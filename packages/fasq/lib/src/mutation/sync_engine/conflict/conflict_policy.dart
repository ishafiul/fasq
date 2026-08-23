import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:meta/meta.dart';

/// Explicit stale-write protection selected for one mutation.
enum ConflictPolicy {
  /// Execute without compare-and-set protection.
  none,

  /// Require an opaque precondition before enqueue and replay.
  required
  ;

  /// Validates the policy and its persisted precondition together.
  void validate(ConflictPrecondition? precondition) {
    if (this == ConflictPolicy.required && precondition == null) {
      throw const MissingConflictPreconditionException();
    }
    if (this == ConflictPolicy.none && precondition != null) {
      throw const UnexpectedConflictPreconditionException();
    }
  }
}

/// Opaque revision, version, or ETag-like compare-and-set token.
@immutable
class ConflictPrecondition {
  /// Creates a non-empty opaque token. Fasq never parses its contents.
  factory ConflictPrecondition(String token) {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      throw const InvalidMutationPayloadException(
        'Conflict precondition must not be empty',
      );
    }
    return ConflictPrecondition._(normalized);
  }

  const ConflictPrecondition._(this.token);

  /// Serialized opaque token.
  final String token;

  /// Decodes a persisted token.
  factory ConflictPrecondition.fromJson(Map<String, Object?> json) {
    final token = json['token'];
    if (token is! String) {
      throw const InvalidMutationPayloadException(
        'Invalid conflict precondition payload',
      );
    }
    return ConflictPrecondition(token);
  }

  /// Encodes this token without interpreting its contents.
  Map<String, Object?> toJson() => {'token': token};

  @override
  bool operator ==(Object other) =>
      other is ConflictPrecondition && token == other.token;

  @override
  int get hashCode => token.hashCode;
}

/// Raised when required compare-and-set protection has no token.
class MissingConflictPreconditionException extends MutationContractException {
  /// Creates a missing-precondition error.
  const MissingConflictPreconditionException()
    : super('Required conflict precondition is missing');
}

/// Raised when a token is supplied for a mutation without protection.
class UnexpectedConflictPreconditionException
    extends MutationContractException {
  /// Creates an unexpected-precondition error.
  const UnexpectedConflictPreconditionException()
    : super('Conflict precondition supplied while policy is none');
}
