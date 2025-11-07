/// Riverpod integration helpers for FASQ queries, mutations, and prefetching.
///
/// Exported providers, notifiers, and extensions make it easy to manage async
/// data via Riverpod while reusing the FASQ caching layer.
library;

export 'src/query_notifier.dart';
export 'src/query_provider.dart';
export 'src/mutation_notifier.dart';
export 'src/mutation_provider.dart';
export 'src/infinite_query_notifier.dart';
export 'src/infinite_query_provider.dart';
export 'src/query_combiner.dart';
export 'src/prefetch_extension.dart';
export 'src/use_prefetch.dart';

export 'package:fasq/fasq.dart';
export 'package:flutter_riverpod/flutter_riverpod.dart';
