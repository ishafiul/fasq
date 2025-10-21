import 'dart:async';

import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Hook that provides a callback to prefetch queries.
///
/// Returns a function that can be called to prefetch a query.
/// Useful for prefetching on hover, on mount, or before navigation.
///
/// Example:
/// ```dart
/// final prefetch = usePrefetchQuery();
///
/// // Prefetch on hover
/// onHover: () => prefetch('user-123', () => api.fetchUser('123')),
/// ```
void Function(String, Future<T> Function(), {QueryOptions? options})
    usePrefetchQuery<T>({QueryClient? client}) {
  final queryClient = client ?? QueryClient();

  return useCallback((String key, Future<T> Function() queryFn,
      {QueryOptions? options}) {
    queryClient.prefetchQuery(key, queryFn, options: options);
  }, []);
}

/// Hook that prefetches queries on mount.
///
/// Useful for warming the cache for upcoming screens or tabs.
///
/// Example:
/// ```dart
/// usePrefetchOnMount([
///   PrefetchConfig(key: 'users', queryFn: () => api.fetchUsers()),
///   PrefetchConfig(key: 'posts', queryFn: () => api.fetchPosts()),
/// ]);
/// ```
void usePrefetchOnMount(List<PrefetchConfig> configs, {QueryClient? client}) {
  final queryClient = client ?? QueryClient();

  useEffect(() {
    queryClient.prefetchQueries(configs);
    return null;
  }, [configs.length]);
}

