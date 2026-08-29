import 'dart:async';

import 'package:fasq_riverpod/fasq_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await QueryClient.resetForTesting();
  });

  test(
    'query adapters preserve core client lifecycle and refresh state',
    () async {
      final client = QueryClient.create();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(client.dispose);

      var calls = 0;
      final releaseRefresh = Completer<void>();
      final provider = queryProvider<String>(
        'riverpod:parity:refresh'.toQueryKey(),
        () async {
          calls++;
          if (calls == 1) return 'cached';
          await releaseRefresh.future;
          return 'fresh';
        },
        client: client,
      );
      final subscription = container.listen(provider, (previous, next) {});
      addTearDown(subscription.close);

      final notifier = container.read(provider.notifier);
      expect(await container.read(provider.future), 'cached');
      expect(notifier.queryClient, same(client));
      expect(notifier.query.referenceCount, 1);
      expect(notifier.hasData, isTrue);

      final refresh = notifier.refetch();
      await Future<void>.delayed(Duration.zero);
      final refreshing = container.read(provider);
      expect(refreshing.hasValue, isTrue);
      expect(refreshing.isLoading, isTrue);
      expect(refreshing.value, 'cached');

      releaseRefresh.complete();
      await refresh;
      await Future<void>.delayed(Duration.zero);
      expect(container.read(provider).value, 'fresh');
      expect(calls, 2);
    },
  );

  test('infinite adapter maps an initial page error to AsyncError', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final provider = infiniteQueryProvider<List<int>, int>(
      'riverpod:parity:infinite-error'.toQueryKey(),
      (page) async => throw StateError('page $page failed'),
      options: InfiniteQueryOptions<List<int>, int>(
        getNextPageParam: (pages, lastPage) => 1,
      ),
    );
    final subscription = container.listen(provider, (previous, next) {});
    addTearDown(subscription.close);

    await expectLater(
      container.read(provider.future),
      throwsA(isA<StateError>()),
    );
    final value = container.read(provider);
    expect(value, isA<AsyncError<InfiniteQueryState<List<int>, int>>>());
    expect(value.hasValue, isFalse);
    expect(value.error.toString(), contains('page 1 failed'));
  });

  test('parallel query providers support list and named parity APIs', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final listProvider = queriesProvider([
      QueryConfig<String>(
        'riverpod:parity:one'.toQueryKey(),
        () async => 'one',
      ),
      QueryConfig<int>('riverpod:parity:two'.toQueryKey(), () async => 2),
    ]);
    final listSubscription = container.listen(
      listProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(listSubscription.close);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    final listState = container.read(listProvider);
    expect(listState.isAllSuccess, isTrue);
    expect(listState.getState<String>(0).value, 'one');
    expect(listState.getState<int>(1).value, 2);

    final namedProvider = namedQueriesProvider([
      NamedQueryConfig<String>(
        name: 'user',
        queryKey: 'riverpod:parity:user'.toQueryKey(),
        queryFn: () async => 'Ada',
      ),
      NamedQueryConfig<int>(
        name: 'age',
        queryKey: 'riverpod:parity:age'.toQueryKey(),
        queryFn: () async => 37,
      ),
    ]);
    final namedSubscription = container.listen(
      namedProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(namedSubscription.close);

    await Future<void>.delayed(const Duration(milliseconds: 20));
    final namedState = container.read(namedProvider);
    expect(namedState.isAllSuccess, isTrue);
    expect(namedState.getState<String>('user').value, 'Ada');
    expect(namedState.getState<int>('age').value, 37);
  });

  test(
    'runtime override is borrowed and explicit containers are isolated',
    () async {
      final runtimeClient = QueryClient.create();
      final runtime = _TestRuntime(runtimeClient);
      final runtimeContainer = ProviderContainer(
        overrides: [fasqRuntimeProvider.overrideWithValue(runtime)],
      );
      addTearDown(runtimeContainer.dispose);

      final runtimeProvider = queryProvider<String>(
        'riverpod:parity:runtime'.toQueryKey(),
        () async => 'runtime',
      );
      final runtimeNotifier = runtimeContainer.read(runtimeProvider.notifier);
      expect(runtimeNotifier.queryClient, same(runtimeClient));
      expect(runtimeNotifier.runtime, same(runtime));
      expect(await runtimeContainer.read(runtimeProvider.future), 'runtime');

      final first = ProviderContainer();
      final second = ProviderContainer();
      addTearDown(first.dispose);
      addTearDown(second.dispose);
      final firstClient = first.read(fasqClientProvider);
      final secondClient = second.read(fasqClientProvider);
      expect(firstClient, isNot(same(secondClient)));

      final secondProvider = queryProvider<String>(
        'riverpod:parity:isolated'.toQueryKey(),
        () async => 'still alive',
        client: secondClient,
      );
      final secondSubscription = second.listen(
        secondProvider,
        (previous, next) {},
        fireImmediately: true,
      );
      addTearDown(secondSubscription.close);
      expect(await second.read(secondProvider.future), 'still alive');
      first.dispose();
      await Future<void>.delayed(Duration.zero);
      expect(
        secondClient.hasQuery('riverpod:parity:isolated'.toQueryKey()),
        isTrue,
      );

      final sentinelKey = 'riverpod:parity:borrowed'.toQueryKey();
      runtimeClient.getQuery<String>(
        sentinelKey,
        queryFn: () async => 'sentinel',
      );
      runtimeContainer.dispose();
      expect(runtimeClient.hasQuery(sentinelKey), isTrue);
      await runtime.close();
    },
  );

  test(
    'mutation adapter exposes submission receipts and core client',
    () async {
      final client = QueryClient.create();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      addTearDown(client.dispose);

      final provider = mutationProvider<String, String>(
        (value) async => 'saved:$value',
        client: client,
      );
      final notifier = container.read(provider.notifier);
      final receipt = await notifier.submit('value');

      expect(receipt.isSucceeded, isTrue);
      expect(receipt.data, 'saved:value');
      expect(notifier.queryClient, same(client));
      expect(notifier.mutation.lastVariables, 'value');
      expect(notifier.isSuccess, isTrue);
    },
  );

  test('durable mutation and queue providers expose queued work', () async {
    final client = QueryClient.create();
    final queue = DurableMutationQueue(
      store: _MemoryOutboxStore(),
      isOnline: () => false,
    );
    final key = const FasqMutationKey<String, String>(
      namespace: 'riverpod',
      name: 'save',
    );
    final definition = DurableMutationDefinition<String, String>(
      contractKey: key,
      codec: const JsonMutationCodec<String>(
        encoder: _encodeString,
        decoder: _decodeString,
      ),
      execute: (value) async => 'saved:$value',
    );
    final runtime = _QueueRuntime(
      client,
      queue,
      DurableMutationCatalog([definition]),
    );
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final mutation = mutationProvider<String, String>(
      null,
      mutationKey: key,
      runtime: runtime,
    );
    final receipt = await container.read(mutation.notifier).submit('offline');
    expect(receipt.isQueued, isTrue);
    expect(receipt.localReference, isNotNull);

    final queueProvider = mutationQueueProvider(runtime: runtime);
    final queueSubscription = container.listen(
      queueProvider,
      (previous, next) {},
      fireImmediately: true,
    );
    addTearDown(queueSubscription.close);
    await Future<void>.delayed(Duration.zero);

    final queueNotifier = container.read(queueProvider.notifier);
    expect(queueNotifier.queue, same(queue));
    expect(queueNotifier.hasRegistration(key.runtimeKey), isTrue);
    expect(queueNotifier.observation.operations, hasLength(1));
    expect(
      queueNotifier.observation.aggregateState,
      isNot(DurableQueueAggregateState.idle),
    );

    await runtime.close();
  });

  test('combineQueries aggregates ordinary AsyncValue providers', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final textProvider = FutureProvider<String>((ref) async => 'text');
    final countProvider = FutureProvider<int>((ref) async => 3);
    final combined = combineQueries([textProvider, countProvider]);
    final subscription = container.listen(combined, (previous, next) {});
    addTearDown(subscription.close);

    await container.read(textProvider.future);
    await container.read(countProvider.future);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(combined);
    expect(state.isAllSuccess, isTrue);
    expect(state.getState<String>(0).value, 'text');
    expect(state.getState<int>(1).value, 3);
  });
}

class _TestRuntime implements FasqRuntime {
  _TestRuntime(this.queryClient);

  @override
  final QueryClient queryClient;

  @override
  DurableMutationQueue? get mutationQueue => null;

  @override
  DurableMutationCatalog get mutations =>
      DurableMutationCatalog(const <DurableMutationDefinitionBase>[]);

  @override
  Future<void> close() => queryClient.dispose();
}

class _QueueRuntime implements FasqRuntime {
  _QueueRuntime(this.queryClient, this.mutationQueue, this._mutations);

  @override
  final QueryClient queryClient;

  @override
  final DurableMutationQueue mutationQueue;

  final DurableMutationCatalog _mutations;

  @override
  DurableMutationCatalog get mutations => _mutations;

  @override
  Future<void> close() async {
    await mutationQueue.close();
    await queryClient.dispose();
  }
}

Object? _encodeString(String value) => value;

String _decodeString(Object? payload) => payload! as String;

class _MemoryOutboxStore implements DurableOutboxStore {
  OutboxSnapshot _snapshot = OutboxSnapshot();
  var _generation = 0;
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
