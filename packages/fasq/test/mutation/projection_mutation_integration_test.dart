import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('rejects a projection builder without a serializable plan', () {
    expect(
      () => Mutation<Object?, Object?>(
        mutationFn: (_) async => null,
        options: MutationOptions(
          projectionBuilder: (_, __, ___) => ProjectionOverlay(
            operationId: OperationId('op'),
            lineageId: LineageId('lineage'),
            plan: ProjectionPlan(
              id: 'missing-plan',
              queryKeys: [StringQueryKey('todo')],
            ),
            patches: const {},
          ),
        ),
      ),
      throwsArgumentError,
    );
  });

  test(
    'public Mutation queues an optimistic projection with its operation',
    () async {
      final plan = ProjectionPlan(
        id: 'todo.public-create',
        queryKeys: [StringQueryKey('todo:tmp-public')],
      );
      final registry = ProjectionRegistry()
        ..register(
          ProjectionDefinition(plan: plan, apply: (_, patch) => patch),
        );
      final queue = DurableMutationQueue(
        store: _MemoryOutboxStore(),
        projectionCoordinator: ProjectionCoordinator(registry: registry),
      );
      final mutation = Mutation<Map<String, Object?>, Map<String, Object?>>(
        mutationFn: (variables) async => variables,
        options: MutationOptions(
          queueWhenOffline: true,
          durableQueue: DurableMutationQueueOptions(
            queue: queue,
            mutationKey: MutationKey(namespace: 'tests', name: 'public-create'),
            codec: _mapCodec,
            conflictPolicy: ConflictPolicy.required,
            conflictPrecondition: ConflictPrecondition('revision-1'),
          ),
          projectionPlan: plan,
          projectionBuilder: (operationId, lineageId, variables) =>
              ProjectionOverlay(
                operationId: operationId,
                lineageId: lineageId,
                plan: plan,
                patches: {'todo:tmp-public': variables},
              ),
        ),
      );

      NetworkStatus.instance.setOnline(online: false);
      await mutation.mutate(const <String, Object?>{
        'id': 'tmp-public',
        'title': 'offline',
      });

      expect(queue.projectionState!.overlays, hasLength(1));
      expect(
        queue.snapshot.active.single.conflictPolicy,
        ConflictPolicy.required,
      );
      expect(
        queue.snapshot.active.single.conflictPrecondition,
        ConflictPrecondition('revision-1'),
      );
      expect(
        queue.projectionState!.overlays.single.plan.registryKey,
        plan.registryKey,
      );

      mutation.dispose();
      NetworkStatus.instance.setOnline(online: true);
      await queue.close();
    },
  );

  test(
    'persists overlays, exposes them to cache sinks, and reconciles replay',
    () async {
      final plan = ProjectionPlan(
        id: 'todo.create',
        queryKeys: [StringQueryKey('todo:tmp-1')],
      );
      final registry = ProjectionRegistry()
        ..register(
          ProjectionDefinition(
            plan: plan,
            apply: (base, patch) => {
              ...(base as Map<Object?, Object?>? ?? const {}),
              ...(patch as Map<Object?, Object?>),
            },
          ),
        );
      final coordinator = ProjectionCoordinator(registry: registry);
      final sinkValues = <String, Object?>{};
      final store = _MemoryOutboxStore();
      final queue = DurableMutationQueue(
        store: store,
        projectionCoordinator: coordinator,
        projectionSink: (key, value) => sinkValues[key] = value,
      );
      final mutationKey = MutationKey(namespace: 'tests', name: 'todo-create');
      queue.register<Map<String, Object?>, Map<String, Object?>>(
        key: mutationKey,
        codec: JsonMutationCodec<Map<String, Object?>>(
          encoder: (value) => value,
          decoder: (payload) => Map<String, Object?>.from(payload! as Map),
        ),
        mutationFn: (variables) async => variables,
      );

      await queue.open();
      final acknowledgement = await queue.enqueue(
        key: mutationKey,
        variables: const <String, Object?>{'id': 'tmp-1', 'title': 'local'},
        projections: [
          MutationProjectionDescriptor(
            id: plan.registryKey,
            queryKeys: plan.queryKeys,
          ),
        ],
      );
      await queue.enqueueProjection(
        ProjectionOverlay(
          operationId: acknowledgement.operationId,
          lineageId: acknowledgement.lineageId,
          plan: plan,
          patches: const {
            'todo:tmp-1': {'id': 'tmp-1', 'title': 'local'},
          },
          temporaryIds: const {'todo': 'tmp-1'},
        ),
      );

      expect(sinkValues['todo:tmp-1'], {
        'id': 'tmp-1',
        'title': 'local',
      });
      expect(queue.snapshot.metadata['projectionState'], isNotNull);

      final replay = await queue.replay();

      expect(replay.didExecute, isTrue);
      expect(queue.projectionState!.overlays, isEmpty);
      await queue.close();
    },
  );

  test('restores projection overlays after queue restart', () async {
    final plan = ProjectionPlan(
      id: 'todo.edit',
      queryKeys: [StringQueryKey('todo:tmp-2')],
    );
    final registry = ProjectionRegistry()
      ..register(
        ProjectionDefinition(plan: plan, apply: (_, patch) => patch),
      );
    final store = _MemoryOutboxStore();
    final first = DurableMutationQueue(
      store: store,
      projectionCoordinator: ProjectionCoordinator(registry: registry),
    );
    final key = MutationKey(namespace: 'tests', name: 'todo-edit');
    first.register<Object?, Map<String, Object?>>(
      key: key,
      codec: _mapCodec,
      mutationFn: (variables) async => variables,
    );
    await first.open();
    final operation = await first.enqueue(
      key: key,
      variables: const <String, Object?>{'title': 'pending'},
    );
    await first.enqueueProjection(
      ProjectionOverlay(
        operationId: operation.operationId,
        lineageId: operation.lineageId,
        plan: plan,
        patches: const {
          'todo:tmp-2': {'title': 'pending'},
        },
      ),
    );
    await first.close();

    final secondCoordinator = ProjectionCoordinator(registry: registry);
    final second = DurableMutationQueue(
      store: store,
      projectionCoordinator: secondCoordinator,
    );
    await second.open();

    expect(
      second.projectionState!.overlays.single.operationId,
      operation.operationId,
    );
    expect(
      second.materializeProjection(StringQueryKey('todo:tmp-2'))!.value,
      {'title': 'pending'},
    );
    await second.close();
  });

  test(
    'remaps temporary IDs in projections and active operations atomically',
    () async {
      final plan = ProjectionPlan(
        id: 'todo.remap',
        queryKeys: [StringQueryKey('todo:tmp-3')],
      );
      final registry = ProjectionRegistry()
        ..register(
          ProjectionDefinition(plan: plan, apply: (_, patch) => patch),
        );
      final store = _MemoryOutboxStore();
      final queue = DurableMutationQueue(
        store: store,
        projectionCoordinator: ProjectionCoordinator(registry: registry),
      );
      final key = MutationKey(namespace: 'tests', name: 'todo-remap');
      queue.register<Object?, Map<String, Object?>>(
        key: key,
        codec: _mapCodec,
        mutationFn: (variables) async => variables,
      );

      await queue.open();
      final operation = await queue.enqueue(
        key: key,
        variables: const <String, Object?>{
          'todoId': 'tmp-3',
          'payload': {'relatedTodoId': 'tmp-3'},
        },
        projections: [
          MutationProjectionDescriptor(
            id: plan.registryKey,
            queryKeys: plan.queryKeys,
          ),
        ],
      );
      await queue.enqueueProjection(
        ProjectionOverlay(
          operationId: operation.operationId,
          lineageId: operation.lineageId,
          plan: plan,
          patches: const {
            'todo:tmp-3': {'id': 'tmp-3'},
          },
          temporaryIds: const {'todo': 'tmp-3'},
        ),
      );

      final outcome = await queue.remapProjectionId(
        temporaryId: 'tmp-3',
        serverId: 'server-3',
      );

      expect(outcome.failure, isNull);
      expect(queue.snapshot.active.single.variables, {
        'todoId': 'server-3',
        'payload': {'relatedTodoId': 'server-3'},
      });
      expect(
        queue.snapshot.active.single.projections.single.queryKeys,
        ['todo:server-3'],
      );
      expect(queue.projectionState!.idMappings['tmp-3'], 'server-3');
      expect(
        queue.projectionState!.overlays.single.plan.queryKeys,
        ['todo:server-3'],
      );
      expect(queue.projectionState!.overlays.single.patches, {
        'todo:server-3': {'id': 'server-3'},
      });
      await queue.close();

      final restarted = DurableMutationQueue(
        store: store,
        projectionCoordinator: ProjectionCoordinator(registry: registry),
      );
      await restarted.open();
      expect(restarted.snapshot.active.single.variables, {
        'todoId': 'server-3',
        'payload': {'relatedTodoId': 'server-3'},
      });
      expect(
        restarted.projectionState!.overlays.single.plan.queryKeys,
        ['todo:server-3'],
      );
      await restarted.close();
    },
  );

  test(
    'passes conflict preconditions and persists conflict evidence',
    () async {
      final plan = ProjectionPlan(
        id: 'todo.conflict',
        queryKeys: [StringQueryKey('todo:server-4')],
      );
      final registry = ProjectionRegistry()
        ..register(
          ProjectionDefinition(plan: plan, apply: (_, patch) => patch),
        );
      final adapter = _ConflictExecutionAdapter();
      final store = _MemoryOutboxStore();
      final queue = DurableMutationQueue(
        store: store,
        executionAdapter: adapter,
        projectionCoordinator: ProjectionCoordinator(registry: registry),
      );
      final key = MutationKey(namespace: 'tests', name: 'todo-conflict');
      queue.register<Object?, Map<String, Object?>>(
        key: key,
        codec: _mapCodec,
        mutationFn: (variables) async => variables,
      );

      await queue.open();
      final operation = await queue.enqueue(
        key: key,
        variables: const <String, Object?>{'id': 'server-4'},
        conflictPolicy: ConflictPolicy.required,
        conflictPrecondition: ConflictPrecondition('revision-1'),
        projections: [
          MutationProjectionDescriptor(
            id: plan.registryKey,
            queryKeys: plan.queryKeys,
          ),
        ],
      );
      await queue.enqueueProjection(
        ProjectionOverlay(
          operationId: operation.operationId,
          lineageId: operation.lineageId,
          plan: plan,
          patches: const {
            'todo:server-4': {'id': 'server-4', 'title': 'local'},
          },
        ),
      );

      final replay = await queue.replay();

      expect(replay.failedOperationIds, [operation.operationId]);
      expect(adapter.context?.conflictPolicy, ConflictPolicy.required);
      expect(
        adapter.context?.conflictPrecondition,
        ConflictPrecondition('revision-1'),
      );
      final deadLetter = queue.snapshot.deadLetters.single;
      final evidence = deadLetter.conflictEvidence!;
      expect(evidence['classification'], {
        'kind': 'staleWrite',
        'messageKey': 'sync.conflict.stale_write',
      });
      expect(evidence['expectedPrecondition'], {'token': 'revision-1'});
      expect(evidence['observedPrecondition'], {'token': 'revision-2'});
      expect(evidence['latestServerSnapshot'], {
        'id': 'server-4',
        'title': 'remote',
      });
      expect(
        queue.projectionState!.overlays.single.state,
        ProjectionOverlayState.conflicted,
      );
      expect(queue.projectionState!.overlays.single.conflictEvidence, evidence);

      final restoredDeadLetter = OutboxDeadLetter.fromJson(deadLetter.toJson());
      expect(restoredDeadLetter.conflictEvidence, evidence);
      await queue.close();
    },
  );
}

final _mapCodec = JsonMutationCodec<Map<String, Object?>>(
  encoder: (value) => value,
  decoder: (payload) => Map<String, Object?>.from(payload! as Map),
);

class _MemoryOutboxStore implements DurableOutboxStore {
  OutboxSnapshot _snapshot = OutboxSnapshot();
  int _generation = 0;
  bool _isOpen = false;

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

class _ConflictExecutionAdapter implements MutationExecutionAdapter {
  MutationExecutionContext? context;

  @override
  Future<MutationExecutionResult> execute(
    MutationExecutionContext context,
    Future<Object?> Function() executor,
  ) async {
    this.context = context;
    return MutationExecutionFailure(
      MutationAdapterFailure(
        category: MutationFailureCategory.conflict,
        messageKey: 'sync.conflict.stale_write',
        disposition: MutationFailureDisposition.terminal,
        conflictKind: ConflictKind.staleWrite,
        observedPrecondition: ConflictPrecondition('revision-2'),
        latestServerSnapshot: const {
          'id': 'server-4',
          'title': 'remote',
        },
      ),
    );
  }
}
