import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    QueryClient.resetForTesting();
  });

  test('InfiniteQueryCubit wires methods to core', () async {
    final cubit = InfiniteQueryCubit<List<int>, int>(
      key: 'bloc:infinite',
      queryFn: (page) async {
        await Future.delayed(const Duration(milliseconds: 5));
        return [page];
      },
      options: InfiniteQueryOptions<List<int>, int>(
        getNextPageParam: (pages, last) => pages.length + 1,
        maxPages: 2,
      ),
    );

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
