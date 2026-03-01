import 'package:fasq/src/core/query_key.dart';
import 'package:fasq/src/core/query_options.dart';

/// Configuration describing a query to prefetch.
class PrefetchConfig<T> {
  /// Creates a prefetch configuration.
  const PrefetchConfig({
    required this.queryKey,
    required this.queryFn,
    this.options,
  });

  /// Key identifying the query to prefetch.
  final QueryKey queryKey;

  /// Function that fetches query data.
  final Future<T> Function() queryFn;

  /// Optional query behavior overrides used during prefetch.
  final QueryOptions? options;
}
