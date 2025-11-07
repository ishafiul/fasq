import 'dart:async';

import 'package:fasq_riverpod/fasq_riverpod.dart';

/// Bridges a FASQ [Query] to Riverpod's [StateNotifier] API.
///
/// Listens to query updates, exposes the current [QueryState], and supports
/// imperative refetch/invalidations from consumers.
class QueryNotifier<T> extends StateNotifier<QueryState<T>> {
  final QueryKey queryKey;
  final Future<T> Function() queryFn;
  final QueryOptions? options;
  final QueryClient? client;

  late final Query<T> _query;
  StreamSubscription<QueryState<T>>? _subscription;

  QueryNotifier({
    required this.queryKey,
    required this.queryFn,
    this.options,
    this.client,
  }) : super(QueryState<T>.idle()) {
    _initialize();
  }

  void _initialize() {
    final queryClient = client ?? QueryClient();
    _query = queryClient.getQuery<T>(queryKey, queryFn, options: options);

    _subscription = _query.stream.listen((newState) {
      if (mounted) {
        state = newState;
      }
    });

    state = _query.state;
  }

  void refetch() {
    _query.fetch();
  }

  void invalidate() {
    final queryClient = client ?? QueryClient();
    queryClient.invalidateQuery(queryKey);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _query.removeListener();
    super.dispose();
  }
}
