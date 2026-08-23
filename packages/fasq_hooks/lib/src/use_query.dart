import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'use_query_client.dart';

/// Returns a reactive query result with state and imperative query actions.
UseQueryResult<T> useQuery<T>(
  QueryKey queryKey, {
  Future<T> Function()? queryFn,
  Future<T> Function(CancellationToken token)? queryFnWithToken,
  QueryOptions? options,
  QueryKey? dependsOn,
  QueryClient? client,
}) {
  assert(
    queryFn != null || queryFnWithToken != null,
    'Either queryFn or queryFnWithToken must be provided',
  );
  final queryClient = useQueryClient(client: client);
  final query = useMemoized(
    () => queryClient.getQuery<T>(
      queryKey,
      queryFn: queryFn,
      queryFnWithToken: queryFnWithToken,
      options: options,
      dependsOn: dependsOn,
    ),
    [queryClient, queryKey.key],
  );
  final state = useState<QueryState<T>>(query.state);
  final hasMounted = useRef(false);

  useEffect(
    () {
      final shouldReconfigure = hasMounted.value;
      hasMounted.value = true;
      final configuredQuery = queryClient.reconfigureQuery<T>(
        queryKey,
        queryFn: queryFn,
        queryFnWithToken: queryFnWithToken,
        options: options,
        dependsOn: dependsOn,
      );
      configuredQuery.addListener();
      state.value = configuredQuery.state;
      final subscription = configuredQuery.stream.listen((nextState) {
        state.value = nextState;
      });
      final shouldFetch = options?.refetchOnMount ?? false;
      if (shouldFetch || shouldReconfigure) {
        unawaited(
          configuredQuery.fetch(forceRefetch: shouldFetch || shouldReconfigure),
        );
      }
      return () {
        unawaited(subscription.cancel());
        configuredQuery.removeListener();
      };
    },
    [queryClient, queryKey.key, queryFn, queryFnWithToken, options, dependsOn],
  );

  return UseQueryResult<T>(
    client: queryClient,
    query: query,
    state: state.value,
  );
}

/// Reactive state and commands for one standard query.
class UseQueryResult<T> {
  /// Creates a query result.
  const UseQueryResult({
    required this.client,
    required this.query,
    required this.state,
  });

  /// Client owning this query.
  final QueryClient client;

  /// Shared query instance.
  final Query<T> query;

  /// Current query state.
  final QueryState<T> state;

  /// Refetches the query, bypassing fresh cache data when requested.
  Future<void> refetch({bool forceRefetch = true}) {
    return query.fetch(forceRefetch: forceRefetch);
  }

  /// Marks this query stale and triggers the core invalidation behavior.
  void invalidate() => client.invalidateQuery(query.queryKey);

  /// Cancels the current cooperative fetch.
  void cancel() => query.cancel();

  /// Writes data through the owning client and updates active subscribers.
  void setData(T data, {bool isSecure = false, Duration? maxAge}) {
    client.setQueryData<T>(
      query.queryKey,
      data,
      isSecure: isSecure,
      maxAge: maxAge,
    );
  }

  /// Removes this query instance and its retained cache entry.
  void remove() => client.removeQuery(query.queryKey);

  /// Query-specific performance metrics.
  QueryMetrics get metrics => query.metrics;

  /// Debug lifecycle information, when available.
  QueryDebugInfo? get debugInfo => query.debugInfo;

  /// Whether the query currently has data.
  bool get hasData => state.hasValue;

  /// Whether the query is loading.
  bool get isLoading => state.isLoading;

  /// Whether the query is successful.
  bool get isSuccess => state.isSuccess;

  /// Whether the query is idle.
  bool get isIdle => state.isIdle;

  /// Whether the query currently has an error.
  bool get hasError => state.hasError;

  /// Whether the query is fetching.
  bool get isFetching => state.isFetching;

  /// Current data value.
  T? get data => state.data;

  /// Current error value.
  Object? get error => state.error;
}
