import 'package:fasq/src/mutation/sync_engine/conflict/conflict_policy.dart';
import 'package:fasq/src/mutation/sync_engine/conflict/conflict_repair.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/store/durable_outbox.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';

/// Explicit actions available for terminal durable work.
enum RepairAction { retry, replace, discard, restoreQuarantine }

/// Safe categories for action failures.
enum RepairActionErrorCode {
  /// No matching operation exists.
  notFound,

  /// The caller scope is not the captured exact scope.
  authScopeMismatch,

  /// The operation cannot accept the action.
  invalidState,

  /// Retry is not allowed for the dead letter.
  notRetryable,

  /// Replacement is not allowed for the dead letter.
  notRepairable,

  /// The idempotency key was reused for another action.
  idempotencyConflict,

  /// A conflict repair needs a fresh compare-and-set token.
  conflictPreconditionRequired,
}

/// Safe public exception; it never carries variables or exception objects.
class RepairActionException implements Exception {
  /// Creates a redacted action exception.
  const RepairActionException(this.code, this.messageKey);

  /// Stable category for application handling.
  final RepairActionErrorCode code;

  /// Stable presentation key.
  final String messageKey;

  @override
  String toString() => 'RepairActionException($code): $messageKey';
}

/// Redacted result returned from an explicit action.
class RepairActionResult {
  /// Creates a safe action result.
  const RepairActionResult({
    required this.action,
    required this.originalOperationId,
    required this.operationId,
    required this.idempotencyKey,
    required this.lineageId,
    required this.idempotentReplay,
    required this.originalEvidencePreserved,
    required this.blockedDependentCount,
    required this.createdOperation,
    required this.messageKey,
  });

  /// Action performed.
  final RepairAction action;

  /// Original terminal operation.
  final OperationId originalOperationId;

  /// Fresh action identity, or fresh queued operation identity.
  final OperationId operationId;

  /// Fresh action/operation idempotency identity.
  final IdempotencyKey idempotencyKey;

  /// Original lineage retained by the action.
  final LineageId lineageId;

  /// Whether the durable action ledger was reused.
  final bool idempotentReplay;

  /// Whether original dead-letter evidence remains retained.
  final bool originalEvidencePreserved;

  /// Number of active dependents left blocked.
  final int blockedDependentCount;

  /// Whether fresh active work was created.
  final bool createdOperation;

  /// Safe presentation key.
  final String messageKey;

  /// Safe metadata for UI and telemetry.
  Map<String, Object?> get metadata => {
    'action': action.name,
    'messageKey': messageKey,
    'idempotentReplay': idempotentReplay,
    'originalEvidencePreserved': originalEvidencePreserved,
    'blockedDependentCount': blockedDependentCount,
    'createdOperation': createdOperation,
  };

  /// Serializes safe identities and metadata only.
  Map<String, Object?> toJson() => {
    'action': action.name,
    'originalOperationId': originalOperationId.value,
    'operationId': operationId.value,
    'idempotencyKey': idempotencyKey.value,
    'lineageId': lineageId.value,
    'idempotentReplay': idempotentReplay,
    'originalEvidencePreserved': originalEvidencePreserved,
    'blockedDependentCount': blockedDependentCount,
    'createdOperation': createdOperation,
    'messageKey': messageKey,
  };

  RepairActionResult copyWith({required bool idempotentReplay}) {
    return RepairActionResult(
      action: action,
      originalOperationId: originalOperationId,
      operationId: operationId,
      idempotencyKey: idempotencyKey,
      lineageId: lineageId,
      idempotentReplay: idempotentReplay,
      originalEvidencePreserved: originalEvidencePreserved,
      blockedDependentCount: blockedDependentCount,
      createdOperation: createdOperation,
      messageKey: messageKey,
    );
  }

