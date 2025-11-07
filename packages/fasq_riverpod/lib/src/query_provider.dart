import 'package:fasq_riverpod/fasq_riverpod.dart';

/// Creates a Riverpod [StateNotifierProvider] that mirrors a FASQ [Query].
///
/// The provider keeps FASQ state in sync with Riverpod and exposes
/// [QueryNotifier] for imperative refetch/invalidations when needed.
StateNotifierProvider<QueryNotifier<T>, QueryState<T>> queryProvider<T>(
  QueryKey queryKey,
  Future<T> Function() queryFn, {
  QueryOptions? options,
}) {
  return StateNotifierProvider<QueryNotifier<T>, QueryState<T>>((ref) {
    return QueryNotifier<T>(
      queryKey: queryKey,
      queryFn: queryFn,
      options: options,
    );
  });
}
