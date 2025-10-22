import 'package:fasq_riverpod/fasq_riverpod.dart';

/// Combined state for multiple queries with helper methods.
class CombinedQueriesState {
  /// List of individual query states.
  final List<QueryState<dynamic>> states;

  const CombinedQueriesState(this.states);

  /// True if all queries are currently loading.
  bool get isAllLoading => states.every((s) => s.isLoading);

  /// True if any query is currently loading.
  bool get isAnyLoading => states.any((s) => s.isLoading);

  /// True if all queries have completed successfully.
  bool get isAllSuccess => states.every((s) => s.isSuccess);

  /// True if any query has an error.
  bool get hasAnyError => states.any((s) => s.hasError);

  /// True if all queries have data.
  bool get isAllData => states.every((s) => s.hasData);

  /// Gets the state for a specific query by index.
  QueryState<T> getState<T>(int index) => states[index] as QueryState<T>;

  /// Gets the number of queries.
  int get length => states.length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CombinedQueriesState &&
        other.states.length == states.length &&
        _listEquals(other.states, states);
  }

  @override
  int get hashCode => states.hashCode;

  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Named combined state for multiple queries with helper methods.
class NamedQueriesState {
  /// Map of query states by name.
  final Map<String, QueryState<dynamic>> states;

  const NamedQueriesState(this.states);

  /// True if all queries are currently loading.
  bool get isAllLoading => states.values.every((s) => s.isLoading);

  /// True if any query is currently loading.
  bool get isAnyLoading => states.values.any((s) => s.isLoading);

  /// True if all queries have completed successfully.
  bool get isAllSuccess => states.values.every((s) => s.isSuccess);

  /// True if any query has an error.
  bool get hasAnyError => states.values.any((s) => s.hasError);

  /// True if all queries have data.
  bool get isAllData => states.values.every((s) => s.hasData);

  /// Gets the state for a specific query by name.
  QueryState<T> getState<T>(String name) => states[name] as QueryState<T>;

  /// Checks if a specific query is loading.
  bool isLoading(String name) => states[name]?.isLoading ?? false;

  /// Checks if a specific query has an error.
  bool hasError(String name) => states[name]?.hasError ?? false;

  /// Gets the number of queries.
  int get length => states.length;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is NamedQueriesState &&
        other.states.length == states.length &&
        _mapEquals(other.states, states);
  }

  @override
  int get hashCode => states.hashCode;

  bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Helper to combine multiple query providers into a single provider.
///
/// Returns a provider that watches all query providers and provides
/// a CombinedQueriesState with helper methods for checking aggregate states.
///
/// Example:
/// ```dart
/// final usersProvider = queryProvider('users', () => api.fetchUsers());
/// final postsProvider = queryProvider('posts', () => api.fetchPosts());
/// final commentsProvider = queryProvider('comments', () => api.fetchComments());
/// final combinedProvider = combineQueries([usersProvider, postsProvider, commentsProvider]);
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
///         UsersList(combined.getState<List<User>>(0)),
///         PostsList(combined.getState<List<Post>>(1)),
///         CommentsList(combined.getState<List<Comment>>(2)),
///       ],
///     );
///   }
/// }
/// ```
Provider<CombinedQueriesState> combineQueries(
  List<StateNotifierProvider<QueryNotifier<dynamic>, QueryState<dynamic>>>
      providers,
) {
  return Provider<CombinedQueriesState>((ref) {
    final states = providers.map((provider) => ref.watch(provider)).toList();
    return CombinedQueriesState(states);
  });
}

/// Helper to combine multiple named query providers into a single provider.
///
/// Returns a provider that watches all query providers and provides
/// a NamedQueriesState with helper methods for checking aggregate states.
///
/// Example:
/// ```dart
/// final usersProvider = queryProvider('users', () => api.fetchUsers());
/// final postsProvider = queryProvider('posts', () => api.fetchPosts());
/// final commentsProvider = queryProvider('comments', () => api.fetchComments());
/// final combinedProvider = combineNamedQueries({
///   'users': usersProvider,
///   'posts': postsProvider,
///   'comments': commentsProvider,
/// });
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
///         UsersList(combined.getState<List<User>>('users')),
///         PostsList(combined.getState<List<Post>>('posts')),
///         CommentsList(combined.getState<List<Comment>>('comments')),
///       ],
///     );
///   }
/// }
/// ```
Provider<NamedQueriesState> combineNamedQueries(
  Map<String,
          StateNotifierProvider<QueryNotifier<dynamic>, QueryState<dynamic>>>
      providers,
) {
  return Provider<NamedQueriesState>((ref) {
    final states = <String, QueryState<dynamic>>{};
    providers.forEach((name, provider) {
      states[name] = ref.watch(provider);
    });
    return NamedQueriesState(states);
  });
}
