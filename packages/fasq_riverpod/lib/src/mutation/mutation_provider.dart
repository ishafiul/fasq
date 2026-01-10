import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mutation_notifier.dart';

/// Creates a Riverpod [AutoDisposeNotifierProvider] that wraps a FASQ [Mutation].
///
/// This is the v2 API that provides idiomatic Riverpod integration while
/// maintaining full compatibility with FASQ's mutation features.
///
/// Unlike queries, mutations are triggered imperatively via the `mutate()` method
/// rather than declaratively. The provider exposes the mutation state for UI updates.
///
/// The provider automatically:
/// - Gets the [QueryClient] from [fasqClientProvider]
/// - Handles mutation lifecycle (loading, success, error)
/// - Disposes the mutation when no longer needed
/// - Supports all FASQ mutation options (onSuccess, onError, offline queuing, etc.)
///
/// Example:
/// ```dart
/// final createUserMutation = mutationProvider<User, CreateUserInput>(
///   (variables) => api.createUser(variables),
///   options: MutationOptions(
///     onSuccess: (user) {
///       print('User created: ${user.id}');
///       // Optionally invalidate related queries
///       ref.read(fasqClientProvider).invalidateQuery(QueryKeys.users);
///     },
///     onError: (error) {
///       print('Failed to create user: $error');
///     },
///   ),
/// );
///
/// // In your widget:
/// Widget build(BuildContext context, WidgetRef ref) {
///   final mutation = ref.watch(createUserMutation);
///
///   return Column(
///     children: [
///       if (mutation.isLoading)
///         CircularProgressIndicator(),
///
///       if (mutation.hasError)
///         Text('Error: ${mutation.error}'),
///
///       if (mutation.isSuccess)
///         Text('User created: ${mutation.data?.name}'),
///
///       ElevatedButton(
///         onPressed: mutation.isLoading ? null : () {
///           ref.read(createUserMutation.notifier).mutate(
///             CreateUserInput(name: 'John', email: 'john@example.com'),
///           );
///         },
///         child: Text('Create User'),
///       ),
///     ],
///   );
/// }
/// ```
///
/// Mutation with optimistic updates:
/// ```dart
/// final updatePostMutation = mutationProvider<Post, UpdatePostInput>(
///   (variables) => api.updatePost(variables),
///   options: MutationOptions(
///     onMutate: (data, variables) {
///       // Optimistically update the cache
///       final client = ref.read(fasqClientProvider);
///       final queryKey = QueryKeys.post(variables.id);
///       final previousData = client.getQueryData<Post>(queryKey);
///
///       client.setQueryData(queryKey, data);
///       return previousData; // Return previous data for rollback
///     },
///     onError: (error) {
///       // Rollback on error
///       // You'd typically store and use the previousData from onMutate
///     },
///   ),
/// );
/// ```
///
/// Mutation with offline support:
/// ```dart
/// final createCommentMutation = mutationProvider<Comment, CreateCommentInput>(
///   (variables) => api.createComment(variables),
///   options: MutationOptions(
///     queueWhenOffline: true,
///     priority: 10, // Higher priority mutations execute first
///     onQueued: (variables) {
///       print('Mutation queued for when online');
///     },
///   ),
/// );
/// ```
AutoDisposeNotifierProvider<MutationNotifier<T, TVariables>, MutationState<T>>
    mutationProvider<T, TVariables>(
  Future<T> Function(TVariables variables) mutationFn, {
  MutationOptions<T, TVariables>? options,
}) {
  return AutoDisposeNotifierProvider<MutationNotifier<T, TVariables>,
      MutationState<T>>(() {
    final notifier = MutationNotifier<T, TVariables>();
    notifier.configure(
      mutationFn: mutationFn,
      options: options,
    );
    return notifier;
  });
}
