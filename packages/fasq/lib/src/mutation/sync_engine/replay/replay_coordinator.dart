import 'dart:async';

import 'package:fasq/src/mutation/sync_engine/codecs/mutation_codec.dart';
import 'package:fasq/src/mutation/sync_engine/kahn_dag.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/store/durable_outbox.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';

/// Why a pending operation cannot be admitted to replay.
enum ReplayBlockReason {
  /// A required parent operation is absent from active work and history.
  missingDependency,

  /// The operation belongs to a dependency cycle.
  cycle,

  /// The operation depends on itself.
  selfDependency,

  /// A prerequisite completed terminally without succeeding.
  parentFailure,

  /// The operation has no runtime codec and executor registration.
  missingRegistration,

  /// A parent-result binding is structurally invalid.
  invalidBinding,

  /// A required parent result field is absent or not JSON-safe.
  missingParentResult,

  /// An active operation reuses an ID from active or terminal storage.
  duplicateOperation,
}

/// Safe, durable diagnostic for a blocked replay operation.
class ReplayDiagnostic {
  /// Creates a replay diagnostic.
  ReplayDiagnostic({
    required this.operationId,
    required this.reason,
    required this.messageKey,
    List<OperationId> relatedOperationIds = const <OperationId>[],
    List<String> missingDependencyIds = const <String>[],
  }) : relatedOperationIds = List.unmodifiable(relatedOperationIds),
       missingDependencyIds = List.unmodifiable(missingDependencyIds);

  /// Operation that remains blocked.
  final OperationId operationId;

  /// Stable reason category.
  final ReplayBlockReason reason;

  /// Safe message key for application presentation.
  final String messageKey;

  /// Parent operations relevant to the diagnostic.
  final List<OperationId> relatedOperationIds;

  /// Missing operation IDs, when [reason] is
  /// [ReplayBlockReason.missingDependency].
  final List<String> missingDependencyIds;

  /// Serializes the diagnostic for the outbox metadata ledger.
  Map<String, Object?> toJson() => {
    'operationId': operationId.value,
    'reason': reason.name,
    'messageKey': messageKey,
    'relatedOperationIds': relatedOperationIds
        .map((operationId) => operationId.value)
        .toList(growable: false),
    'missingDependencyIds': missingDependencyIds,
  };
}

/// Observable result of one replay request.
class ReplayRunResult {
  /// Creates a replay result.
  ReplayRunResult({
    required List<OperationId> executedOperationIds,
    required List<OperationId> failedOperationIds,
    required List<OperationId> recoveredUnknownOutcomeIds,
    required List<ReplayDiagnostic> blockedOperations,
  }) : executedOperationIds = List.unmodifiable(executedOperationIds),
       failedOperationIds = List.unmodifiable(failedOperationIds),
       recoveredUnknownOutcomeIds = List.unmodifiable(
         recoveredUnknownOutcomeIds,
       ),
       blockedOperations = List.unmodifiable(blockedOperations);

  /// Operations whose registered executor was invoked.
  final List<OperationId> executedOperationIds;

  /// Operations whose executor returned a failure recorded for repair.
  final List<OperationId> failedOperationIds;

  /// Operations recovered from a prior process crash.
  final List<OperationId> recoveredUnknownOutcomeIds;

  /// Operations left blocked with durable diagnostics.
  final List<ReplayDiagnostic> blockedOperations;

  /// Whether this request invoked at least one executor.
  bool get didExecute => executedOperationIds.isNotEmpty;
}

/// Coordinates one-owner, dependency-aware replay over a durable outbox.
///
/// The coordinator owns scheduling and durable state transitions. The
/// registration registry remains the only runtime executor seam, so immediate
/// execution and replay cannot drift into separate mutation implementations.
class DurableReplayCoordinator {
  /// Creates a replay coordinator.
  DurableReplayCoordinator({
    required DurableOutboxStore store,
    required MutationRegistrationRegistry registrations,
    DateTime Function()? now,
  }) : _store = store,
       _registrations = registrations,
       _now = now ?? DateTime.now;

  static const _diagnosticsMetadataKey = 'replayDiagnostics';

