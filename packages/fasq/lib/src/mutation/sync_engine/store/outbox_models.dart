import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_json.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';

/// One terminal operation retained for repair and inspection.
class OutboxDeadLetter {
  /// Creates a dead-letter record.
  OutboxDeadLetter({
    required this.operation,
    required this.category,
    required this.messageKey,
    required this.retryable,
    required this.repairable,
    required this.failedAt,
    Map<String, Object?>? conflictEvidence,
  }) : conflictEvidence = conflictEvidence == null
           ? null
           : _immutableJsonMap(conflictEvidence, 'conflictEvidence');

  /// Recreates a dead-letter record from validated JSON.
  factory OutboxDeadLetter.fromJson(Map<String, Object?> json) {
    final operation = json['operation'];
    final category = json['category'];
    final messageKey = json['messageKey'];
    final failedAt = json['failedAt'];
    if (operation is! Map<Object?, Object?> ||
        category is! String ||
        messageKey is! String ||
        failedAt is! String) {
      throw const OutboxCorruptException();
    }
    final parsedCategory = MutationFailureCategory.values.where(
      (value) => value.name == category,
    );
    if (parsedCategory.isEmpty) throw const OutboxCorruptException();
    final rawConflictEvidence = json['conflictEvidence'];
    if (rawConflictEvidence != null &&
        rawConflictEvidence is! Map<Object?, Object?>) {
      throw const OutboxCorruptException();
    }
    final parsedConflictEvidence = rawConflictEvidence == null
        ? null
        : _objectMap(rawConflictEvidence as Map<Object?, Object?>);
    return OutboxDeadLetter(
      operation: MutationOperation.fromJson(_objectMap(operation)),
      category: parsedCategory.first,
      messageKey: messageKey,
      retryable: json['retryable'] == true,
      repairable: json['repairable'] == true,
      failedAt: _date(failedAt),
      conflictEvidence: parsedConflictEvidence,
    );
  }

  /// Operation that could not be completed.
  final MutationOperation operation;

  /// Normalized safe failure category.
  final MutationFailureCategory category;

  /// Stable safe message key for presentation.
  final String messageKey;

  /// Whether an executor-declared retry is allowed.
  final bool retryable;

  /// Whether an explicit repair is allowed.
  final bool repairable;

  /// Time at which the operation entered dead-letter storage.
  final DateTime failedAt;

  /// Durable, sanitized evidence for a conflict failure, when available.
  final Map<String, Object?>? conflictEvidence;

  /// Serializes the record without raw exception details.
  Map<String, Object?> toJson() => {
    'operation': operation.toJson(),
    'category': category.name,
    'messageKey': messageKey,
    'retryable': retryable,
    'repairable': repairable,
    'failedAt': failedAt.toIso8601String(),
    'conflictEvidence': conflictEvidence,
  };
}

/// A compact completion ledger entry retained after active work is removed.
class OutboxHistoryEntry {
  /// Creates a history entry.
  const OutboxHistoryEntry({
    required this.operationId,
    required this.state,
    required this.completedAt,
    this.authScope,
    this.resultProjection,
  });

  /// Creates a history entry after validating and freezing its projection.
  factory OutboxHistoryEntry.validated({
    required OperationId operationId,
    required MutationOperationState state,
    required DateTime completedAt,
    AuthScope? authScope,
    Object? resultProjection,
  }) {
    return OutboxHistoryEntry(
      operationId: operationId,
      state: state,
      completedAt: completedAt,
      authScope: authScope,
      resultProjection: _immutableJsonValue(
        resultProjection,
        'resultProjection',
      ),
    );
  }

  /// Recreates a history entry from validated JSON.
  factory OutboxHistoryEntry.fromJson(Map<String, Object?> json) {
    final operationId = json['operationId'];
    final state = json['state'];
    final completedAt = json['completedAt'];
    final authScope = json['authScope'];
    if (operationId is! String || state is! String || completedAt is! String) {
      throw const OutboxCorruptException();
    }
    MutationOperationState parsedState;
    try {
      parsedState = parseMutationOperationState(state);
    } on Exception {
      throw const OutboxCorruptException();
    }
    try {
      return OutboxHistoryEntry.validated(
        operationId: OperationId(operationId),
        state: parsedState,
        completedAt: _date(completedAt),
        authScope: _parseAuthScope(authScope),
        resultProjection: json['resultProjection'],
      );
    } on OutboxCorruptException {
      rethrow;
    } on Exception {
      throw const OutboxCorruptException();
    }
  }

  /// Completed operation identity.
  final OperationId operationId;

  /// Final state recorded in the completion ledger.
  final MutationOperationState state;

  /// Completion or discard timestamp.
  final DateTime completedAt;

  /// Exact non-secret authentication scope that owned the operation.
  final AuthScope? authScope;

  /// Optional JSON-safe projected result.
  final Object? resultProjection;

  /// Serializes the history entry.
  Map<String, Object?> toJson() => {
    'operationId': operationId.value,
    'state': state.name,
    'completedAt': completedAt.toIso8601String(),
    'authScope': authScope?.toJson(),
    'resultProjection': resultProjection,
  };
}

