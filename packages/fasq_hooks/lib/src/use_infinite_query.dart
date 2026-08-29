import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'use_query_client.dart';

/// Returns reactive infinite-query state and pagination commands.
UseInfiniteQueryResult<TData, TParam> useInfiniteQuery<TData, TParam>(
  QueryKey queryKey,
  Future<TData> Function(TParam param) queryFn, {
  InfiniteQueryOptions<TData, TParam>? options,
  QueryClient? client,
}) {
  final queryClient = useQueryClient(client: client);
  final query = useMemoized(
    () => queryClient.getInfiniteQuery<TData, TParam>(
      queryKey,
      queryFn,
      options: options,
    ),
    [queryClient, queryKey.key],
  );
  final state = useState<InfiniteQueryState<TData, TParam>>(query.state);
  final hasMounted = useRef(false);

  useEffect(() {
    final shouldReconfigure = hasMounted.value;
    hasMounted.value = true;
    final configuredQuery = queryClient.reconfigureInfiniteQuery<TData, TParam>(
      queryKey,
      queryFn,
      options: options,
    );
    final hadPagesBeforeActivation = configuredQuery.state.pages.isNotEmpty;
    if (shouldReconfigure) configuredQuery.reset();
    configuredQuery.addListener();
    state.value = configuredQuery.state;
    final subscription = configuredQuery.stream.listen((nextState) {
      state.value = nextState;
    });
    if (options?.refetchOnMount == true &&
        !shouldReconfigure &&
        hadPagesBeforeActivation) {
      unawaited(_refetchInfinitePages(configuredQuery));
    }
    return () {
      unawaited(subscription.cancel());
      configuredQuery.removeListener();
    };
  }, [queryClient, queryKey.key, queryFn, options]);

  return UseInfiniteQueryResult<TData, TParam>(
    client: queryClient,
    query: query,
    state: state.value,
  );
}

Future<void> _refetchInfinitePages<TData, TParam>(
  InfiniteQuery<TData, TParam> query,
) async {
  final pageCount = query.state.pages.length;
  for (var index = 0; index < pageCount; index++) {
    await query.refetchPage(index);
  }
}

/// Reactive state and commands for one infinite query.
class UseInfiniteQueryResult<TData, TParam> {
  /// Creates an infinite query result.
  const UseInfiniteQueryResult({
    required this.client,
    required this.query,
    required this.state,
  });

  /// Client owning the query.
  final QueryClient client;

  /// Shared infinite-query instance.
  final InfiniteQuery<TData, TParam> query;

  /// Current pagination state.
  final InfiniteQueryState<TData, TParam> state;

  /// Fetches the next page.
  Future<void> fetchNextPage([TParam? parameter]) =>
      query.fetchNextPage(parameter);

  /// Fetches the previous page.
  Future<void> fetchPreviousPage() => query.fetchPreviousPage();

  /// Refetches one existing page.
  Future<void> refetchPage(int index) => query.refetchPage(index);

  /// Clears all pages and returns to idle state.
  void reset() => query.reset();

  /// Invalidates this query in the shared client cache.
  void invalidate() => client.invalidateQuery(query.queryKey);

  /// Removes this query from the client registry.
  void remove() => client.removeInfiniteQuery(query.queryKey);

  /// Whether another forward page is available.
  bool get hasNextPage => query.hasNextPage;

  /// Whether another backward page is available.
  bool get hasPreviousPage => query.hasPreviousPage;
}
