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

    final notifier = container.read(provider.notifier);
    expect(container.read(provider).pages, isEmpty);
    await notifier.fetchNextPage(1);
    expect(
        container.read(provider).pages.where((p) => p.data != null).length, 1);
  });
}
