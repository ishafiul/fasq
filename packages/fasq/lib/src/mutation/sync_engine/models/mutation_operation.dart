import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_json.dart';
import 'package:meta/meta.dart';

/// Durable lifecycle state for one queued mutation operation.
enum MutationOperationState {
  /// Operation is persisted and eligible for scheduling.
  pending,

  /// Operation executor is currently running.
  running,

  /// Operation waits for its retry time.
  retryScheduled,

  /// Operation is paused by lifecycle or policy.
  paused,

  /// Operation waits for authentication readiness or reauthentication.
  authBlocked,

  /// Operation was denied by the current authorization policy and needs
  /// explicit repair or user action before it can run again.
  authorizationBlocked,

  /// Operation is retained for its original scope after identity change.
  quarantined,

  /// Operation cannot run until a dependency or repair is resolved.
  blocked,

  /// Operation completed successfully.
  succeeded,

  /// Operation failed permanently and needs user/application action.
  failedTerminal,

  /// Execution result is ambiguous and must not be blindly replayed.
  unknownOutcome,

  /// Operation was intentionally removed from active work.
  discarded,

  /// Stored contract version needs migration.
  migrationRequired,

  /// Durable state failed integrity checks.
  storageCorrupt,
}

/// Parses a persisted operation state without silently accepting unknown data.
MutationOperationState parseMutationOperationState(String value) {
  for (final state in MutationOperationState.values) {
    if (state.name == value) return state;
  }
  throw UnknownMutationStateException(value);
}

/// JSON-safe durable contract for a queued mutation operation.
@immutable
class MutationOperation {
  /// Creates an operation contract.
  factory MutationOperation({
    required OperationId operationId,
    required MutationKey mutationKey,
    required Object? variables,
    required DateTime createdAt,
    required IdempotencyKey idempotencyKey,
    required LineageId lineageId,
    required AuthPolicy authPolicy,
    required MutationOperationState state,
    int priority = 0,
    AuthScope? authScope,
    List<MutationDependency> dependencies = const <MutationDependency>[],
    List<MutationProjectionDescriptor> projections =
        const <MutationProjectionDescriptor>[],
    int attemptCount = 0,
    int maxAttempts = 5,
    Duration maxAge = const Duration(days: 30),
    DateTime? nextRunAt,
    String? rateLimitBucket,
    DateTime? lastAttemptAt,
  }) {
    if ((authPolicy == AuthPolicy.required) != (authScope != null)) {
      throw ArgumentError.value(
        authScope,
        'authScope',
        'must be present only for required auth policy',
      );
    }
    if (attemptCount < 0) {
      throw ArgumentError.value(
        attemptCount,
        'attemptCount',
        'must not be negative',
      );
    }
    if (maxAttempts < 1) {
      throw ArgumentError.value(maxAttempts, 'maxAttempts', 'must be positive');
    }
    if (maxAge <= Duration.zero) {
      throw ArgumentError.value(maxAge, 'maxAge', 'must be positive');
    }
    validateJsonValue(variables, 'variables');
    return MutationOperation._(
      operationId: operationId,
      mutationKey: mutationKey,
      variables: variables,
      createdAt: createdAt,
      idempotencyKey: idempotencyKey,
      lineageId: lineageId,
      authPolicy: authPolicy,
      state: state,
      priority: priority,
      authScope: authScope,
      dependencies: List.unmodifiable(dependencies),
      projections: List.unmodifiable(projections),
      attemptCount: attemptCount,
      maxAttempts: maxAttempts,
      maxAge: maxAge,
      nextRunAt: nextRunAt,
      rateLimitBucket: rateLimitBucket,
      lastAttemptAt: lastAttemptAt,
    );
  }

  const MutationOperation._({
    required this.operationId,
    required this.mutationKey,
    required this.variables,
    required this.createdAt,
    required this.idempotencyKey,
    required this.lineageId,
    required this.authPolicy,
    required this.state,
    required this.priority,
    required this.dependencies,
    required this.projections,
    required this.attemptCount,
    required this.maxAttempts,
    required this.maxAge,
    required this.nextRunAt,
    required this.rateLimitBucket,
    required this.lastAttemptAt,
    this.authScope,
  });

