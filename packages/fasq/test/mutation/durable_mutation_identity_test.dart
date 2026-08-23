import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

const _createKey = FasqMutationKey<Map<String, Object?>, Map<String, Object?>>(
  namespace: 'posts',
  name: 'create',
);
const _updateKey = FasqMutationKey<Map<String, Object?>, Map<String, Object?>>(
  namespace: 'posts',
  name: 'update',
);
const _createAuthorKey =
    FasqMutationKey<Map<String, Object?>, Map<String, Object?>>(
      namespace: 'authors',
      name: 'create',
    );
const _dependencies =
    <FasqMutationDependency<Object?, Object?, Object?, Object?>>[
      FasqMutationDependency<
        Map<String, Object?>,
        Map<String, Object?>,
        Map<String, Object?>,
        String
      >(
        dependsOn: _createKey,
        fromResult: FasqMutationField<Map<String, Object?>, String>('id'),
        toInput: FasqMutationField<Map<String, Object?>, String>('postId'),
      ),
    ];
const _mapCodec = JsonMutationCodec<Map<String, Object?>>(
  encoder: _encodeMap,
  decoder: _decodeMap,
);

void main() {
  test(
    'local reference creates exact dependency and binds server ID',
    () async {
      final executed = <String>[];
      Object? updateVariables;
      final queue = _queue(
        create: (variables) async {
          executed.add('create');
          return <String, Object?>{'id': 'server-1'};
        },
        update: (variables) async {
          executed.add('update');
          updateVariables = variables;
          return <String, Object?>{'id': variables['postId']};
        },
      );
      await queue.open();

      final parent = await queue.enqueue(
        key: _createKey.runtimeKey,
        variables: <String, Object?>{'title': 'draft'},
      );
      final child = await queue.enqueue(
        key: _updateKey.runtimeKey,
        variables: <String, Object?>{
          'postId': parent.localReference,
        },
      );

      expect(child.operation.dependencies, hasLength(1));
      expect(
        child.operation.dependencies.single.parentOperationId,
        parent.operationId,
      );

      await queue.replay();

      expect(executed, <String>['create', 'update']);
      expect(updateVariables, <String, Object?>{'postId': 'server-1'});
      final parentHistory = queue.snapshot.history.firstWhere(
        (entry) => entry.operationId == parent.operationId,
      );
      expect(parentHistory.identity?.localId, parent.localReference);
      final recovered = OutboxSnapshot.fromJson(queue.snapshot.toJson());
      expect(
        recovered.history.first.identity?.localId,
        parent.localReference,
      );
      await queue.close();
    },
  );

  test('resolved local reference is rewritten before enqueue', () async {
    final queue = _queue(
      create: (_) async => <String, Object?>{'id': 'server-1'},
      update: (variables) async => variables,
    );
    await queue.open();
    final parent = await queue.enqueue(
      key: _createKey.runtimeKey,
      variables: const <String, Object?>{'title': 'draft'},
    );
    await queue.replay();

    final child = await queue.enqueue(
      key: _updateKey.runtimeKey,
      variables: <String, Object?>{'postId': parent.localReference},
    );

    expect(child.operation.dependencies, isEmpty);
    expect(child.operation.variables, <String, Object?>{'postId': 'server-1'});
    await queue.close();
  });

  test('unknown reference remains a canonical server ID', () async {
    final queue = _queue(
      create: (_) async => <String, Object?>{'id': 'unused'},
      update: (variables) async => variables,
    );
    await queue.open();

    final child = await queue.enqueue(
      key: _updateKey.runtimeKey,
      variables: <String, Object?>{'postId': 'server-existing'},
    );

    expect(child.operation.dependencies, isEmpty);
    expect(
      child.operation.variables,
      <String, Object?>{'postId': 'server-existing'},
    );
    await queue.close();
  });

  test('local identity resolution never crosses auth scope', () async {
    final queue = DurableMutationQueue(store: _MemoryOutboxStore());
    queue
      ..register<Map<String, Object?>, Map<String, Object?>>(
        key: _createKey.runtimeKey,
        codec: _mapCodec,
        mutationFn: (_) async => <String, Object?>{'id': 'server-1'},
        authPolicy: AuthPolicy.required,
        dependencies: const [],
      )
      ..register<Map<String, Object?>, Map<String, Object?>>(
        key: _updateKey.runtimeKey,
        codec: _mapCodec,
        mutationFn: (variables) async => variables,
        authPolicy: AuthPolicy.required,
        dependencies: _dependencies,
      );
    await queue.open();
    final firstScope = AuthScope(
      principalId: 'first',
      tenantId: 'tenant',
      authRealm: 'test',
    );
    final secondScope = AuthScope(
      principalId: 'second',
      tenantId: 'tenant',
      authRealm: 'test',
    );
    final parent = await queue.enqueue(
      key: _createKey.runtimeKey,
      variables: const <String, Object?>{'title': 'draft'},
      authScope: firstScope,
    );

    final child = await queue.enqueue(
      key: _updateKey.runtimeKey,
      variables: <String, Object?>{'postId': parent.localReference},
      authScope: secondScope,
    );

    expect(child.operation.dependencies, isEmpty);
    expect(
      child.operation.variables,
      <String, Object?>{'postId': parent.localReference},
    );
    await queue.close();
  });

  test(
    'offline create followed by online update uses one durable path',
    () async {
      var isOnline = false;
      Object? updateVariables;
      final queue = DurableMutationQueue(
        store: _MemoryOutboxStore(),
        isOnline: () => isOnline,
      );
      final create =
          DurableMutation<Map<String, Object?>, Map<String, Object?>>.define(
            key: _createKey,
            codec: _mapCodec,
            execute: (_) async => <String, Object?>{'id': 'server-1'},
            dependencies: const [],
          );
      final update =
          DurableMutation<Map<String, Object?>, Map<String, Object?>>.define(
            key: _updateKey,
            codec: _mapCodec,
            execute: (variables) async {
              updateVariables = variables;
              return <String, Object?>{'id': variables['postId']};
            },
            dependencies: _dependencies,
          );
      final createMutation =
          Mutation<Map<String, Object?>, Map<String, Object?>>(
            mutationFn: create.execute,
            options: create.bind(queue),
          );
      final updateMutation =
          Mutation<Map<String, Object?>, Map<String, Object?>>(
            mutationFn: update.execute,
            options: update.bind(queue),
          );

      final parent = await createMutation.submit(
        const <String, Object?>{'title': 'draft'},
      );
      expect(createMutation.state.isQueued, isTrue);

      isOnline = true;
      await updateMutation.mutate(<String, Object?>{
        'postId': parent.localReference,
      });

      expect(updateMutation.state.isSuccess, isTrue);
      expect(updateVariables, <String, Object?>{'postId': 'server-1'});
      expect(queue.snapshot.active, isEmpty);
      expect(queue.snapshot.history, hasLength(2));

      createMutation.dispose();
      updateMutation.dispose();
      await queue.close();
    },
  );

  test(
    'online parent followed by offline child retains resolvable reference',
    () async {
      var isOnline = true;
      Object? updateVariables;
      final queue = DurableMutationQueue(
        store: _MemoryOutboxStore(),
        isOnline: () => isOnline,
      );
      final create =
          DurableMutation<Map<String, Object?>, Map<String, Object?>>.define(
            key: _createKey,
            codec: _mapCodec,
            execute: (_) async => <String, Object?>{'id': 'server-1'},
          );
      final update =
          DurableMutation<Map<String, Object?>, Map<String, Object?>>.define(
            key: _updateKey,
            codec: _mapCodec,
            execute: (variables) async {
              updateVariables = variables;
              return variables;
            },
            dependencies: _dependencies,
          );
      final createMutation =
          Mutation<Map<String, Object?>, Map<String, Object?>>(
            mutationFn: create.execute,
            options: create.bind(queue),
          );
      final updateMutation =
          Mutation<Map<String, Object?>, Map<String, Object?>>(
            mutationFn: update.execute,
            options: update.bind(queue),
          );

      final parent = await createMutation.submit(
        const <String, Object?>{'title': 'online'},
      );
      expect(parent.isSucceeded, isTrue);

      isOnline = false;
      final child = await updateMutation.submit(<String, Object?>{
        'postId': parent.localReference,
      });
      expect(child.isQueued, isTrue);
      expect(queue.snapshot.active.single.dependencies, isEmpty);
      expect(
        queue.snapshot.active.single.variables,
        <String, Object?>{'postId': 'server-1'},
      );

      isOnline = true;
      await queue.replay();
      expect(updateVariables, <String, Object?>{'postId': 'server-1'});

      createMutation.dispose();
      updateMutation.dispose();
      await queue.close();
    },
  );

  test('resolves multiple dependencies in mixed completed states', () async {
    Object? updateVariables;
    final queue = DurableMutationQueue(store: _MemoryOutboxStore());
    queue
      ..register<Map<String, Object?>, Map<String, Object?>>(
        key: _createKey.runtimeKey,
        codec: _mapCodec,
        mutationFn: (_) async => <String, Object?>{'id': 'post-server'},
      )
      ..register<Map<String, Object?>, Map<String, Object?>>(
        key: _createAuthorKey.runtimeKey,
        codec: _mapCodec,
        mutationFn: (_) async => <String, Object?>{'id': 'author-server'},
      )
      ..register<Map<String, Object?>, Map<String, Object?>>(
        key: _updateKey.runtimeKey,
        codec: _mapCodec,
        mutationFn: (variables) async {
          updateVariables = variables;
          return variables;
        },
        dependencies: [
          ..._dependencies,
          const FasqMutationDependency<
            Map<String, Object?>,
            Map<String, Object?>,
            Map<String, Object?>,
            String
          >(
            dependsOn: _createAuthorKey,
            fromResult: FasqMutationField<Map<String, Object?>, String>('id'),
            toInput: FasqMutationField<Map<String, Object?>, String>(
              'authorId',
            ),
          ),
        ],
      );
    await queue.open();

    final completedParent = await queue.enqueue(
      key: _createKey.runtimeKey,
      variables: const <String, Object?>{'title': 'post'},
    );
    await queue.replay();
    final pendingParent = await queue.enqueue(
      key: _createAuthorKey.runtimeKey,
      variables: const <String, Object?>{'name': 'author'},
    );
    final child = await queue.enqueue(
      key: _updateKey.runtimeKey,
      variables: <String, Object?>{
        'postId': completedParent.localReference,
        'authorId': pendingParent.localReference,
      },
    );

    expect(child.operation.dependencies, hasLength(1));
    expect(
      child.operation.dependencies.single.parentOperationId,
      pendingParent.operationId,
    );
    expect(
      child.operation.variables,
      <String, Object?>{
        'postId': 'post-server',
        'authorId': pendingParent.localReference,
      },
    );

    await queue.replay();
    expect(updateVariables, <String, Object?>{
      'postId': 'post-server',
      'authorId': 'author-server',
    });
    await queue.close();
  });
}

