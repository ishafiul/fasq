import 'dart:async';

import 'package:fasq_bloc/fasq_bloc.dart';

class QueryCubit<T> extends Cubit<QueryState<T>> {
  final String key;
  final Future<T> Function() queryFn;
  final QueryOptions? options;
  final QueryClient? client;

  late final Query<T> _query;
  StreamSubscription<QueryState<T>>? _subscription;

  QueryCubit({
    required this.key,
    required this.queryFn,
    this.options,
    this.client,
  }) : super(QueryState<T>.idle()) {
    _initialize();
  }

  void _initialize() {
    final queryClient = client ?? QueryClient();
    _query = queryClient.getQuery<T>(key, queryFn, options: options);

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
    final queryClient = client ?? QueryClient();
    queryClient.invalidateQuery(key);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _query.removeListener();
    return super.close();
  }
}
