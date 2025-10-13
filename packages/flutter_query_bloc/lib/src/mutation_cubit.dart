import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_query/flutter_query.dart';

class MutationCubit<TData, TVariables> extends Cubit<MutationState<TData>> {
  late final Mutation<TData, TVariables> _mutation;
  StreamSubscription<MutationState<TData>>? _subscription;

  MutationCubit({
    required Future<TData> Function(TVariables variables) mutationFn,
    void Function(TData data)? onSuccessCallback,
    void Function(Object error)? onErrorCallback,
  }) : super(const MutationState.idle()) {
    _mutation = Mutation<TData, TVariables>(
      mutationFn: mutationFn,
      options: MutationOptions(
        onSuccess: onSuccessCallback,
        onError: onErrorCallback,
      ),
    );

    _subscription = _mutation.stream.listen((newState) {
      if (!isClosed) {
        emit(newState);
      }
    });
  }

  Future<void> mutate(TVariables variables) async {
    await _mutation.mutate(variables);
  }

  void reset() {
    _mutation.reset();
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    _mutation.dispose();
    return super.close();
  }
}

