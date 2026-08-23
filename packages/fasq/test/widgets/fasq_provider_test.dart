import 'package:fasq/fasq.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('provides runtime with query and mutation resources', (
    tester,
  ) async {
    final queue = DurableMutationQueue(store: _MemoryOutboxStore());
    final runtime = _TestRuntime(
      queryClient: QueryClient.create(),
      mutationQueue: queue,
    );
    late FasqRuntime resolvedRuntime;
    late QueryClient? resolvedClient;

    await tester.pumpWidget(
      FasqProvider(
        runtime: runtime,
        child: Builder(
          builder: (context) {
            resolvedRuntime = context.fasqRuntime;
            resolvedClient = context.queryClient;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolvedRuntime, same(runtime));
    expect(resolvedClient, same(runtime.queryClient));
    expect(resolvedRuntime.mutationQueue, same(queue));

    await tester.pumpWidget(const SizedBox.shrink());
    await runtime.close();
  });

  testWidgets('updates borrowed runtime resources without disposing them', (
    tester,
  ) async {
    final firstQueue = DurableMutationQueue(store: _MemoryOutboxStore());
    final secondQueue = DurableMutationQueue(store: _MemoryOutboxStore());
    final first = _TestRuntime(
      queryClient: QueryClient.create(),
      mutationQueue: firstQueue,
    );
    final second = _TestRuntime(
      queryClient: QueryClient.create(),
      mutationQueue: secondQueue,
    );
    QueryClient? resolvedClient;
    FasqRuntime? resolvedRuntime;

    Widget app(FasqRuntime runtime) {
      return FasqProvider(
        runtime: runtime,
        child: Builder(
          builder: (context) {
            resolvedClient = context.queryClient;
            resolvedRuntime = context.fasqRuntime;
            return const SizedBox.shrink();
          },
        ),
      );
    }

    await tester.pumpWidget(app(first));
    expect(resolvedClient, same(first.queryClient));
    expect(resolvedRuntime?.mutationQueue, same(firstQueue));

    await tester.pumpWidget(app(second));
    expect(resolvedClient, same(second.queryClient));
    expect(resolvedRuntime?.mutationQueue, same(secondQueue));
    expect(first.closeCalls, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    await first.close();
    await second.close();
  });

  testWidgets('throws an actionable error when provider is missing', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (builderContext) {
          context = builderContext;
          return const SizedBox.shrink();
        },
      ),
    );

    expect(
      () => FasqProvider.of(context),
      throwsA(
        isA<FlutterError>().having(
          (error) => error.message,
          'message',
          contains('Wrap the application in FasqProvider'),
        ),
      ),
    );
  });
}

class _TestRuntime implements FasqRuntime {
  _TestRuntime({required this.queryClient, this.mutationQueue})
    : mutations = DurableMutationCatalog(const []);

  @override
  final QueryClient queryClient;

  @override
  final DurableMutationQueue? mutationQueue;

  @override
  final DurableMutationCatalog mutations;

  int closeCalls = 0;

  @override
  Future<void> close() async {
    closeCalls++;
    await mutationQueue?.close();
    await queryClient.dispose();
  }
}

class _MemoryOutboxStore implements DurableOutboxStore {
  OutboxSnapshot _snapshot = OutboxSnapshot();
  int _generation = 0;

  @override
  int get generation => _generation;

  @override
  OutboxSnapshot get snapshot => _snapshot;

  @override
  Future<void> close() async {}

  @override
  Future<OutboxSnapshot> open() async => _snapshot;

  @override
  Future<OutboxSnapshot> transact(
    DurableOutboxTransaction transaction, {
    int? expectedGeneration,
  }) async {
    _snapshot = transaction(_snapshot);
    _generation++;
    return _snapshot;
  }
}
