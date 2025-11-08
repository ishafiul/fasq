import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/mutation.dart';
import '../core/mutation_options.dart';
import '../core/mutation_snapshot.dart';
import '../core/mutation_state.dart';
import '../core/query_client.dart';

class MutationBuilder<T, TVariables> extends StatefulWidget {
  final Future<T> Function(TVariables variables) mutationFn;
  final Widget Function(
    BuildContext context,
    MutationState<T> state,
    Future<void> Function(TVariables variables) mutate,
  ) builder;
  final MutationOptions<T, TVariables>? options;

  const MutationBuilder({
    required this.mutationFn,
    required this.builder,
    this.options,
    super.key,
  });

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
    _subscription?.cancel();
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

    final snapshot = MutationSnapshot<T, TVariables>(
      previousState: previous,
      currentState: current,
      variables: _mutation.lastVariables,
      options: widget.options,
    );
    final meta = widget.options?.meta;

    if (!previous.isLoading && current.isLoading) {
      client.notifyMutationLoading(snapshot, meta, context);
    }

    if (!previous.isSuccess && current.isSuccess) {
      client.notifyMutationSuccess(snapshot, meta, context);
      client.notifyMutationSettled(snapshot, meta, context);
    }

    if (!previous.isError && current.isError) {
      client.notifyMutationError(snapshot, meta, context);
      client.notifyMutationSettled(snapshot, meta, context);
    }
  }
}
