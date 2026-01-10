import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'infinite_query_notifier.dart';

/// Creates a Riverpod [AutoDisposeAsyncNotifierProvider] that wraps a FASQ [InfiniteQuery].
///
/// This is the v2 API that returns [AsyncValue<InfiniteQueryState<TData, TParam>>]
/// instead of raw [InfiniteQueryState], providing a more idiomatic Riverpod experience.
///
/// The provider automatically:
/// - Gets the [QueryClient] from [fasqClientProvider]
/// - Maps [InfiniteQueryState] to [AsyncValue] (loading/data/error)
/// - Handles pagination with proper loading states
/// - Disposes the query when no longer needed
///
/// Example:
/// ```dart
/// final postsProvider = infiniteQueryProvider<Post, int>(
///   QueryKeys.posts,
///   (pageParam) => api.fetchPosts(page: pageParam),
///   options: InfiniteQueryOptions(
///     initialParam: 0,
///     getNextPageParam: (lastPage, allPages) => allPages.length,
///   ),
/// );
///
/// // In your widget:
/// Widget build(BuildContext context, WidgetRef ref) {
///   final postsAsync = ref.watch(postsProvider);
///
///   return postsAsync.when(
///     data: (infiniteState) {
///       final allPosts = infiniteState.pages.expand((p) => p.data).toList();
///       return ListView.builder(
///         itemCount: allPosts.length + (infiniteState.hasNextPage ? 1 : 0),
///         itemBuilder: (context, index) {
///           if (index == allPosts.length) {
///             // Load more button
///             return ElevatedButton(
///               onPressed: () => ref.read(postsProvider.notifier).fetchNextPage(),
///               child: Text('Load More'),
///             );
///           }
///           return PostTile(allPosts[index]);
///         },
///       );
///     },
///     loading: () => CircularProgressIndicator(),
///     error: (error, stack) => Text('Error: $error'),
///   );
/// }
/// ```
///
/// Access notifier methods:
/// ```dart
/// // Fetch next page
/// ref.read(postsProvider.notifier).fetchNextPage();
///
/// // Fetch previous page
/// ref.read(postsProvider.notifier).fetchPreviousPage();
///
/// // Reset to first page
/// ref.read(postsProvider.notifier).reset();
///
/// // Invalidate and refetch
/// ref.read(postsProvider.notifier).invalidate();
/// ```
AutoDisposeAsyncNotifierProvider<InfiniteQueryNotifier<TData, TParam>,
    InfiniteQueryState<TData, TParam>> infiniteQueryProvider<TData, TParam>(
  QueryKey queryKey,
  Future<TData> Function(TParam param) queryFn, {
  InfiniteQueryOptions<TData, TParam>? options,
}) {
  return AutoDisposeAsyncNotifierProvider<InfiniteQueryNotifier<TData, TParam>,
      InfiniteQueryState<TData, TParam>>(() {
    final notifier = InfiniteQueryNotifier<TData, TParam>();
    notifier.configure(
      queryKey: queryKey,
      queryFn: queryFn,
      options: options,
    );
    return notifier;
  });
}
