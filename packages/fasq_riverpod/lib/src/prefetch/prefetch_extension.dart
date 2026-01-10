import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/client_provider.dart';

/// Extension on WidgetRef for prefetching queries using dependency injection.
///
/// This is the v2 API that uses [fasqClientProvider] to get the QueryClient,
/// enabling full dependency injection and testability.
///
/// Prefetching is useful for:
/// - Warming the cache before navigation
/// - Loading data on hover/focus
/// - Preloading data for upcoming screens
/// - Reducing perceived latency
///
/// Example - Prefetch on hover:
/// ```dart
/// MouseRegion(
///   onEnter: (_) {
///     ref.prefetchQuery(
///       QueryKeys.userDetails(userId),
///       () => api.fetchUserDetails(userId),
///     );
///   },
///   child: UserListTile(userId),
/// )
/// ```
///
/// Example - Prefetch before navigation:
/// ```dart
/// ElevatedButton(
///   onPressed: () async {
///     // Start prefetching
///     ref.prefetchQuery(
///       QueryKeys.postDetails(postId),
///       () => api.fetchPost(postId),
///     );
///
///     // Navigate (data will be cached when screen loads)
///     Navigator.push(
///       context,
///       MaterialPageRoute(
///         builder: (_) => PostDetailsScreen(postId),
///       ),
///     );
///   },
///   child: Text('View Post'),
/// )
/// ```
///
/// Example - Prefetch multiple queries:
/// ```dart
/// @override
/// void initState() {
///   super.initState();
///   // Prefetch multiple queries in parallel
///   Future.microtask(() {
///     ref.prefetchQueries([
///       PrefetchConfig(
///         queryKey: QueryKeys.users,
///         queryFn: () => api.fetchUsers(),
///       ),
///       PrefetchConfig(
///         queryKey: QueryKeys.posts,
///         queryFn: () => api.fetchPosts(),
///       ),
///     ]);
///   });
/// }
/// ```
extension PrefetchExtension on WidgetRef {
  /// Prefetches a query to warm the cache.
  ///
  /// Uses the [QueryClient] from [fasqClientProvider], ensuring consistency
  /// with your app's configured cache settings.
  ///
  /// If the cache already contains fresh data for the given key, the prefetch
  /// is skipped to avoid unnecessary network requests.
  ///
  /// The prefetch happens in the background and doesn't block the UI.
  ///
  /// Example:
  /// ```dart
  /// await ref.prefetchQuery(
  ///   QueryKeys.product(productId),
  ///   () => api.fetchProduct(productId),
  ///   options: QueryOptions(
  ///     staleTime: Duration(minutes: 5),
  ///   ),
  /// );
  /// ```
  Future<void> prefetchQuery<T>(
    QueryKey queryKey,
    Future<T> Function() queryFn, {
    QueryOptions? options,
  }) async {
    final client = read(fasqClientProvider);
    await client.prefetchQuery(queryKey, queryFn, options: options);
  }

  /// Prefetches multiple queries in parallel.
  ///
  /// Uses the [QueryClient] from [fasqClientProvider] and executes all
  /// prefetch operations concurrently for better performance.
  ///
  /// Each query is prefetched independently, and failures in one query
  /// do not affect others.
  ///
  /// Example:
  /// ```dart
  /// await ref.prefetchQueries([
  ///   PrefetchConfig(
  ///     queryKey: QueryKeys.users,
  ///     queryFn: () => api.fetchUsers(),
  ///     options: QueryOptions(staleTime: Duration(minutes: 5)),
  ///   ),
  ///   PrefetchConfig(
  ///     queryKey: QueryKeys.posts,
  ///     queryFn: () => api.fetchPosts(),
  ///   ),
  ///   PrefetchConfig(
  ///     queryKey: QueryKeys.comments,
  ///     queryFn: () => api.fetchComments(),
  ///   ),
  /// ]);
  /// ```
  Future<void> prefetchQueries(List<PrefetchConfig> configs) async {
    final client = read(fasqClientProvider);
    await client.prefetchQueries(configs);
  }
}