  factory RepairActionResult.fromJson(Map<String, Object?> json) {
    final action = json['action'];
    final original = json['originalOperationId'];
    final operation = json['operationId'];
    final idempotency = json['idempotencyKey'];
    final lineage = json['lineageId'];
    final messageKey = json['messageKey'];
    final dependentCount = json['blockedDependentCount'];
    if (action is! String ||
        original is! String ||
        operation is! String ||
        idempotency is! String ||
        lineage is! String ||
        messageKey is! String ||
        dependentCount is! int) {
      throw const RepairActionException(
        RepairActionErrorCode.invalidState,
        'sync.repair.invalid_action_ledger',
      );
    }
    final parsedAction = RepairAction.values.where(
      (candidate) => candidate.name == action,
    );
    if (parsedAction.isEmpty || dependentCount < 0) {
      throw const RepairActionException(
        RepairActionErrorCode.invalidState,
        'sync.repair.invalid_action_ledger',
      );
    }
    return RepairActionResult(
      action: parsedAction.single,
      originalOperationId: OperationId(original),
      operationId: OperationId(operation),
      idempotencyKey: IdempotencyKey(idempotency),
      lineageId: LineageId(lineage),
      idempotentReplay: false,
      originalEvidencePreserved: json['originalEvidencePreserved'] == true,
      blockedDependentCount: dependentCount,
      createdOperation: json['createdOperation'] == true,
      messageKey: messageKey,
    );
  }
}

/// Redacted event emitted after an action attempt.
class RepairTelemetryEvent {
  /// Creates an event without payloads, credentials, scopes, or exceptions.
  const RepairTelemetryEvent({
    required this.action,
    required this.outcome,
    required this.originalOperationId,
    required this.operationId,
    required this.idempotentReplay,
    required this.blockedDependentCount,
    required this.messageKey,
  });

  /// Attempted action.
  final RepairAction action;

  /// Applied, idempotent, denied, or rejected.
  final String outcome;

  /// Safe original operation identity.
  final String? originalOperationId;

  /// Safe fresh action identity.
  final String? operationId;

  /// Whether the action ledger was reused.
  final bool idempotentReplay;

  /// Number of blocked dependents.
  final int blockedDependentCount;

  /// Safe presentation key.
  final String messageKey;

  /// JSON-safe telemetry metadata.
  Map<String, Object?> get metadata => {
    'action': action.name,
    'outcome': outcome,
    'originalOperationId': originalOperationId,
    'operationId': operationId,
    'idempotentReplay': idempotentReplay,
    'blockedDependentCount': blockedDependentCount,
    'messageKey': messageKey,
  };
}

/// Optional best-effort redacted telemetry adapter.
typedef RepairTelemetryAdapter = void Function(RepairTelemetryEvent event);

/// Explicit durable retry, replacement, discard, and quarantine restore.
class DurableRepairService {
  /// Creates a service over an existing durable outbox.
  DurableRepairService({
    required DurableOutboxStore store,
    RepairIdentityFactory? identities,
    RepairTelemetryAdapter? telemetry,
    DateTime Function()? now,
  }) : _store = store,
       _identities = identities ?? UuidRepairIdentityFactory(),
       _telemetry = telemetry,
       _now = now ?? DateTime.now;

  static const _ledgerKey = 'fasq.sync.repair.actionLedger.v1';
  final DurableOutboxStore _store;
  final RepairIdentityFactory _identities;
  final RepairTelemetryAdapter? _telemetry;
  final DateTime Function() _now;

  /// Retries a retryable dead letter with fresh identities.
  Future<RepairActionResult> retry({
    required OperationId operationId,
    required String idempotencyKey,
    AuthScope? currentAuthScope,
  }) => _perform(
    action: RepairAction.retry,
    operationId: operationId,
    idempotencyKey: idempotencyKey,
    currentAuthScope: currentAuthScope,
  );

  /// Replaces a repairable dead letter with explicit variables.
  Future<RepairActionResult> repair({
    required OperationId operationId,
    required String idempotencyKey,
    required Object? variables,
    MutationKey? mutationKey,
    ConflictPrecondition? conflictPrecondition,
    AuthScope? currentAuthScope,
  }) => _perform(
    action: RepairAction.replace,
    operationId: operationId,
    idempotencyKey: idempotencyKey,
    variables: variables,
    mutationKey: mutationKey,
    conflictPrecondition: conflictPrecondition,
    currentAuthScope: currentAuthScope,
  );

  /// Alias for [repair].
  Future<RepairActionResult> replace({
    required OperationId operationId,
    required String idempotencyKey,
    required Object? variables,
    MutationKey? mutationKey,
    ConflictPrecondition? conflictPrecondition,
    AuthScope? currentAuthScope,
  }) => repair(
    operationId: operationId,
    idempotencyKey: idempotencyKey,
    variables: variables,
    mutationKey: mutationKey,
    conflictPrecondition: conflictPrecondition,
    currentAuthScope: currentAuthScope,
  );

