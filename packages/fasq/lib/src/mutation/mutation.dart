import 'dart:async';

import 'package:fasq/src/client/query_client.dart';
import 'package:fasq/src/mutation/durable_mutation_queue.dart';
import 'package:fasq/src/mutation/mutation_options.dart';
import 'package:fasq/src/mutation/mutation_snapshot.dart';
import 'package:fasq/src/mutation/mutation_state.dart';
import 'package:fasq/src/mutation/network_status.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';

/// Executes and tracks a mutation with optional offline queueing.
class Mutation<T, TVariables> {
  /// Creates a mutation executor for [mutationFn] with optional [options].
  Mutation({
    required this.mutationFn,
    this.options,
  }) {
    _controller = StreamController<MutationState<T>>.broadcast();
    options?.validateDurableConfiguration();
    final durableQueue = options?.durableQueue;
    if (durableQueue != null &&
        !durableQueue.queue.hasRegistration(durableQueue.mutationKey)) {
      durableQueue.queue.register<T, TVariables>(
        key: durableQueue.mutationKey,
        codec: durableQueue.codec,
        mutationFn: mutationFn,
        authPolicy: durableQueue.authPolicy,
        resultEncoder: options?.resultEncoder,
        dependencies: durableQueue.dependencies,
      );
    }
  }

  /// Function that performs the mutation work.
  final Future<T> Function(TVariables variables) mutationFn;

  /// Optional mutation behavior and callbacks.
  final MutationOptions<T, TVariables>? options;

  MutationState<T> _currentState = const MutationState.idle();
  late final StreamController<MutationState<T>> _controller;
  bool _isDisposed = false;
  TVariables? _lastVariables;

  /// Broadcast stream of mutation state updates.
  Stream<MutationState<T>> get stream => _controller.stream;

  /// Current mutation state snapshot.
  MutationState<T> get state => _currentState;

  /// Whether this mutation instance has been disposed.
  bool get isDisposed => _isDisposed;

  /// Runs the mutation with [variables].
  ///
  /// When offline queueing is enabled and the device is offline, the mutation
  /// is queued instead of executed immediately.
  Future<void> mutate(TVariables variables) async {
    await submit(variables);
  }

  /// Submits the mutation and returns its durable identity and outcome.
  ///
  /// Durable mutations always receive a Fasq-owned
  /// [MutationSubmission.localReference].
  /// Pass that opaque value through a dependent command's mapped input field;
  /// Fasq replaces it with the producer's remote result before execution.
  Future<MutationSubmission<T>> submit(TVariables variables) async {
    if (_isDisposed) return MutationSubmission<T>.failed();
    _lastVariables = variables;
    final durableOptions = options?.durableQueue;
    final isOffline =
        !(durableOptions?.queue.isOnline ?? NetworkStatus.instance.isOnline);
    final shouldQueue = isOffline && (options?.queueWhenOffline ?? false);
    final shouldWriteAhead = durableOptions?.writeAhead ?? false;
    if (shouldQueue || shouldWriteAhead) {
      if (durableOptions == null) {
        throw StateError('Durable mutation configuration is missing');
      }
      return _mutateDurably(
        variables,
        durableOptions,
        executeImmediately: shouldWriteAhead && !isOffline,
      );
    }
    return _executeImmediately(variables);
  }

  Future<MutationSubmission<T>> _mutateDurably(
    TVariables variables,
    DurableMutationQueueOptions<TVariables> durableOptions, {
    required bool executeImmediately,
  }) async {
    final client = QueryClient.maybeInstance;
    if (executeImmediately) _notifyLoading(client);
    try {
      final queue = durableOptions.queue;
      await queue.open();
      final acknowledgement = await queue.enqueue(
        key: durableOptions.mutationKey,
        variables: variables,
        authScope:
            durableOptions.authScope ??
            (durableOptions.authPolicy == AuthPolicy.required
                ? queue.currentAuthScope
                : null),
        conflictPolicy: durableOptions.conflictPolicy,
        conflictPrecondition: durableOptions.conflictPrecondition,
        priority: options?.priority ?? 0,
        maxAttempts: options?.maxRetries ?? 5,
        projections: _projectionDescriptors(),
      );
      await _enqueueProjection(queue, acknowledgement, variables);
      if (!executeImmediately) {
        _notifyQueued(variables);
        return MutationSubmission<T>.queued(
          localReference: acknowledgement.localReference,
        );
      }

      final replay = await queue.replay();
      if (replay.successfulResults.containsKey(acknowledgement.operationId)) {
        final data = _typedResult(
          replay.successfulResults[acknowledgement.operationId],
        );
        _notifySuccess(data, variables, client);
        return MutationSubmission<T>.succeeded(
          data: data,
          localReference: acknowledgement.localReference,
        );
      }
      if (replay.failedOperationIds.contains(acknowledgement.operationId)) {
        _notifyError(
          DurableMutationExecutionException(acknowledgement.operationId),
          StackTrace.current,
          client,
        );
        return MutationSubmission<T>.failed(
          localReference: acknowledgement.localReference,
        );
      }
      _notifyQueued(variables);
      return MutationSubmission<T>.queued(
        localReference: acknowledgement.localReference,
      );
    } on Object catch (error, stackTrace) {
      _notifyError(error, stackTrace, client);
      rethrow;
    }
  }

