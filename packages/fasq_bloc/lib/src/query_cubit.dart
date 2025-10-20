import 'dart:async';

import 'package:fasq_bloc/fasq_bloc.dart';

class QueryCubit<T> extends Cubit<QueryState<T>> {
  final String key;
  final Future<T> Function() queryFn;
  final QueryOptions? options;

  late final Query<T> _query;
  StreamSubscription<QueryState<T>>? _subscription;

  QueryCubit({
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
      if (!isClosed) {
        emit(newState);
      }
    });

    emit(_query.state);
  }

  void refetch() {
    _query.fetch();
  }

  void invalidate() {
    QueryClient().invalidateQuery(key);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _query.removeListener();
    return super.close();
  }
}
