import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/client_provider.dart';
import 'combined_query_provider.dart';

/// Configuration for one query in [queriesProvider].
class QueryConfig<T> {
  /// Creates a query configuration.
  const QueryConfig(
    this.queryKey,
    this.queryFn, {
    this.queryFnWithToken,
    this.options,
    this.dependsOn,
  });

  /// Stable query identity.
  final QueryKey queryKey;

  /// Ordinary query function.
  final Future<T> Function()? queryFn;

  /// Cancellation-aware query function.
  final Future<T> Function(CancellationToken token)? queryFnWithToken;

  /// Query behavior options.
  final QueryOptions? options;

  /// Parent query used for cascading cancellation.
  final QueryKey? dependsOn;
}

/// Configuration for one named query in [namedQueriesProvider].
class NamedQueryConfig<T> {
  /// Creates a named query configuration.
  const NamedQueryConfig({
    required this.name,
    required this.queryKey,
    this.queryFn,
    this.queryFnWithToken,
    this.options,
    this.dependsOn,
  });

  /// Stable name used to retrieve the combined state.
  final String name;

  /// Stable query identity.
  final QueryKey queryKey;

  /// Ordinary query function.
  final Future<T> Function()? queryFn;

  /// Cancellation-aware query function.
  final Future<T> Function(CancellationToken token)? queryFnWithToken;

  /// Query behavior options.
  final QueryOptions? options;

  /// Parent query used for cascading cancellation.
  final QueryKey? dependsOn;
}

/// Notifier that owns a set of reference-counted core queries.
class QueriesNotifier extends AutoDisposeNotifier<CombinedQueriesState> {
  List<QueryConfig<dynamic>> _configs = const [];
  QueryClient? _providedClient;
  FasqRuntime? _providedRuntime;

  final _queries = <Query<dynamic>>[];
  final _subscriptions = <StreamSubscription<QueryState<dynamic>>>[];
  final _attached = <bool>[];
  QueryClient? _client;
  var _cleanedUp = false;

  /// Initializes the query set.
  void configure({
    required List<QueryConfig<dynamic>> configs,
    QueryClient? client,
    FasqRuntime? runtime,
  }) {
    _configs = List.unmodifiable(configs);
    _providedClient = client;
    _providedRuntime = runtime;
  }

  /// Client owning all queries in the set.
  QueryClient get queryClient {
    final existing = _client;
    if (existing != null) return existing;
    final resolved =
        _providedClient ??
        _providedRuntime?.queryClient ??
        ref.read(fasqClientProvider);
    _client = resolved;
    return resolved!;
  }

  /// The underlying core queries in input order.
  List<Query<dynamic>> get queries => List.unmodifiable(_queries);

  /// Re-fetches every query in the set.
  Future<void> refetch({bool forceRefetch = true}) async {
    await Future.wait(
      _queries.map(
        (query) => query.fetch(forceRefetch: forceRefetch).catchError((_) {}),
      ),
    );
  }

  @override
  CombinedQueriesState build() {
    _cleanup();
    _cleanedUp = false;
    final keepAlive = ref.keepAlive();
    ref.onCancel(keepAlive.close);
    final configuredRuntime =
        _providedRuntime ?? ref.watch(fasqRuntimeProvider);
    _client =
        _providedClient ??
        configuredRuntime?.queryClient ??
        ref.watch(fasqClientProvider);

    if (_configs.any(
      (config) => config.queryFn == null && config.queryFnWithToken == null,
    )) {
      throw StateError(
        'Every QueryConfig requires queryFn or queryFnWithToken.',
      );
    }

    for (final config in _configs) {
      final query = _client!.reconfigureQuery<dynamic>(
        config.queryKey,
        queryFn: config.queryFn,
        queryFnWithToken: config.queryFnWithToken,
        options: config.options,
        dependsOn: config.dependsOn,
      );
      _queries.add(query);
      _attached.add(false);
      _subscriptions.add(
        query.stream.listen((nextState) {
          if (!_cleanedUp) state = _stateFromQueries();
        }),
      );
    }

    for (var index = 0; index < _queries.length; index++) {
      _queries[index].addListener();
      _attached[index] = true;
    }
    final initial = _stateFromQueries();
    ref.onDispose(_cleanup);
    for (final query in _queries) {
      unawaited(_refreshIfNeeded(query));
    }
    return initial;
  }

  CombinedQueriesState _stateFromQueries() {
    return CombinedQueriesState(
      _queries.map((query) => _queryStateToAsyncValue(query.state)),
    );
  }

  void _cleanup() {
    if (_cleanedUp) return;
    _cleanedUp = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    for (var index = 0; index < _queries.length; index++) {
      if (_attached[index]) _queries[index].removeListener();
    }
    _queries.clear();
    _attached.clear();
  }
}

/// Notifier that owns named reference-counted core queries.
class NamedQueriesNotifier extends AutoDisposeNotifier<NamedQueriesState> {
  List<NamedQueryConfig<dynamic>> _configs = const [];
  QueryClient? _providedClient;
  FasqRuntime? _providedRuntime;

  final _queries = <String, Query<dynamic>>{};
  final _subscriptions = <StreamSubscription<QueryState<dynamic>>>[];
  final _attached = <String, bool>{};
  QueryClient? _client;
  var _cleanedUp = false;