  final DurableOutboxStore _store;
  final MutationRegistrationRegistry _registrations;
  final DateTime Function() _now;
  Future<void> _tail = Future<void>.value();
  bool _isOpen = false;
  List<OperationId> _recoveredUnknownOutcomeIds = const <OperationId>[];

  /// Opens the store and converts leftover running work into safe dead letters.
  Future<void> open() {
    return _serialized(() async {
      if (_isOpen) return;
      await _store.open();
      try {
        _recoveredUnknownOutcomeIds = await _recoverInterrupted();
        _isOpen = true;
      } on Object {
        try {
          await _store.close();
        } on Object {
          // Preserve the recovery failure; the store owns its cleanup error.
        }
        rethrow;
      }
    });
  }

  /// Replays all currently admissible work in deterministic order.
  Future<ReplayRunResult> replay() {
    return _serialized(() async {
      _requireOpen();
      final executed = <OperationId>[];
      final failed = <OperationId>[];
      final blocked = <String, ReplayDiagnostic>{};
      final recovered = List<OperationId>.from(_recoveredUnknownOutcomeIds);
      _recoveredUnknownOutcomeIds = const <OperationId>[];

      await _clearDiagnostics();
      while (true) {
        final selection = _select(_store.snapshot);
        for (final diagnostic in selection.diagnostics) {
          _recordDiagnostic(blocked, diagnostic);
        }
        if (selection.diagnostics.isNotEmpty) {
          await _persistDiagnostics(selection);
        }

        final next = selection.orderedNodes.isEmpty
            ? null
            : selection.orderedNodes.first.payload;
        if (next == null) break;

        final started = await _start(next);
        if (started == null) continue;
        final operation = started.operation;
        executed.add(operation.operationId);

        Object? result;
        try {
          result = await _registrations.execute(
            operation.mutationKey,
            operation.variables,
          );
        } on Object catch (error) {
          failed.add(operation.operationId);
          await _completeFailure(
            started,
            error,
            unknownOutcome: !_isDeterministicFailure(error),
          );
          continue;
        }
        await _completeSuccess(started, result);
      }

      return ReplayRunResult(
        executedOperationIds: List.unmodifiable(executed),
        failedOperationIds: List.unmodifiable(failed),
        recoveredUnknownOutcomeIds: List.unmodifiable(recovered),
        blockedOperations: List.unmodifiable(blocked.values),
      );
    });
  }

  /// Closes the coordinator and releases the outbox owner marker.
  Future<void> close() {
    return _serialized(() async {
      if (!_isOpen) return;
      await _store.close();
      _isOpen = false;
    });
  }

  Future<List<OperationId>> _recoverInterrupted() async {
    final running = _store.snapshot.active
        .where((operation) => operation.state == MutationOperationState.running)
        .toList(growable: false);
    if (running.isEmpty) return const <OperationId>[];

    final expectedGeneration = _store.generation;
    await _store.transact(
      (current) {
        final runningIds = running
            .map((operation) => operation.operationId)
            .toSet();
        final active = current.active
            .where((operation) => !runningIds.contains(operation.operationId))
            .toList();
        final deadLetters = [...current.deadLetters];
        final history = [...current.history];
        for (final operation in running) {
          final unknownOutcome = operation.copyWith(
            state: MutationOperationState.unknownOutcome,
          );
          deadLetters.add(
            OutboxDeadLetter(
              operation: unknownOutcome,
              category: MutationFailureCategory.unknown,
              messageKey: 'sync.replay.unknown_outcome',
              retryable: false,
              repairable: true,
              failedAt: _now(),
            ),
          );
          history.add(
            OutboxHistoryEntry.validated(
              operationId: operation.operationId,
              state: MutationOperationState.unknownOutcome,
              completedAt: _now(),
            ),
          );
        }
        return current.copyWith(
          active: active,
          deadLetters: deadLetters,
          history: history,
        );
      },
      expectedGeneration: expectedGeneration,
    );
    return running
        .map((operation) => operation.operationId)
        .toList(growable: false);
  }

