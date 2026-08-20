import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
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
    );
  }

  DurableObservation._({
    required List<DurableOperationObservation> operations,
    required List<DurableHistoryObservation> history,
  }) : _operations = List.unmodifiable(operations),
       _history = List.unmodifiable(history);

  final List<DurableOperationObservation> _operations;
  final List<DurableHistoryObservation> _history;

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
  }) {
    if (authScope != null) {
      return List.unmodifiable(
        _history.where(
          (entry) =>
              entry.operationId == operationId && entry.authScope == authScope,
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
    final history = resolvedFilter.authScope == null
        ? List<DurableHistoryObservation>.unmodifiable(_history)
        : _history
              .where((entry) => entry.authScope == resolvedFilter.authScope)
              .toList(growable: false);
    return DurableQueueObservation(
      operations: operations,
      history: history,
      aggregateState: _aggregateState(operations),
    );
  }

  /// All retained operation observations, before caller filtering.
  List<DurableOperationObservation> get operations => _operations;

  /// All retained history observations, without private result projections.
  List<DurableHistoryObservation> get history => _history;
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
  final history = filter.authScope == null
      ? observation.history
      : observation.history
            .where((entry) => entry.authScope == filter.authScope)
            .toList(growable: false);
  return DurableQueueObservation(
    operations: operations,
    history: history,
    aggregateState: _aggregateState(operations),
  );
}

DurableQueueAggregateState _aggregateState(
  List<DurableOperationObservation> operations,
) {
  if (operations.isEmpty) return DurableQueueAggregateState.idle;

  final states = operations.map((operation) => operation.state).toSet();
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
