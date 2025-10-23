import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/query.dart';
import '../core/query_client.dart';
import '../core/query_options.dart';
import '../core/query_state.dart';

/// A widget that executes an async operation and builds UI based on its state.
///
/// [QueryBuilder] automatically manages the query lifecycle, subscribing when
/// mounted and unsubscribing when disposed. It handles loading, error, and
/// success states, making async operations simple to use in Flutter widgets.
///
/// The query is shared across all widgets with the same [queryKey], so
/// multiple [QueryBuilder] widgets with identical keys will share state
/// and only execute the async operation once.
///
/// Example:
/// ```dart
/// QueryBuilder<List<User>>(
///   queryKey: 'users',
///   queryFn: () => api.fetchUsers(),
///   builder: (context, state) {
///     if (state.isLoading) return CircularProgressIndicator();
///     if (state.hasError) return Text('Error: ${state.error}');
///     if (state.hasData) return UserList(users: state.data!);
///     return SizedBox();
///   },
/// )
/// ```
class QueryBuilder<T> extends StatefulWidget {
  /// Unique identifier for this query.
  ///
  /// Widgets with the same key share the same query instance.
  final String queryKey;

  /// The async function to execute.
  ///
  /// Can be any Future-returning function: API calls, database queries,
  /// file operations, computations, etc.
  final Future<T> Function() queryFn;

  /// Builds the widget tree based on the current query state.
  ///
  /// Called whenever the query state changes, passing the latest [QueryState].
  final Widget Function(BuildContext context, QueryState<T> state) builder;

  /// Optional configuration for the query.
  final QueryOptions? options;

  const QueryBuilder({
    required this.queryKey,
    required this.queryFn,
    required this.builder,
    this.options,
    super.key,
  });

  @override
  State<QueryBuilder<T>> createState() => _QueryBuilderState<T>();
}

class _QueryBuilderState<T> extends State<QueryBuilder<T>> {
  late Query<T> _query;
  StreamSubscription<QueryState<T>>? _subscription;

  @override
  void initState() {
    super.initState();
    _initializeQuery();
  }

  void _initializeQuery() {
    final client = QueryClient();
    _query = client.getQuery<T>(
      widget.queryKey,
      widget.queryFn,
      options: widget.options,
    );

    _query.addListener();
    _subscription = _query.stream.listen((state) {
      if (mounted) {
        setState(() {});
      }
    });

    // Trigger fetch to check for staleness and update state
    _query.fetch();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _query.removeListener();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _query.state);
  }
}