  _ReplaySelection _select(OutboxSnapshot snapshot) {
    final pending = snapshot.active
        .where((operation) => operation.state == MutationOperationState.pending)
        .toList(growable: false);
    if (pending.isEmpty) {
      return const _ReplaySelection(
        generation: 0,
        orderedNodes: <SyncDagNode<MutationOperation>>[],
        diagnostics: <ReplayDiagnostic>[],
      );
    }

    final pendingIds = pending
        .map((operation) => operation.operationId.value)
        .toSet();
    final directDiagnostics = <String, ReplayDiagnostic>{};
    final deferredIds = <String>{};

    // A history/dead-letter pair is the intentional terminal record for one
    // operation. Only a pending active record conflicts with those ledgers.
    final terminalOperationIds = <String>{
      ...snapshot.history.map((entry) => entry.operationId.value),
      ...snapshot.deadLetters.map(
        (entry) => entry.operation.operationId.value,
      ),
    };
    final seenOperationIds = <String>{};
    for (final operation in pending) {
      if (!seenOperationIds.add(operation.operationId.value) ||
          terminalOperationIds.contains(operation.operationId.value)) {
        _recordDiagnostic(
          directDiagnostics,
          _diagnostic(
            operation.operationId,
            ReplayBlockReason.duplicateOperation,
            'sync.replay.duplicate_operation',
          ),
        );
      }
    }

    for (final operation in pending) {
      if (!_registrations.contains(operation.mutationKey)) {
        _recordDiagnostic(
          directDiagnostics,
          _diagnostic(
            operation.operationId,
            ReplayBlockReason.missingRegistration,
            'sync.replay.missing_registration',
          ),
        );
      }
      final childBindingPaths = <String>{};
      for (final dependency in operation.dependencies) {
        final parentId = dependency.parentOperationId.value;
        if (parentId == operation.operationId.value) {
          _recordDiagnostic(
            directDiagnostics,
            _diagnostic(
              operation.operationId,
              ReplayBlockReason.selfDependency,
              'sync.replay.self_dependency',
              related: [dependency.parentOperationId],
            ),
          );
          continue;
        }
        final childVariablePath = dependency.childVariablePath;
        if (!_hasValidBinding(dependency) ||
            (childVariablePath != null &&
                !childBindingPaths.add(childVariablePath))) {
          _recordDiagnostic(
            directDiagnostics,
            _diagnostic(
              operation.operationId,
              ReplayBlockReason.invalidBinding,
              'sync.replay.invalid_parent_binding',
              related: [dependency.parentOperationId],
            ),
          );
          continue;
        }

        final activeParent = _findActive(snapshot, parentId);
        final historyParent = _findHistory(snapshot, parentId);
        final deadLetterParent = _findDeadLetter(snapshot, parentId);
        if (activeParent != null && terminalOperationIds.contains(parentId)) {
          _recordDiagnostic(
            directDiagnostics,
            _diagnostic(
              operation.operationId,
              ReplayBlockReason.duplicateOperation,
              'sync.replay.duplicate_operation',
              related: [dependency.parentOperationId],
            ),
          );
          continue;
        }
        if (historyParent?.state == MutationOperationState.succeeded) continue;
        if (deadLetterParent != null ||
            activeParent?.state == MutationOperationState.failedTerminal ||
            activeParent?.state == MutationOperationState.unknownOutcome ||
            activeParent?.state == MutationOperationState.blocked ||
            (historyParent != null &&
                historyParent.state != MutationOperationState.succeeded)) {
          _recordDiagnostic(
            directDiagnostics,
            _diagnostic(
              operation.operationId,
              ReplayBlockReason.parentFailure,
              'sync.replay.parent_failed',
              related: [dependency.parentOperationId],
            ),
          );
          continue;
        }
        if (activeParent == null && historyParent == null) {
          _recordDiagnostic(
            directDiagnostics,
            _diagnostic(
              operation.operationId,
              ReplayBlockReason.missingDependency,
              'sync.replay.missing_dependency',
              missing: [parentId],
            ),
          );
          continue;
        }
        if (activeParent != null && !pendingIds.contains(parentId)) {
          deferredIds.add(operation.operationId.value);
        }
      }
    }

    final candidates = pending
        .where(
          (operation) =>
              !directDiagnostics.containsKey(operation.operationId.value) &&
              !deferredIds.contains(operation.operationId.value),
        )
        .map(
          (operation) => SyncDagNode<MutationOperation>(
            id: operation.operationId.value,
            payload: operation,
            dependsOnIds: operation.dependencies
                .map((dependency) => dependency.parentOperationId.value)
                .where(pendingIds.contains)
                .toList(growable: false),
          ),
        )
        .toList(growable: false);

    final resolution = const KahnDagSorter<MutationOperation>(
      readyNodeComparator: _compareReadyNodes,
    ).resolve(candidates);
    final diagnostics = <ReplayDiagnostic>[...directDiagnostics.values];
    for (final blockedNode in resolution.blockedNodes) {
      final reason = blockedNode.reason;
      final missingIds = blockedNode.missingDependencyIds;
      final parentFailure = missingIds.any(directDiagnostics.containsKey);
      diagnostics.add(
        _diagnostic(
          blockedNode.node.payload.operationId,
          parentFailure
              ? ReplayBlockReason.parentFailure
              : switch (reason) {
                  SyncDagBlockReason.missingDependency =>
                    ReplayBlockReason.missingDependency,
                  SyncDagBlockReason.cycle => ReplayBlockReason.cycle,
                  SyncDagBlockReason.selfDependency =>
                    ReplayBlockReason.selfDependency,
                },
          parentFailure ? 'sync.replay.parent_failed' : _messageKeyFor(reason),
          missing: parentFailure ? const <String>[] : missingIds,
        ),
      );
    }
    return _ReplaySelection(
      generation: _store.generation,
      orderedNodes: resolution.orderedNodes,
      diagnostics: _deduplicateDiagnostics(diagnostics),
    );
  }

