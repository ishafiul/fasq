import 'dart:async';

import 'package:fasq_bloc/fasq_bloc.dart';

/// Base cubit that wraps a FASQ [Mutation].
///
/// Use [mutationFn] for an ordinary mutation or [mutationKey] with a
/// [runtime] for a generated durable mutation. The underlying core mutation
/// remains available through [mutation], so queueing, projections, retries,
/// auth, and other [MutationOptions] behavior are handled by FASQ itself.
abstract class MutationCubit<TData, TVariables>
    extends Cubit<MutationState<TData>> {
  MutationCubit({QueryClient? client, FasqRuntime? runtime})
    : _providedClient = client,
      _providedRuntime = runtime,
      super(const MutationState.idle()) {
    _initialize();
  }

  final QueryClient? _providedClient;
  final FasqRuntime? _providedRuntime;

  late final Mutation<TData, TVariables> _mutation;
  StreamSubscription<MutationState<TData>>? _subscription;
  QueryClient? _queryClient;

  /// Ordinary mutation function used when [mutationKey] is null.
  Future<TData> Function(TVariables variables)? get mutationFn => null;

  /// Typed durable mutation identity resolved from [runtime].
  FasqMutationKey<TData, TVariables>? get mutationKey => null;

  /// Optional behavior and callback configuration for the mutation.
  MutationOptions<TData, TVariables>? get options => null;

  /// Explicit client used by this cubit.
  QueryClient? get client => _providedClient ?? _providedRuntime?.queryClient;

  /// Runtime that supplies the durable mutation catalog and queue.
  FasqRuntime? get runtime => _providedRuntime;

  /// Gets the QueryClient instance used by the underlying mutation.
  QueryClient get queryClient => _resolvedClient;

  /// The underlying core mutation.
  Mutation<TData, TVariables> get mutation => _mutation;

  /// Variables passed to the most recent submission.
  TVariables? get lastVariables => _mutation.lastVariables;

  /// Whether the underlying core mutation has been disposed.
  bool get isDisposed => _mutation.isDisposed;

  /// Whether the mutation is currently loading.
  bool get isLoading => state.isLoading;

  /// Whether the mutation is durably queued.
  bool get isQueued => state.isQueued;

  /// Whether the mutation succeeded.
  bool get isSuccess => state.isSuccess;

  /// Whether the mutation failed.
  bool get isError => state.isError;

  /// Whether the mutation is idle.
  bool get isIdle => state.isIdle;

  /// Whether successful mutation data exists.
  bool get hasData => state.hasData;

  /// Whether the mutation has an error.
  bool get hasError => state.hasError;

  /// Latest mutation result data.
  TData? get data => state.data;

  /// Latest mutation error.
  Object? get error => state.error;

  /// Latest mutation error stack trace.
  StackTrace? get stackTrace => state.stackTrace;

  QueryClient get _resolvedClient {
    final existing = _queryClient;
    if (existing != null) return existing;
    final resolved = client ?? runtime?.queryClient ?? QueryClient();
    _queryClient = resolved;
    return resolved;
  }

  void _initialize() {
    final key = mutationKey;
    final function = mutationFn;
    if ((key == null) == (function == null)) {
      throw StateError(
        'MutationCubit requires exactly one of mutationFn or mutationKey.',
      );
    }
    final configuredRuntime = runtime;
    if (key != null) {
      if (configuredRuntime == null) {
        throw StateError('Mutation ${key.value} requires a FasqRuntime.');
      }
      final queue = configuredRuntime.mutationQueue;
      if (queue == null) {
        throw StateError(
          'Mutation ${key.value} requires a runtime with a durable queue.',
        );
      }
      _mutation = MutationFactory.fromKey<TData, TVariables>(
        key: key,
        catalog: configuredRuntime.mutations,
        queue: queue,
        options: options,
        client: _resolvedClient,
      );
    } else {
      _mutation = MutationFactory.fromFunction<TData, TVariables>(
        mutationFn: function!,
        options: options,
        client: _resolvedClient,
      );
    }

    _subscription = _mutation.stream.listen((newState) {
      if (!isClosed) {
        emit(newState);
      }
    });
  }

  /// Submits a mutation and runs Bloc-specific lifecycle callbacks.
  ///
  /// The returned receipt preserves the core outcome, including a durable
  /// [MutationSubmission.localReference] when work is queued.
  Future<MutationSubmission<TData>> mutate(
    TVariables variables, {
    FutureOr<dynamic> Function()? onMutate,
    FutureOr<void> Function(TData result)? onSuccess,
    FutureOr<void> Function(Object error, dynamic context)? onError,
    FutureOr<void> Function()? onSettled,
  }) async {
    if (isClosed) return MutationSubmission<TData>.failed();

    dynamic context;
    var submission = MutationSubmission<TData>.failed();
    var errorCallbackInvoked = false;

    try {
      if (onMutate != null) {
        context = await onMutate();
      }

      submission = await _mutation.submit(variables);
      if (isClosed) return submission;

      if (submission.isSucceeded && onSuccess != null) {
        await onSuccess(submission.data as TData);
      } else if (!submission.isSucceeded &&
          !submission.isQueued &&
          _mutation.state.error != null &&
          onError != null) {
        errorCallbackInvoked = true;
        await onError(_mutation.state.error!, context);
      }
    } on Object catch (error) {
      if (!isClosed && onError != null && !errorCallbackInvoked) {
        await onError(error, context);
      }
    } finally {
      if (!isClosed && onSettled != null) {
        await onSettled();
      }
    }

    return submission;
  }

  /// Submits a mutation without Bloc-specific callbacks.
  Future<MutationSubmission<TData>> submit(TVariables variables) {
    return mutate(variables);
  }

  /// Resets this mutation to its idle state.
  void reset() {
    if (!isClosed) {
      _mutation.reset();
    }
  }

  @override
  Future<void> close() {
    unawaited(_subscription?.cancel());
    _mutation.dispose();
    return super.close();
  }
}
