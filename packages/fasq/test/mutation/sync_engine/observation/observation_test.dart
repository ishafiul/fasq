import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/observation/observation.dart';
import 'package:fasq/src/mutation/sync_engine/observation/observation_models.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';
import 'package:test/test.dart';

void main() {
  final userScope = AuthScope(
    principalId: 'user-1',
    tenantId: 'tenant-a',
    authRealm: 'app',
  );
  final otherScope = AuthScope(
    principalId: 'user-2',
    tenantId: 'tenant-a',
    authRealm: 'app',
  );
  final mutationKey = MutationKey(namespace: 'notes', name: 'save');

  test('builds immutable redacted operation and dead-letter views', () {
    final operation = _operation(
      id: 'op-1',
      key: mutationKey,
      scope: userScope,
      variables: <String, Object?>{'secret': 'private-body'},
    );
    final snapshot = OutboxSnapshot(
      active: [operation],
      deadLetters: [
        OutboxDeadLetter(
          operation: _operation(id: 'op-2', key: mutationKey),
          category: MutationFailureCategory.conflict,
          messageKey: 'mutation.conflict',
          retryable: false,
          repairable: true,
          failedAt: DateTime.utc(2026, 1, 2),
          conflictEvidence: <String, Object?>{
            'secret': 'must-not-be-public',
          },
        ),
      ],
    );

    final observation = buildQueueObservation(snapshot);

    expect(observation.operations, hasLength(2));
    expect(observation.operations.first.authScope, userScope);
    expect(observation.operations.first.failure, isNull);
    expect(observation.operations.last.state, DurableOperationState.conflict);
    expect(
      observation.operations.last.failure,
      isA<DurableFailureObservation>(),
    );
    expect(
      observation.operations.last.failure!.messageKey,
      'mutation.conflict',
    );
    expect(observation.operations.last.failure!.retryable, isFalse);
    expect(observation.operations.last.failure!.repairable, isTrue);
    expect(
      () => observation.operations.add(observation.operations.first),
      throwsUnsupportedError,
    );
    expect(
      observation.operations.first.toString(),
      isNot(contains('private-body')),
    );
  });

  test(
    'filters authenticated operations by exact scope and preserves anonymous',
    () {
      final snapshot = OutboxSnapshot(
        active: [
          _operation(id: 'same-user', key: mutationKey, scope: userScope),
          _operation(id: 'other-user', key: mutationKey, scope: otherScope),
          _operation(id: 'anonymous', key: mutationKey),
        ],
      );

      final scoped = buildQueueObservation(
        snapshot,
        filter: DurableQueueObservationFilter(authScope: userScope),
      );
      final scopedOnly = buildQueueObservation(
        snapshot,
        filter: DurableQueueObservationFilter(
          authScope: userScope,
          includeUnauthenticated: false,
        ),
      );

      expect(
        scoped.operations.map((operation) => operation.operationId.value),
        containsAll(<String>['same-user', 'anonymous']),
      );
      expect(
        scoped.operations.map((operation) => operation.operationId.value),
        isNot(contains('other-user')),
      );
      expect(
        scopedOnly.operations.map((operation) => operation.operationId.value),
        <String>['same-user'],
      );
    },
  );

  test(
    'supports point lookup, state filters, dead letters, and retained history',
    () {
      final operation = _operation(
        id: 'queued',
        key: mutationKey,
        state: MutationOperationState.pending,
      );
      final snapshot = OutboxSnapshot(
        active: [operation],
        deadLetters: [
          OutboxDeadLetter(
            operation: _operation(id: 'failed', key: mutationKey),
            category: MutationFailureCategory.business,
            messageKey: 'mutation.rejected',
            retryable: false,
            repairable: false,
            failedAt: DateTime.utc(2026, 1, 2),
          ),
        ],
        history: [
          OutboxHistoryEntry.validated(
            operationId: OperationId('done'),
            state: MutationOperationState.succeeded,
            completedAt: DateTime.utc(2026, 1, 3),
            resultProjection: <String, Object?>{'private': true},
          ),
        ],
      );
      final observation = DurableObservation.fromSnapshot(snapshot);

      expect(
        observation.getOperation(OperationId('queued'))!.state,
        DurableOperationState.queued,
      );
      expect(observation.getOperation(OperationId('missing')), isNull);
      expect(
        observation
            .listOperations(
              DurableOperationFilter(
                states: <DurableOperationState>{
                  DurableOperationState.failedTerminal,
                },
              ),
            )
            .single
            .operationId
            .value,
        'failed',
      );
      expect(
        observation.getOperationHistory(OperationId('done')).single,
        isA<DurableHistoryObservation>(),
      );
      expect(
        observation
            .getOperationHistory(OperationId('done'))
            .single
            .hasResultProjection,
        isTrue,
      );
      expect(
        observation.getOperationHistory(
          OperationId('done'),
          authScope: userScope,
        ),
        isEmpty,
      );
    },
  );

  test(
    'derives aggregate queue state with attention before syncing and waiting',
    () {
      final active = <MutationOperation>[
        _operation(id: 'running', state: MutationOperationState.running),
        _operation(id: 'waiting', state: MutationOperationState.pending),
      ];
      expect(
        buildQueueObservation(OutboxSnapshot(active: active)).aggregateState,
        DurableQueueAggregateState.syncing,
      );
      expect(
        buildQueueObservation(
          OutboxSnapshot(
            active: [
              _operation(
                id: 'quarantined',
                state: MutationOperationState.quarantined,
              ),
            ],
          ),
        ).aggregateState,
        DurableQueueAggregateState.quarantined,
      );
      expect(
        buildQueueObservation(
          OutboxSnapshot(
            deadLetters: [
              OutboxDeadLetter(
                operation: _operation(id: 'failed'),
                category: MutationFailureCategory.unknown,
                messageKey: 'mutation.unknown',
                retryable: false,
                repairable: false,
                failedAt: DateTime.utc(2026, 1, 2),
              ),
            ],
          ),
        ).aggregateState,
        DurableQueueAggregateState.attentionRequired,
      );
    },
  );

  test('exposes discarded audit state and unknown record guidance', () {
    final discarded = _operation(
      id: 'discarded',
      key: mutationKey,
      state: MutationOperationState.failedTerminal,
    );
    final observation = buildQueueObservation(
      OutboxSnapshot(
        deadLetters: [
          OutboxDeadLetter(
            operation: discarded,
            category: MutationFailureCategory.business,
            messageKey: 'mutation.rejected',
            retryable: false,
            repairable: false,
            failedAt: DateTime.utc(2026, 1, 2),
          ),
        ],
        history: [
          OutboxHistoryEntry.validated(
            operationId: discarded.operationId,
            state: MutationOperationState.discarded,
            completedAt: DateTime.utc(2026, 1, 3),
          ),
        ],
        unknownRecords: const [
          OutboxUnknownRecord(
            recordId: 'unknown-1',
            kind: OutboxUnknownRecordKind.active,
            schemaVersion: 1,
            messageKey: 'sync.outbox.unknown_record',
          ),
        ],
      ),
    );

    expect(
      observation.operations.single.state,
      DurableOperationState.discarded,
    );
    expect(observation.history.single.state, DurableOperationState.discarded);
    expect(observation.unknownRecords.single.recordId, 'unknown-1');
    expect(
      observation.aggregateState,
      DurableQueueAggregateState.attentionRequired,
    );
  });
}

MutationOperation _operation({
  required String id,
  MutationKey? key,
  AuthScope? scope,
  MutationOperationState state = MutationOperationState.pending,
  Object? variables,
}) {
  return MutationOperation(
    operationId: OperationId(id),
    mutationKey: key ?? MutationKey(namespace: 'test', name: 'mutation'),
    variables: variables ?? <String, Object?>{'value': id},
    createdAt: DateTime.utc(2026, 1, 1),
    idempotencyKey: IdempotencyKey('idem-$id'),
    lineageId: LineageId('lineage-$id'),
    authPolicy: scope == null ? AuthPolicy.none : AuthPolicy.required,
    authScope: scope,
    state: state,
  );
}
