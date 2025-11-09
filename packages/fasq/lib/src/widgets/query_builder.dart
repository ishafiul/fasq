import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/query.dart';
import '../core/query_client.dart';
import '../core/query_key.dart';
import '../core/query_options.dart';
import '../core/query_snapshot.dart';
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
  final QueryKey queryKey;

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
  late QueryState<T> _state;
  QueryClient? _client;
  bool _initialized = false;
  bool _hasQuery = false;

  @override
  void initState() {
    super.initState();
    _client = QueryClient.maybeInstance ?? QueryClient();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initialized = true;
    _initializeQuery();
  }

  void _initializeQuery() {
    final client = _client ?? QueryClient();
    final query = client.getQuery<T>(
      widget.queryKey,
      widget.queryFn,
      options: widget.options,
    );
    final forceRefetch = widget.options?.refetchOnMount ?? false;
    _attachQuery(
      query,
      shouldFetch: true,
      forceRefetch: forceRefetch,
    );
  }

  void _attachQuery(
    Query<T> query, {
    required bool shouldFetch,
    bool forceRefetch = false,
  }) {
    _detachCurrentQuery();

    _query = query;
    _hasQuery = true;
    _state = _query.state;

    _query.addListener();
    _subscription = _query.stream.listen((state) {
      if (mounted) {
        final previous = _state;
        _state = state;
        _emitContextNotifications(previous, state);
        setState(() {});
      }
    });

    if (shouldFetch) {
      _query.fetch(forceRefetch: forceRefetch);
    } else if (mounted) {
      setState(() {});
    }
  }

  void _detachCurrentQuery() {
    _subscription?.cancel();
    _subscription = null;

    if (_hasQuery) {
      _query.removeListener();
      _hasQuery = false;
    }
  }

  @override
  void dispose() {
    _detachCurrentQuery();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant QueryBuilder<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialized) {
      return;
    }

    final keyChanged = widget.queryKey != oldWidget.queryKey;
    final fnChanged = widget.queryFn != oldWidget.queryFn;
    final optionsChanged = !identical(widget.options, oldWidget.options);

    if (!keyChanged && !fnChanged && !optionsChanged) {
      return;
    }

    final client = _client ?? QueryClient();

    if (optionsChanged && !keyChanged) {
      final existing = client.getQueryByKey<T>(widget.queryKey);
      final isExclusivelyOwned = existing != null &&
          existing.referenceCount <= 1 &&
          existing == _query;
      if (isExclusivelyOwned) {
        client.removeQuery(widget.queryKey);
      }
    }

    final newQuery = client.getQuery<T>(
      widget.queryKey,
      widget.queryFn,
      options: widget.options,
    );

    final shouldFetch = keyChanged || fnChanged || optionsChanged;
    final forceRefetch =
        (widget.options?.refetchOnMount ?? false) || keyChanged || fnChanged;
    _attachQuery(
      newQuery,
      shouldFetch: shouldFetch,
      forceRefetch: forceRefetch,
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, _state);
  }

  void _emitContextNotifications(
    QueryState<T> previous,
    QueryState<T> current,
  ) {
    final client = _client;
    if (client == null || !mounted) {
      return;
    }

    final snapshot = QuerySnapshot<T>(
      queryKey: widget.queryKey,
      previousState: previous,
      currentState: current,
      options: widget.options,
    );
    final meta = widget.options?.meta;

    final enteredLoading = (!previous.isLoading && current.isLoading) ||
        (!previous.isFetching && current.isFetching);
    if (enteredLoading) {
      client.notifyQueryLoading(snapshot, meta, context);
    }

    final becameSuccess = (!previous.isSuccess && current.isSuccess) ||
        (previous.isFetching && !current.isFetching && current.isSuccess);
    if (becameSuccess) {
      client.notifyQuerySuccess(snapshot, meta, context);
      client.notifyQuerySettled(snapshot, meta, context);
    }

    final becameError = !previous.hasError && current.hasError;
    if (becameError) {
      client.notifyQueryError(snapshot, meta, context);
      client.notifyQuerySettled(snapshot, meta, context);
    }
  }
}