  /// Discards a dead letter while retaining its evidence.
  Future<RepairActionResult> discard({
    required OperationId operationId,
    required String idempotencyKey,
    AuthScope? currentAuthScope,
  }) => _perform(
    action: RepairAction.discard,
    operationId: operationId,
    idempotencyKey: idempotencyKey,
    currentAuthScope: currentAuthScope,
  );

  /// Restores a quarantined operation to pending under its exact scope.
  Future<RepairActionResult> restoreQuarantine({
    required OperationId operationId,
    required String idempotencyKey,
    required AuthScope currentAuthScope,
  }) => _perform(
    action: RepairAction.restoreQuarantine,
    operationId: operationId,
    idempotencyKey: idempotencyKey,
    currentAuthScope: currentAuthScope,
  );

  Future<RepairActionResult> _perform({
    required RepairAction action,
    required OperationId operationId,
    required String idempotencyKey,
    required AuthScope? currentAuthScope,
    Object? variables,
    MutationKey? mutationKey,
    ConflictPrecondition? conflictPrecondition,
  }) async {
    final requestKey = idempotencyKey.trim();
    if (requestKey.isEmpty) {
      throw const RepairActionException(
        RepairActionErrorCode.invalidState,
        'sync.repair.idempotency_key_required',
      );
    }
    await _store.open();
    for (var attempt = 0; attempt < 2; attempt++) {
      final existing = _ledger(_store.snapshot, requestKey);
      if (existing != null) {
        _validate(existing, action, operationId);
        final result = existing.copyWith(idempotentReplay: true);
        _emit(result, 'idempotent');
        return result;
      }
      RepairActionResult? applied;
      try {
        await _store.transact(
          (current) {
            final concurrent = _ledger(current, requestKey);
            if (concurrent != null) {
              _validate(concurrent, action, operationId);
              return current;
            }
            final plan = _apply(
              current: current,
              action: action,
              operationId: operationId,
              variables: variables,
              mutationKey: mutationKey,
              conflictPrecondition: conflictPrecondition,
              currentAuthScope: currentAuthScope,
            );
            applied = plan.result;
            return _commit(current, requestKey, plan);
          },
          expectedGeneration: _store.generation,
        );
      } on RepairActionException catch (error) {
        _emitRejected(action, operationId, error);
        rethrow;
      } on OutboxGenerationConflictException {
        if (attempt == 0) continue;
        rethrow;
      }
      final result = _ledger(_store.snapshot, requestKey);
      if (result == null) {
        throw const RepairActionException(
          RepairActionErrorCode.invalidState,
          'sync.repair.action_not_committed',
        );
      }
      final returned = result.copyWith(idempotentReplay: applied == null);
      _emit(returned, applied == null ? 'idempotent' : 'applied');
      return returned;
    }
    throw const RepairActionException(
      RepairActionErrorCode.invalidState,
      'sync.repair.generation_conflict',
    );
  }