  Future<_StartedOperation?> _start(MutationOperation operation) async {
    final expectedGeneration = _store.generation;
    final snapshot = _store.snapshot;
    final current = _findActive(snapshot, operation.operationId.value);
    if (current == null || current.state != MutationOperationState.pending) {
      return null;
    }
    final projection = _resolveDependencies(current, snapshot);
    final projectionDiagnostic = projection.diagnostic;
    if (projectionDiagnostic != null) {
      await _persistDiagnostics(
        _ReplaySelection(
          generation: _store.generation,
          orderedNodes: const <SyncDagNode<MutationOperation>>[],
          diagnostics: <ReplayDiagnostic>[projectionDiagnostic],
        ),
      );
      return null;
    }
    final started = current.copyWith(
      variables: projection.variables,
      state: MutationOperationState.running,
    );
    final committed = await _store.transact(
      (latest) {
        final latestOperation = _findActive(
          latest,
          operation.operationId.value,
        );
        if (latestOperation == null ||
            latestOperation.state != MutationOperationState.pending) {
          return latest;
        }
        return latest.copyWith(
          active: _replaceActive(latest.active, started),
        );
      },
      expectedGeneration: expectedGeneration,
    );
    final result = _findActive(committed, operation.operationId.value);
    if (result == null || result.state != MutationOperationState.running) {
      return null;
    }
    return _StartedOperation(
      operation: result,
      generation: _store.generation,
    );
  }

  Future<void> _completeSuccess(
    _StartedOperation started,
    Object? result,
  ) async {
    final operation = started.operation;
    OutboxHistoryEntry history;
    try {
      history = OutboxHistoryEntry.validated(
        operationId: operation.operationId,
        state: MutationOperationState.succeeded,
        completedAt: _now(),
        resultProjection: result,
      );
    } on Object {
      await _completeFailure(
        started,
        const InvalidMutationPayloadException(
          'Mutation result cannot be persisted safely',
        ),
        unknownOutcome: true,
      );
      return;
    }
    await _store.transact(
      (current) {
        final active = _findActive(current, operation.operationId.value);
        if (active == null || active.state != MutationOperationState.running) {
          throw StateError(
            'Replay completion lost operation ${operation.operationId.value}',
          );
        }
        return current.copyWith(
          active: _removeActive(current.active, operation.operationId),
          history: [...current.history, history],
        );
      },
      expectedGeneration: started.generation,
    );
  }