  /// Recreates an operation from a validated JSON-safe map.
  factory MutationOperation.fromJson(Map<String, Object?> json) {
    final operationId = json['operationId'];
    final mutationKey = json['mutationKey'];
    final variables = json['variables'];
    final createdAt = json['createdAt'];
    final idempotencyKey = json['idempotencyKey'];
    final lineageId = json['lineageId'];
    final authPolicy = json['authPolicy'];
    final state = json['state'];
    final priority = json['priority'];
    final attemptCount = json['attemptCount'];
    final maxAttempts = json['maxAttempts'];
    final maxAgeMs = json['maxAgeMs'];
    final nextRunAt = json['nextRunAt'];
    final rateLimitBucket = json['rateLimitBucket'];
    final lastAttemptAt = json['lastAttemptAt'];
    if (operationId is! String ||
        mutationKey is! Map<Object?, Object?> ||
        createdAt is! String ||
        idempotencyKey is! String ||
        lineageId is! String ||
        authPolicy is! String ||
        state is! String ||
        (priority != null && priority is! int) ||
        (attemptCount != null && attemptCount is! int) ||
        (maxAttempts != null && maxAttempts is! int) ||
        (maxAgeMs != null && maxAgeMs is! int) ||
        (nextRunAt != null && nextRunAt is! String) ||
        (rateLimitBucket != null && rateLimitBucket is! String) ||
        (lastAttemptAt != null && lastAttemptAt is! String)) {
      throw const InvalidMutationPayloadException(
        'Invalid mutation operation payload',
      );
    }
    validateJsonValue(json, 'operation');

    final scope = json['authScope'];
    final parsedAuthPolicy = _parseAuthPolicy(authPolicy);
    final parsedScope = scope == null
        ? null
        : AuthScope.fromJson(_asObjectMap(scope));
    if ((parsedAuthPolicy == AuthPolicy.required) != (parsedScope != null)) {
      throw const InvalidMutationPayloadException(
        'Auth policy and auth scope do not match',
      );
    }
    final dependencies = _decodeList(
      json['dependencies'],
      'dependencies',
      MutationDependency.fromJson,
    );
    final projections = _decodeList(
      json['projections'],
      'projections',
      MutationProjectionDescriptor.fromJson,
    );

    return MutationOperation(
      operationId: OperationId(operationId),
      mutationKey: MutationKey.fromJson(_asObjectMap(mutationKey)),
      variables: variables,
      createdAt: _parseCreatedAt(createdAt),
      idempotencyKey: IdempotencyKey(idempotencyKey),
      lineageId: LineageId(lineageId),
      authPolicy: parsedAuthPolicy,
      state: parseMutationOperationState(state),
      priority: priority as int? ?? 0,
      attemptCount: attemptCount as int? ?? 0,
      maxAttempts: maxAttempts as int? ?? 5,
      maxAge: Duration(
        milliseconds:
            maxAgeMs as int? ?? const Duration(days: 30).inMilliseconds,
      ),
      nextRunAt: _parseOptionalDate(nextRunAt as String?),
      rateLimitBucket: rateLimitBucket as String?,
      lastAttemptAt: _parseOptionalDate(lastAttemptAt as String?),
      authScope: parsedScope,
      dependencies: dependencies,
      projections: projections,
    );
  }

  /// Durable operation occurrence identity.
  final OperationId operationId;

  /// Logical operation registration key.
  final MutationKey mutationKey;

  /// JSON-safe encoded variables, not a runtime model or closure.
  final Object? variables;

  /// Enqueue timestamp.
  final DateTime createdAt;

  /// Stable key reused for automatic retries and restarts.
  final IdempotencyKey idempotencyKey;

  /// Lineage shared by the original operation and explicit repairs.
  final LineageId lineageId;

  /// Authentication requirement selected at enqueue.
  final AuthPolicy authPolicy;

  /// Exact captured scope for authenticated work.
  final AuthScope? authScope;

  /// Parent operation bindings.
  final List<MutationDependency> dependencies;

  /// Explicit cache projection plans.
  final List<MutationProjectionDescriptor> projections;

  /// Current durable lifecycle state.
  final MutationOperationState state;

  /// Deterministic scheduling priority. Higher values run first.
  final int priority;

  /// Number of executor invocations already started.
  final int attemptCount;

  /// Maximum executor invocations allowed for this operation.
  final int maxAttempts;

  /// Maximum age measured from [createdAt].
  final Duration maxAge;