DurableMutationQueue _queue({
  required Future<Map<String, Object?>> Function(Map<String, Object?>) create,
  required Future<Map<String, Object?>> Function(Map<String, Object?>) update,
}) {
  final queue = DurableMutationQueue(store: _MemoryOutboxStore());
  queue
    ..register<Map<String, Object?>, Map<String, Object?>>(
      key: _createKey.runtimeKey,
      codec: _mapCodec,
      mutationFn: create,
      dependencies: const [],
    )
    ..register<Map<String, Object?>, Map<String, Object?>>(
      key: _updateKey.runtimeKey,
      codec: _mapCodec,
      mutationFn: update,
      dependencies: _dependencies,
    );
  return queue;
}

Object? _encodeMap(Map<String, Object?> value) => value;

Map<String, Object?> _decodeMap(Object? value) =>
    Map<String, Object?>.from(value! as Map);

class _MemoryOutboxStore implements DurableOutboxStore {
  OutboxSnapshot _snapshot = OutboxSnapshot();
  int _generation = 0;
  bool _isOpen = false;

  @override
  int get generation => _generation;

  @override
  OutboxSnapshot get snapshot => _snapshot;

  @override
  Future<OutboxSnapshot> open() async {
    _isOpen = true;
    return _snapshot;
  }

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
