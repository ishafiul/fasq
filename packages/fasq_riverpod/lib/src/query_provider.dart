import 'package:fasq_riverpod/fasq_riverpod.dart';

StateNotifierProvider<QueryNotifier<T>, QueryState<T>> queryProvider<T>(
  String key,
  Future<T> Function() queryFn, {
  QueryOptions? options,
}) {
  return StateNotifierProvider<QueryNotifier<T>, QueryState<T>>((ref) {
    return QueryNotifier<T>(
      key: key,
      queryFn: queryFn,
      options: options,
    );
  });
}