/// The single logical state committed by a durable outbox transaction.
class OutboxSnapshot {
  /// Creates an immutable logical store snapshot.
  OutboxSnapshot({
    List<MutationOperation> active = const <MutationOperation>[],
    List<OutboxDeadLetter> deadLetters = const <OutboxDeadLetter>[],
    List<OutboxHistoryEntry> history = const <OutboxHistoryEntry>[],
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : active = List.unmodifiable(active.map(_copyOperation)),
       deadLetters = List.unmodifiable(deadLetters.map(_copyDeadLetter)),
       history = List.unmodifiable(history.map(_copyHistoryEntry)),
       metadata = _immutableJsonMap(metadata, 'metadata');

  /// Recreates a snapshot from validated JSON.
  factory OutboxSnapshot.fromJson(Map<String, Object?> json) {
    try {
      return OutboxSnapshot(
        active: _decodeList(
          json['active'],
          MutationOperation.fromJson,
        ),
        deadLetters: _decodeList(
          json['deadLetters'],
          OutboxDeadLetter.fromJson,
        ),
        history: _decodeList(
          json['history'],
          OutboxHistoryEntry.fromJson,
        ),
        metadata: _metadata(json['metadata']),
      );
    } on OutboxCorruptException {
      rethrow;
    } on Exception {
      throw const OutboxCorruptException();
    }
  }

  /// Active work eligible for replay or waiting on dependencies.
  final List<MutationOperation> active;

  /// Terminal work retained for repair and inspection.
  final List<OutboxDeadLetter> deadLetters;

  /// Completed/discarded operation ledger.
  final List<OutboxHistoryEntry> history;

  /// JSON-safe dependency or projection metadata owned by the store.
  final Map<String, Object?> metadata;

  /// Returns a changed immutable snapshot.
  OutboxSnapshot copyWith({
    List<MutationOperation>? active,
    List<OutboxDeadLetter>? deadLetters,
    List<OutboxHistoryEntry>? history,
    Map<String, Object?>? metadata,
  }) {
    return OutboxSnapshot(
      active: active ?? this.active,
      deadLetters: deadLetters ?? this.deadLetters,
      history: history ?? this.history,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Number of records retained by the logical store.
  int get recordCount => active.length + deadLetters.length + history.length;

  /// Serializes the complete logical store payload.
  Map<String, Object?> toJson() => {
    'active': active.map((item) => item.toJson()).toList(),
    'deadLetters': deadLetters.map((item) => item.toJson()).toList(),
    'history': history.map((item) => item.toJson()).toList(),
    'metadata': metadata,
  };
}

typedef _JsonDecoder<T> = T Function(Map<String, Object?> json);

List<T> _decodeList<T>(Object? value, _JsonDecoder<T> decode) {
  if (value is! List<Object?>) throw const OutboxCorruptException();
  return value
      .map((item) {
        if (item is! Map<Object?, Object?>) {
          throw const OutboxCorruptException();
        }
        return decode(_objectMap(item));
      })
      .toList(growable: false);
}

Map<String, Object?> _metadata(Object? value) {
  if (value == null) return const <String, Object?>{};
  if (value is! Map<Object?, Object?>) throw const OutboxCorruptException();
  return _objectMap(value);
}

MutationOperation _copyOperation(MutationOperation operation) {
  return MutationOperation(
    operationId: operation.operationId,
    mutationKey: operation.mutationKey,
    variables: _immutableJsonValue(operation.variables, 'variables'),
    createdAt: operation.createdAt,
    idempotencyKey: operation.idempotencyKey,
    lineageId: operation.lineageId,
    authPolicy: operation.authPolicy,
    conflictPolicy: operation.conflictPolicy,
    conflictPrecondition: operation.conflictPrecondition,
    state: operation.state,
    priority: operation.priority,
    attemptCount: operation.attemptCount,
    maxAttempts: operation.maxAttempts,
    maxAge: operation.maxAge,
    nextRunAt: operation.nextRunAt,
    rateLimitBucket: operation.rateLimitBucket,
    lastAttemptAt: operation.lastAttemptAt,
    authScope: operation.authScope,
    dependencies: List.unmodifiable(operation.dependencies),
    projections: List.unmodifiable(operation.projections),
  );
}

OutboxDeadLetter _copyDeadLetter(OutboxDeadLetter deadLetter) {
  return OutboxDeadLetter(
    operation: _copyOperation(deadLetter.operation),
    category: deadLetter.category,
    messageKey: deadLetter.messageKey,
    retryable: deadLetter.retryable,
    repairable: deadLetter.repairable,
    failedAt: deadLetter.failedAt,
    conflictEvidence: deadLetter.conflictEvidence,
  );
}

OutboxHistoryEntry _copyHistoryEntry(OutboxHistoryEntry entry) {
  return OutboxHistoryEntry.validated(
    operationId: entry.operationId,
    state: entry.state,
    completedAt: entry.completedAt,
    authScope: entry.authScope,
    resultProjection: entry.resultProjection,
  );
}

Map<String, Object?> _immutableJsonMap(
  Map<Object?, Object?> value,
  String path,
) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw InvalidMutationPayloadException('$path has a non-string key');
    }
    result[key] = _immutableJsonValue(entry.value, '$path.$key');
  }
  return Map.unmodifiable(result);
}

Object? _immutableJsonValue(Object? value, [String path = 'value']) {
  validateJsonValue(value, path);
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(
      value.map((item) => _immutableJsonValue(item, path)),
    );
  }
  if (value is Map<Object?, Object?>) {
    return _immutableJsonMap(value, path);
  }
  return value;
}

Map<String, Object?> _objectMap(Map<Object?, Object?> value) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    if (entry.key is! String) throw const OutboxCorruptException();
    result[entry.key! as String] = entry.value;
  }
  return result;
}

AuthScope? _parseAuthScope(Object? value) {
  if (value == null) return null;
  if (value is! Map<Object?, Object?>) {
    throw const OutboxCorruptException();
  }
  try {
    return AuthScope.fromJson(_objectMap(value));
  } on Exception {
    throw const OutboxCorruptException();
  }
}

DateTime _date(String value) {
  try {
    return DateTime.parse(value);
  } on FormatException {
    throw const OutboxCorruptException();
  }
}
