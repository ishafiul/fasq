import 'dart:async';

import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

InfiniteQueryState<TData, TParam> useInfiniteQuery<TData, TParam>(
  String key,
  Future<TData> Function(TParam param) queryFn, {
  InfiniteQueryOptions<TData, TParam>? options,
}) {
  final client = QueryClient();

  final state =
      useState<InfiniteQueryState<TData, TParam>>(InfiniteQueryState.idle());

  useEffect(() {
    final query =
        client.getInfiniteQuery<TData, TParam>(key, queryFn, options: options);

    query.addListener();

    final subscription = query.stream.listen((newState) {
      state.value = newState;
    });

    state.value = query.state;

    return () {
      subscription.cancel();
      query.removeListener();
    };
  }, [key]);

  return state.value;
}
