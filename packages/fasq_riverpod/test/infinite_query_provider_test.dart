import 'package:fasq_riverpod/fasq_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await QueryClient.resetForTesting();
  });

  test('infiniteQueryProvider exposes state and methods', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final provider = infiniteQueryProvider<List<int>, int>(
      'riverpod:infinite'.toQueryKey(),
      (page) async {
        await Future.delayed(const Duration(milliseconds: 5));
        return [page];
      },
      options: InfiniteQueryOptions<List<int>, int>(
        getNextPageParam: (pages, last) => pages.length + 1,
      ),
    );

    // Initially should be loading
    final initialValue = container.read(provider);
    expect(initialValue, isA<AsyncLoading>());

    // Fetch the first page
    final notifier = container.read(provider.notifier);
    await notifier.fetchNextPage(1);

    // Wait for data to be available
    await Future.delayed(const Duration(milliseconds: 50));

    // Check that we have data
    final asyncValue = container.read(provider);
    expect(asyncValue, isA<AsyncData<InfiniteQueryState<List<int>, int>>>());

    final state = asyncValue.value!;
    expect(state.pages.where((p) => p.data != null).length, 1);
    expect(state.pages.first.data, [1]);
  });
}
