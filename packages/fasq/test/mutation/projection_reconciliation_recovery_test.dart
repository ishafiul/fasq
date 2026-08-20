import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final mutationKey = MutationKey(namespace: 'tests', name: 'save');
  final plan = ProjectionPlan(
    id: 'todo.recovery',
    queryKeys: [StringQueryKey('todo:tmp-1')],
  );

  test(
    'reconciles persisted history after reopening with pending overlay',
    () async {
      final store = _RestartableOutboxStore();
      final first = _queue(store, plan, mutationKey);
      await first.open();
      final operation = await first.enqueue(
        key: mutationKey,
        variables: const <String, Object?>{'id': 'tmp-1'},
      );
      await first.enqueueProjection(
        ProjectionOverlay(
          operationId: operation.operationId,
          lineageId: operation.lineageId,
          plan: plan,
          patches: const {
            'todo:tmp-1': {'id': 'tmp-1'},
          },
        ),
      );
      await first.close();

      store.seed(
        OutboxSnapshot(
          history: [
            OutboxHistoryEntry.validated(
              operationId: operation.operationId,
              state: MutationOperationState.succeeded,
              completedAt: DateTime.utc(2026, 8, 21),
            ),
          ],
          metadata: store.snapshot.metadata,
        ),
      );

      final reopened = _queue(store, plan, mutationKey);
      await reopened.open();
      await reopened.replay();

      expect(reopened.projectionState!.overlays, isEmpty);
      await reopened.close();
    },
  );

  test(
    'reconciles persisted dead letter after reopening with pending overlay',
    () async {
      final store = _RestartableOutboxStore();
      final first = _queue(store, plan, mutationKey);
      await first.open();
      final operation = await first.enqueue(
        key: mutationKey,
        variables: const <String, Object?>{'id': 'tmp-1'},
      );
      await first.enqueueProjection(
        ProjectionOverlay(
          operationId: operation.operationId,
          lineageId: operation.lineageId,
          plan: plan,
          patches: const {
            'todo:tmp-1': {'id': 'tmp-1'},
          },
        ),
      );
      await first.close();

      store.seed(
        OutboxSnapshot(
          deadLetters: [
            OutboxDeadLetter(
              operation: operation.operation.copyWith(
                state: MutationOperationState.failedTerminal,
              ),
              category: MutationFailureCategory.business,
              messageKey: 'todo.save_rejected',
              retryable: false,
              repairable: true,
              failedAt: DateTime.utc(2026, 8, 21),
            ),
          ],
          metadata: store.snapshot.metadata,
        ),
      );

      final reopened = _queue(store, plan, mutationKey);
      await reopened.open();
      await reopened.replay();

      expect(reopened.projectionState!.overlays, isEmpty);
      await reopened.close();
    },
  );
}

DurableMutationQueue _queue(
  _RestartableOutboxStore store,
  ProjectionPlan plan,
  MutationKey mutationKey,
) {
  final registry = ProjectionRegistry()
    ..register(
      ProjectionDefinition(plan: plan, apply: (_, patch) => patch),
    );
  final queue = DurableMutationQueue(
    store: store,
    projectionCoordinator: ProjectionCoordinator(registry: registry),
  );
  queue.register<Map<String, Object?>, Map<String, Object?>>(
    key: mutationKey,
    codec: JsonMutationCodec<Map<String, Object?>>(
      encoder: (value) => value,
      decoder: (payload) => Map<String, Object?>.from(payload! as Map),
    ),
    mutationFn: (variables) async => variables,
  );
  return queue;
}

class _RestartableOutboxStore implements DurableOutboxStore {
  OutboxSnapshot _snapshot = OutboxSnapshot();
  int _generation = 0;
  bool _isOpen = false;

  void seed(OutboxSnapshot snapshot) {
    _snapshot = snapshot;
  }

  @override
  Future<OutboxSnapshot> open() async {
    _isOpen = true;
    return _snapshot;
  }

  @override
  OutboxSnapshot get snapshot => _snapshot;

  @override
  int get generation => _generation;

  @override
  Future<OutboxSnapshot> transact(
    DurableOutboxTransaction transaction, {
    int? expectedGeneration,
  }) async {
    if (!_isOpen) throw StateError('store is closed');
    if (expectedGeneration != null && expectedGeneration != _generation) {
      throw const OutboxGenerationConflictException();
    }
    _snapshot = transaction(_snapshot);
    _generation++;
    return _snapshot;
  }

  @override
  Future<void> close() async {
    _isOpen = false;
  }
}
