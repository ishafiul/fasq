import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('queues durable mutations through MutationBuilder', (
    tester,
  ) async {
    final queue = DurableMutationQueue(store: _MemoryOutboxStore());
    final queryClient = QueryClient.create();
    const mutationKey = FasqMutationKey<String, String>(
      namespace: 'tests',
      name: 'builder',
    );
    final mutation = DurableMutation<String, String>.define(
      key: mutationKey,
      codec: JsonMutationCodec<String>(
        encoder: (value) => value,
        decoder: (payload) => payload! as String,
      ),
      execute: (value) async => 'done:$value',
    );
    await (queue..register<String, String>(
          key: mutation.key,
          codec: mutation.codec,
          mutationFn: mutation.execute,
        ))
        .open();
    final runtime = _TestRuntime(
      queryClient: queryClient,
      mutationQueue: queue,
      mutations: DurableMutationCatalog([mutation]),
    );
    Future<MutationSubmission<String>> Function(String)? mutate;

    await tester.pumpWidget(
      MaterialApp(
        home: FasqProvider(
          runtime: runtime,
          child: MutationBuilder<String, String>(
            mutationKey: mutationKey,
            builder: (context, state, run) {
              mutate = run;
              return Text(state.isQueued ? 'queued' : 'idle');
            },
          ),
        ),
      ),
    );

    NetworkStatus.instance.setOnline(online: false);
    final submission = await mutate!.call('payload');
    await tester.pump();

    expect(find.text('queued'), findsOneWidget);
    expect(queue.snapshot.active, hasLength(1));
    expect(submission.isQueued, isTrue);
    expect(submission.localReference, startsWith('fasq-local:'));

    NetworkStatus.instance.setOnline(online: true);
    await tester.pumpWidget(const SizedBox.shrink());
    await queue.close();
    await queryClient.dispose();
  });
}

class _TestRuntime implements FasqRuntime {
  const _TestRuntime({
    required this.queryClient,
    required this.mutationQueue,
    required this.mutations,
  });

  @override
  final QueryClient queryClient;

  @override
  final DurableMutationQueue mutationQueue;

  @override
  final DurableMutationCatalog mutations;

  @override
  Future<void> close() async {}
}

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
