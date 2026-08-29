import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('MutationQueueCubit observes and filters the durable queue', () async {
    final store = _MemoryOutboxStore();
    final queue = DurableMutationQueue(store: store);
    final key = MutationKey(namespace: 'bloc', name: 'queue-test');
    final codec = JsonMutationCodec<Map<String, Object?>>(
      encoder: (value) => value,
      decoder: (payload) => Map<String, Object?>.from(payload! as Map),
    );
    final cubit = MutationQueueCubit(queue: queue);
    cubit.register<Map<String, Object?>, Map<String, Object?>>(
      key: key,
      codec: codec,
      mutationFn: (variables) async => variables,
    );

    expect(cubit.state.aggregateState, DurableQueueAggregateState.idle);
    expect(cubit.hasRegistration(key), isTrue);
    await cubit.open();
    final acknowledgement = await cubit.enqueue(
      key: key,
      variables: <String, Object?>{'value': 'queued'},
      operationId: OperationId('bloc-queue-operation'),
      idempotencyKey: IdempotencyKey('bloc-queue-idempotency'),
      lineageId: LineageId('bloc-queue-lineage'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.operations, hasLength(1));
    expect(
      cubit.state.operations.single.operationId.value,
      'bloc-queue-operation',
    );
    expect(cubit.hasRetainedOperation(acknowledgement.operationId), isTrue);
    expect(
      cubit.hasRetainedIdempotencyKey(acknowledgement.idempotencyKey),
      isTrue,
    );
    expect(cubit.aggregateState(), cubit.currentAggregateState);
    expect((await cubit.watch().first).operations, hasLength(1));
    expect(cubit.listOperations(), hasLength(1));

    cubit.setFilter(
      DurableOperationFilter(
        mutationKey: MutationKey(namespace: 'other', name: 'mutation'),
      ),
    );
    expect(cubit.state.operations, isEmpty);
    expect(cubit.aggregateState(), DurableQueueAggregateState.idle);
    expect(cubit.currentAggregateState, DurableQueueAggregateState.idle);

    await cubit.close();
    await queue.close();
  });

  test('MutationQueueCubit can be created from a runtime queue', () async {
    final queue = DurableMutationQueue(store: _MemoryOutboxStore());
    final runtime = _TestRuntime(queue);
    final cubit = MutationQueueCubit(runtime: runtime);

    expect(cubit.queue, same(queue));
    await cubit.close();
    await runtime.close();
  });

  test(
    'MutationCubit supports runtime durable mutations and receipts',
    () async {
      final queue = DurableMutationQueue(
        store: _MemoryOutboxStore(),
        isOnline: () => false,
      );
      const key = FasqMutationKey<String, String>(
        namespace: 'bloc',
        name: 'durable-test',
      );
      final definition = DurableMutationDefinition<String, String>(
        contractKey: key,
        codec: const JsonMutationCodec<String>(
          encoder: _encodeString,
          decoder: _decodeString,
        ),
        execute: (value) async => 'processed:$value',
      );
      final runtime = _TestRuntime(queue, DurableMutationCatalog([definition]));
      final cubit = _DurableMutationCubit(runtime);

      final submission = await cubit.submit('offline-value');
      await Future<void>.delayed(Duration.zero);

      expect(submission.isQueued, isTrue);
      expect(submission.localReference, isNotNull);
      expect(cubit.state.isQueued, isTrue);
      expect(queue.snapshot.active, hasLength(1));

      cubit.reset();
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isIdle, isTrue);
      expect(cubit.state.isQueued, isFalse);

      await cubit.close();
      await runtime.close();
    },
  );
}

Object? _encodeString(String value) => value;

String _decodeString(Object? payload) => payload! as String;

class _TestRuntime implements FasqRuntime {
  _TestRuntime(this.mutationQueue, [DurableMutationCatalog? catalog])
    : queryClient = QueryClient.create(),
      _mutations = catalog ?? DurableMutationCatalog(const []);

  @override
  final QueryClient queryClient;

  @override
  final DurableMutationQueue mutationQueue;

  @override
  DurableMutationCatalog get mutations => _mutations;

  final DurableMutationCatalog _mutations;

  @override
  Future<void> close() async {
    await mutationQueue.close();
    await queryClient.dispose();
  }
}

class _DurableMutationCubit extends MutationCubit<String, String> {
  _DurableMutationCubit(FasqRuntime runtime) : super(runtime: runtime);

  @override
  FasqMutationKey<String, String> get mutationKey =>
      const FasqMutationKey(namespace: 'bloc', name: 'durable-test');
}

class _MemoryOutboxStore implements DurableOutboxStore {
  OutboxSnapshot _snapshot = OutboxSnapshot();
  int _generation = 0;
  var _isOpen = false;

  @override
  int get generation => _generation;

  @override
  OutboxSnapshot get snapshot => _snapshot;

  @override
  Future<void> close() async {
    _isOpen = false;
  }

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
}
