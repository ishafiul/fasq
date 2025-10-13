import 'dart:async';

import 'package:flutter/widgets.dart';

import '../core/mutation.dart';
import '../core/mutation_options.dart';
import '../core/mutation_state.dart';

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

  @override
  void initState() {
    super.initState();
    _initializeMutation();
  }

  void _initializeMutation() {
    _mutation = Mutation<T, TVariables>(
      mutationFn: widget.mutationFn,
      options: widget.options,
    );

    _subscription = _mutation.stream.listen((state) {
      if (mounted) {
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
      _mutation.state,
      _mutation.mutate,
    );
  }
}

