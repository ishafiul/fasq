import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';

import 'package:fasq/src/mutation/sync_engine/observation/observation_models.dart';

export 'package:fasq/src/mutation/sync_engine/observation/observation_models.dart';

/// Read-only projection of one durable outbox snapshot.
///
/// The projection is rebuilt from each store snapshot. It never exposes
/// serialized variables, conflict evidence, credential material, or raw
/// exceptions.
class DurableObservation {
  /// Builds a redacted immutable observation index from [snapshot].
  factory DurableObservation.fromSnapshot(OutboxSnapshot snapshot) {
    final discardedOperationIds = snapshot.history
        .where((entry) => entry.state == MutationOperationState.discarded)
        .map((entry) => entry.operationId)
        .toSet();
    final operations = <DurableOperationObservation>[
      ...snapshot.active.map(
        (operation) => DurableOperationObservation.fromOperation(
          operation,
          recordKind: DurableObservationRecordKind.active,
        ),
      ),
      ...snapshot.deadLetters.map(
        (deadLetter) => DurableOperationObservation.fromOperation(
          deadLetter.operation,
          recordKind: DurableObservationRecordKind.deadLetter,
          stateOverride:
              discardedOperationIds.contains(
                deadLetter.operation.operationId,
              )
              ? DurableOperationState.discarded
              : null,
          failure: DurableFailureObservation(
            category: deadLetter.category,
            messageKey: deadLetter.messageKey,
            retryable: deadLetter.retryable,
            repairable: deadLetter.repairable,
          ),
          failedAt: deadLetter.failedAt,
        ),
      ),
    ];
    return DurableObservation._(
      operations: operations,
      history: snapshot.history
          .map(DurableHistoryObservation.fromEntry)
          .toList(growable: false),
      unknownRecords: snapshot.unknownRecords
          .map(
            (record) => DurableUnknownRecordObservation(
              recordId: record.recordId,
              recordKind: DurableObservationRecordKind.unknown,
              schemaVersion: record.schemaVersion,
              messageKey: record.messageKey,
            ),
          )
          .toList(growable: false),
    );
  }

  DurableObservation._({
    required List<DurableOperationObservation> operations,
    required List<DurableHistoryObservation> history,
    required List<DurableUnknownRecordObservation> unknownRecords,
  }) : _operations = List.unmodifiable(operations),
       _history = List.unmodifiable(history),
       _unknownRecords = List.unmodifiable(unknownRecords);

  final List<DurableOperationObservation> _operations;
  final List<DurableHistoryObservation> _history;
  final List<DurableUnknownRecordObservation> _unknownRecords;

  /// Returns one active/dead-letter operation matching [operationId].
  DurableOperationObservation? getOperation(
    OperationId operationId, {
    DurableOperationFilter? filter,
  }) {
    final resolvedFilter = filter ?? DurableOperationFilter();
    for (final operation in _operations) {
      if (operation.operationId == operationId &&
          resolvedFilter.matches(operation)) {
        return operation;
      }
    }
    return null;
  }

  /// Lists active and retained dead-letter operations matching [filter].
  List<DurableOperationObservation> listOperations([
    DurableOperationFilter? filter,
  ]) {
    final resolvedFilter = filter ?? DurableOperationFilter();
    final matches = <DurableOperationObservation>[];
    for (final operation in _operations) {
      if (!resolvedFilter.matches(operation)) continue;
      matches.add(operation);
      if (resolvedFilter.limit != null &&
          matches.length == resolvedFilter.limit) {
        break;
      }
    }
    return List.unmodifiable(matches);
  }

  /// Returns retained completion entries for [operationId].
  ///
  /// A scope-filtered history lookup returns only entries owned by that scope.
  List<DurableHistoryObservation> getOperationHistory(
    OperationId operationId, {
    AuthScope? authScope,
    bool scopeBound = false,
    bool includeUnauthenticated = false,
  }) {
    if (scopeBound || authScope != null) {
      return List.unmodifiable(
        _history.where(
          (entry) =>
              entry.operationId == operationId &&
              (entry.authScope == authScope ||
                  (includeUnauthenticated && entry.authScope == null)),
        ),
      );
    }
    return List.unmodifiable(
      _history.where((entry) => entry.operationId == operationId),
    );
  }

