import 'dart:async';

import 'package:fasq_bloc/fasq_bloc.dart';

abstract class QueryCubit<T> extends Cubit<QueryState<T>> {
  late final Query<T> _query;
  StreamSubscription<QueryState<T>>? _subscription;

  QueryCubit() : super(QueryState<T>.idle()) {
    _initialize();
  }

  String get key;

  Future<T> Function() get queryFn;

  QueryOptions? get options => null;

  QueryClient? get client => null;

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
