import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

/// Configuration for one query in a [MultiQueryBuilder].
class MultiQueryConfig {
  /// Unique identifier for this query.
  final QueryKey queryKey;

  /// Legacy query function used when [queryFnWithToken] is absent.
  final Future<dynamic> Function()? queryFn;

  /// Cancellation-aware query function.
  final Future<dynamic> Function(CancellationToken token)? queryFnWithToken;

  /// Parent query key used for cascading cancellation.
  final QueryKey? dependsOn;

  /// Optional configuration for this query.
  final QueryOptions? options;

  const MultiQueryConfig({
    required this.queryKey,
    this.queryFn,
    this.queryFnWithToken,
    this.dependsOn,
    this.options,
  }) : assert(
         queryFn != null || queryFnWithToken != null,
         'Either queryFn or queryFnWithToken must be provided',
       );
}

/// Combined state for multiple queries with helper methods.
class MultiQueryState {
  /// List of individual query states.
  final List<QueryState<dynamic>> states;

  const MultiQueryState(this.states);

  /// True if all queries are currently loading.
  bool get isAllLoading => states.every((state) => state.isLoading);

  /// True if any query is currently loading.
  bool get isAnyLoading => states.any((state) => state.isLoading);

  /// True if all queries have completed successfully.
  bool get isAllSuccess => states.every((state) => state.isSuccess);

  /// True if any query has an error.
  bool get hasAnyError => states.any((state) => state.hasError);

  /// True if all queries have data.
  bool get isAllData => states.every((state) => state.hasData);

  /// Gets the state for a specific query by index.
  QueryState<T> getState<T>(int index) => _typedState(states[index]);

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
  int get hashCode => Object.hashAll(states);

  bool _listEquals<T>(List<T> first, List<T> second) {
    if (first.length != second.length) return false;
    for (var index = 0; index < first.length; index++) {
      if (first[index] != second[index]) return false;
    }
    return true;
  }
}

/// Widget that manages multiple queries and provides combined state.
class MultiQueryBuilder extends StatefulWidget {
  /// Configuration for each query to execute.
  final List<MultiQueryConfig> configs;

  /// Optional client. Otherwise the nearest core/provider client is used.
  final QueryClient? client;

  /// Builder function that receives the combined state.
  final Widget Function(BuildContext context, MultiQueryState state) builder;

  const MultiQueryBuilder({
    super.key,
    required this.configs,
    required this.builder,
    this.client,
  });

  @override
  State<MultiQueryBuilder> createState() => _MultiQueryBuilderState();
}

class _MultiQueryBuilderState extends State<MultiQueryBuilder> {
  final List<Query<dynamic>> _queries = [];
  final List<bool> _queryReferences = [];
  final List<StreamSubscription<QueryState<dynamic>>> _subscriptions = [];
  List<QueryState<dynamic>> _states = [];
  QueryClient? _client;
  var _initialized = false;
  var _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = _resolveClient();
    if (!_initialized || !identical(client, _client)) {
      _initialized = true;
      _client = client;
      _rebuildQueries(client, shouldRefetch: false);
    }
  }

  @override
  void didUpdateWidget(covariant MultiQueryBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.client != oldWidget.client ||
        _configsChanged(oldWidget.configs, widget.configs)) {
      final client = _resolveClient();
      _client = client;
      _rebuildQueries(client, shouldRefetch: true);
    }
  }

  QueryClient _resolveClient() {
    return widget.client ?? context.queryClient ?? QueryClient();
  }

  void _rebuildQueries(QueryClient client, {required bool shouldRefetch}) {
    _generation++;
    _detachQueries();

    final nextQueries = <Query<dynamic>>[];
    final nextStates = <QueryState<dynamic>>[];
    for (final config in widget.configs) {
      final query = client.reconfigureQuery<dynamic>(
        config.queryKey,
        queryFn: config.queryFn,
        queryFnWithToken: config.queryFnWithToken,
        options: config.options,
        dependsOn: config.dependsOn,
      );
      nextQueries.add(query);
      nextStates.add(query.state);
    }

    _queries.addAll(nextQueries);
    _queryReferences.addAll(List<bool>.filled(nextQueries.length, false));
    _states = nextStates;

    final generation = _generation;
    for (var index = 0; index < _queries.length; index++) {
      final queryIndex = index;
      _subscriptions.add(
        _queries[queryIndex].stream.listen((newState) {
          if (!mounted || generation != _generation) return;
          setState(() {
            _states[queryIndex] = newState;
          });
        }),
      );
    }
    unawaited(
      _activateQueries(client, generation, shouldRefetch: shouldRefetch),
    );
  }

  Future<void> _activateQueries(
    QueryClient client,
    int generation, {
    required bool shouldRefetch,
  }) async {
    try {
      await client.persistenceInitialization;
    } on Object catch (error, stackTrace) {
      if (mounted && generation == _generation) {
        setState(() {
          for (var index = 0; index < _states.length; index++) {
            _states[index] = QueryState<dynamic>.error(error, stackTrace);
          }
        });
      }
      return;
    }

    if (!mounted || generation != _generation) return;
    for (var index = 0; index < _queries.length; index++) {
      _queries[index].addListener();
      _queryReferences[index] = true;
      _states[index] = _queries[index].state;
    }
    if (mounted && generation == _generation) {
      setState(() {});
    }

    final fetches = <Future<void>>[];
    for (final query in _queries) {
      final forceRefetch =
          shouldRefetch || query.options?.refetchOnMount == true;
      final isFirstSubscriber =
          query.referenceCount == 1 && !query.state.hasValue;
      final shouldFetch =
          !isFirstSubscriber &&
          (forceRefetch || (query.state.hasValue && query.state.isStale));
      if (!shouldFetch) continue;
      fetches.add(query.fetch(forceRefetch: forceRefetch).catchError((_) {}));
    }
    await Future.wait(fetches);
  }

  void _detachQueries() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    for (var index = 0; index < _queries.length; index++) {
      if (_queryReferences[index]) {
        _queries[index].removeListener();
      }
    }
    _queries.clear();
    _queryReferences.clear();
  }

  bool _configsChanged(
    List<MultiQueryConfig> previous,
    List<MultiQueryConfig> next,
  ) {
    if (previous.length != next.length) return true;
    for (var index = 0; index < previous.length; index++) {
      final oldConfig = previous[index];
      final newConfig = next[index];
      if (oldConfig.queryKey.key != newConfig.queryKey.key ||
          !identical(oldConfig.queryFn, newConfig.queryFn) ||
          !identical(oldConfig.queryFnWithToken, newConfig.queryFnWithToken) ||
          oldConfig.dependsOn?.key != newConfig.dependsOn?.key ||
          !identical(oldConfig.options, newConfig.options)) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _generation++;
    _detachQueries();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, MultiQueryState(List.unmodifiable(_states)));
  }
}

