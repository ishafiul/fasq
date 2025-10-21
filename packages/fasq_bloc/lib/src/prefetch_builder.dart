import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

import 'prefetch_cubit.dart';

/// Widget that prefetches queries on mount.
///
/// Example:
/// ```dart
/// PrefetchBuilder(
///   configs: [
///     PrefetchConfig(key: 'users', queryFn: () => api.fetchUsers()),
///     PrefetchConfig(key: 'posts', queryFn: () => api.fetchPosts()),
///   ],
///   child: YourWidget(),
/// )
/// ```
class PrefetchBuilder extends StatefulWidget {
  final List<PrefetchConfig> configs;
  final Widget child;
  
  const PrefetchBuilder({
    super.key,
    required this.configs,
    required this.child,
  });
  
  @override
  State<PrefetchBuilder> createState() => _PrefetchBuilderState();
}

class _PrefetchBuilderState extends State<PrefetchBuilder> {
  late final PrefetchQueryCubit _cubit;
  
  @override
  void initState() {
    super.initState();
    _cubit = PrefetchQueryCubit();
    _cubit.prefetchAll(widget.configs);
  }
  
  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) => widget.child;
}