  _RepairPlan _apply({
    required OutboxSnapshot current,
    required RepairAction action,
    required OperationId operationId,
    required Object? variables,
    required MutationKey? mutationKey,
    required ConflictPrecondition? conflictPrecondition,
    required AuthScope? currentAuthScope,
  }) {
    final deadLetter = _deadLetter(current, operationId);
    final activeOperation = _active(current, operationId);
    final original = deadLetter?.operation ?? activeOperation;
    if (original == null) {
      throw const RepairActionException(
        RepairActionErrorCode.notFound,
        'sync.repair.operation_not_found',
      );
    }
    if (_wasDiscarded(current, operationId)) {
      throw const RepairActionException(
        RepairActionErrorCode.invalidState,
        'sync.repair.operation_discarded',
      );
    }
    if (original.authPolicy == AuthPolicy.required &&
        original.authScope != currentAuthScope) {
      throw const RepairActionException(
        RepairActionErrorCode.authScopeMismatch,
        'sync.repair.auth_scope_mismatch',
      );
    }
    if (action == RepairAction.restoreQuarantine) {
      if (activeOperation?.state != MutationOperationState.quarantined) {
        throw const RepairActionException(
          RepairActionErrorCode.invalidState,
          'sync.repair.not_quarantined',
        );
      }
    } else if (deadLetter == null) {
      throw const RepairActionException(
        RepairActionErrorCode.invalidState,
        'sync.repair.not_dead_lettered',
      );
    }
    if (action == RepairAction.retry &&
        (!deadLetter!.retryable ||
            deadLetter.category == MutationFailureCategory.conflict)) {
      throw const RepairActionException(
        RepairActionErrorCode.notRetryable,
        'sync.repair.retry_not_allowed',
      );
    }
    if (action == RepairAction.replace && !deadLetter!.repairable) {
      throw const RepairActionException(
        RepairActionErrorCode.notRepairable,
        'sync.repair.replacement_not_allowed',
      );
    }
    if (action == RepairAction.replace &&
        deadLetter!.category == MutationFailureCategory.conflict &&
        (conflictPrecondition == null ||
            conflictPrecondition ==
                deadLetter.operation.conflictPrecondition)) {
      throw const RepairActionException(
        RepairActionErrorCode.conflictPreconditionRequired,
        'sync.repair.fresh_conflict_precondition_required',
      );
    }

    final freshOperationId = _identities.newOperationId();
    final freshIdempotencyKey = _identities.newIdempotencyKey();
    var active = current.active;
    var history = current.history;
    var blockedCount = 0;
    MutationOperation? replacement;
    if (action == RepairAction.restoreQuarantine) {
      active = [
        for (final item in active)
          item.operationId == operationId
              ? item.copyWith(state: MutationOperationState.pending)
              : item,
      ];
    } else if (action == RepairAction.discard) {
      final blocked = _block(active, operationId);
      active = blocked.active;
      blockedCount = blocked.count;
      history = [
        ...history,
        OutboxHistoryEntry.validated(
          operationId: original.operationId,
          state: MutationOperationState.discarded,
          completedAt: _now().toUtc(),
          idempotencyKey: original.idempotencyKey,
          mutationKey: original.mutationKey,
          authScope: original.authScope,
          identity: original.identity,
        ),
      ];
    } else {
      final source = deadLetter!.operation;
      final nextPrecondition = action == RepairAction.retry
          ? source.conflictPrecondition
          : conflictPrecondition ?? source.conflictPrecondition;
      replacement = MutationOperation(
        operationId: freshOperationId,
        mutationKey: action == RepairAction.retry
            ? source.mutationKey
            : mutationKey ?? source.mutationKey,
        variables: action == RepairAction.retry ? source.variables : variables,
        createdAt: _now().toUtc(),
        idempotencyKey: freshIdempotencyKey,
        lineageId: source.lineageId,
        authPolicy: source.authPolicy,
        authScope: source.authScope,
        conflictPolicy: nextPrecondition == null
            ? ConflictPolicy.none
            : ConflictPolicy.required,
        conflictPrecondition: nextPrecondition,
        state: MutationOperationState.pending,
        priority: source.priority,
        identity: action == RepairAction.retry ? source.identity : null,
        maxAttempts: source.maxAttempts,
        maxAge: source.maxAge,
        rateLimitBucket: source.rateLimitBucket,
        dependencies: source.dependencies,
        projections: source.projections,
      );
      final blocked = _block(
        active,
        operationId,
        replacementOperationId: replacement.operationId,
      );
      active = [...blocked.active, replacement];
      blockedCount = blocked.count;
    }
    return _RepairPlan(
      active: active,
      history: history,
      result: RepairActionResult(
        action: action,
        originalOperationId: operationId,
        operationId: freshOperationId,
        idempotencyKey: freshIdempotencyKey,
        lineageId: original.lineageId,
        idempotentReplay: false,
        originalEvidencePreserved: deadLetter != null,
        blockedDependentCount: blockedCount,
        createdOperation: replacement != null,
        messageKey: 'sync.repair.${action.name}',
      ),
    );
  }

  _Blocked _block(
    List<MutationOperation> operations,
    OperationId parent, {
    OperationId? replacementOperationId,
  }) {
    final blockedIds = <OperationId>{parent};
    var count = 0;
    final updated = List<MutationOperation>.of(operations);
    var discoveredDependent = true;
    while (discoveredDependent) {
      discoveredDependent = false;
      for (var index = 0; index < updated.length; index++) {
        final operation = updated[index];
        final dependsOnBlocked = operation.dependencies.any(
          (dependency) => blockedIds.contains(dependency.parentOperationId),
        );
        if (!dependsOnBlocked || !blockedIds.add(operation.operationId)) {
          continue;
        }
        discoveredDependent = true;
        final dependencies = replacementOperationId == null
            ? operation.dependencies
            : operation.dependencies
                  .map(
                    (dependency) => dependency.parentOperationId == parent
                        ? MutationDependency(
                            parentOperationId: replacementOperationId,
                            parentResultPath: dependency.parentResultPath,
                            childVariablePath: dependency.childVariablePath,
                          )
                        : dependency,
                  )
                  .toList(growable: false);
        final terminal =
            operation.state == MutationOperationState.succeeded ||
            operation.state == MutationOperationState.discarded;
        updated[index] = terminal
            ? operation.copyWith(dependencies: dependencies)
            : operation.copyWith(
                state: MutationOperationState.blocked,
                dependencies: dependencies,
              );
        if (!terminal) count++;
      }
    }
    return _Blocked(updated, count);
  }

