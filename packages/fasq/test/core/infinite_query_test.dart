import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    QueryClient.resetForTesting();
  });

  test('accumulates pages and sets hasNextPage', () async {
    final client = QueryClient();
    int calls = 0;
    final query = client.getInfiniteQuery<List<int>, int>(
      'test:infinite',
      (page) async {
        calls++;
        await Future.delayed(const Duration(milliseconds: 10));
        return List.generate(3, (i) => (page - 1) * 3 + i + 1);
      },
      options: InfiniteQueryOptions<List<int>, int>(
        getNextPageParam: (pages, last) => last == null ? 1 : pages.length + 1,
        maxPages: 3,
      ),
    );

    query.addListener();
    await query.fetchNextPage(1);
    await query.fetchNextPage();
    await query.fetchNextPage();

    expect(calls, 3);
    expect(query.state.pages.length, 3);
    expect(query.state.hasNextPage, true);
  });

  test('respects maxPages by evicting oldest', () async {
    final client = QueryClient();
    final query = client.getInfiniteQuery<List<int>, int>(
      'test:maxpages',
      (page) async {
        await Future.delayed(const Duration(milliseconds: 10));
        return [page];
      },
      options: InfiniteQueryOptions<List<int>, int>(
        getNextPageParam: (pages, last) => last == null ? 1 : pages.length + 1,
        maxPages: 2,
      ),
    );

    query.addListener();
    await query.fetchNextPage(1);
    await query.fetchNextPage();
    await query.fetchNextPage();

    final dataPages = query.state.pages.where((p) => p.data != null).toList();
    expect(dataPages.length, 2);
  });

  test('per-page error does not drop previous pages', () async {
    final client = QueryClient();
    final query = client.getInfiniteQuery<List<int>, int>(
      'test:error-page',
      (p) async {
        await Future.delayed(const Duration(milliseconds: 10));
        if (p == 2) {
          throw Exception('fail page 2');
        }
        return [p];
      },
      options: InfiniteQueryOptions<List<int>, int>(
        getNextPageParam: (pages, last) => last == null ? 1 : pages.length + 1,
      ),
    );

    query.addListener();
    await query.fetchNextPage(1);
    await query.fetchNextPage(); // 2 -> error
    await query.fetchNextPage(); // 3

    expect(query.state.pages.length, 3);
    expect(query.state.pages[0].data, isNotNull);
    expect(query.state.pages[1].error, isNotNull);
    expect(query.state.pages[2].data, isNotNull);
  });

  test('removeListener prevents negative reference count', () {
    final client = QueryClient();
    final query = client.getInfiniteQuery<List<int>, int>(
      'test:negative-refs',
      (page) async => [page],
      options: InfiniteQueryOptions<List<int>, int>(
        getNextPageParam: (pages, last) => pages.length + 1,
        enabled: false, // Disable to prevent prefetch
      ),
    );

    // Start with 0 references
    expect(query.referenceCount, 0);

    // Try to remove listener when count is already 0
    query.removeListener();
    expect(query.referenceCount, 0); // Should remain 0, not go negative

    // Add one listener
    query.addListener();
    expect(query.referenceCount, 1);

    // Remove listener twice (more removes than adds)
    query.removeListener();
    expect(query.referenceCount, 0);

    query.removeListener(); // This should not make it negative
    expect(query.referenceCount, 0); // Should remain 0
  });
}
