import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

import 'prefetch_cubit.dart';

/// Widget that prefetches queries on mount.
///
/// Example:
/// ```dart
/// PrefetchBuilder(
///   configs: [
///     PrefetchConfig(
///       queryKey: 'users'.toQueryKey(),
///       queryFn: () => api.fetchUsers(),
///     ),
///     PrefetchConfig(
///       queryKey: 'posts'.toQueryKey(),
///       queryFn: () => api.fetchPosts(),
///     ),
///   ],
///   child: YourWidget(),
/// )
/// ```
class PrefetchBuilder extends StatefulWidget {
  final List<PrefetchConfig> configs;
  final Widget child;

  /// Optional client. Otherwise the nearest core/provider client is used.
  final QueryClient? client;

  /// Receives prefetch failures that cannot be represented by this widget's
  /// child-only API.
  final void Function(Object error, StackTrace stackTrace)? onError;

  const PrefetchBuilder({
    super.key,
    required this.configs,
    required this.child,
    this.client,
    this.onError,
  });

  @override
  State<PrefetchBuilder> createState() => _PrefetchBuilderState();
}

class _PrefetchBuilderState extends State<PrefetchBuilder> {
  PrefetchQueryCubit? _cubit;
  QueryClient? _client;
  var _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = widget.client ?? context.queryClient ?? QueryClient();
    if (!identical(client, _client)) {
      unawaited(_cubit?.close());
      _client = client;
      _cubit = PrefetchQueryCubit(client: client);
      _prefetch();
    }
  }

  @override
  void didUpdateWidget(covariant PrefetchBuilder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.client != oldWidget.client ||
        _configsChanged(oldWidget.configs, widget.configs)) {
      final client = widget.client ?? context.queryClient ?? QueryClient();
      if (!identical(client, _client)) {
        unawaited(_cubit?.close());
        _client = client;
        _cubit = PrefetchQueryCubit(client: client);
      }
      _prefetch();
    }
  }

  void _prefetch() {
    final cubit = _cubit;
    if (cubit == null) return;
    final generation = ++_generation;
    unawaited(_runPrefetch(cubit, generation));
  }

  Future<void> _runPrefetch(PrefetchQueryCubit cubit, int generation) async {
    try {
      await cubit.prefetchAll(widget.configs);
    } on Object catch (error, stackTrace) {
      if (mounted && generation == _generation) {
        widget.onError?.call(error, stackTrace);
      }
    }
  }

  bool _configsChanged(
    List<PrefetchConfig> previous,
    List<PrefetchConfig> next,
  ) {
    if (previous.length != next.length) return true;
    for (var index = 0; index < previous.length; index++) {
      final oldConfig = previous[index];
      final newConfig = next[index];
      if (oldConfig.queryKey.key != newConfig.queryKey.key ||
          !identical(oldConfig.queryFn, newConfig.queryFn) ||
          !identical(oldConfig.options, newConfig.options)) {
        return true;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _generation++;
    unawaited(_cubit?.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
