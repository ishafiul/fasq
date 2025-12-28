import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter/material.dart';

/// Configuration for a single query in a MultiQueryBuilder.
class MultiQueryConfig {
  /// Unique identifier for this query.
  final QueryKey queryKey;

  /// Function that returns a Future with the data.
  final Future<dynamic> Function() queryFn;

  /// Optional configuration for this query.
  final QueryOptions? options;

  const MultiQueryConfig({
    required this.queryKey,
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
///     MultiQueryConfig(
///       queryKey: 'users'.toQueryKey(),
///       queryFn: () => api.fetchUsers(),
///     ),
///     MultiQueryConfig(
///       queryKey: 'posts'.toQueryKey(),
///       queryFn: () => api.fetchPosts(),
///     ),
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
        config.queryKey,
        queryFn: config.queryFn,
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

/// Named configuration for MultiQueryBuilder
class NamedQueryConfig {
  /// Name identifier for this query.
  final String name;

  /// Unique identifier for this query.
  final QueryKey queryKey;

  /// Function that returns a Future with the data.
  final Future<dynamic> Function() queryFn;

  /// Optional configuration for this query.
  final QueryOptions? options;

  const NamedQueryConfig({
    required this.name,
    required this.queryKey,
    required this.queryFn,
    this.options,
  });
}

/// Named state for multiple queries with helper methods.
class NamedQueryState {
  /// Map of individual query states by name.
  final Map<String, QueryState<dynamic>> states;

  const NamedQueryState(this.states);

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
    return other is NamedQueryState &&
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

/// Widget that manages multiple named queries and provides combined state.
///
/// Executes all queries in parallel and rebuilds when any query state changes.
/// Provides helper methods to check aggregate states across all queries.
///
/// Example:
/// ```dart
/// NamedMultiQueryBuilder(
///   configs: [
///     NamedQueryConfig(
///       name: 'users',
///       queryKey: 'users'.toQueryKey(),
///       queryFn: () => api.fetchUsers(),
///     ),
///     NamedQueryConfig(
///       name: 'posts',
///       queryKey: 'posts'.toQueryKey(),
///       queryFn: () => api.fetchPosts(),
///     ),
///   ],
///   builder: (context, state) {
///     if (state.isAllLoading) return CircularProgressIndicator();
///     if (state.hasAnyError) return ErrorWidget();
///
///     return Column(
///       children: [
///         UsersList(state.getState<List<User>>('users')),
///         PostsList(state.getState<List<Post>>('posts')),
///       ],
///     );
///   },
/// )
/// ```
class NamedMultiQueryBuilder extends StatefulWidget {
  /// Configuration for each query to execute.
  final List<NamedQueryConfig> configs;

  /// Builder function that receives the combined state.
  final Widget Function(BuildContext context, NamedQueryState state) builder;

  const NamedMultiQueryBuilder({
    super.key,
    required this.configs,
    required this.builder,
  });

  @override
  State<NamedMultiQueryBuilder> createState() => _NamedMultiQueryBuilderState();
}

class _NamedMultiQueryBuilderState extends State<NamedMultiQueryBuilder> {
  final Map<String, Query> _queries = {};
  final List<StreamSubscription> _subscriptions = [];
  Map<String, QueryState<dynamic>> _states = {};

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
        config.queryKey,
        queryFn: config.queryFn,
        options: config.options,
      );
      _queries[config.name] = query;
      query.addListener();
    }

    // Initialize states with current query states
    _states = _queries.map((name, query) => MapEntry(name, query.state));

    // Subscribe to state changes for each query
    _queries.forEach((name, query) {
      _subscriptions.add(query.stream.listen((newState) {
        if (mounted) {
          setState(() {
            _states[name] = newState;
          });
        }
      }));
    });
  }

  @override
  void dispose() {
    // Cancel all subscriptions
    for (final sub in _subscriptions) {
      sub.cancel();
    }

    // Remove listeners from all queries
    for (final query in _queries.values) {
      query.removeListener();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, NamedQueryState(_states));
  }
}
