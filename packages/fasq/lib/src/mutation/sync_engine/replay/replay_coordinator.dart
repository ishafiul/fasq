import 'dart:async';

import 'package:fasq/src/mutation/sync_engine/codecs/mutation_codec.dart';
import 'package:fasq/src/mutation/sync_engine/conflict/conflict_models.dart';
import 'package:fasq/src/mutation/sync_engine/conflict/conflict_policy.dart';
import 'package:fasq/src/mutation/sync_engine/execution/auth_session.dart';
import 'package:fasq/src/mutation/sync_engine/execution/execution_context.dart';
import 'package:fasq/src/mutation/sync_engine/kahn_dag.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_json_path.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/replay/retry_policy.dart';
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
    List<OperationId> scheduledRetryOperationIds = const <OperationId>[],
    Map<OperationId, Object?> successfulResults =
        const <OperationId, Object?>{},
  }) : executedOperationIds = List.unmodifiable(executedOperationIds),
       failedOperationIds = List.unmodifiable(failedOperationIds),
       recoveredUnknownOutcomeIds = List.unmodifiable(
         recoveredUnknownOutcomeIds,
       ),
       blockedOperations = List.unmodifiable(blockedOperations),
       scheduledRetryOperationIds = List.unmodifiable(
         scheduledRetryOperationIds,
       ),
       successfulResults = Map.unmodifiable(successfulResults);

  /// Operations whose registered executor was invoked.
  final List<OperationId> executedOperationIds;

  /// Operations whose executor returned a failure recorded for repair.
  final List<OperationId> failedOperationIds;

  /// Operations recovered from a prior process crash.
  final List<OperationId> recoveredUnknownOutcomeIds;

  /// Operations left blocked with durable diagnostics.
  final List<ReplayDiagnostic> blockedOperations;

  /// Operations that failed safely and were scheduled for later replay.
  final List<OperationId> scheduledRetryOperationIds;

  /// Typed in-process results produced during this replay request.
  ///
  /// Results are intentionally not serialized. Restart recovery uses
  /// persisted result projections instead.
  final Map<OperationId, Object?> successfulResults;

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
    MutationExecutionAdapter? executionAdapter,
    RetryPolicy retryPolicy = const RetryPolicy(),
    AuthSessionProvider? authSessionProvider,
    bool Function()? isOnline,
    this.ownsStore = true,
  }) : _store = store,
       _registrations = registrations,
       _now = now ?? DateTime.now,
       _executionAdapter =
           executionAdapter ?? const DirectMutationExecutionAdapter(),
       _retryPolicy = retryPolicy,
       _authSessionProvider = authSessionProvider,
       _isOnline = isOnline;

  static const _diagnosticsMetadataKey = 'replayDiagnostics';
  static const _rateLimitPausesMetadataKey = 'rateLimitPauses';

  final DurableOutboxStore _store;
  final MutationRegistrationRegistry _registrations;
  final DateTime Function() _now;
  final MutationExecutionAdapter _executionAdapter;
  final RetryPolicy _retryPolicy;
  final AuthSessionProvider? _authSessionProvider;
  final bool Function()? _isOnline;

  /// Whether this coordinator owns the durable store lifecycle.
  final bool ownsStore;
  final AuthScopeGate _authScopeGate = const AuthScopeGate();
  Future<void> _tail = Future<void>.value();
  bool _isOpen = false;
  List<OperationId> _recoveredUnknownOutcomeIds = const <OperationId>[];
  Map<String, DateTime> _rateLimitPauses = const <String, DateTime>{};
  String? _lastServedRateLimitBucket;

  /// Opens the store and converts leftover running work into safe dead letters.
  Future<void> open() {
    return _serialized(() async {
      if (_isOpen) return;
      await _store.open();
      try {
        _rateLimitPauses = _readRateLimitPauses(_store.snapshot.metadata);
        _recoveredUnknownOutcomeIds = await _recoverInterrupted();
        _isOpen = true;
      } on Object {
        if (ownsStore) {
          try {
            await _store.close();
          } on Object {
            // Preserve the recovery failure; the store owns its cleanup error.
          }
        }
        rethrow;
      }
    });
  }

  /// Replays all currently admissible work in deterministic order.
  ///
  /// When [cancellationToken] is omitted, cancellation remains internal to
  /// this replay request. A supplied token lets the caller stop future work
  /// and lets cooperative adapters observe cancellation for active work.
  Future<ReplayRunResult> replay({
    ReplayCancellationToken? cancellationToken,
  }) {
    return _serialized(() async {
      _requireOpen();
      final replayCancellationToken =
          cancellationToken ?? ReplayCancellationToken();
      final executed = <OperationId>[];
      final failed = <OperationId>[];
      final scheduledRetries = <OperationId>[];
      final blocked = <String, ReplayDiagnostic>{};
      final successfulResults = <OperationId, Object?>{};
      final recovered = List<OperationId>.from(_recoveredUnknownOutcomeIds);
      _recoveredUnknownOutcomeIds = const <OperationId>[];

      await _applyReadinessGates();
      await _applySchedulingLimits();
      await _unblockReadyOperations();
      await _clearDiagnostics();
      while (true) {
        if (replayCancellationToken.isCancelled) break;
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
        _lastServedRateLimitBucket = operation.rateLimitBucket;
        executed.add(operation.operationId);

        final context = MutationExecutionContext(
          operationId: operation.operationId,
          idempotencyKey: operation.idempotencyKey,
          authPolicy: operation.authPolicy,
          authScope: operation.authScope,
          conflictPolicy: operation.conflictPolicy,
          conflictPrecondition: operation.conflictPrecondition,
          attempt: operation.attemptCount,
          cancellationToken: replayCancellationToken,
        );
        MutationExecutionResult execution;
        try {
          execution = await _executionAdapter.execute(
            context,
            () => _registrations.executeRegistered(
              operation.mutationKey,
              operation.variables,
            ),
          );
        } on Object catch (error) {
          execution = MutationExecutionFailure(
            _classifyAdapterError(error),
          );
        }
        if (execution case MutationExecutionSuccess(:final value)) {
          final registered = value;
          if (registered is RegisteredMutationExecution) {
            final completed = await _completeSuccess(
              started,
              registered.projection,
            );
            if (completed) {
              successfulResults[operation.operationId] = registered.data;
            } else {
              failed.add(operation.operationId);
            }
          } else {
            final completed = await _completeSuccess(started, registered);
            if (completed) {
              successfulResults[operation.operationId] = registered;
            } else {
              failed.add(operation.operationId);
            }
          }
          continue;
        }
        if (execution case MutationExecutionFailure(:final failure)) {
          failed.add(operation.operationId);
          final action = await _completeFailure(
            started,
            failure,
          );
          if (action == RetryPlanAction.retry) {
            scheduledRetries.add(operation.operationId);
          }
        }
      }

      return ReplayRunResult(
        executedOperationIds: List.unmodifiable(executed),
        failedOperationIds: List.unmodifiable(failed),
        recoveredUnknownOutcomeIds: List.unmodifiable(recovered),
        blockedOperations: List.unmodifiable(blocked.values),
        scheduledRetryOperationIds: List.unmodifiable(scheduledRetries),
        successfulResults: successfulResults,
      );
    });
  }

  /// Closes the coordinator and releases the outbox owner marker.
  Future<void> close() {
    return _serialized(() async {
      if (!_isOpen) return;
      if (ownsStore) await _store.close();
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
              idempotencyKey: operation.idempotencyKey,
              mutationKey: operation.mutationKey,
              authScope: operation.authScope,
              identity: operation.identity,
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
    final replayable = snapshot.active
        .where(_isReplayable)
        .toList(growable: false);
    if (replayable.isEmpty) {
      return const _ReplaySelection(
        generation: 0,
        orderedNodes: <SyncDagNode<MutationOperation>>[],
        diagnostics: <ReplayDiagnostic>[],
      );
    }

    final pending = replayable.where(_isDue).toList(growable: false);
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

    final resolution = KahnDagSorter<MutationOperation>(
      readyNodeComparator: (left, right) => _compareReadyNodes(
        left,
        right,
        preferredBucket: _lastServedRateLimitBucket,
      ),
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
    if (current == null || !_isReplayable(current)) {
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
      attemptCount: current.attemptCount + 1,
      lastAttemptAt: _now(),
      nextRunAt: null,
    );
    final committed = await _store.transact(
      (latest) {
        final latestOperation = _findActive(
          latest,
          operation.operationId.value,
        );
        if (latestOperation == null || !_isReplayable(latestOperation)) {
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

  Future<bool> _completeSuccess(
    _StartedOperation started,
    Object? result,
  ) async {
    final operation = started.operation;
    OutboxHistoryEntry history;
    try {
      final identity = _resolveIdentity(operation.identity, result);
      history = OutboxHistoryEntry.validated(
        operationId: operation.operationId,
        state: MutationOperationState.succeeded,
        completedAt: _now(),
        idempotencyKey: operation.idempotencyKey,
        mutationKey: operation.mutationKey,
        authScope: operation.authScope,
        identity: identity,
        resultProjection: result,
      );
    } on Object {
      await _completeFailure(
        started,
        const MutationAdapterFailure(
          category: MutationFailureCategory.payload,
          messageKey: 'sync.replay.invalid_result',
          disposition: MutationFailureDisposition.unknownOutcome,
          outcomeKnowledge: MutationOutcomeKnowledge.unknown,
        ),
      );
      return false;
    }
    await _store.transact(
      (current) {
        final currentActive = _findActive(
          current,
          operation.operationId.value,
        );
        if (currentActive == null ||
            currentActive.state != MutationOperationState.running) {
          throw StateError(
            'Replay completion lost operation ${operation.operationId.value}',
          );
        }
        final nextActive = _removeActive(current.active, operation.operationId);
        final updatedHistory = [...current.history, history];
        return current.copyWith(
          active: _unblockDependents(nextActive, updatedHistory),
          history: updatedHistory,
        );
      },
      expectedGeneration: started.generation,
    );
    return true;
  }

  Future<RetryPlanAction> _completeFailure(
    _StartedOperation started,
    MutationAdapterFailure failure,
  ) async {
    final operation = started.operation;
    final plan = _retryPolicy.plan(
      operation: operation,
      failure: failure,
      now: _now(),
    );
    if (plan.action == RetryPlanAction.retry ||
        plan.action == RetryPlanAction.pause) {
      await _store.transact(
        (current) {
          final active = _findActive(current, operation.operationId.value);
          if (active == null ||
              active.state != MutationOperationState.running) {
            throw StateError(
              'Replay failure lost operation ${operation.operationId.value}',
            );
          }
          final nextState = plan.action == RetryPlanAction.retry
              ? MutationOperationState.retryScheduled
              : _pauseStateFor(failure);
          final metadata = Map<String, Object?>.from(current.metadata);
          final bucket = failure.rateLimitBucket;
          final nextRunAt = plan.nextRunAt;
          if (bucket != null && nextRunAt != null) {
            final pauses = _readRateLimitPauses(metadata)..[bucket] = nextRunAt;
            metadata[_rateLimitPausesMetadataKey] = _encodeRateLimitPauses(
              pauses,
            );
            _rateLimitPauses = pauses;
          }
          return current.copyWith(
            active: _replaceActive(
              current.active,
              operation.copyWith(
                state: nextState,
                nextRunAt: plan.nextRunAt,
                rateLimitBucket:
                    failure.rateLimitBucket ?? operation.rateLimitBucket,
              ),
            ),
            metadata: metadata,
          );
        },
        expectedGeneration: started.generation,
      );
      return plan.action;
    }

    final unknownOutcome = plan.action == RetryPlanAction.unknownOutcome;
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
        final failedOperation = operation.copyWith(
          state: state,
          nextRunAt: null,
        );
        return current.copyWith(
          active: _removeActive(current.active, operation.operationId),
          deadLetters: [
            ...current.deadLetters,
            OutboxDeadLetter(
              operation: failedOperation,
              category: unknownOutcome
                  ? MutationFailureCategory.unknown
                  : failure.category,
              messageKey: unknownOutcome
                  ? 'sync.replay.unknown_outcome'
                  : plan.messageKey,
              retryable: _isRetryableTerminal(failure, plan.action),
              repairable: failure.repairable,
              failedAt: _now(),
              conflictEvidence:
                  failure.category == MutationFailureCategory.conflict
                  ? ConflictEvidence(
                      operation: operation,
                      classification: ConflictClassification(
                        kind: failure.conflictKind,
                        messageKey: failure.messageKey,
                      ),
                      occurredAt: _now(),
                      expectedPrecondition: operation.conflictPrecondition,
                      observedPrecondition: failure.observedPrecondition,
                      latestServerSnapshot: failure.latestServerSnapshot,
                      projectionImpact:
                          failure.projectionImpact ??
                          operation.projections
                              .map((item) => item.toJson())
                              .toList(growable: false),
                    ).toJson()
                  : null,
            ),
          ],
          history: [
            ...current.history,
            OutboxHistoryEntry.validated(
              operationId: operation.operationId,
              state: state,
              completedAt: _now(),
              idempotencyKey: operation.idempotencyKey,
              mutationKey: operation.mutationKey,
              authScope: operation.authScope,
              identity: operation.identity,
            ),
          ],
        );
      },
      expectedGeneration: started.generation,
    );
    return plan.action;
  }

  Future<void> _clearDiagnostics() async {
    final snapshot = _store.snapshot;
    if (!snapshot.metadata.containsKey(_diagnosticsMetadataKey)) return;
    if (snapshot.active.any(
      (operation) => operation.state == MutationOperationState.blocked,
    )) {
      return;
    }
    final metadata = Map<String, Object?>.from(snapshot.metadata)
      ..remove(_diagnosticsMetadataKey);
    await _store.transact(
      (current) => current.copyWith(metadata: metadata),
      expectedGeneration: _store.generation,
    );
  }

  Future<void> _applyReadinessGates() async {
    final session = _authSessionProvider == null
        ? null
        : await _authSessionProvider.currentSession();
    final isOnline = _isOnline?.call() ?? true;
    final snapshot = _store.snapshot;
    final changed = <MutationOperation>[];
    for (final operation in snapshot.active) {
      if (!_isReplayable(operation) &&
          operation.state != MutationOperationState.paused &&
          operation.state != MutationOperationState.authBlocked &&
          operation.state != MutationOperationState.quarantined) {
        continue;
      }
      var nextState = operation.state;
      if (!isOnline) {
        nextState = MutationOperationState.paused;
      } else if (operation.authPolicy == AuthPolicy.required &&
          session == null) {
        nextState = MutationOperationState.authBlocked;
      } else if (session != null) {
        final decision = _authScopeGate.evaluate(operation, session);
        nextState = switch (decision) {
          AuthExecutionDecision.allowed =>
            _isReplayable(operation)
                ? operation.state
                : MutationOperationState.pending,
          AuthExecutionDecision.blocked => MutationOperationState.authBlocked,
          AuthExecutionDecision.quarantined =>
            MutationOperationState.quarantined,
        };
      } else if (operation.state == MutationOperationState.paused) {
        nextState = MutationOperationState.pending;
      }
      if (nextState != operation.state) {
        changed.add(operation.copyWith(state: nextState));
      }
    }
    if (changed.isEmpty) return;
    final replacements = {
      for (final operation in changed) operation.operationId.value: operation,
    };
    await _store.transact(
      (current) => current.copyWith(
        active: [
          for (final operation in current.active)
            replacements[operation.operationId.value] ?? operation,
        ],
      ),
      expectedGeneration: _store.generation,
    );
  }

  Future<void> _applySchedulingLimits() async {
    final now = _now();
    final reasonByOperationId = <String, String>{};
    for (final operation in _store.snapshot.active) {
      if (operation.state == MutationOperationState.running) continue;
      if (operation.attemptCount >= operation.maxAttempts) {
        reasonByOperationId[operation.operationId.value] =
            'sync.replay.max_attempts';
      } else if (!now.isBefore(operation.createdAt.add(operation.maxAge))) {
        reasonByOperationId[operation.operationId.value] =
            'sync.replay.max_age';
      }
    }
    if (reasonByOperationId.isEmpty) return;

    await _store.transact(
      (current) {
        final limited = <MutationOperation>[];
        final active = <MutationOperation>[];
        for (final operation in current.active) {
          if (reasonByOperationId.containsKey(operation.operationId.value)) {
            limited.add(operation);
          } else {
            active.add(operation);
          }
        }
        if (limited.isEmpty) return current;
        return current.copyWith(
          active: active,
          deadLetters: [
            ...current.deadLetters,
            for (final operation in limited)
              OutboxDeadLetter(
                operation: operation.copyWith(
                  state: MutationOperationState.failedTerminal,
                  nextRunAt: null,
                ),
                category: MutationFailureCategory.unknown,
                messageKey: operation.attemptCount >= operation.maxAttempts
                    ? 'sync.replay.max_attempts'
                    : 'sync.replay.max_age',
                retryable: _isRetryableSchedulingLimit(operation),
                repairable: true,
                failedAt: now,
              ),
          ],
          history: [
            ...current.history,
            for (final operation in limited)
              OutboxHistoryEntry.validated(
                operationId: operation.operationId,
                state: MutationOperationState.failedTerminal,
                completedAt: now,
                idempotencyKey: operation.idempotencyKey,
                mutationKey: operation.mutationKey,
                authScope: operation.authScope,
                identity: operation.identity,
              ),
          ],
        );
      },
      expectedGeneration: _store.generation,
    );
  }

  bool _isReplayable(MutationOperation operation) {
    return operation.state == MutationOperationState.pending ||
        operation.state == MutationOperationState.retryScheduled;
  }

  Future<void> _unblockReadyOperations() async {
    final snapshot = _store.snapshot;
    final readyIds = snapshot.active
        .where(
          (operation) =>
              operation.state == MutationOperationState.blocked &&
              operation.dependencies.isNotEmpty &&
              _allDependenciesSucceeded(operation, snapshot),
        )
        .map((operation) => operation.operationId.value)
        .toSet();
    if (readyIds.isEmpty) return;

    await _store.transact(
      (current) => current.copyWith(
        active: [
          for (final operation in current.active)
            readyIds.contains(operation.operationId.value)
                ? operation.copyWith(state: MutationOperationState.pending)
                : operation,
        ],
      ),
      expectedGeneration: _store.generation,
    );
  }

  List<MutationOperation> _unblockDependents(
    List<MutationOperation> active,
    List<OutboxHistoryEntry> history,
  ) {
    final snapshot = OutboxSnapshot(active: active, history: history);
    return [
      for (final operation in active)
        operation.state == MutationOperationState.blocked &&
                operation.dependencies.isNotEmpty &&
                _allDependenciesSucceeded(operation, snapshot)
            ? operation.copyWith(state: MutationOperationState.pending)
            : operation,
    ];
  }

  bool _allDependenciesSucceeded(
    MutationOperation operation,
    OutboxSnapshot snapshot,
  ) {
    return operation.dependencies.every((dependency) {
      final parent = _findHistory(
        snapshot,
        dependency.parentOperationId.value,
      );
      return parent?.state == MutationOperationState.succeeded;
    });
  }

  bool _isRetryableTerminal(
    MutationAdapterFailure failure,
    RetryPlanAction action,
  ) {
    return action == RetryPlanAction.terminal &&
        failure.disposition == MutationFailureDisposition.retry &&
        failure.outcomeKnowledge == MutationOutcomeKnowledge.known &&
        failure.category != MutationFailureCategory.conflict;
  }

  bool _isRetryableSchedulingLimit(MutationOperation operation) {
    return operation.state == MutationOperationState.retryScheduled &&
        operation.conflictPolicy == ConflictPolicy.none;
  }

  bool _isDue(MutationOperation operation) {
    final nextRunAt = operation.nextRunAt;
    if (nextRunAt != null && nextRunAt.isAfter(_now())) return false;
    final bucket = operation.rateLimitBucket;
    final pausedUntil = bucket == null ? null : _rateLimitPauses[bucket];
    return pausedUntil == null || !pausedUntil.isAfter(_now());
  }

  MutationAdapterFailure _classifyAdapterError(Object error) {
    return error is MutationAdapterException
        ? error.failure
        : const DefaultMutationFailureClassifier().classify(error);
  }

  MutationOperationState _pauseStateFor(MutationAdapterFailure failure) {
    return switch (failure.category) {
      MutationFailureCategory.authentication =>
        MutationOperationState.authBlocked,
      MutationFailureCategory.authorization =>
        MutationOperationState.authorizationBlocked,
      _ => MutationOperationState.paused,
    };
  }

  Map<String, DateTime> _readRateLimitPauses(Map<String, Object?> metadata) {
    final raw = metadata[_rateLimitPausesMetadataKey];
    if (raw is! Map<Object?, Object?>) return <String, DateTime>{};
    final result = <String, DateTime>{};
    for (final entry in raw.entries) {
      if (entry.key is! String || entry.value is! String) continue;
      try {
        result[entry.key! as String] = DateTime.parse(entry.value! as String);
      } on FormatException {
        // Invalid scheduler metadata is ignored; operation records remain safe.
      }
    }
    return result;
  }

  Map<String, Object?> _encodeRateLimitPauses(
    Map<String, DateTime> pauses,
  ) => {
    for (final entry in pauses.entries)
      entry.key: entry.value.toIso8601String(),
  };

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
      final lookup = readMutationJsonPath(
        parent.resultProjection,
        parentResultPath,
      );
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
        variables = writeMutationJsonPath(
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
    return (parentResultPath == null ||
            isValidMutationJsonPath(parentResultPath)) &&
        (childVariablePath == null ||
            isValidMutationJsonPath(childVariablePath));
  }

  MutationIdentityLink? _resolveIdentity(
    MutationIdentityLink? identity,
    Object? result,
  ) {
    if (identity == null) return null;
    final serverIdPath = identity.serverIdPath;
    if (serverIdPath == null) return identity;
    final lookup = readMutationJsonPath(result, serverIdPath);
    final serverId = lookup.value;
    if (!lookup.found || serverId is! String || serverId.trim().isEmpty) {
      throw const InvalidMutationResultException();
    }
    return identity.resolve(serverId);
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
  SyncDagNode<MutationOperation> right, {
  String? preferredBucket,
}) {
  if (preferredBucket != null) {
    final leftIsPreferred = left.payload.rateLimitBucket == preferredBucket;
    final rightIsPreferred = right.payload.rateLimitBucket == preferredBucket;
    if (leftIsPreferred != rightIsPreferred) {
      return leftIsPreferred ? 1 : -1;
    }
  }
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
