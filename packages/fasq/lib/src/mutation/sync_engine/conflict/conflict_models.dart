import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_json.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:meta/meta.dart';
import 'package:fasq/src/mutation/sync_engine/conflict/conflict_policy.dart';

/// Transport-independent reason supplied by an execution adapter.
enum ConflictKind { staleWrite, duplicateCreate, missingResource, unknown }

/// Safe normalized conflict classification returned by an adapter.
@immutable
class ConflictClassification {
  /// Creates classification without transport-specific fields.
  factory ConflictClassification({
    required ConflictKind kind,
    required String messageKey,
  }) {
    final normalized = messageKey.trim();
    if (normalized.isEmpty) {
      throw const InvalidMutationPayloadException(
        'Conflict message key must not be empty',
      );
    }
    return ConflictClassification._(kind: kind, messageKey: normalized);
  }

  const ConflictClassification._({
    required this.kind,
    required this.messageKey,
  });

  factory ConflictClassification.fromJson(Map<String, Object?> json) {
    final kind = json['kind'];
    final messageKey = json['messageKey'];
    if (kind is! String || messageKey is! String) {
      throw const InvalidMutationPayloadException(
        'Invalid conflict classification payload',
      );
    }
    final parsedKind = ConflictKind.values.where((value) => value.name == kind);
    if (parsedKind.isEmpty) {
      throw InvalidMutationPayloadException('Unknown conflict kind: $kind');
    }
    return ConflictClassification(
      kind: parsedKind.single,
      messageKey: messageKey,
    );
  }

  final ConflictKind kind;
  final String messageKey;

  Map<String, Object?> toJson() => {
    'kind': kind.name,
    'messageKey': messageKey,
  };
}

/// Immutable, restart-safe evidence for one conflict.
@immutable
class ConflictEvidence {
  /// Creates evidence while validating optional adapter-provided snapshots.
  ConflictEvidence({
    required MutationOperation operation,
    required this.classification,
    required this.occurredAt,
    this.expectedPrecondition,
    this.observedPrecondition,
    Object? latestServerSnapshot,
    Object? projectionImpact,
  }) : operation = _copyOperation(operation),
       latestServerSnapshot = _freezeJson(latestServerSnapshot),
       projectionImpact = _freezeJson(projectionImpact);

  factory ConflictEvidence.fromJson(Map<String, Object?> json) {
    final operation = json['operation'];
    final classification = json['classification'];
    final occurredAt = json['occurredAt'];
    if (operation is! Map<Object?, Object?> ||
        classification is! Map<Object?, Object?> ||
        occurredAt is! String) {
      throw const InvalidMutationPayloadException(
        'Invalid conflict evidence payload',
      );
    }
    final expected = json['expectedPrecondition'];
    final observed = json['observedPrecondition'];
    return ConflictEvidence(
      operation: MutationOperation.fromJson(_objectMap(operation)),
      classification: ConflictClassification.fromJson(
        _objectMap(classification),
      ),
      occurredAt: _parseDate(occurredAt),
      expectedPrecondition: expected == null
          ? null
          : ConflictPrecondition.fromJson(_objectMap(expected)),
      observedPrecondition: observed == null
          ? null
          : ConflictPrecondition.fromJson(_objectMap(observed)),
      latestServerSnapshot: json['latestServerSnapshot'],
      projectionImpact: json['projectionImpact'],
    );
  }

  final MutationOperation operation;
  final ConflictClassification classification;
  final DateTime occurredAt;
  final ConflictPrecondition? expectedPrecondition;
  final ConflictPrecondition? observedPrecondition;
  final Object? latestServerSnapshot;
  final Object? projectionImpact;

  OperationId get operationId => operation.operationId;
  MutationKey get mutationKey => operation.mutationKey;
  IdempotencyKey get idempotencyKey => operation.idempotencyKey;
  AuthScope? get authScope => operation.authScope;

  Map<String, Object?> toJson() => {
    'operation': operation.toJson(),
    'classification': classification.toJson(),
    'occurredAt': occurredAt.toIso8601String(),
    'expectedPrecondition': expectedPrecondition?.toJson(),
    'observedPrecondition': observedPrecondition?.toJson(),
    'latestServerSnapshot': latestServerSnapshot,
    'projectionImpact': projectionImpact,
  };
}

class ConflictRepairException extends MutationContractException {
  const ConflictRepairException(super.message);
}

class ConflictAuthScopeMismatchException extends ConflictRepairException {
  const ConflictAuthScopeMismatchException()
    : super('Current auth scope does not match conflict scope');
}

DateTime _parseDate(String value) {
  try {
    return DateTime.parse(value);
  } on FormatException {
    throw const InvalidMutationPayloadException(
      'Invalid conflict evidence timestamp',
    );
  }
}

Object? _freezeJson(Object? value) {
  validateJsonValue(value);
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(_freezeJson));
  }
  if (value is Map<Object?, Object?>) {
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw const InvalidMutationPayloadException(
          'Conflict JSON object keys must be strings',
        );
      }
      result[entry.key! as String] = _freezeJson(entry.value);
    }
    return Map<String, Object?>.unmodifiable(result);
  }
  return value;
}

MutationOperation _copyOperation(MutationOperation operation) {
  return MutationOperation(
    operationId: operation.operationId,
    mutationKey: operation.mutationKey,
    variables: _freezeJson(operation.variables),
    createdAt: operation.createdAt,
    idempotencyKey: operation.idempotencyKey,
    lineageId: operation.lineageId,
    authPolicy: operation.authPolicy,
    conflictPolicy: operation.conflictPolicy,
    conflictPrecondition: operation.conflictPrecondition,
    authScope: operation.authScope,
    state: operation.state,
    priority: operation.priority,
    dependencies: operation.dependencies,
    projections: operation.projections,
    attemptCount: operation.attemptCount,
    maxAttempts: operation.maxAttempts,
    maxAge: operation.maxAge,
    nextRunAt: operation.nextRunAt,
    rateLimitBucket: operation.rateLimitBucket,
    lastAttemptAt: operation.lastAttemptAt,
  );
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const InvalidMutationPayloadException('Expected a JSON object');
  }
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) {
      throw const InvalidMutationPayloadException(
        'JSON object keys must be strings',
      );
    }
    result[entry.key! as String] = entry.value;
  }
  return result;
}
