import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    QueryCache.gcInterval = Duration.zero;
    InfiniteQuery.disposalDelay = Duration.zero;
  });

  tearDown(() async {
    InfiniteQuery.disposalDelay = const Duration(seconds: 5);
    await QueryClient.resetForTesting();
  });

  testWidgets('exposes infinite pagination commands', (tester) async {
    UseInfiniteQueryResult<List<int>, int>? result;
    await tester.pumpWidget(
      MaterialApp(
        home: HookBuilder(
          builder: (context) {
            final fetch = useCallback<Future<List<int>> Function(int page)>(
              (page) async => [page],
              const [],
            );
            final options = useMemoized(
              () => InfiniteQueryOptions<List<int>, int>(
                getNextPageParam: (pages, lastPage) {
                  if (pages.length >= 2) return null;
                  return pages.length + 1;
                },
              ),
              const [],
            );
            result = useInfiniteQuery<List<int>, int>(
              'pages'.toQueryKey(),
              fetch,
              options: options,
            );
            return Text(result!.state.pages.length.toString());
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(result!.state.pages, hasLength(1));

    await result!.fetchNextPage();
    await tester.pumpAndSettle();
    expect(result!.state.pages, hasLength(2));

    await result!.refetchPage(0);
    result!.reset();
    expect(result!.query.state.pages, isEmpty);
  });
}
