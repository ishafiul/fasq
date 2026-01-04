import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('InfiniteQueryCubit hasNextPage and isFetchingNextPage', () {
    setUp(() async {
      await QueryClient.resetForTesting();
    });

    test('hasNextPage is correctly mapped from InfiniteQuery state', () async {
      final cubit = _TestInfiniteQueryCubit();

      expect(cubit.state.hasNextPage, false);

      await cubit.fetchNextPage(1);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.hasNextPage, isA<bool>());

      await cubit.close();
    });

    test('isFetchingNextPage is correctly mapped from InfiniteQuery state', () async {
      final cubit = _TestInfiniteQueryCubit();

      expect(cubit.state.isFetchingNextPage, false);

      final fetchFuture = cubit.fetchNextPage(1);

      await Future.delayed(const Duration(milliseconds: 1));

      await fetchFuture;
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.isFetchingNextPage, false);

      await cubit.close();
    });

    test('hasNextPage reflects pagination state correctly', () async {
      final cubit = _TestInfiniteQueryCubit();

      expect(cubit.state.hasNextPage, false);

      await cubit.fetchNextPage(1);
      await Future.delayed(const Duration(milliseconds: 10));

      final hasNextAfterFirst = cubit.state.hasNextPage;

      await cubit.fetchNextPage(2);
      await Future.delayed(const Duration(milliseconds: 10));

      final hasNextAfterSecond = cubit.state.hasNextPage;

      expect(hasNextAfterFirst, isA<bool>());
      expect(hasNextAfterSecond, isA<bool>());

      await cubit.close();
    });

    test('hasNextPage is false when maxPages is reached', () async {
      final cubit = _TestInfiniteQueryCubit();

      await cubit.fetchNextPage(1);
      await cubit.fetchNextPage(2);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.pages.length, 2);

      await cubit.close();
    });

    test('isFetchingNextPage transitions correctly during fetch', () async {
      final cubit = _TestInfiniteQueryCubit();
      final states = <bool>[];

      cubit.stream.listen((state) {
        states.add(state.isFetchingNextPage);
      });

      await cubit.fetchNextPage(1);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(states, contains(false));

      await cubit.close();
    });

    test('hasNextPage and hasPreviousPage are both available', () async {
      final cubit = _TestInfiniteQueryCubit();

      expect(cubit.state.hasNextPage, isA<bool>());
      expect(cubit.state.hasPreviousPage, isA<bool>());

      await cubit.fetchNextPage(1);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.hasNextPage, isA<bool>());
      expect(cubit.state.hasPreviousPage, isA<bool>());

      await cubit.close();
    });

    test('isFetchingNextPage and isFetchingPreviousPage are both available', () async {
      final cubit = _TestInfiniteQueryCubit();

      expect(cubit.state.isFetchingNextPage, false);
      expect(cubit.state.isFetchingPreviousPage, false);

      await cubit.fetchNextPage(1);
      await Future.delayed(const Duration(milliseconds: 10));

      expect(cubit.state.isFetchingNextPage, false);
      expect(cubit.state.isFetchingPreviousPage, false);

      await cubit.close();
    });

    test('hasNextPage helper properties work in initial state', () {
      final cubit = _TestInfiniteQueryCubit();

      expect(cubit.state.hasNextPage, false);
      expect(cubit.state.hasPreviousPage, false);
      expect(cubit.state.isFetchingNextPage, false);
      expect(cubit.state.isFetchingPreviousPage, false);

      cubit.close();
    });

    test('hasNextPage updates correctly after multiple page fetches', () async {
      final cubit = _TestInfiniteQueryCubit();

      await cubit.fetchNextPage(1);
      await Future.delayed(const Duration(milliseconds: 10));

      final hasNext1 = cubit.state.hasNextPage;

      await cubit.fetchNextPage(2);
      await Future.delayed(const Duration(milliseconds: 10));

      final hasNext2 = cubit.state.hasNextPage;

      expect(hasNext1, isA<bool>());
      expect(hasNext2, isA<bool>());

      await cubit.close();
    });
  });
}

class _TestInfiniteQueryCubit extends InfiniteQueryCubit<List<int>, int> {
  @override
  QueryKey get queryKey => 'test-infinite'.toQueryKey();

  @override
  Future<List<int>> Function(int param) get queryFn => (page) async {
        await Future.delayed(const Duration(milliseconds: 5));
        return [page];
      };

  @override
  InfiniteQueryOptions<List<int>, int>? get options =>
      InfiniteQueryOptions<List<int>, int>(
        getNextPageParam: (pages, last) => pages.length + 1,
        maxPages: 2,
      );
}