  /// Builds a filtered snapshot and its derived aggregate state.
  DurableQueueObservation queueObservation({
    DurableOperationFilter? filter,
  }) {
    final resolvedFilter = filter ?? DurableOperationFilter();
    final operations = listOperations(resolvedFilter);
    final history = !resolvedFilter.scopeBound
        ? _history
        : _history
              .where(
                (entry) =>
                    entry.authScope == resolvedFilter.authScope ||
                    (resolvedFilter.includeUnauthenticated &&
                        entry.authScope == null),
              )
              .toList(growable: false);
    return DurableQueueObservation(
      operations: operations,
      history: history,
      unknownRecords: _unknownRecords,
      aggregateState: _aggregateState(
        operations,
        hasUnknownRecords: _unknownRecords.isNotEmpty,
      ),
    );
  }

  /// All retained operation observations, before caller filtering.
  List<DurableOperationObservation> get operations => _operations;

  /// All retained history observations, without private result projections.
  List<DurableHistoryObservation> get history => _history;

  /// Safe metadata for records requiring explicit recovery.
  List<DurableUnknownRecordObservation> get unknownRecords => _unknownRecords;
}

/// Builds a redacted queue observation from one durable store snapshot.
DurableQueueObservation buildQueueObservation(
  OutboxSnapshot snapshot, {
  DurableOperationFilter? filter,
}) {
  return DurableObservation.fromSnapshot(snapshot).queueObservation(
    filter: filter,
  );
}

/// Applies [filter] to an already-built queue observation.
///
/// This helper is useful when a queue keeps one restart-safe base snapshot and
/// callers need independent views without rebuilding the redacted records.
DurableQueueObservation filterQueueObservation(
  DurableQueueObservation observation,
  DurableOperationFilter filter,
) {
  final operations = observation.operations
      .where(filter.matches)
      .take(filter.limit ?? observation.operations.length)
      .toList(growable: false);
  final history = !filter.scopeBound
      ? observation.history
      : observation.history
            .where(
              (entry) =>
                  entry.authScope == filter.authScope ||
                  (filter.includeUnauthenticated && entry.authScope == null),
            )
            .toList(growable: false);
  return DurableQueueObservation(
    operations: operations,
    history: history,
    unknownRecords: observation.unknownRecords,
    aggregateState: _aggregateState(
      operations,
      hasUnknownRecords: observation.unknownRecords.isNotEmpty,
    ),
  );
}

DurableQueueAggregateState _aggregateState(
  List<DurableOperationObservation> operations, {
  bool hasUnknownRecords = false,
}) {
  final actionableOperations = operations
      .where((operation) => operation.state != DurableOperationState.discarded)
      .toList(growable: false);
  if (hasUnknownRecords) return DurableQueueAggregateState.attentionRequired;
  if (actionableOperations.isEmpty) return DurableQueueAggregateState.idle;

  final states = actionableOperations
      .map((operation) => operation.state)
      .toSet();
  if (states.any(_isAttentionState)) {
    return DurableQueueAggregateState.attentionRequired;
  }
  if (states.contains(DurableOperationState.running)) {
    return DurableQueueAggregateState.syncing;
  }
  if (states.contains(DurableOperationState.quarantined)) {
    return DurableQueueAggregateState.quarantined;
  }
  return DurableQueueAggregateState.waiting;
}

bool _isAttentionState(DurableOperationState state) {
  return switch (state) {
    DurableOperationState.authorizationBlocked ||
    DurableOperationState.conflict ||
    DurableOperationState.failedTerminal ||
    DurableOperationState.unknownOutcome ||
    DurableOperationState.migrationRequired ||
    DurableOperationState.storageCorrupt => true,
    _ => false,
  };
}
