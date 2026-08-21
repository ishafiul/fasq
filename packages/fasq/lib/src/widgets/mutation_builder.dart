import 'dart:async';

import 'package:fasq/src/client/query_client.dart';
import 'package:fasq/src/mutation/durable_mutation.dart';
import 'package:fasq/src/mutation/mutation.dart';
import 'package:fasq/src/mutation/mutation_options.dart';
import 'package:fasq/src/mutation/mutation_snapshot.dart';
import 'package:fasq/src/mutation/mutation_state.dart';
import 'package:fasq/src/widgets/durable_mutation_scope.dart';
import 'package:flutter/widgets.dart';

/// A widget that builds UI from the state of a mutation.
class MutationBuilder<T, TVariables> extends StatefulWidget {
  /// Creates a [MutationBuilder].
  const MutationBuilder({
    this.mutationFn,
    this.mutation,
    required this.builder,
    this.options,
    super.key,
  }) : assert(
         (mutationFn == null) != (mutation == null),
         'Provide exactly one of mutationFn or mutation.',
       );

  /// Async mutation function invoked by the `mutate` callback.
  final Future<T> Function(TVariables variables)? mutationFn;

  /// Durable mutation handle bound to the nearest [DurableMutationScope].
  ///
  /// Use this for mutations that must survive an offline restart. The legacy
  /// [mutationFn] form remains the simplest option for online-only work.
  final DurableMutation<T, TVariables>? mutation;

  /// Builds UI from the current mutation `state` and `mutate` callback.
  final Widget Function(
    BuildContext context,
    MutationState<T> state,
    Future<void> Function(TVariables variables) mutate,
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
  var _initialized = false;

  @override
  void initState() {
    super.initState();
    _client = QueryClient.maybeInstance ?? QueryClient();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) {
      return;
    }
    _initializeMutation();
    _initialized = true;
  }

  void _initializeMutation() {
    final durableMutation = widget.mutation;
    final mutationFn = durableMutation?.execute ?? widget.mutationFn;
    if (mutationFn == null) {
      throw StateError(
        'MutationBuilder requires a mutation function or handle',
      );
    }
    _effectiveOptions = durableMutation == null
        ? widget.options
        : durableMutation.bind(
            DurableMutationScope.of(context),
            base: widget.options,
          );
    _mutation = Mutation<T, TVariables>(
      mutationFn: mutationFn,
      options: _effectiveOptions,
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

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _mutation.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.builder(
      context,
      _state,
      _mutation.mutate,
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
