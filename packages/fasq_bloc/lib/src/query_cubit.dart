import 'dart:async';

import 'package:fasq_bloc/fasq_bloc.dart';

/// Base cubit that mirrors a FASQ [Query] lifecycle.
///
/// Subclasses provide the [queryKey] and [queryFn] (and optionally options or a
/// custom client). The cubit automatically listens to query updates and emits
/// the latest [QueryState].
abstract class QueryCubit<T> extends Cubit<QueryState<T>>
    with FasqSubscriptionMixin<QueryState<T>> {
  late Query<T> _query;
  late QueryKey _currentQueryKey;
  QueryOptions? _currentOptions;
  StreamSubscription<QueryState<T>>? _querySubscription;

  QueryCubit() : super(QueryState<T>.idle()) {
    _currentQueryKey = queryKey;
    _currentOptions = options;
    _initialize();
  }

  QueryKey get queryKey;

  Future<T> Function() get queryFn;

  QueryOptions? get options => null;

  QueryClient? get client => null;

  void _initialize() {
    final queryClient = client ?? QueryClient();
    _query =
        queryClient.getQuery<T>(queryKey, queryFn: queryFn, options: options);

    if (options?.enabled == false) {
      emit(QueryState<T>.idle());
    } else {
      emit(_query.state);
    }

    _querySubscription = subscribeToQuery<T>(
      _query,
      (newState) {
        if (!isClosed) {
          if (options?.enabled == false &&
              newState.status == QueryStatus.loading) {
            return;
          }
          emit(newState);
        }
      },
    );
  }

  void refetch() {
    _query.fetch();
  }

  void invalidate() {
    final queryClient = client ?? QueryClient();
    queryClient.invalidateQuery(queryKey);
  }

  /// Cancels any in-flight fetch operation for this query.
  ///
  /// This signals the query function to abort via [CancellationToken].
  /// The actual cancellation is cooperative - the query function must
  /// check [CancellationToken.isCancelled] to respond to cancellation requests.
  void cancel() {
    _query.cancel();
  }

  /// Manually updates the cached data for this query.
  ///
  /// This is useful for imperative cache updates or optimistic updates.
  /// The query state will be updated to reflect the new data.
  ///
  /// [data] - The new data to set in the cache for this query.
  void setData(T data) {
    final queryClient = client ?? QueryClient();
    queryClient.setQueryData<T>(_currentQueryKey, data);
  }

  /// Updates the query options dynamically at runtime.
  ///
  /// If the [newQueryKey] or [newOptions] differ from the current ones,
  /// the query will be swapped with a new instance. This ensures that
  /// all option changes are properly applied.
  ///
  /// [newQueryKey] - Optional new query key. If provided and different from
  ///   current, triggers a full query swap.
  /// [newOptions] - New query options to apply.
  void updateOptions({
    QueryKey? newQueryKey,
    QueryOptions? newOptions,
  }) {
    if (isClosed) return;

    final queryKeyChanged =
        newQueryKey != null && newQueryKey.key != _currentQueryKey.key;
    final optionsChanged = newOptions != _currentOptions;

    if (!queryKeyChanged && !optionsChanged) {
      return;
    }

    final queryClient = client ?? QueryClient();
    final effectiveQueryKey = newQueryKey ?? _currentQueryKey;
    final effectiveOptions = newOptions ?? _currentOptions;

    _query.removeListener();

    _currentQueryKey = effectiveQueryKey;
    _currentOptions = effectiveOptions;

    _query = queryClient.getQuery<T>(
      effectiveQueryKey,
      queryFn: queryFn,
      options: effectiveOptions,
    );

    if (effectiveOptions?.enabled == false) {
      emit(QueryState<T>.idle());
    } else {
      emit(_query.state);
    }

    unsubscribe(_querySubscription);

    _querySubscription = subscribeToQuery<T>(
      _query,
      (newState) {
        if (!isClosed) {
          if (effectiveOptions?.enabled == false &&
              newState.status == QueryStatus.loading) {
            return;
          }
          emit(newState);
        }
      },
    );
  }

  @override
  Future<void> close() {
    _query.removeListener();
    return super.close();
  }
}
