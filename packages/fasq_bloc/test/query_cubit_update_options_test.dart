import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueryCubit updateOptions', () {
    setUp(() async {
      await QueryClient.resetForTesting();
    });

    test('updateOptions updates options when queryKey unchanged', () async {
      final cubit = _TestQueryCubit();

      expect(cubit.state.status, QueryStatus.loading);

      cubit.updateOptions(
        newOptions: QueryOptions(staleTime: const Duration(minutes: 10)),
      );

      expect(cubit.subscriptionCount, 1);

      await cubit.close();
    });

    test('updateOptions swaps query when queryKey changes', () async {
      final cubit = _TestQueryCubit();

      expect(cubit.state.status, QueryStatus.loading);

      cubit.updateOptions(
        newQueryKey: 'new-key'.toQueryKey(),
        newOptions: QueryOptions(),
      );

      expect(cubit.subscriptionCount, 1);

      await cubit.close();
    });

    test('updateOptions does nothing when options unchanged', () async {
      final cubit = _TestQueryCubit();
      final initialSubscriptionCount = cubit.subscriptionCount;

      cubit.updateOptions(
        newOptions: cubit.options,
      );

      expect(cubit.subscriptionCount, initialSubscriptionCount);

      await cubit.close();
    });

    test('updateOptions handles enabled option change', () async {
      final cubit = _TestQueryCubit();

      cubit.updateOptions(
        newOptions: QueryOptions(enabled: false),
      );

      expect(cubit.state.isIdle, true);

      await cubit.close();
    });

    test('updateOptions maintains subscription after option update', () async {
      final cubit = _TestQueryCubit();

      cubit.updateOptions(
        newOptions: QueryOptions(staleTime: const Duration(minutes: 5)),
      );

      cubit.refetch();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.hasData, true);

      await cubit.close();
    });

    test('updateOptions with queryKey change fetches new data', () async {
      final cubit = _TestQueryCubit();

      cubit.updateOptions(
        newQueryKey: 'different-key'.toQueryKey(),
        newOptions: QueryOptions(),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(cubit.subscriptionCount, 1);

      await cubit.close();
    });

    test('updateOptions does not emit state after cubit is closed', () async {
      final cubit = _TestQueryCubit();

      await cubit.close();

      expect(() {
        cubit.updateOptions(newOptions: QueryOptions());
      }, returnsNormally);

      expect(cubit.subscriptionCount, 0);
    });

    test('updateOptions handles rapid option changes', () async {
      final cubit = _TestQueryCubit();

      cubit.updateOptions(
          newOptions: QueryOptions(staleTime: const Duration(minutes: 1)));
      cubit.updateOptions(
          newOptions: QueryOptions(staleTime: const Duration(minutes: 2)));
      cubit.updateOptions(
          newOptions: QueryOptions(staleTime: const Duration(minutes: 3)));

      expect(cubit.subscriptionCount, 1);

      await cubit.close();
    });

    test('updateOptions with queryKey change maintains correct state',
        () async {
      final cubit = _TestQueryCubit();

      cubit.refetch();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.hasData, true);

      cubit.updateOptions(
        newQueryKey: 'new-key'.toQueryKey(),
        newOptions: QueryOptions(),
      );

      await Future.delayed(const Duration(milliseconds: 50));

      expect(cubit.subscriptionCount, 1);

      await cubit.close();
    });

    test('updateOptions preserves queryFn when swapping query', () async {
      final cubit = _TestQueryCubit();

      cubit.updateOptions(
        newQueryKey: 'new-key'.toQueryKey(),
        newOptions: QueryOptions(),
      );

      cubit.refetch();
      await Future.delayed(const Duration(milliseconds: 50));

      expect(cubit.state.hasData, true);

      await cubit.close();
    });
  });
}

class _TestQueryCubit extends QueryCubit<String> {
  _TestQueryCubit();

  @override
  QueryKey get queryKey => 'test-query'.toQueryKey();

  @override
  Future<String> Function() get queryFn => () async {
        await Future.delayed(const Duration(milliseconds: 5));
        return 'test data';
      };
}