/// Named configuration for [NamedMultiQueryBuilder].
class NamedQueryConfig {
  /// Name used to retrieve this query's state.
  final String name;

  /// Unique identifier for this query.
  final QueryKey queryKey;

  /// Legacy query function used when [queryFnWithToken] is absent.
  final Future<dynamic> Function()? queryFn;

  /// Cancellation-aware query function.
  final Future<dynamic> Function(CancellationToken token)? queryFnWithToken;

  /// Parent query key used for cascading cancellation.
  final QueryKey? dependsOn;

  /// Optional configuration for this query.
  final QueryOptions? options;

  const NamedQueryConfig({
    required this.name,
    required this.queryKey,
    this.queryFn,
    this.queryFnWithToken,
    this.dependsOn,
    this.options,
  }) : assert(
         queryFn != null || queryFnWithToken != null,
         'Either queryFn or queryFnWithToken must be provided',
       );
}

/// Named state for multiple queries with helper methods.
class NamedQueryState {
  /// Map of individual query states by name.
  final Map<String, QueryState<dynamic>> states;

  const NamedQueryState(this.states);

  /// True if all queries are currently loading.
  bool get isAllLoading => states.values.every((state) => state.isLoading);

  /// True if any query is currently loading.
  bool get isAnyLoading => states.values.any((state) => state.isLoading);

  /// True if all queries have completed successfully.
  bool get isAllSuccess => states.values.every((state) => state.isSuccess);

  /// True if any query has an error.
  bool get hasAnyError => states.values.any((state) => state.hasError);

  /// True if all queries have data.
  bool get isAllData => states.values.every((state) => state.hasData);

  /// Gets the state for a specific query by name.
  QueryState<T> getState<T>(String name) => _typedState(states[name]!);

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
  int get hashCode => Object.hashAllUnordered(
    states.entries.map((entry) => Object.hash(entry.key, entry.value)),
  );

  bool _mapEquals<K, V>(Map<K, V> first, Map<K, V> second) {
    if (first.length != second.length) return false;
    for (final key in first.keys) {
      if (!second.containsKey(key) || first[key] != second[key]) return false;
    }
    return true;
  }
}

/// Widget that manages multiple named queries and provides combined state.
class NamedMultiQueryBuilder extends StatefulWidget {
  /// Configuration for each named query to execute.
  final List<NamedQueryConfig> configs;

  /// Optional client. Otherwise the nearest core/provider client is used.
  final QueryClient? client;

  /// Builder function that receives the combined state.
  final Widget Function(BuildContext context, NamedQueryState state) builder;

  const NamedMultiQueryBuilder({
    super.key,
    required this.configs,
    required this.builder,
    this.client,
  });

  @override
  State<NamedMultiQueryBuilder> createState() => _NamedMultiQueryBuilderState();
}

