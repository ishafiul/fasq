import 'dart:async';

import 'package:fasq_bloc/fasq_bloc.dart';

/// Base cubit that wraps a FASQ [Mutation].
///
/// Emits [MutationState] changes as the mutation runs and exposes helper
/// methods [mutate] and [reset] for subclasses.
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

  /// Gets the QueryClient instance for cache operations.
  ///
  /// Returns the client from [client] if provided, otherwise returns
  /// the singleton QueryClient instance. This method is useful for
  /// optimistic updates in lifecycle hooks.
  QueryClient get queryClient => client ?? QueryClient();

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

  Future<void> mutate(
    TVariables variables, {
    FutureOr<dynamic> Function()? onMutate,
    FutureOr<void> Function(TData result)? onSuccess,
    FutureOr<void> Function(Object error, dynamic context)? onError,
    FutureOr<void> Function()? onSettled,
  }) async {
    dynamic context;

    try {
      if (onMutate != null) {
        context = await onMutate();
      }

      await _mutation.mutate(variables);

      if (!isClosed) {
        if (_mutation.state.isSuccess && _mutation.state.data != null) {
          if (onSuccess != null) {
            await onSuccess(_mutation.state.data as TData);
          }
        } else if (_mutation.state.isError && _mutation.state.error != null) {
          if (onError != null) {
            await onError(_mutation.state.error!, context);
          }
        }
      }
    } catch (error) {
      if (!isClosed) {
        if (onError != null) {
          await onError(error, context);
        }
      }
    } finally {
      if (!isClosed && onSettled != null) {
        await onSettled();
      }
    }
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
