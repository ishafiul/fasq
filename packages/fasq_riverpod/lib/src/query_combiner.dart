import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fasq_riverpod/fasq_riverpod.dart';
import 'package:fasq/fasq.dart';

/// Combined state for two queries with helper methods.
class CombinedQueryState2<T1, T2> {
  /// State of the first query.
  final QueryState<T1> state1;

  /// State of the second query.
  final QueryState<T2> state2;

  const CombinedQueryState2(this.state1, this.state2);

  /// True if both queries are currently loading.
  bool get isAllLoading => state1.isLoading && state2.isLoading;

  /// True if any query is currently loading.
  bool get isAnyLoading => state1.isLoading || state2.isLoading;

  /// True if both queries have completed successfully.
  bool get isAllSuccess => state1.isSuccess && state2.isSuccess;

  /// True if any query has an error.
  bool get hasAnyError => state1.hasError || state2.hasError;

  /// True if both queries have data.
  bool get isAllData => state1.hasData && state2.hasData;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CombinedQueryState2<T1, T2> &&
        other.state1 == state1 &&
        other.state2 == state2;
  }

  @override
  int get hashCode => Object.hash(state1, state2);
}

/// Combined state for three queries with helper methods.
class CombinedQueryState3<T1, T2, T3> {
  /// State of the first query.
  final QueryState<T1> state1;

  /// State of the second query.
  final QueryState<T2> state2;

  /// State of the third query.
  final QueryState<T3> state3;

  const CombinedQueryState3(this.state1, this.state2, this.state3);

  /// True if all three queries are currently loading.
  bool get isAllLoading =>
      state1.isLoading && state2.isLoading && state3.isLoading;

  /// True if any query is currently loading.
  bool get isAnyLoading =>
      state1.isLoading || state2.isLoading || state3.isLoading;

  /// True if all three queries have completed successfully.
  bool get isAllSuccess =>
      state1.isSuccess && state2.isSuccess && state3.isSuccess;

  /// True if any query has an error.
  bool get hasAnyError => state1.hasError || state2.hasError || state3.hasError;

  /// True if all three queries have data.
  bool get isAllData => state1.hasData && state2.hasData && state3.hasData;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CombinedQueryState3<T1, T2, T3> &&
        other.state1 == state1 &&
        other.state2 == state2 &&
        other.state3 == state3;
  }

  @override
  int get hashCode => Object.hash(state1, state2, state3);
}

/// Helper to combine two query providers into a single provider.
///
/// Returns a provider that watches both query providers and provides
/// a CombinedQueryState2 with helper methods for checking aggregate states.
///
/// Example:
/// ```dart
/// final usersProvider = queryProvider('users', () => api.fetchUsers());
/// final postsProvider = queryProvider('posts', () => api.fetchPosts());
/// final combinedProvider = combineQueries2(usersProvider, postsProvider);
///
/// class MyWidget extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final combined = ref.watch(combinedProvider);
///
///     if (combined.isAllLoading) return CircularProgressIndicator();
///     if (combined.hasAnyError) return ErrorWidget();
///
///     return Column(
///       children: [
///         UsersList(combined.state1),
///         PostsList(combined.state2),
///       ],
///     );
///   }
/// }
/// ```
Provider<CombinedQueryState2<T1, T2>> combineQueries2<T1, T2>(
  StateNotifierProvider<QueryNotifier<T1>, QueryState<T1>> provider1,
  StateNotifierProvider<QueryNotifier<T2>, QueryState<T2>> provider2,
) {
  return Provider<CombinedQueryState2<T1, T2>>((ref) {
    return CombinedQueryState2(
      ref.watch(provider1),
      ref.watch(provider2),
    );
  });
}

/// Helper to combine three query providers into a single provider.
///
/// Returns a provider that watches all three query providers and provides
/// a CombinedQueryState3 with helper methods for checking aggregate states.
///
/// Example:
/// ```dart
/// final usersProvider = queryProvider('users', () => api.fetchUsers());
/// final postsProvider = queryProvider('posts', () => api.fetchPosts());
/// final commentsProvider = queryProvider('comments', () => api.fetchComments());
/// final combinedProvider = combineQueries3(usersProvider, postsProvider, commentsProvider);
///
/// class Dashboard extends ConsumerWidget {
///   @override
///   Widget build(BuildContext context, WidgetRef ref) {
///     final combined = ref.watch(combinedProvider);
///
///     if (combined.isAllLoading) return CircularProgressIndicator();
///     if (combined.hasAnyError) return ErrorWidget();
///
///     return Column(
///       children: [
///         UsersList(combined.state1),
///         PostsList(combined.state2),
///         CommentsList(combined.state3),
///       ],
///     );
///   }
/// }
/// ```
Provider<CombinedQueryState3<T1, T2, T3>> combineQueries3<T1, T2, T3>(
  StateNotifierProvider<QueryNotifier<T1>, QueryState<T1>> provider1,
  StateNotifierProvider<QueryNotifier<T2>, QueryState<T2>> provider2,
  StateNotifierProvider<QueryNotifier<T3>, QueryState<T3>> provider3,
) {
  return Provider<CombinedQueryState3<T1, T2, T3>>((ref) {
    return CombinedQueryState3(
      ref.watch(provider1),
      ref.watch(provider2),
      ref.watch(provider3),
    );
  });
}
