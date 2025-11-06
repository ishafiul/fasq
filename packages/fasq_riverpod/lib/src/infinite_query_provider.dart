import 'package:fasq_riverpod/fasq_riverpod.dart';

StateNotifierProvider<InfiniteQueryNotifier<TData, TParam>,
    InfiniteQueryState<TData, TParam>> infiniteQueryProvider<TData, TParam>(
  QueryKey queryKey,
  Future<TData> Function(TParam param) queryFn, {
  InfiniteQueryOptions<TData, TParam>? options,
}) {
  return StateNotifierProvider<InfiniteQueryNotifier<TData, TParam>,
      InfiniteQueryState<TData, TParam>>((ref) {
    return InfiniteQueryNotifier<TData, TParam>(
      queryKey: queryKey,
      queryFn: queryFn,
      options: options,
    );
  });
}
