import 'package:fasq_bloc/fasq_bloc.dart';

/// Base cubit that manages a paginated FASQ [InfiniteQuery].
///
/// Subclasses declare pagination parameters and can call helper methods like
/// [fetchNextPage] to drive loading from the UI.
abstract class InfiniteQueryCubit<TData, TParam>
    extends Cubit<InfiniteQueryState<TData, TParam>>
    with FasqSubscriptionMixin<InfiniteQueryState<TData, TParam>> {
  late final InfiniteQuery<TData, TParam> _query;

  InfiniteQueryCubit() : super(InfiniteQueryState<TData, TParam>.idle()) {
    _initialize();
  }

  QueryKey get queryKey;

  Future<TData> Function(TParam param) get queryFn;

  InfiniteQueryOptions<TData, TParam>? get options => null;

  void _initialize() {
    final client = QueryClient();
    _query = client.getInfiniteQuery<TData, TParam>(queryKey, queryFn,
        options: options);

    emit(_query.state);

    subscribeToInfiniteQuery<TData, TParam>(
      _query,
      (newState) {
        if (!isClosed) {
          emit(newState);
        }
      },
    );
  }

  Future<void> fetchNextPage([TParam? param]) => _query.fetchNextPage(param);

  Future<void> fetchPreviousPage() => _query.fetchPreviousPage();

  Future<void> refetchPage(int index) => _query.refetchPage(index);

  void reset() => _query.reset();

  @override
  Future<void> close() {
    _query.removeListener();
    return super.close();
  }
}
