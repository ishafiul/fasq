import 'dart:async';

import 'package:fasq_riverpod/fasq_riverpod.dart';

class QueryNotifier<T> extends StateNotifier<QueryState<T>> {
  final String key;
  final Future<T> Function() queryFn;
  final QueryOptions? options;

  late final Query<T> _query;
  StreamSubscription<QueryState<T>>? _subscription;

  QueryNotifier({
    required this.key,
    required this.queryFn,
    this.options,
  }) : super(QueryState<T>.idle()) {
    _initialize();
  }

  void _initialize() {
    final client = QueryClient();
    _query = client.getQuery<T>(key, queryFn, options: options);

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
    QueryClient().invalidateQuery(key);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _query.removeListener();
    super.dispose();
  }
}
