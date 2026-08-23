import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'use_query.dart';
import 'use_query_client.dart';

/// Configuration for one standard query in a parallel query set.
class QueryConfig<T> {
  /// Creates a query configuration.
  const QueryConfig(
    this.queryKey,
    this.queryFn, {
    this.queryFnWithToken,
    this.options,
    this.dependsOn,
  });

  /// Stable query identity.
  final QueryKey queryKey;

  /// Ordinary fetch function.
  final Future<T> Function()? queryFn;

  /// Cancellation-aware fetch function.
  final Future<T> Function(CancellationToken token)? queryFnWithToken;

  /// Query behavior options.
  final QueryOptions? options;

  /// Optional parent query dependency.
  final QueryKey? dependsOn;
}

/// Executes and observes multiple queries keyed by their query identity.
List<UseQueryResult<dynamic>> useQueries(
  List<QueryConfig<dynamic>> configs, {
  QueryClient? client,
}) {
  final queryClient = useQueryClient(client: client);
  final results = useState<List<UseQueryResult<dynamic>>>(const []);
  final hasMounted = useRef(false);
  final dependencies = _queryDependencies(queryClient, configs);

  useEffect(() {
    final shouldReconfigure = hasMounted.value;
    hasMounted.value = true;
    final queries = configs
        .map(
          (config) => queryClient.reconfigureQuery<dynamic>(
            config.queryKey,
            queryFn: config.queryFn,
            queryFnWithToken: config.queryFnWithToken,
            options: config.options,
            dependsOn: config.dependsOn,
          ),
        )
        .toList(growable: false);
    final subscriptions = <StreamSubscription<QueryState<dynamic>>>[];

    for (var index = 0; index < queries.length; index++) {
      final query = queries[index];
      query.addListener();
      subscriptions.add(
        query.stream.listen((state) {
          final next = List<UseQueryResult<dynamic>>.from(results.value);
          if (index >= next.length) return;
          next[index] = UseQueryResult<dynamic>(
            client: queryClient,
            query: query,
            state: state,
          );
          results.value = next;
        }),
      );
    }

    results.value = [
      for (final query in queries)
        UseQueryResult<dynamic>(
          client: queryClient,
          query: query,
          state: query.state,
        ),
    ];
    for (final query in queries) {
      if (query.options?.refetchOnMount == true || shouldReconfigure) {
        unawaited(
          query.fetch(
            forceRefetch:
                shouldReconfigure || query.options?.refetchOnMount == true,
          ),
        );
      }
    }

    return () {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
      for (final query in queries) {
        query.removeListener();
      }
    };
  }, dependencies);

  return results.value;
}

/// Configuration for one named query.
class NamedQueryConfig<T> {
  /// Creates a named query configuration.
  const NamedQueryConfig({
    required this.name,
    required this.queryKey,
    this.queryFn,
    this.queryFnWithToken,
    this.options,
    this.dependsOn,
  });

  /// Stable UI name.
  final String name;

  /// Stable query identity.
  final QueryKey queryKey;

  /// Ordinary fetch function.
  final Future<T> Function()? queryFn;

  /// Cancellation-aware fetch function.
  final Future<T> Function(CancellationToken token)? queryFnWithToken;

  /// Query behavior options.
  final QueryOptions? options;

  /// Optional parent query dependency.
  final QueryKey? dependsOn;
}

/// Executes and observes named queries keyed by name and query identity.
Map<String, UseQueryResult<dynamic>> useNamedQueries(
  List<NamedQueryConfig<dynamic>> configs, {
  QueryClient? client,
}) {
  final queryClient = useQueryClient(client: client);
  final results = useState<Map<String, UseQueryResult<dynamic>>>({});
  final hasMounted = useRef(false);
  final dependencies = <Object?>[
    queryClient,
    for (final config in configs) ...<Object?>[
      config.name,
      config.queryKey.key,
      config.queryFn,
      config.queryFnWithToken,
      config.options,
      config.dependsOn?.key,
    ],
  ];

  useEffect(() {
    final shouldReconfigure = hasMounted.value;
    hasMounted.value = true;
    final queries = <String, Query<dynamic>>{
      for (final config in configs)
        config.name: queryClient.reconfigureQuery<dynamic>(
          config.queryKey,
          queryFn: config.queryFn,
          queryFnWithToken: config.queryFnWithToken,
          options: config.options,
          dependsOn: config.dependsOn,
        ),
    };
    final subscriptions = <StreamSubscription<QueryState<dynamic>>>[];
    queries.forEach((name, query) {
      query.addListener();
      subscriptions.add(
        query.stream.listen((state) {
          final next = Map<String, UseQueryResult<dynamic>>.from(results.value);
          next[name] = UseQueryResult<dynamic>(
            client: queryClient,
            query: query,
            state: state,
          );
          results.value = next;
        }),
      );
    });
    results.value = {
      for (final entry in queries.entries)
        entry.key: UseQueryResult<dynamic>(
          client: queryClient,
          query: entry.value,
          state: entry.value.state,
        ),
    };
    for (final config in configs) {
      final query = queries[config.name];
      if (query == null) continue;
      if (config.options?.refetchOnMount == true || shouldReconfigure) {
        unawaited(
          query.fetch(
            forceRefetch:
                shouldReconfigure || config.options?.refetchOnMount == true,
          ),
        );
      }
    }

    return () {
      for (final subscription in subscriptions) {
        unawaited(subscription.cancel());
      }
      for (final query in queries.values) {
        query.removeListener();
      }
    };
  }, dependencies);

  return results.value;
}

List<Object?> _queryDependencies(
  QueryClient queryClient,
  List<QueryConfig<dynamic>> configs,
) {
  return <Object?>[
    queryClient,
    for (final config in configs) ...<Object?>[
      config.queryKey.key,
      config.queryFn,
      config.queryFnWithToken,
      config.options,
      config.dependsOn?.key,
    ],
  ];
}