  /// Absolute time at which delayed work may run again.
  final DateTime? nextRunAt;

  /// Stable adapter-defined fairness bucket.
  final String? rateLimitBucket;

  /// Timestamp of the most recent executor invocation.
  final DateTime? lastAttemptAt;

  /// Returns this operation with selected durable fields replaced.
  MutationOperation copyWith({
    Object? variables = _unset,
    MutationOperationState? state,
    int? priority,
    int? attemptCount,
    int? maxAttempts,
    Duration? maxAge,
    Object? nextRunAt = _unset,
    Object? rateLimitBucket = _unset,
    Object? lastAttemptAt = _unset,
  }) {
    return MutationOperation(
      operationId: operationId,
      mutationKey: mutationKey,
      variables: identical(variables, _unset) ? this.variables : variables,
      createdAt: createdAt,
      idempotencyKey: idempotencyKey,
      lineageId: lineageId,
      authPolicy: authPolicy,
      state: state ?? this.state,
      priority: priority ?? this.priority,
      attemptCount: attemptCount ?? this.attemptCount,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      maxAge: maxAge ?? this.maxAge,
      nextRunAt: identical(nextRunAt, _unset)
          ? this.nextRunAt
          : nextRunAt as DateTime?,
      rateLimitBucket: identical(rateLimitBucket, _unset)
          ? this.rateLimitBucket
          : rateLimitBucket as String?,
      lastAttemptAt: identical(lastAttemptAt, _unset)
          ? this.lastAttemptAt
          : lastAttemptAt as DateTime?,
      authScope: authScope,
      dependencies: dependencies,
      projections: projections,
    );
  }

  /// Serializes this operation into a JSON-safe map.
  Map<String, Object?> toJson() => {
    'operationId': operationId.value,
    'mutationKey': mutationKey.toJson(),
    'variables': variables,
    'createdAt': createdAt.toIso8601String(),
    'idempotencyKey': idempotencyKey.value,
    'lineageId': lineageId.value,
    'authPolicy': authPolicy.name,
    'authScope': authScope?.toJson(),
    'dependencies': dependencies.map((item) => item.toJson()).toList(),
    'projections': projections.map((item) => item.toJson()).toList(),
    'state': state.name,
    'priority': priority,
    'attemptCount': attemptCount,
    'maxAttempts': maxAttempts,
    'maxAgeMs': maxAge.inMilliseconds,
    'nextRunAt': nextRunAt?.toIso8601String(),
    'rateLimitBucket': rateLimitBucket,
    'lastAttemptAt': lastAttemptAt?.toIso8601String(),
  };

  static AuthPolicy _parseAuthPolicy(String value) {
    for (final policy in AuthPolicy.values) {
      if (policy.name == value) return policy;
    }
    throw InvalidMutationPayloadException('Unknown auth policy: $value');
  }

  static DateTime _parseCreatedAt(String value) {
    try {
      return DateTime.parse(value);
    } on FormatException {
      throw const InvalidMutationPayloadException(
        'Invalid mutation operation timestamp',
      );
    }
  }

  static DateTime? _parseOptionalDate(String? value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value);
    } on FormatException {
      throw const InvalidMutationPayloadException(
        'Invalid mutation operation timestamp',
      );
    }
  }

  static List<T> _decodeList<T>(
    Object? value,
    String fieldName,
    T Function(Map<String, Object?> json) decode,
  ) {
    if (value == null) return <T>[];
    if (value is! List<Object?>) {
      throw InvalidMutationPayloadException('$fieldName must be a list');
    }
    return value
        .map((item) {
          if (item is! Map<Object?, Object?>) {
            throw InvalidMutationPayloadException(
              '$fieldName contains an invalid item',
            );
          }
          return decode(_asObjectMap(item));
        })
        .toList(growable: false);
  }

  static Map<String, Object?> _asObjectMap(Object? value) {
    if (value is! Map<Object?, Object?>) {
      throw const InvalidMutationPayloadException('Expected a JSON object');
    }
    final result = <String, Object?>{};
    for (final entry in value.entries) {
      final key = entry.key;
      if (key is! String) {
        throw const InvalidMutationPayloadException(
          'JSON object keys must be strings',
        );
      }
      result[key] = entry.value;
    }
    return result;
  }
}

const _unset = _Unset();

class _Unset {
  const _Unset();
}