  List<MutationProjectionDescriptor> _projectionDescriptors() {
    final projectionPlan = options?.projectionPlan;
    if (projectionPlan == null) {
      return const <MutationProjectionDescriptor>[];
    }
    return <MutationProjectionDescriptor>[
      MutationProjectionDescriptor(
        id: projectionPlan.registryKey,
        queryKeys: projectionPlan.queryKeys,
      ),
    ];
  }

  Future<void> _enqueueProjection(
    DurableMutationQueue queue,
    DurableEnqueueAcknowledgement acknowledgement,
    TVariables variables,
  ) async {
    final projectionBuilder = options?.projectionBuilder;
    if (projectionBuilder == null) return;
    try {
      await queue.enqueueProjection(
        projectionBuilder(
          acknowledgement.operationId,
          acknowledgement.lineageId,
          variables,
        ),
      );
    } on Object {
      // Projection failures never change durable mutation outcome.
    }
  }

  T _typedResult(Object? value) {
    if (value is T) return value;
    throw const InvalidMutationResultException();
  }

  Future<MutationSubmission<T>> _executeImmediately(
    TVariables variables,
  ) async {
    final client = QueryClient.maybeInstance;
    _notifyLoading(client);
    try {
      final data = await mutationFn(variables);
      _notifySuccess(data, variables, client);
      return MutationSubmission<T>.succeeded(data: data);
    } on Object catch (error, stackTrace) {
      _notifyError(error, stackTrace, client);
      return MutationSubmission<T>.failed();
    }
  }

  void _notifyLoading(QueryClient? client) {
    final previous = _currentState;
    _updateState(const MutationState.loading());
    if (client != null) {
      client.notifyMutationLoading(_snapshot(previous), options?.meta, null);
    }
  }

  void _notifySuccess(T data, TVariables variables, QueryClient? client) {
    if (_isDisposed) return;
    final previous = _currentState;
    _updateState(MutationState.success(data));
    options?.onMutate?.call(data, variables);
    options?.onSuccess?.call(data);
    if (client != null) {
      final snapshot = _snapshot(previous);
      client
        ..notifyMutationSuccess(snapshot, options?.meta, null)
        ..notifyMutationSettled(snapshot, options?.meta, null);
    }
  }

  void _notifyQueued(TVariables variables) {
    if (_isDisposed) return;
    _updateState(const MutationState.queued());
    options?.onQueued?.call(variables);
  }

  void _notifyError(
    Object error,
    StackTrace stackTrace,
    QueryClient? client,
  ) {
    if (_isDisposed) return;
    final previous = _currentState;
    _updateState(MutationState.error(error, stackTrace));
    options?.onError?.call(error);
    if (client != null) {
      final snapshot = _snapshot(previous);
      client
        ..notifyMutationError(snapshot, options?.meta, null)
        ..notifyMutationSettled(snapshot, options?.meta, null);
    }
  }

  /// Resets this mutation to the idle state.
  void reset() {
    if (_isDisposed) return;
    _lastVariables = null;
    _updateState(const MutationState.idle());
  }

  void _updateState(MutationState<T> newState) {
    _currentState = newState;
    if (!_controller.isClosed) {
      _controller.add(newState);
    }
  }

  MutationSnapshot<T, TVariables> _snapshot(
    MutationState<T> previousState,
  ) {
    return MutationSnapshot<T, TVariables>(
      previousState: previousState,
      currentState: _currentState,
      variables: _lastVariables,
      options: options,
    );
  }

  /// Variables passed to the most recent [mutate] call.
  TVariables? get lastVariables => _lastVariables;

  /// Disposes this mutation and closes its state stream.
  void dispose() {
    if (_isDisposed) return;

    _isDisposed = true;
    unawaited(_controller.close());
  }
}

/// Outcome returned by [Mutation.submit].
class MutationSubmission<T> {
  const MutationSubmission._({
    required this.status,
    this.data,
    this.localReference,
  });

  /// Creates a successful submission.
  const MutationSubmission.succeeded({required T data, String? localReference})
    : this._(
        status: MutationSubmissionStatus.succeeded,
        data: data,
        localReference: localReference,
      );

  /// Creates a durably queued submission.
  const MutationSubmission.queued({required String localReference})
    : this._(
        status: MutationSubmissionStatus.queued,
        localReference: localReference,
      );

  /// Creates a failed submission.
  const MutationSubmission.failed({String? localReference})
    : this._(
        status: MutationSubmissionStatus.failed,
        localReference: localReference,
      );

  /// Submission lifecycle outcome.
  final MutationSubmissionStatus status;

  /// Successful result when execution completed in this process.
  final T? data;

  /// Opaque Fasq-owned identity accepted by mapped dependent inputs.
  final String? localReference;

  /// Whether execution completed successfully.
  bool get isSucceeded => status == MutationSubmissionStatus.succeeded;

  /// Whether durable work remains queued.
  bool get isQueued => status == MutationSubmissionStatus.queued;
}

/// Immediate outcome of a mutation submission.
enum MutationSubmissionStatus {
  /// Execution succeeded.
  succeeded,

  /// Work is durably retained for replay.
  queued,

  /// Execution failed.
  failed,
}

/// Raised when write-ahead replay executes but cannot complete its operation.
class DurableMutationExecutionException implements Exception {
  /// Creates a write-ahead execution failure.
  const DurableMutationExecutionException(this.operationId);

  /// Durable operation that failed.
  final OperationId operationId;

  @override
  String toString() =>
      'Durable mutation execution failed: ${operationId.value}';
}
