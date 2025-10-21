import 'dart:async';

import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

/// Configuration for a single query in a parallel query setup.
class QueryConfig<T> {
  /// Unique identifier for this query.
  final String key;

  /// Function that returns a Future with the data.
  final Future<T> Function() queryFn;

  /// Optional configuration for this query.
  final QueryOptions? options;

  const QueryConfig(this.key, this.queryFn, {this.options});
}

/// Hook that executes multiple queries in parallel and returns their states.
///
/// Each query executes independently and updates its state asynchronously.
/// The hook returns a list of QueryState objects corresponding to each config.
///
/// Example:
/// ```dart
/// final queries = useQueries([
///   QueryConfig('users', () => api.fetchUsers()),
///   QueryConfig('posts', () => api.fetchPosts()),
///   QueryConfig('comments', () => api.fetchComments()),
/// ]);
///
/// final allLoaded = queries.every((q) => q.hasData);
/// final anyError = queries.any((q) => q.hasError);
/// ```
List<QueryState<dynamic>> useQueries(List<QueryConfig> configs) {
  final client = QueryClient();
  final states = useState<List<QueryState<dynamic>>>([]);

  useEffect(() {
    final queries = configs
        .map((config) => client.getQuery(config.key, config.queryFn,
            options: config.options))
        .toList();

    // Add listeners to all queries
    for (final query in queries) {
      query.addListener();
    }

    // Subscribe to state changes for each query
    final subscriptions = <StreamSubscription>[];
    for (int i = 0; i < queries.length; i++) {
      subscriptions.add(queries[i].stream.listen((newState) {
        final newStates = List<QueryState<dynamic>>.from(states.value);
        newStates[i] = newState;
        states.value = newStates;
      }));
    }

    // Initialize with current states
    states.value = queries.map((q) => q.state).toList();

    // Cleanup function
    return () {
      for (final sub in subscriptions) {
        sub.cancel();
      }
      for (final query in queries) {
        query.removeListener();
      }
    };
  }, [configs.length]);

  return states.value;
}