  Future<void> _completeFailure(
    _StartedOperation started,
    Object error, {
    bool unknownOutcome = false,
  }) async {
    final operation = started.operation;
    final category = unknownOutcome
        ? MutationFailureCategory.unknown
        : _failureCategory(error);
    final state = unknownOutcome
        ? MutationOperationState.unknownOutcome
        : MutationOperationState.failedTerminal;
    await _store.transact(
      (current) {
        final active = _findActive(current, operation.operationId.value);
        if (active == null || active.state != MutationOperationState.running) {
          throw StateError(
            'Replay failure lost operation ${operation.operationId.value}',
          );
        }
        final failedOperation = operation.copyWith(state: state);
        return current.copyWith(
          active: _removeActive(current.active, operation.operationId),
          deadLetters: [
            ...current.deadLetters,
            OutboxDeadLetter(
              operation: failedOperation,
              category: category,
              messageKey: unknownOutcome
                  ? 'sync.replay.unknown_outcome'
                  : _messageKeyForFailure(category),
              retryable: false,
              repairable: true,
              failedAt: _now(),
            ),
          ],
          history: [
            ...current.history,
            OutboxHistoryEntry.validated(
              operationId: operation.operationId,
              state: state,
              completedAt: _now(),
            ),
          ],
        );
      },
      expectedGeneration: started.generation,
    );
  }

  Future<void> _clearDiagnostics() async {
    final snapshot = _store.snapshot;
    if (!snapshot.metadata.containsKey(_diagnosticsMetadataKey)) return;
    final metadata = Map<String, Object?>.from(snapshot.metadata)
      ..remove(_diagnosticsMetadataKey);
    await _store.transact(
      (current) => current.copyWith(metadata: metadata),
      expectedGeneration: _store.generation,
    );
  }

  Future<void> _persistDiagnostics(_ReplaySelection selection) async {
    if (selection.diagnostics.isEmpty) return;
    await _store.transact(
      (current) {
        final diagnosticById = <String, ReplayDiagnostic>{
          for (final diagnostic in selection.diagnostics)
            diagnostic.operationId.value: diagnostic,
        };
        final active = current.active
            .map((operation) {
              final diagnostic = diagnosticById[operation.operationId.value];
              if (diagnostic == null ||
                  operation.state != MutationOperationState.pending) {
                return operation;
              }
              return operation.copyWith(state: MutationOperationState.blocked);
            })
            .toList(growable: false);
        final metadata = Map<String, Object?>.from(current.metadata)
          ..[_diagnosticsMetadataKey] = selection.diagnostics
              .map((diagnostic) => diagnostic.toJson())
              .toList(growable: false);
        return current.copyWith(active: active, metadata: metadata);
      },
      expectedGeneration: selection.generation,
    );
  }

  _ProjectionResult _resolveDependencies(
    MutationOperation operation,
    OutboxSnapshot snapshot,
  ) {
    var variables = operation.variables;
    for (final dependency in operation.dependencies) {
      if (dependency.parentResultPath == null &&
          dependency.childVariablePath == null) {
        continue;
      }
      final parent = _findHistory(
        snapshot,
        dependency.parentOperationId.value,
      );
      if (parent == null || parent.state != MutationOperationState.succeeded) {
        return _ProjectionResult.diagnostic(
          _diagnostic(
            operation.operationId,
            ReplayBlockReason.missingParentResult,
            'sync.replay.parent_result_missing',
            related: [dependency.parentOperationId],
          ),
        );
      }
      final parentResultPath = dependency.parentResultPath;
      final childVariablePath = dependency.childVariablePath;
      if (parentResultPath == null || childVariablePath == null) {
        return _ProjectionResult.diagnostic(
          _diagnostic(
            operation.operationId,
            ReplayBlockReason.invalidBinding,
            'sync.replay.invalid_parent_binding',
            related: [dependency.parentOperationId],
          ),
        );
      }
      final lookup = _readJsonPath(parent.resultProjection, parentResultPath);
      if (!lookup.found) {
        return _ProjectionResult.diagnostic(
          _diagnostic(
            operation.operationId,
            ReplayBlockReason.missingParentResult,
            'sync.replay.parent_result_missing',
            related: [dependency.parentOperationId],
          ),
        );
      }
      try {
        variables = _writeJsonPath(
          variables,
          childVariablePath,
          lookup.value,
        );
      } on InvalidMutationPayloadException {
        return _ProjectionResult.diagnostic(
          _diagnostic(
            operation.operationId,
            ReplayBlockReason.invalidBinding,
            'sync.replay.invalid_parent_binding',
            related: [dependency.parentOperationId],
          ),
        );
      }
    }
    return _ProjectionResult.variables(variables);
  }

