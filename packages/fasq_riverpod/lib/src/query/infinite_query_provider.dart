import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'infinite_query_notifier.dart';

/// Creates a Riverpod provider backed by a core [InfiniteQuery].
AutoDisposeAsyncNotifierProvider<
  InfiniteQueryNotifier<TData, TParam>,
  InfiniteQueryState<TData, TParam>
>
infiniteQueryProvider<TData, TParam>(
  QueryKey queryKey,
  Future<TData> Function(TParam param) queryFn, {
  InfiniteQueryOptions<TData, TParam>? options,
  QueryClient? client,
  FasqRuntime? runtime,
}) {
  return AutoDisposeAsyncNotifierProvider<
    InfiniteQueryNotifier<TData, TParam>,
    InfiniteQueryState<TData, TParam>
  >(() {
    final notifier = InfiniteQueryNotifier<TData, TParam>();
    notifier.configure(
      queryKey: queryKey,
      queryFn: queryFn,
      options: options,
      client: client,
      runtime: runtime,
    );
    return notifier;
  });
}