  /// Initializes the named query set.
  void configure({
    required List<NamedQueryConfig<dynamic>> configs,
    QueryClient? client,
    FasqRuntime? runtime,
  }) {
    _configs = List.unmodifiable(configs);
    _providedClient = client;
    _providedRuntime = runtime;
  }

  /// Client owning all named queries.
  QueryClient get queryClient {
    final existing = _client;
    if (existing != null) return existing;
    final resolved =
        _providedClient ??
        _providedRuntime?.queryClient ??
        ref.read(fasqClientProvider);
    _client = resolved;
    return resolved!;
  }

  /// The underlying core queries keyed by configured name.
  Map<String, Query<dynamic>> get queries => Map.unmodifiable(_queries);

  /// Re-fetches every named query in the set.
  Future<void> refetch({bool forceRefetch = true}) async {
    await Future.wait(
      _queries.values.map(
        (query) => query.fetch(forceRefetch: forceRefetch).catchError((_) {}),
      ),
    );
  }

  @override
  NamedQueriesState build() {
    _cleanup();
    _cleanedUp = false;
    final keepAlive = ref.keepAlive();
    ref.onCancel(keepAlive.close);
    final configuredRuntime =
        _providedRuntime ?? ref.watch(fasqRuntimeProvider);
    _client =
        _providedClient ??
        configuredRuntime?.queryClient ??
        ref.watch(fasqClientProvider);

    final names = <String>{};
    for (final config in _configs) {
      if (!names.add(config.name)) {
        throw ArgumentError.value(
          config.name,
          'configs',
          'Named query names must be unique.',
        );
      }
      if (config.queryFn == null && config.queryFnWithToken == null) {
        throw StateError(
          'Every NamedQueryConfig requires queryFn or queryFnWithToken.',
        );
      }
      final query = _client!.reconfigureQuery<dynamic>(
        config.queryKey,
        queryFn: config.queryFn,
        queryFnWithToken: config.queryFnWithToken,
        options: config.options,
        dependsOn: config.dependsOn,
      );
      _queries[config.name] = query;
      _attached[config.name] = false;
      _subscriptions.add(
        query.stream.listen((nextState) {
          if (!_cleanedUp) state = _stateFromQueries();
        }),
      );
    }

    for (final entry in _queries.entries) {
      entry.value.addListener();
      _attached[entry.key] = true;
    }
    final initial = _stateFromQueries();
    ref.onDispose(_cleanup);
    for (final query in _queries.values) {
      unawaited(_refreshIfNeeded(query));
    }
    return initial;
  }

  NamedQueriesState _stateFromQueries() {
    return NamedQueriesState({
      for (final entry in _queries.entries)
        entry.key: _queryStateToAsyncValue(entry.value.state),
    });
  }

  void _cleanup() {
    if (_cleanedUp) return;
    _cleanedUp = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    for (final entry in _queries.entries) {
      if (_attached[entry.key] ?? false) entry.value.removeListener();
    }
    _queries.clear();
    _attached.clear();
  }
}

/// Creates a Riverpod provider that executes several FASQ queries in parallel.
AutoDisposeNotifierProvider<QueriesNotifier, CombinedQueriesState>
queriesProvider(
  List<QueryConfig<dynamic>> configs, {
  QueryClient? client,
  FasqRuntime? runtime,
}) {
  return AutoDisposeNotifierProvider<QueriesNotifier, CombinedQueriesState>(() {
    final notifier = QueriesNotifier();
    notifier.configure(configs: configs, client: client, runtime: runtime);
    return notifier;
  });
}

/// Creates a Riverpod provider that executes several named queries in parallel.
AutoDisposeNotifierProvider<NamedQueriesNotifier, NamedQueriesState>
namedQueriesProvider(
  List<NamedQueryConfig<dynamic>> configs, {
  QueryClient? client,
  FasqRuntime? runtime,
}) {
  return AutoDisposeNotifierProvider<NamedQueriesNotifier, NamedQueriesState>(
    () {
      final notifier = NamedQueriesNotifier();
      notifier.configure(configs: configs, client: client, runtime: runtime);
      return notifier;
    },
  );
}

AsyncValue<dynamic> _queryStateToAsyncValue(QueryState<dynamic> queryState) {
  if (queryState.hasError) {
    final errorState = AsyncError<dynamic>(
      queryState.error!,
      queryState.stackTrace ?? StackTrace.current,
    );
    if (queryState.hasData) {
      return errorState.copyWithPrevious(AsyncData<dynamic>(queryState.data));
    }
    return errorState;
  }
  if (queryState.hasData) {
    final dataState = AsyncData<dynamic>(queryState.data);
    if (queryState.isFetching) {
      return AsyncLoading<dynamic>().copyWithPrevious(dataState);
    }
    return dataState;
  }
  return const AsyncLoading<Never>();
}

Future<void> _refreshIfNeeded(Query<dynamic> query) async {
  final queryState = query.state;
  if (!queryState.hasData) return;
  final forceRefetch = query.options?.refetchOnMount == true;
  if (!forceRefetch && !queryState.isStale) return;
  try {
    await query.fetch(forceRefetch: forceRefetch);
  } on Object {
    // The core query has already emitted its error state.
  }
}
