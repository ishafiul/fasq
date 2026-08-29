import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'query_notifier.dart';

/// Creates a Riverpod provider backed by a core [Query].
///
/// The positional function is retained for source compatibility. Provide an
/// explicit [client] or [runtime] for scoped applications; otherwise the
/// provider resolves [fasqClientProvider].
AutoDisposeAsyncNotifierProvider<QueryNotifier<T>, T> queryProvider<T>(
  QueryKey queryKey,
  Future<T> Function() queryFn, {
  QueryOptions? options,
  QueryKey? dependsOn,
  QueryClient? client,
  FasqRuntime? runtime,
}) {
  return AutoDisposeAsyncNotifierProvider<QueryNotifier<T>, T>(() {
    final notifier = QueryNotifier<T>();
    notifier.configure(
      queryKey: queryKey,
      queryFn: queryFn,
      options: options,
      dependsOn: dependsOn,
      client: client,
      runtime: runtime,
    );
    return notifier;
  });
}

/// Creates a query provider whose function receives a cancellation token.
AutoDisposeAsyncNotifierProvider<QueryNotifier<T>, T> queryProviderWithToken<T>(
  QueryKey queryKey,
  Future<T> Function(CancellationToken token) queryFnWithToken, {
  QueryOptions? options,
  QueryKey? dependsOn,
  QueryClient? client,
  FasqRuntime? runtime,
}) {
  return AutoDisposeAsyncNotifierProvider<QueryNotifier<T>, T>(() {
    final notifier = QueryNotifier<T>();
    notifier.configure(
      queryKey: queryKey,
      queryFnWithToken: queryFnWithToken,
      options: options,
      dependsOn: dependsOn,
      client: client,
      runtime: runtime,
    );
    return notifier;
  });
}
