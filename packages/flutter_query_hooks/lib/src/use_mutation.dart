import 'dart:async';

import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:flutter_query/flutter_query.dart';

UseMutationResult<TData, TVariables> useMutation<TData, TVariables>(
  Future<TData> Function(TVariables variables) mutationFn, {
  void Function(TData data)? onSuccess,
  void Function(Object error)? onError,
}) {
  final state = useState<MutationState<TData>>(const MutationState.idle());
  final mutation = useMemoized(
    () => Mutation<TData, TVariables>(
      mutationFn: mutationFn,
      options: MutationOptions(
        onSuccess: onSuccess,
        onError: onError,
      ),
    ),
  );

  useEffect(() {
    final subscription = mutation.stream.listen((newState) {
      state.value = newState;
    });

    state.value = mutation.state;

    return () {
      subscription.cancel();
      mutation.dispose();
    };
  }, [mutation]);

  return UseMutationResult(
    mutate: mutation.mutate,
    reset: mutation.reset,
    state: state.value,
  );
}

class UseMutationResult<TData, TVariables> {
  final Future<void> Function(TVariables) mutate;
  final void Function() reset;
  final MutationState<TData> state;

  const UseMutationResult({
    required this.mutate,
    required this.reset,
    required this.state,
  });

  bool get isLoading => state.isLoading;
  bool get hasData => state.hasData;
  bool get hasError => state.hasError;
  bool get isIdle => state.isIdle;
  bool get isSuccess => state.isSuccess;
  TData? get data => state.data;
  Object? get error => state.error;
}

