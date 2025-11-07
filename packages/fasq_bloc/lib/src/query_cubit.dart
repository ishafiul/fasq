import 'dart:async';

import 'package:fasq_bloc/fasq_bloc.dart';

/// Base cubit that mirrors a FASQ [Query] lifecycle.
///
/// Subclasses provide the [queryKey] and [queryFn] (and optionally options or a
/// custom client). The cubit automatically listens to query updates and emits
/// the latest [QueryState].
abstract class QueryCubit<T> extends Cubit<QueryState<T>> {
  late final Query<T> _query;
  StreamSubscription<QueryState<T>>? _subscription;

  QueryCubit() : super(QueryState<T>.idle()) {
    _initialize();
  }

  QueryKey get queryKey;

  Future<T> Function() get queryFn;

  QueryOptions? get options => null;

  QueryClient? get client => null;

  void _initialize() {
    final queryClient = client ?? QueryClient();
    _query = queryClient.getQuery<T>(queryKey, queryFn, options: options);

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
    queryClient.invalidateQuery(queryKey);
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _query.removeListener();
    return super.close();
  }
}