  bool _hasValidBinding(MutationDependency dependency) {
    final parentResultPath = dependency.parentResultPath;
    final childVariablePath = dependency.childVariablePath;
    if ((parentResultPath == null) != (childVariablePath == null)) {
      return false;
    }
    return (parentResultPath == null || _isValidJsonPath(parentResultPath)) &&
        (childVariablePath == null || _isValidJsonPath(childVariablePath));
  }

  void _requireOpen() {
    if (!_isOpen) {
      throw StateError('The replay coordinator is not open');
    }
  }

  Future<T> _serialized<T>(Future<T> Function() operation) async {
    final previous = _tail;
    final completer = _Completion();
    _tail = completer.future;
    await previous;
    try {
      return await operation();
    } finally {
      completer.complete();
    }
  }
}

class _ReplaySelection {
  const _ReplaySelection({
    required this.generation,
    required this.orderedNodes,
    required this.diagnostics,
  });

  final int generation;
  final List<SyncDagNode<MutationOperation>> orderedNodes;
  final List<ReplayDiagnostic> diagnostics;
}

class _StartedOperation {
  const _StartedOperation({required this.operation, required this.generation});

  final MutationOperation operation;
  final int generation;
}

class _ProjectionResult {
  const _ProjectionResult._({this.variables, this.diagnostic});

  factory _ProjectionResult.variables(Object? variables) =>
      _ProjectionResult._(variables: variables);

  factory _ProjectionResult.diagnostic(ReplayDiagnostic diagnostic) =>
      _ProjectionResult._(diagnostic: diagnostic);

  final Object? variables;
  final ReplayDiagnostic? diagnostic;
}

class _PathLookup {
  const _PathLookup({required this.found, required this.value});

  final bool found;
  final Object? value;
}

class _Completion {
  final _completer = Completer<void>();

  Future<void> get future => _completer.future;

  void complete() => _completer.complete();
}

ReplayDiagnostic _diagnostic(
  OperationId operationId,
  ReplayBlockReason reason,
  String messageKey, {
  List<OperationId> related = const <OperationId>[],
  List<String> missing = const <String>[],
}) {
  return ReplayDiagnostic(
    operationId: operationId,
    reason: reason,
    messageKey: messageKey,
    relatedOperationIds: List.unmodifiable(related),
    missingDependencyIds: List.unmodifiable(missing),
  );
}

void _recordDiagnostic(
  Map<String, ReplayDiagnostic> diagnostics,
  ReplayDiagnostic diagnostic,
) {
  final operationId = diagnostic.operationId.value;
  final previous = diagnostics[operationId];
  diagnostics[operationId] = previous == null
      ? diagnostic
      : _mergeDiagnosticDetails(previous, diagnostic);
}

ReplayDiagnostic _mergeDiagnosticDetails(
  ReplayDiagnostic previous,
  ReplayDiagnostic current,
) {
  return ReplayDiagnostic(
    operationId: current.operationId,
    reason: current.reason,
    messageKey: current.messageKey,
    relatedOperationIds: _appendUnique(
      previous.relatedOperationIds,
      current.relatedOperationIds,
    ),
    missingDependencyIds: _appendUnique(
      previous.missingDependencyIds,
      current.missingDependencyIds,
    ),
  );
}

List<T> _appendUnique<T>(Iterable<T> previous, Iterable<T> current) {
  final values = <T>{...previous}..addAll(current);
  return List.unmodifiable(values);
}

List<ReplayDiagnostic> _deduplicateDiagnostics(
  Iterable<ReplayDiagnostic> diagnostics,
) {
  final byId = <String, ReplayDiagnostic>{};
  for (final diagnostic in diagnostics) {
    _recordDiagnostic(byId, diagnostic);
  }
  return byId.values.toList(growable: false);
}

int _compareReadyNodes(
  SyncDagNode<MutationOperation> left,
  SyncDagNode<MutationOperation> right,
) {
  final priority = right.payload.priority.compareTo(left.payload.priority);
  if (priority != 0) return priority;
  final createdAt = left.payload.createdAt.compareTo(right.payload.createdAt);
  if (createdAt != 0) return createdAt;
  return left.payload.operationId.value.compareTo(
    right.payload.operationId.value,
  );
}

