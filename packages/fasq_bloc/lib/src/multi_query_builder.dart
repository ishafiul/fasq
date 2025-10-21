import 'dart:async';

import 'package:flutter/material.dart';
import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:fasq/fasq.dart';

/// Configuration for a single query in a MultiQueryBuilder.
class MultiQueryConfig {
  /// Unique identifier for this query.
  final String key;

  /// Function that returns a Future with the data.
  final Future<dynamic> Function() queryFn;

  /// Optional configuration for this query.
  final QueryOptions? options;

  const MultiQueryConfig({
    required this.key,
    required this.queryFn,
    this.options,
  });
}

/// Combined state for multiple queries with helper methods.
class MultiQueryState {
  /// List of individual query states.
  final List<QueryState<dynamic>> states;

  const MultiQueryState(this.states);

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
    return other is MultiQueryState &&
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

/// Widget that manages multiple queries and provides combined state.
///
/// Executes all queries in parallel and rebuilds when any query state changes.
/// Provides helper methods to check aggregate states across all queries.
///
/// Example:
/// ```dart
/// MultiQueryBuilder(
///   configs: [
///     MultiQueryConfig(key: 'users', queryFn: () => api.fetchUsers()),
///     MultiQueryConfig(key: 'posts', queryFn: () => api.fetchPosts()),
///   ],
///   builder: (context, state) {
///     if (state.isAllLoading) return CircularProgressIndicator();
///     if (state.hasAnyError) return ErrorWidget();
///
///     return Column(
///       children: [
///         UsersList(state.getState<List<User>>(0)),
///         PostsList(state.getState<List<Post>>(1)),
///       ],
///     );
///   },
/// )
/// ```
class MultiQueryBuilder extends StatefulWidget {
  /// Configuration for each query to execute.
  final List<MultiQueryConfig> configs;

  /// Builder function that receives the combined state.
  final Widget Function(BuildContext context, MultiQueryState state) builder;

  const MultiQueryBuilder({
    super.key,
    required this.configs,
    required this.builder,
  });

  @override
  State<MultiQueryBuilder> createState() => _MultiQueryBuilderState();
}

class _MultiQueryBuilderState extends State<MultiQueryBuilder> {
  final List<Query> _queries = [];
  final List<StreamSubscription> _subscriptions = [];
  List<QueryState<dynamic>> _states = [];

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  void _initialize() {
    final client = QueryClient();

    // Create queries for each config
    for (final config in widget.configs) {
      final query = client.getQuery(
        config.key,
        config.queryFn,
        options: config.options,
      );
      _queries.add(query);
      query.addListener();
    }

    // Initialize states with current query states
    _states = _queries.map((q) => q.state).toList();

    // Subscribe to state changes for each query
    for (int i = 0; i < _queries.length; i++) {
      _subscriptions.add(_queries[i].stream.listen((newState) {
        if (mounted) {
          setState(() {
            _states[i] = newState;
          });
        }
      }));
    }
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }

    // Remove listeners from all queries
    for (final query in _queries) {
      query.removeListener();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, MultiQueryState(_states));
  }
}
