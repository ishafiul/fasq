import 'package:fasq_riverpod/fasq_riverpod.dart';

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