class _NamedMultiQueryBuilderState extends State<NamedMultiQueryBuilder> {
  final Map<String, Query<dynamic>> _queries = {};
  final Map<String, bool> _queryReferences = {};
  final List<StreamSubscription<QueryState<dynamic>>> _subscriptions = [];
  Map<String, QueryState<dynamic>> _states = {};
  QueryClient? _client;
  var _initialized = false;
  var _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = _resolveClient();
    if (!_initialized || !identical(client, _client)) {
      _initialized = true;
      _client = client;
      _rebuildQueries(client, shouldRefetch: false);
    }
  }

  @override
  void didUpdateWidget(covariant NamedMultiQueryBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.client != oldWidget.client ||
        _configsChanged(oldWidget.configs, widget.configs)) {
      final client = _resolveClient();
      _client = client;
      _rebuildQueries(client, shouldRefetch: true);
    }
  }

  QueryClient _resolveClient() {
    return widget.client ?? context.queryClient ?? QueryClient();
  }

  void _rebuildQueries(QueryClient client, {required bool shouldRefetch}) {
    _generation++;
    _detachQueries();

    final names = <String>{};
    for (final config in widget.configs) {
      if (!names.add(config.name)) {
        throw ArgumentError.value(
          config.name,
          'configs',
          'Named query names must be unique.',
        );
      }
    }

    final nextStates = <String, QueryState<dynamic>>{};
    for (final config in widget.configs) {
      final query = client.reconfigureQuery<dynamic>(
        config.queryKey,
        queryFn: config.queryFn,
        queryFnWithToken: config.queryFnWithToken,
        options: config.options,
        dependsOn: config.dependsOn,
      );
      _queries[config.name] = query;
      _queryReferences[config.name] = false;
      nextStates[config.name] = query.state;
    }
    _states = nextStates;

    final generation = _generation;
    for (final entry in _queries.entries) {
      final name = entry.key;
      _subscriptions.add(
        entry.value.stream.listen((newState) {
          if (!mounted || generation != _generation) return;
          setState(() {
            _states[name] = newState;
          });
        }),
      );
    }
    unawaited(
      _activateQueries(client, generation, shouldRefetch: shouldRefetch),
    );
  }

  Future<void> _activateQueries(
    QueryClient client,
    int generation, {
    required bool shouldRefetch,
  }) async {
    try {
      await client.persistenceInitialization;
    } on Object catch (error, stackTrace) {
      if (mounted && generation == _generation) {
        setState(() {
          _states = {
            for (final name in _states.keys)
              name: QueryState<dynamic>.error(error, stackTrace),
          };
        });
      }
      return;
    }

    if (!mounted || generation != _generation) return;
    for (final entry in _queries.entries) {
      entry.value.addListener();
      _queryReferences[entry.key] = true;
      _states[entry.key] = entry.value.state;
    }
    if (mounted && generation == _generation) {
      setState(() {});
    }

    final fetches = <Future<void>>[];
    for (final query in _queries.values) {
      final forceRefetch =
          shouldRefetch || query.options?.refetchOnMount == true;
      final isFirstSubscriber =
          query.referenceCount == 1 && !query.state.hasValue;
      final shouldFetch =
          !isFirstSubscriber &&
          (forceRefetch || (query.state.hasValue && query.state.isStale));
      if (!shouldFetch) continue;
      fetches.add(query.fetch(forceRefetch: forceRefetch).catchError((_) {}));
    }
    await Future.wait(fetches);
  }

  void _detachQueries() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    for (final entry in _queries.entries) {
      if (_queryReferences[entry.key] ?? false) {
        entry.value.removeListener();
      }
    }
    _queries.clear();
    _queryReferences.clear();
  }

  bool _configsChanged(
    List<NamedQueryConfig> previous,
    List<NamedQueryConfig> next,
  ) {
    if (previous.length != next.length) return true;
    for (var index = 0; index < previous.length; index++) {
      final oldConfig = previous[index];
      final newConfig = next[index];
      if (oldConfig.name != newConfig.name ||
          oldConfig.queryKey.key != newConfig.queryKey.key ||
          !identical(oldConfig.queryFn, newConfig.queryFn) ||
          !identical(oldConfig.queryFnWithToken, newConfig.queryFnWithToken) ||
          oldConfig.dependsOn?.key != newConfig.dependsOn?.key ||
          !identical(oldConfig.options, newConfig.options)) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _generation++;
    _detachQueries();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(context, NamedQueryState(Map.unmodifiable(_states)));
  }
}

QueryState<T> _typedState<T>(QueryState<dynamic> state) {
  return QueryState<T>(
    status: state.status,
    data: state.data as T?,
    hasValue: state.hasValue,
    error: state.error,
    stackTrace: state.stackTrace,
    isFetching: state.isFetching,
    dataUpdatedAt: state.dataUpdatedAt,
    isStale: state.isStale,
  );
}
