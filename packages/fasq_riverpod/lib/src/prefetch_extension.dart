import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Extension on WidgetRef for prefetching queries.
extension PrefetchExtension on WidgetRef {
  /// Prefetch a query to warm the cache.
  Future<void> prefetchQuery<T>(
    String key,
    Future<T> Function() queryFn, {
    QueryOptions? options,
    QueryClient? client,
  }) async {
    final queryClient = client ?? QueryClient();
    await queryClient.prefetchQuery(key, queryFn, options: options);
  }
  
  /// Prefetch multiple queries in parallel.
  Future<void> prefetchQueries(List<PrefetchConfig> configs, {QueryClient? client}) async {
    final queryClient = client ?? QueryClient();
    await queryClient.prefetchQueries(configs);
  }
}
