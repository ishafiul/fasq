import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'use_query_client.dart';

/// Returns a stable asynchronous callback for prefetching one query.
Future<void> Function(QueryKey, Future<T> Function(), {QueryOptions? options})
usePrefetchQuery<T>({QueryClient? client}) {
  final queryClient = useQueryClient(client: client);
  return useCallback((
    QueryKey queryKey,
    Future<T> Function() queryFn, {
    QueryOptions? options,
  }) {
    return queryClient.prefetchQuery(queryKey, queryFn, options: options);
  }, [queryClient]);
}

/// Starts configured prefetches whenever the configuration changes.
void usePrefetchOnMount(
  List<PrefetchConfig<dynamic>> configs, {
  QueryClient? client,
}) {
  final queryClient = useQueryClient(client: client);
  final dependencies = <Object?>[
    queryClient,
    for (final config in configs) ...<Object?>[
      config.queryKey.key,
      config.queryFn,
      config.options,
    ],
  ];

  useEffect(() {
    unawaited(queryClient.prefetchQueries(configs));
    return null;
  }, dependencies);
}
