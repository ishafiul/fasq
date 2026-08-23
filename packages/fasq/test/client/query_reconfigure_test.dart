import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    Query.disposalDelay = Duration.zero;
    InfiniteQuery.disposalDelay = Duration.zero;
    QueryCache.gcInterval = Duration.zero;
  });

  tearDown(() async => QueryClient.resetForTesting());

  test('reconfigures a standard query in place', () async {
    final client = QueryClient();
    final key = 'reconfigure'.toQueryKey();
    final query = client.getQuery<String>(
      key,
      queryFn: () async => 'old',
    );
    query.addListener();
    await query.fetch(forceRefetch: true);

    final reconfigured = client.reconfigureQuery<String>(
      key,
      queryFn: () async => 'new',
    );
    expect(identical(reconfigured, query), isTrue);
    await reconfigured.fetch(forceRefetch: true);
    expect(reconfigured.state.data, 'new');
  });

  test('reconfigures an infinite query in place', () async {
    final client = QueryClient();
    final key = 'infinite-reconfigure'.toQueryKey();
    final query = client.getInfiniteQuery<List<int>, int>(
      key,
      (page) async => [page],
      options: InfiniteQueryOptions<List<int>, int>(
        getNextPageParam: (pages, last) => pages.length < 1 ? 1 : null,
      ),
    );
    await query.addListener();
    await query.fetchNextPage();

    final reconfigured = client.reconfigureInfiniteQuery<List<int>, int>(
      key,
      (page) async => [page + 10],
    );
    expect(identical(reconfigured, query), isTrue);
    await reconfigured.refetchPage(0);
    expect(reconfigured.state.pages.single.data, [11]);
  });
}
