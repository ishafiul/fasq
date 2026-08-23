import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

import 'use_query_client.dart';

/// Creates either an ordinary or a runtime-registered durable mutation.
UseMutationResult<TData, TVariables> useMutation<TData, TVariables>({
  Future<TData> Function(TVariables variables)? mutationFn,
  FasqMutationKey<TData, TVariables>? mutationKey,
  MutationOptions<TData, TVariables>? options,
  QueryClient? client,
  void Function(TData data)? onSuccess,
  void Function(Object error)? onError,
}) {
  assert(
    (mutationFn == null) != (mutationKey == null),
    'Provide exactly one of mutationFn or mutationKey.',
  );
  final queryClient = useQueryClient(client: client);
  final context = useContext();
  final runtime = FasqProvider.maybeOf(context);
  if (mutationKey != null && runtime == null) {
    throw StateError(
      'Mutation ${mutationKey.value} requires a FasqProvider runtime.',
    );
  }
  final successCallback = useRef<void Function(TData)?>(onSuccess);
  successCallback.value = onSuccess;
  final errorCallback = useRef<void Function(Object)?>(onError);
  errorCallback.value = onError;
  final effectiveOptions = useMemoized(
    () => _mergeCallbacks(
      options,
      (data) => successCallback.value?.call(data),
      (error) => errorCallback.value?.call(error),
    ),
    [options],
  );
  final mutationFunction =
      useRef<Future<TData> Function(TVariables variables)?>(mutationFn);
  mutationFunction.value = mutationFn;
  final stableMutationFunction = useMemoized(
    () => (TVariables variables) {
      final current = mutationFunction.value;
      if (current == null) {
        throw StateError('An ordinary mutation function is required.');
      }
      return current(variables);
    },
    const [],
  );
  final mutation = useMemoized(() {
    if (mutationKey != null) {
      final durableQueue = runtime?.mutationQueue;
      if (durableQueue == null) {
        throw StateError(
          'Mutation ${mutationKey.value} requires OfflineSync and a '
          'FasqProvider runtime.',
        );
      }
      return MutationFactory.fromKey<TData, TVariables>(
        key: mutationKey,
        catalog: runtime!.mutations,
        queue: durableQueue,
        options: effectiveOptions,
        client: queryClient,
      );
    }
    return MutationFactory.fromFunction<TData, TVariables>(
      mutationFn: stableMutationFunction,
      options: effectiveOptions,
      client: queryClient,
    );
  }, [queryClient, runtime, mutationKey?.runtimeKey, effectiveOptions]);
  final state = useState<MutationState<TData>>(mutation.state);

  useEffect(() {
    state.value = mutation.state;
    final subscription = mutation.stream.listen((nextState) {
      state.value = nextState;
    });
    return () {
      unawaited(subscription.cancel());
      mutation.dispose();
    };
  }, [mutation]);

  return UseMutationResult<TData, TVariables>(
    mutation: mutation,
    state: state.value,
  );
}

MutationOptions<TData, TVariables>? _mergeCallbacks<TData, TVariables>(
  MutationOptions<TData, TVariables>? options,
  void Function(TData data)? onSuccess,
  void Function(Object error)? onError,
) {
  if (onSuccess == null && onError == null) return options;
  return MutationOptions<TData, TVariables>(
    onSuccess: (data) {
      options?.onSuccess?.call(data);
      onSuccess?.call(data);
    },
    onError: (error) {
      options?.onError?.call(error);
      onError?.call(error);
    },
    onMutate: options?.onMutate,
    queueWhenOffline: options?.queueWhenOffline ?? false,
    durableQueue: options?.durableQueue,
    resultEncoder: options?.resultEncoder,
    projectionPlan: options?.projectionPlan,
    projectionBuilder: options?.projectionBuilder,
    maxRetries: options?.maxRetries,
    onQueued: options?.onQueued,
    priority: options?.priority ?? 0,
    meta: options?.meta,
  );
}

/// Reactive state and commands for one mutation.
class UseMutationResult<TData, TVariables> {
  /// Creates a mutation result.
  const UseMutationResult({required this.mutation, required this.state});

  /// Underlying core mutation.
  final Mutation<TData, TVariables> mutation;

  /// Current mutation state.
  final MutationState<TData> state;

  /// Submits the mutation and returns its durable outcome.
  Future<MutationSubmission<TData>> mutate(TVariables variables) {
    return mutation.submit(variables);
  }

  /// Alias for [mutate] matching the core mutation API.
  Future<MutationSubmission<TData>> submit(TVariables variables) {
    return mutation.submit(variables);
  }

  /// Resets the mutation to idle.
  void reset() => mutation.reset();

  /// Whether the mutation is currently loading.
  bool get isLoading => state.isLoading;

  /// Whether the mutation is queued for later replay.
  bool get isQueued => state.isQueued;

  /// Whether the mutation succeeded.
  bool get isSuccess => state.isSuccess;

  /// Whether the mutation failed.
  bool get isError => state.isError;

  /// Whether the mutation is idle.
  bool get isIdle => state.isIdle;

  /// Whether successful data exists.
  bool get hasData => state.hasData;

  /// Whether an error exists.
  bool get hasError => state.hasError;

  /// Latest result data.
  TData? get data => state.data;

  /// Latest error.
  Object? get error => state.error;

  /// Latest error stack trace.
  StackTrace? get stackTrace => state.stackTrace;
}
