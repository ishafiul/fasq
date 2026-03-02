import 'dart:async';

import 'package:fasq/src/client/query_client.dart';
import 'package:fasq/src/mutation/mutation.dart';
import 'package:fasq/src/mutation/mutation_options.dart';
import 'package:fasq/src/mutation/mutation_snapshot.dart';
import 'package:fasq/src/mutation/mutation_state.dart';
import 'package:flutter/widgets.dart';

/// A widget that builds UI from the state of a mutation.
class MutationBuilder<T, TVariables> extends StatefulWidget {
  /// Creates a [MutationBuilder].
  const MutationBuilder({
    required this.mutationFn,
    required this.builder,
    this.options,
    super.key,
  });

  /// Async mutation function invoked by the `mutate` callback.
  final Future<T> Function(TVariables variables) mutationFn;

  /// Builds UI from the current mutation `state` and `mutate` callback.
  final Widget Function(
    BuildContext context,
    MutationState<T> state,
    Future<void> Function(TVariables variables) mutate,
  ) builder;

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
  QueryClient? _client;

  @override
  void initState() {
    super.initState();
    _client = QueryClient.maybeInstance ?? QueryClient();
    _initializeMutation();
  }

  void _initializeMutation() {
    _mutation = Mutation<T, TVariables>(
      mutationFn: widget.mutationFn,
      options: widget.options,
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
      options: widget.options,
    );
    final meta = widget.options?.meta;

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