  OutboxSnapshot _commit(
    OutboxSnapshot current,
    String requestKey,
    _RepairPlan plan,
  ) {
    final ledger = <Object?>[
      if (current.metadata[_ledgerKey] case final List<Object?> entries)
        ...entries,
      <String, Object?>{
        'requestKey': requestKey,
        'result': plan.result.toJson(),
      },
    ];
    return current.copyWith(
      active: plan.active,
      history: plan.history,
      metadata: {...current.metadata, _ledgerKey: ledger},
    );
  }

  RepairActionResult? _ledger(OutboxSnapshot snapshot, String requestKey) {
    final raw = snapshot.metadata[_ledgerKey];
    if (raw is! List<Object?>) return null;
    for (final item in raw) {
      if (item is! Map<Object?, Object?>) continue;
      final entry = _strings(item);
      if (entry['requestKey'] != requestKey) continue;
      final result = entry['result'];
      if (result is! Map<Object?, Object?>) {
        throw const RepairActionException(
          RepairActionErrorCode.invalidState,
          'sync.repair.invalid_action_ledger',
        );
      }
      return RepairActionResult.fromJson(_strings(result));
    }
    return null;
  }

  Map<String, Object?> _strings(Map<Object?, Object?> value) => {
    for (final item in value.entries)
      if (item.key is String) item.key as String: item.value,
  };

  void _validate(
    RepairActionResult result,
    RepairAction action,
    OperationId operationId,
  ) {
    if (result.action != action || result.originalOperationId != operationId) {
      throw const RepairActionException(
        RepairActionErrorCode.idempotencyConflict,
        'sync.repair.idempotency_conflict',
      );
    }
  }

  OutboxDeadLetter? _deadLetter(OutboxSnapshot snapshot, OperationId id) {
    for (final entry in snapshot.deadLetters) {
      if (entry.operation.operationId == id) return entry;
    }
    return null;
  }

  MutationOperation? _active(OutboxSnapshot snapshot, OperationId id) {
    for (final operation in snapshot.active) {
      if (operation.operationId == id) return operation;
    }
    return null;
  }

  bool _wasDiscarded(OutboxSnapshot snapshot, OperationId operationId) {
    return snapshot.history.any(
      (entry) =>
          entry.operationId == operationId &&
          entry.state == MutationOperationState.discarded,
    );
  }

  void _emit(RepairActionResult result, String outcome) {
    try {
      _telemetry?.call(
        RepairTelemetryEvent(
          action: result.action,
          outcome: outcome,
          originalOperationId: result.originalOperationId.value,
          operationId: result.operationId.value,
          idempotentReplay: result.idempotentReplay,
          blockedDependentCount: result.blockedDependentCount,
          messageKey: result.messageKey,
        ),
      );
    } on Object {
      // Telemetry is best effort.
    }
  }

  void _emitRejected(
    RepairAction action,
    OperationId operationId,
    RepairActionException error,
  ) {
    try {
      _telemetry?.call(
        RepairTelemetryEvent(
          action: action,
          outcome: error.code == RepairActionErrorCode.authScopeMismatch
              ? 'denied'
              : 'rejected',
          originalOperationId: operationId.value,
          operationId: null,
          idempotentReplay: false,
          blockedDependentCount: 0,
          messageKey: error.messageKey,
        ),
      );
    } on Object {
      // Telemetry is best effort.
    }
  }
}

class _RepairPlan {
  const _RepairPlan({
    required this.active,
    required this.history,
    required this.result,
  });

  final List<MutationOperation> active;
  final List<OutboxHistoryEntry> history;
  final RepairActionResult result;
}

class _Blocked {
  const _Blocked(this.active, this.count);

  final List<MutationOperation> active;
  final int count;
}
