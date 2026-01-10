import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'query_notifier.dart';

/// Creates a Riverpod [AutoDisposeAsyncNotifierProvider] that wraps a FASQ [Query].
///
/// This is the v2 API that returns [AsyncValue<T>] instead of [QueryState<T>],
/// providing a more idiomatic Riverpod experience.
///
/// The provider automatically:
/// - Gets the [QueryClient] from [fasqClientProvider]
/// - Maps [QueryState] to [AsyncValue] (loading/data/error)
/// - Handles background refetching with proper loading states
/// - Disposes the query when no longer needed
///
/// Example:
/// ```dart
/// final userProvider = queryProvider<User>(
///   QueryKeys.user(userId),
///   () => api.fetchUser(userId),
///   options: QueryOptions(
///     staleTime: Duration(minutes: 5),
///   ),
/// );
///
/// // In your widget:
/// Widget build(BuildContext context, WidgetRef ref) {
///   final userAsync = ref.watch(userProvider);
///
///   return userAsync.when(
///     data: (user) => Text(user.name),
///     loading: () => CircularProgressIndicator(),
///     error: (error, stack) => Text('Error: $error'),
///   );
/// }
///
/// // Refresh manually:
/// ref.read(userProvider.notifier).refetch();
///
/// // Invalidate and refetch:
/// ref.read(userProvider.notifier).invalidate();
/// ```
///
/// For dependent queries:
/// ```dart
/// final userProvider = queryProvider<User>(...);
///
/// final postsProvider = queryProvider<List<Post>>(
///   QueryKeys.userPosts(userId),
///   () => api.fetchPosts(userId),
///   dependsOn: QueryKeys.user(userId), // Cancelled if user query disposes
/// );
/// ```
AutoDisposeAsyncNotifierProvider<QueryNotifier<T>, T> queryProvider<T>(
  QueryKey queryKey,
  Future<T> Function() queryFn, {
  QueryOptions? options,
  QueryKey? dependsOn,
}) {
  return AutoDisposeAsyncNotifierProvider<QueryNotifier<T>, T>(() {
    final notifier = QueryNotifier<T>();
    notifier.configure(
      queryKey: queryKey,
      queryFn: queryFn,
      options: options,
      dependsOn: dependsOn,
    );
    return notifier;
  });
}

/// Creates a query provider with a cancellation token.
///
/// Similar to [queryProvider] but the query function receives a [CancellationToken]
/// that can be used to cancel long-running operations.
///
/// Example:
/// ```dart
/// final dataProvider = queryProviderWithToken<Data>(
///   QueryKeys.data,
///   (token) async {
///     // Use token to cancel fetch if query is disposed
///     return await api.fetchData(cancellationToken: token);
///   },
/// );
/// ```
AutoDisposeAsyncNotifierProvider<QueryNotifier<T>, T>
    queryProviderWithToken<T>(
  QueryKey queryKey,
  Future<T> Function(CancellationToken token) queryFnWithToken, {
  QueryOptions? options,
  QueryKey? dependsOn,
}) {
  return AutoDisposeAsyncNotifierProvider<QueryNotifier<T>, T>(() {
    final notifier = QueryNotifier<T>();
    notifier.configure(
      queryKey: queryKey,
      queryFnWithToken: queryFnWithToken,
      options: options,
      dependsOn: dependsOn,
    );
    return notifier;
  });
}
