import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_json.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_envelope.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';

/// Logical collection in which an unrecognized record was found.
enum OutboxUnknownRecordKind { active, deadLetter, history }

/// Safe durable marker for a record that requires explicit recovery.
class OutboxUnknownRecord {
  /// Creates an unknown-record marker.
  const OutboxUnknownRecord({
    required this.recordId,
    required this.kind,
    required this.schemaVersion,
    required this.messageKey,
  });

  /// Stable opaque identifier for the record.
  final String recordId;

  /// Collection containing the record.
  final OutboxUnknownRecordKind kind;

  /// Schema version in which the record was encountered.
  final int schemaVersion;

  /// Stable diagnostic key for migration or recovery guidance.
  final String messageKey;

  /// Serializes only safe metadata; malformed payloads are never re-exposed.
  Map<String, Object?> toJson() => {
    'recordId': recordId,
    'kind': kind.name,
    'schemaVersion': schemaVersion,
    'messageKey': messageKey,
  };

  /// Decodes a previously retained marker.
  factory OutboxUnknownRecord.fromJson(Map<String, Object?> json) {
    final recordId = json['recordId'];
    final kind = json['kind'];
    final schemaVersion = json['schemaVersion'];
    final messageKey = json['messageKey'];
    if (recordId is! String ||
        recordId.isEmpty ||
        kind is! String ||
        schemaVersion is! int ||
        messageKey is! String ||
        messageKey.isEmpty) {
      throw const OutboxCorruptException();
    }
    final parsedKind = OutboxUnknownRecordKind.values.where(
      (value) => value.name == kind,
    );
    if (parsedKind.isEmpty) throw const OutboxCorruptException();
    return OutboxUnknownRecord(
      recordId: recordId,
      kind: parsedKind.single,
      schemaVersion: schemaVersion,
      messageKey: messageKey,
    );
  }
}

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
    this.idempotencyKey,
    this.authScope,
    this.resultProjection,
  });

  /// Creates a history entry after validating and freezing its projection.
  factory OutboxHistoryEntry.validated({
    required OperationId operationId,
    required MutationOperationState state,
    required DateTime completedAt,
    IdempotencyKey? idempotencyKey,
    AuthScope? authScope,
    Object? resultProjection,
  }) {
    return OutboxHistoryEntry(
      operationId: operationId,
      state: state,
      completedAt: completedAt,
      idempotencyKey: idempotencyKey,
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
    final idempotencyKey = json['idempotencyKey'];
    final authScope = json['authScope'];
    if (operationId is! String || state is! String || completedAt is! String) {
      throw const OutboxCorruptException();
    }
    IdempotencyKey? parsedIdempotencyKey;
    if (idempotencyKey != null) {
      if (idempotencyKey is! String) throw const OutboxCorruptException();
      try {
        parsedIdempotencyKey = IdempotencyKey(idempotencyKey);
      } on Exception {
        throw const OutboxCorruptException();
      }
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
        idempotencyKey: parsedIdempotencyKey,
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

  /// Stable retry and duplicate-prevention identity.
  ///
  /// Nullable only for history written by versions before this field existed.
  final IdempotencyKey? idempotencyKey;

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
    'idempotencyKey': idempotencyKey?.value,
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
    List<OutboxUnknownRecord> unknownRecords = const <OutboxUnknownRecord>[],
    Map<String, Object?> metadata = const <String, Object?>{},
  }) : active = List.unmodifiable(active.map(_copyOperation)),
       deadLetters = List.unmodifiable(deadLetters.map(_copyDeadLetter)),
       history = List.unmodifiable(history.map(_copyHistoryEntry)),
       unknownRecords = List.unmodifiable(unknownRecords),
       metadata = _immutableJsonMap(metadata, 'metadata');

  /// Recreates a snapshot from validated JSON.
  factory OutboxSnapshot.fromJson(Map<String, Object?> json) {
    try {
      final active = _decodeKnownList(
        json['active'],
        kind: OutboxUnknownRecordKind.active,
        decode: MutationOperation.fromJson,
      );
      final deadLetters = _decodeKnownList(
        json['deadLetters'],
        kind: OutboxUnknownRecordKind.deadLetter,
        decode: OutboxDeadLetter.fromJson,
      );
      final history = _decodeKnownList(
        json['history'],
        kind: OutboxUnknownRecordKind.history,
        decode: OutboxHistoryEntry.fromJson,
      );
      return OutboxSnapshot(
        active: active.records,
        deadLetters: deadLetters.records,
        history: history.records,
        unknownRecords: [
          ...active.unknownRecords,
          ...deadLetters.unknownRecords,
          ...history.unknownRecords,
          ..._decodeUnknownRecords(json['unknownRecords']),
        ],
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

  /// Persisted records that require explicit migration or recovery.
  final List<OutboxUnknownRecord> unknownRecords;

  /// JSON-safe dependency or projection metadata owned by the store.
  final Map<String, Object?> metadata;

  /// Returns a changed immutable snapshot.
  OutboxSnapshot copyWith({
    List<MutationOperation>? active,
    List<OutboxDeadLetter>? deadLetters,
    List<OutboxHistoryEntry>? history,
    List<OutboxUnknownRecord>? unknownRecords,
    Map<String, Object?>? metadata,
  }) {
    return OutboxSnapshot(
      active: active ?? this.active,
      deadLetters: deadLetters ?? this.deadLetters,
      history: history ?? this.history,
      unknownRecords: unknownRecords ?? this.unknownRecords,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Number of records retained by the logical store.
  int get recordCount =>
      active.length +
      deadLetters.length +
      history.length +
      unknownRecords.length;

  /// Serializes the complete logical store payload.
  Map<String, Object?> toJson() => {
    'active': active.map((item) => item.toJson()).toList(),
    'deadLetters': deadLetters.map((item) => item.toJson()).toList(),
    'history': history.map((item) => item.toJson()).toList(),
    'unknownRecords': unknownRecords.map((item) => item.toJson()).toList(),
    'metadata': metadata,
  };
}

typedef _JsonDecoder<T> = T Function(Map<String, Object?> json);

_DecodedKnownList<T> _decodeKnownList<T>(
  Object? value, {
  required OutboxUnknownRecordKind kind,
  required _JsonDecoder<T> decode,
}) {
  if (value is! List<Object?>) {
    return _DecodedKnownList(
      records: <T>[],
      unknownRecords: [
        _unknownRecord(
          kind: kind,
          index: 0,
          messageKey: 'sync.outbox.unknown_collection',
        ),
      ],
    );
  }
  final records = <T>[];
  final unknownRecords = <OutboxUnknownRecord>[];
  for (var index = 0; index < value.length; index++) {
    final item = value[index];
    try {
      if (item is! Map<Object?, Object?>) {
        throw const OutboxCorruptException();
      }
      records.add(decode(_objectMap(item)));
    } on Object {
      unknownRecords.add(_unknownRecord(kind: kind, index: index, item: item));
    }
  }
  return _DecodedKnownList(
    records: List.unmodifiable(records),
    unknownRecords: List.unmodifiable(unknownRecords),
  );
}

class _DecodedKnownList<T> {
  const _DecodedKnownList({
    required this.records,
    required this.unknownRecords,
  });

  final List<T> records;
  final List<OutboxUnknownRecord> unknownRecords;
}

OutboxUnknownRecord _unknownRecord({
  required OutboxUnknownRecordKind kind,
  required int index,
  Object? item,
  String? messageKey,
}) {
  final itemMap = item is Map<Object?, Object?> ? item : null;
  final operationId = itemMap?['operationId'];
  final recordId = operationId is String && operationId.isNotEmpty
      ? operationId
      : 'unknown-${kind.name}-$index';
  return OutboxUnknownRecord(
    recordId: recordId,
    kind: kind,
    schemaVersion: currentOutboxSchemaVersion,
    messageKey: messageKey ?? 'sync.outbox.unknown_record',
  );
}

List<OutboxUnknownRecord> _decodeUnknownRecords(Object? value) {
  if (value == null) return const <OutboxUnknownRecord>[];
  if (value is! List<Object?>) throw const OutboxCorruptException();
  return value
      .map((item) {
        if (item is! Map<Object?, Object?>) {
          throw const OutboxCorruptException();
        }
        return OutboxUnknownRecord.fromJson(_objectMap(item));
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
    idempotencyKey: entry.idempotencyKey,
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
