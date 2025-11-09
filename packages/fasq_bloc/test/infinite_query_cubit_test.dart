import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await QueryClient.resetForTesting();
  });

  test('InfiniteQueryCubit wires methods to core', () async {
    final cubit = _TestInfiniteQueryCubit();

    expect(cubit.state.pages, isEmpty);
    await cubit.fetchNextPage(1);
    await cubit.fetchNextPage();
    final pages = cubit.state.pages.where((p) => p.data != null).toList();
    expect(pages.length, 2);

    await cubit.refetchPage(1);
    expect(cubit.state.pages[1].data, isNotNull);

    await cubit.close();
  });
}

class _TestInfiniteQueryCubit extends InfiniteQueryCubit<List<int>, int> {
  @override
  QueryKey get queryKey => 'bloc:infinite'.toQueryKey();

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