String _messageKeyFor(SyncDagBlockReason reason) {
  return switch (reason) {
    SyncDagBlockReason.missingDependency => 'sync.replay.missing_dependency',
    SyncDagBlockReason.cycle => 'sync.replay.cycle',
    SyncDagBlockReason.selfDependency => 'sync.replay.self_dependency',
  };
}

MutationFailureCategory _failureCategory(Object error) {
  if (error is InvalidMutationPayloadException) {
    return MutationFailureCategory.payload;
  }
  if (error is UnknownMutationKeyException) {
    return MutationFailureCategory.executor;
  }
  return MutationFailureCategory.unknown;
}

bool _isDeterministicFailure(Object error) {
  return error is InvalidMutationPayloadException ||
      error is UnknownMutationKeyException;
}

String _messageKeyForFailure(MutationFailureCategory category) {
  return 'sync.replay.failure.${category.name}';
}

MutationOperation? _findActive(OutboxSnapshot snapshot, String operationId) {
  for (final operation in snapshot.active) {
    if (operation.operationId.value == operationId) return operation;
  }
  return null;
}

OutboxHistoryEntry? _findHistory(OutboxSnapshot snapshot, String operationId) {
  for (final entry in snapshot.history) {
    if (entry.operationId.value == operationId) return entry;
  }
  return null;
}

OutboxDeadLetter? _findDeadLetter(OutboxSnapshot snapshot, String operationId) {
  for (final entry in snapshot.deadLetters) {
    if (entry.operation.operationId.value == operationId) return entry;
  }
  return null;
}

List<MutationOperation> _replaceActive(
  List<MutationOperation> active,
  MutationOperation replacement,
) {
  return [
    for (final operation in active)
      if (operation.operationId == replacement.operationId)
        replacement
      else
        operation,
  ];
}

List<MutationOperation> _removeActive(
  List<MutationOperation> active,
  OperationId operationId,
) {
  return active
      .where((operation) => operation.operationId != operationId)
      .toList(growable: false);
}

_PathLookup _readJsonPath(Object? root, String path) {
  var current = root;
  for (final segment in _pathSegments(path)) {
    if (current is! Map<Object?, Object?> || !current.containsKey(segment)) {
      return const _PathLookup(found: false, value: null);
    }
    current = current[segment];
  }
  return _PathLookup(found: true, value: current);
}

Object? _writeJsonPath(Object? root, String path, Object? value) {
  final segments = _pathSegments(path);
  if (root is! Map<Object?, Object?>) {
    throw const InvalidMutationPayloadException(
      'Child variables must be a JSON object for parent binding',
    );
  }
  final result = _copyJsonMap(root);
  var current = result;
  for (var index = 0; index < segments.length; index++) {
    final segment = segments[index];
    if (index == segments.length - 1) {
      current[segment] = value;
      break;
    }
    final existing = current[segment];
    if (existing == null) {
      final next = <String, Object?>{};
      current[segment] = next;
      current = next;
    } else if (existing is Map<Object?, Object?>) {
      final next = _copyJsonMap(existing);
      current[segment] = next;
      current = next;
    } else {
      throw const InvalidMutationPayloadException(
        'Child variable path crosses a non-object value',
      );
    }
  }
  return result;
}

List<String> _pathSegments(String path) {
  final segments = path.split('.');
  if (segments.any((segment) => segment.trim().isEmpty)) {
    throw const InvalidMutationPayloadException(
      'JSON path contains an empty segment',
    );
  }
  return segments.map((segment) => segment.trim()).toList(growable: false);
}

bool _isValidJsonPath(String path) {
  return path.split('.').every((segment) => segment.trim().isNotEmpty);
}

Map<String, Object?> _copyJsonMap(Map<Object?, Object?> value) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const InvalidMutationPayloadException(
        'JSON object keys must be strings',
      );
    }
    result[key] = _copyJsonValue(entry.value);
  }
  return result;
}

Object? _copyJsonValue(Object? value) {
  if (value is Map<Object?, Object?>) return _copyJsonMap(value);
  if (value is List<Object?>) {
    return value.map(_copyJsonValue).toList(growable: false);
  }
  return value;
}
