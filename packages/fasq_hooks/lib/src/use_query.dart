import 'dart:async';

import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

QueryState<T> useQuery<T>(
  QueryKey queryKey,
  Future<T> Function() queryFn, {
  QueryOptions? options,
  QueryClient? client,
}) {
  final queryClient = client ?? QueryClient();

  final state = useState<QueryState<T>>(QueryState.idle());

  useEffect(() {
    final query = queryClient.getQuery<T>(queryKey, queryFn, options: options);

    query.addListener();

    final subscription = query.stream.listen((newState) {
      state.value = newState;
    });

    state.value = query.state;

    return () {
      subscription.cancel();
      query.removeListener();
    };
  }, [queryKey.key]);

  return state.value;
}
