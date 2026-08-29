import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await QueryClient.resetForTesting();
  });

  test(
    'QueryCubit supports token functions, dependencies, and reconfigure',
    () async {
      final client = QueryClient.create();
      final parentKey = 'parity:parent'.toQueryKey();
      client.getQuery<int>(parentKey, queryFn: () async => 1);
      final cubit = _TokenQueryCubit(client, parentKey);

      await cubit.ready;
      await cubit.query.fetch(forceRefetch: true);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.receivedToken, isNotNull);
      expect(cubit.state.data, 'token-result');
      expect(cubit.query.referenceCount, 1);

      final originalQuery = cubit.query;
      cubit.updateOptions(
        newQueryFn: () async => 'ordinary-result',
        clearQueryFnWithToken: true,
      );
      await cubit.ready;
      await cubit.query.fetch(forceRefetch: true);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.query, same(originalQuery));
      expect(cubit.state.data, 'ordinary-result');

      await cubit.close();
      expect(originalQuery.referenceCount, 0);
      await client.dispose();
    },
  );

  test('QueryCubit honors refetchOnMount for cached data', () async {
    final client = QueryClient.create();
    final key = 'parity:refetch'.toQueryKey();
    client.setQueryData(key, 'cached');
    var calls = 0;
    final cubit = _RefetchQueryCubit(client, () => calls++);

    await cubit.ready;
    await Future<void>.delayed(Duration.zero);

    expect(calls, greaterThan(0));
    expect(cubit.state.data, 'fresh');

    await cubit.close();
    await client.dispose();
  });

  test('QueryCubit refetches stale cached data on mount', () async {
    final client = QueryClient.create();
    final key = 'parity:stale'.toQueryKey();
    client.setQueryData(key, 'cached');
    var calls = 0;
    final cubit = _StaleQueryCubit(client, () => calls++);

    await cubit.ready;
    await Future<void>.delayed(Duration.zero);

    expect(calls, 1);
    expect(cubit.state.data, 'fresh');

    await cubit.close();
    await client.dispose();
  });

  test('InfiniteQueryCubit reconfigure preserves loaded pages', () async {
    final client = QueryClient.create();
    final cubit = _InfiniteParityCubit(client);

    await cubit.ready;
    await cubit.fetchNextPage(1);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.pages.single.data, [1]);

    cubit.updateOptions(newQueryFn: (page) async => [page + 10]);
    await cubit.ready;
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.pages.single.data, [1]);
    await cubit.refetchPage(0);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.pages.single.data, [11]);

    await cubit.close();
    await client.dispose();
  });

  test(
    'InfiniteQueryCubit refetchOnMount does not advance the first page',
    () async {
      final client = QueryClient.create();
      final calls = <int>[];
      final cubit = _MountInfiniteParityCubit(client, calls);

      await cubit.ready;
      await Future<void>.delayed(Duration.zero);

      expect(calls, [1]);
      expect(cubit.state.pages, hasLength(1));
      expect(cubit.state.pages.single.param, 1);

      await cubit.close();
      await client.dispose();
    },
  );

  test('QueryCubit stays idle after disabling an active query', () async {
    final client = QueryClient.create();
    final cubit = _DisableQueryParityCubit(client);

    await cubit.ready;
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.isSuccess, isTrue);

    cubit.updateOptions(newOptions: QueryOptions(enabled: false));
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.isIdle, isTrue);
    expect(cubit.state.hasValue, isFalse);

    await cubit.close();
    await client.dispose();
  });

  test(
    'MutationCubit uses its explicit client and returns a receipt',
    () async {
      final client = QueryClient.create();
      final observer = _MutationObserver();
      client.addObserver(observer);
      final cubit = _ResultMutationCubit(client);

      final submission = await cubit.submit('input');

      expect(submission.isSucceeded, isTrue);
      expect(submission.data, 'result:input');
      expect(cubit.lastVariables, 'input');
      expect(cubit.queryClient, same(client));
      expect(observer.events, <String>['loading', 'success', 'settled']);

      await cubit.close();
      await client.dispose();
    },
  );

  test('MutationCubit preserves nullable success callbacks', () async {
    final cubit = _NullableMutationCubit();
    var callbackCalled = false;

    final submission = await cubit.mutate(
      'input',
      onSuccess: (value) {
        callbackCalled = true;
        expect(value, isNull);
      },
    );

    expect(submission.isSucceeded, isTrue);
    expect(callbackCalled, isTrue);

    await cubit.close();
  });
}

