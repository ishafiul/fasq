import 'dart:async';

import 'package:fasq/src/client/query_client.dart';
import 'package:fasq/src/mutation/durable_mutation_definition.dart';
import 'package:fasq/src/mutation/durable_mutation_queue.dart';
import 'package:fasq/src/mutation/mutation.dart';
import 'package:fasq/src/mutation/mutation_contract.dart';
import 'package:fasq/src/mutation/mutation_options.dart';
import 'package:fasq/src/mutation/mutation_snapshot.dart';
import 'package:fasq/src/mutation/mutation_state.dart';
import 'package:fasq/src/widgets/fasq_provider.dart';
import 'package:fasq/src/widgets/query_client_provider.dart';
import 'package:flutter/widgets.dart';

/// A widget that builds UI from the state of a mutation.
class MutationBuilder<T, TVariables> extends StatefulWidget {
  /// Creates a [MutationBuilder].
  const MutationBuilder({
    required this.builder,
    this.mutationFn,
    this.mutationKey,
    this.options,
    super.key,
  }) : assert(
         (mutationFn == null) != (mutationKey == null),
         'Provide exactly one of mutationFn or mutationKey.',
       );

  /// Async mutation function invoked by the `mutate` callback.
  final Future<T> Function(TVariables variables)? mutationFn;

  /// Typed durable mutation key resolved from the nearest [FasqProvider].
  ///
  /// The key's generic arguments must match this builder's result and
  /// variables. Its executor and queue are registered during bootstrap.
  final FasqMutationKey<T, TVariables>? mutationKey;

  /// Builds UI from the current mutation `state` and `mutate` callback.
  final Widget Function(
    BuildContext context,
    MutationState<T> state,
    Future<MutationSubmission<T>> Function(TVariables variables) mutate,
  )
  builder;

  /// Optional behavior and callback configuration for the mutation.
  final MutationOptions<T, TVariables>? options;

  @override
  State<MutationBuilder<T, TVariables>> createState() =>
      _MutationBuilderState<T, TVariables>();
}

class _MutationBuilderState<T, TVariables>
    extends State<MutationBuilder<T, TVariables>> {
  late Mutation<T, TVariables> _mutation;
  StreamSubscription<MutationState<T>>? _subscription;
  late MutationState<T> _state;
  MutationOptions<T, TVariables>? _effectiveOptions;
  QueryClient? _client;
  DurableMutationQueue? _durableQueue;
  DurableMutationDefinition<T, TVariables>? _durableDefinition;
  var _ownsClient = false;
  var _initialized = false;

  @override
  void initState() {
    super.initState();
    _client = QueryClient.maybeInstance;
  }

  @override
  void didUpdateWidget(MutationBuilder<T, TVariables> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_initialized ||
        identical(oldWidget.mutationFn, widget.mutationFn) &&
            oldWidget.mutationKey?.runtimeKey ==
                widget.mutationKey?.runtimeKey &&
            identical(oldWidget.options, widget.options)) {
      return;
    }
    final durable = _resolveDurableDefinition();
    _replaceMutation(durable.queue, durable.definition);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final providedClient = context.queryClient;
    if (providedClient != null) {
      if (!identical(providedClient, _client)) {
        _disposeOwnedClient();
        _client = providedClient;
      }
      _ownsClient = false;
    } else if (_client == null) {
      _client = QueryClient();
      _ownsClient = true;
    }
    final durable = _resolveDurableDefinition();
    final durableQueue = durable.queue;
    final durableDefinition = durable.definition;
    if (!_initialized) {
      _initializeMutation(durableQueue, durableDefinition);
      _initialized = true;
      return;
    }

    if (!identical(durableQueue, _durableQueue) ||
        !identical(durableDefinition, _durableDefinition)) {
      _replaceMutation(durableQueue, durableDefinition);
    }
  }

  ({
    DurableMutationQueue? queue,
    DurableMutationDefinition<T, TVariables>? definition,
  })
  _resolveDurableDefinition() {
    final mutationKey = widget.mutationKey;
    if (mutationKey == null) {
      return (queue: null, definition: null);
    }
    final runtime = FasqProvider.of(context);
    final queue = runtime.mutationQueue;
    if (queue == null) {
      throw FlutterError(
        'Mutation ${mutationKey.value} requires OfflineSync. Register it '
        'during bootstrap and provide that runtime through FasqProvider.',
      );
    }
    return (
      queue: queue,
      definition: runtime.mutations.resolve(mutationKey),
    );
  }

  void _initializeMutation(
    DurableMutationQueue? durableQueue,
    DurableMutationDefinition<T, TVariables>? durableDefinition,
  ) {
    final mutationFn = durableDefinition?.execute ?? widget.mutationFn;
    if (mutationFn == null) {
      throw StateError(
        'MutationBuilder requires a mutation function or handle',
      );
    }
    _durableQueue = durableQueue;
    _durableDefinition = durableDefinition;
    _effectiveOptions = durableDefinition == null
        ? widget.options
        : durableDefinition.bind(durableQueue!, base: widget.options);
    _mutation = Mutation<T, TVariables>(
      mutationFn: mutationFn,
      options: _effectiveOptions,
      client: _client,
    );
    _state = _mutation.state;

    _subscription = _mutation.stream.listen((state) {
      if (mounted) {
        final previous = _state;
        _state = state;
        _emitContextNotifications(previous, state);
        setState(() {});
      }
    });
  }

  void _replaceMutation(
    DurableMutationQueue? durableQueue,
    DurableMutationDefinition<T, TVariables>? durableDefinition,
  ) {
    unawaited(_subscription?.cancel());
    _mutation.dispose();
    _initializeMutation(durableQueue, durableDefinition);
  }

  void _disposeOwnedClient() {
    if (!_ownsClient) return;
    final client = _client;
    _ownsClient = false;
    _client = null;
    if (client != null) {
      unawaited(client.dispose());
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _mutation.dispose();
    _disposeOwnedClient();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _state,
      _mutation.submit,
    );
  }

  void _emitContextNotifications(
    MutationState<T> previous,
    MutationState<T> current,
  ) {
    final client = _client;
    if (client == null || !mounted) {
      return;
    }

    final effectiveContext = mounted ? context : null;
    if (effectiveContext == null) {
      return;
    }

    final snapshot = MutationSnapshot<T, TVariables>(
      previousState: previous,
      currentState: current,
      variables: _mutation.lastVariables,
      options: _effectiveOptions,
    );
    final meta = _effectiveOptions?.meta;

    if (!previous.isLoading && current.isLoading) {
      client.notifyMutationLoading(snapshot, meta, effectiveContext);
    }

    if (!previous.isSuccess && current.isSuccess) {
      client
        ..notifyMutationSuccess(snapshot, meta, effectiveContext)
        ..notifyMutationSettled(snapshot, meta, effectiveContext);
    }

    if (!previous.isError && current.isError) {
      client
        ..notifyMutationError(snapshot, meta, effectiveContext)
        ..notifyMutationSettled(snapshot, meta, effectiveContext);
    }
  }
}
