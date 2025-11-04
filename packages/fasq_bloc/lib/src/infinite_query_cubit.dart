import 'dart:async';

import 'package:fasq_bloc/fasq_bloc.dart';

abstract class InfiniteQueryCubit<TData, TParam>
    extends Cubit<InfiniteQueryState<TData, TParam>> {
  late final InfiniteQuery<TData, TParam> _query;
  StreamSubscription<InfiniteQueryState<TData, TParam>>? _subscription;

  InfiniteQueryCubit() : super(InfiniteQueryState<TData, TParam>.idle()) {
    _initialize();
  }

  String get key;

  Future<TData> Function(TParam param) get queryFn;

  InfiniteQueryOptions<TData, TParam>? get options => null;

  void _initialize() {
    final client = QueryClient();
    _query =
        client.getInfiniteQuery<TData, TParam>(key, queryFn, options: options);

    _subscription = _query.stream.listen((newState) {
      if (!isClosed) {
        emit(newState);
      }
    });

    emit(_query.state);
  }

  Future<void> fetchNextPage([TParam? param]) => _query.fetchNextPage(param);

  Future<void> fetchPreviousPage() => _query.fetchPreviousPage();

  Future<void> refetchPage(int index) => _query.refetchPage(index);

  void reset() => _query.reset();

  @override
  Future<void> close() {
    _subscription?.cancel();
    _query.removeListener();
    return super.close();
  }
}