class _TokenQueryCubit extends QueryCubit<String> {
  _TokenQueryCubit(QueryClient client, this._parentKey) : super(client: client);

  final QueryKey _parentKey;
  CancellationToken? receivedToken;

  @override
  QueryKey get queryKey => 'parity:token'.toQueryKey();

  @override
  QueryKey get dependsOn => _parentKey;

  @override
  Future<String> Function(CancellationToken token)? get queryFnWithToken =>
      (token) async {
        receivedToken = token;
        return 'token-result';
      };
}

class _RefetchQueryCubit extends QueryCubit<String> {
  _RefetchQueryCubit(QueryClient client, this._onFetch) : super(client: client);

  final int Function() _onFetch;

  @override
  QueryKey get queryKey => 'parity:refetch'.toQueryKey();

  @override
  QueryOptions get options => QueryOptions(refetchOnMount: true);

  @override
  Future<String> Function() get queryFn => () async {
    _onFetch();
    return 'fresh';
  };
}

class _StaleQueryCubit extends QueryCubit<String> {
  _StaleQueryCubit(QueryClient client, this._onFetch) : super(client: client);

  final void Function() _onFetch;

  @override
  QueryKey get queryKey => 'parity:stale'.toQueryKey();

  @override
  Future<String> Function() get queryFn => () async {
    _onFetch();
    return 'fresh';
  };
}

class _InfiniteParityCubit extends InfiniteQueryCubit<List<int>, int> {
  _InfiniteParityCubit(QueryClient client) : super(client: client);

  @override
  QueryKey get queryKey => 'parity:infinite'.toQueryKey();

  @override
  Future<List<int>> Function(int param) get queryFn =>
      (param) async => [param];
}

class _MountInfiniteParityCubit extends InfiniteQueryCubit<List<int>, int> {
  _MountInfiniteParityCubit(QueryClient client, this.calls)
    : super(client: client);

  final List<int> calls;

  @override
  QueryKey get queryKey => 'parity:infinite-mount'.toQueryKey();

  @override
  InfiniteQueryOptions<List<int>, int> get options => InfiniteQueryOptions(
    refetchOnMount: true,
    getNextPageParam: (pages, _) => pages.length + 1,
  );

  @override
  Future<List<int>> Function(int param) get queryFn => (param) async {
    calls.add(param);
    return [param];
  };
}

class _DisableQueryParityCubit extends QueryCubit<String> {
  _DisableQueryParityCubit(QueryClient client) : super(client: client);

  @override
  QueryKey get queryKey => 'parity:disable'.toQueryKey();

  @override
  Future<String> Function() get queryFn =>
      () async => 'loaded';
}

class _ResultMutationCubit extends MutationCubit<String, String> {
  _ResultMutationCubit(QueryClient client) : super(client: client);

  @override
  Future<String> Function(String variables) get mutationFn =>
      (variables) async => 'result:$variables';
}

class _NullableMutationCubit extends MutationCubit<String?, String> {
  @override
  Future<String?> Function(String variables) get mutationFn =>
      (_) async => null;
}

class _MutationObserver extends QueryClientObserver {
  final events = <String>[];

  @override
  void onMutationLoading(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    events.add('loading');
  }

  @override
  void onMutationSuccess(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    events.add('success');
  }

  @override
  void onMutationSettled(
    MutationSnapshot<dynamic, dynamic> snapshot,
    MutationMeta? meta,
    BuildContext? context,
  ) {
    events.add('settled');
  }
}
