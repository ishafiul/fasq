import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueryCubit cancel() and setData()', () {
    setUp(() async {
      await QueryClient.resetForTesting();
    });

    test('cancel() cancels in-flight fetch operation', () async {
      final cubit = _TestQueryCubit();

      cubit.refetch();
      cubit.cancel();

      await Future.delayed(const Duration(milliseconds: 10));

      await cubit.close();
    });

    test('cancel() can be called multiple times safely', () {
      final cubit = _TestQueryCubit();

      cubit.cancel();
      cubit.cancel();
      cubit.cancel();

      expect(() => cubit.cancel(), returnsNormally);

      cubit.close();
    });

    test('setData() updates cached data for the query', () async {
      final queryClient = QueryClient();
      final cubit = _TestQueryCubitWithClient(queryClient);

      const newData = 'updated data';

      cubit.setData(newData);

      final cachedData = queryClient.getQueryData<String>(cubit.queryKey);
      expect(cachedData, newData);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.hasData, true);
      expect(cubit.state.data, newData);

      await cubit.close();
      await queryClient.dispose();
    });

    test('setData() updates query state immediately', () async {
      final queryClient = QueryClient();
      final cubit = _TestQueryCubitWithClient(queryClient);

      expect(cubit.state.isIdle, true);

      const newData = 'manual data';

      cubit.setData(newData);

      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.hasData, true);
      expect(cubit.state.data, newData);

      await cubit.close();
      await queryClient.dispose();
    });

    test('setData() maintains type safety', () {
      final queryClient = QueryClient();
      final cubit = _TestQueryCubitWithClient(queryClient);

      const stringData = 'test string';

      cubit.setData(stringData);

      final cachedData = queryClient.getQueryData<String>(cubit.queryKey);
      expect(cachedData, stringData);
      expect(cachedData, isA<String>());

      cubit.close();
      queryClient.dispose();
    });

    test('setData() works with custom QueryClient', () {
      final customClient = QueryClient();
      final cubit = _TestQueryCubitWithClient(customClient);

      const newData = 'custom client data';

      cubit.setData(newData);

      final cachedData = customClient.getQueryData<String>(cubit.queryKey);
      expect(cachedData, newData);

      cubit.close();
      customClient.dispose();
    });

    test('setData() can be called multiple times', () {
      final queryClient = QueryClient();
      final cubit = _TestQueryCubitWithClient(queryClient);

      cubit.setData('first');
      cubit.setData('second');
      cubit.setData('third');

      final cachedData = queryClient.getQueryData<String>(cubit.queryKey);
      expect(cachedData, 'third');

      cubit.close();
      queryClient.dispose();
    });

    test('cancel() and setData() can be used together', () async {
      final queryClient = QueryClient();
      final cubit = _TestQueryCubitWithClient(queryClient);

      cubit.refetch();
      cubit.cancel();

      await Future.delayed(const Duration(milliseconds: 5));

      cubit.setData('cancelled then set');

      final cachedData = queryClient.getQueryData<String>(cubit.queryKey);
      expect(cachedData, 'cancelled then set');

      await cubit.close();
      await queryClient.dispose();
    });

    test('setData() updates state even when query is idle', () {
      final queryClient = QueryClient();
      final cubit = _TestQueryCubitWithClient(queryClient);

      expect(cubit.state.isIdle, true);

      cubit.setData('idle update');

      expect(cubit.state.hasData, true);
      expect(cubit.state.data, 'idle update');

      cubit.close();
      queryClient.dispose();
    });

    test('cancel() does not affect setData()', () {
      final queryClient = QueryClient();
      final cubit = _TestQueryCubitWithClient(queryClient);

      cubit.cancel();
      cubit.setData('data after cancel');

      final cachedData = queryClient.getQueryData<String>(cubit.queryKey);
      expect(cachedData, 'data after cancel');

      cubit.close();
      queryClient.dispose();
    });
  });
}

class _TestQueryCubit extends QueryCubit<String> {
  _TestQueryCubit();

  @override
  QueryKey get queryKey => 'test-query'.toQueryKey();

  @override
  Future<String> Function() get queryFn => () async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'test data';
      };
}

class _TestQueryCubitWithClient extends QueryCubit<String> {
  final QueryClient _client;

  _TestQueryCubitWithClient(this._client);

  @override
  QueryClient? get client => _client;

  @override
  QueryKey get queryKey => 'test-query-client'.toQueryKey();

  @override
  Future<String> Function() get queryFn => () async {
        await Future.delayed(const Duration(milliseconds: 5));
        return 'test data';
      };
}

