import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_query/flutter_query.dart';
import 'query_notifier.dart';

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

