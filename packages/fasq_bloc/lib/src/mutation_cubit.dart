import 'dart:async';

import 'package:fasq_bloc/fasq_bloc.dart';

abstract class MutationCubit<TData, TVariables>
    extends Cubit<MutationState<TData>> {
  late final Mutation<TData, TVariables> _mutation;
  StreamSubscription<MutationState<TData>>? _subscription;

  MutationCubit() : super(const MutationState.idle()) {
    _initialize();
  }

  Future<TData> Function(TVariables variables) get mutationFn;

  MutationOptions<TData, TVariables>? get options => null;

  QueryClient? get client => null;

  void _initialize() {
    _mutation = Mutation<TData, TVariables>(
      mutationFn: mutationFn,
      options: options,
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
