import 'query_key.dart';
import 'query_options.dart';

class PrefetchConfig<T> {
  final QueryKey queryKey;
  final Future<T> Function() queryFn;
  final QueryOptions? options;

  const PrefetchConfig({
    required this.queryKey,
    required this.queryFn,
    this.options,
  });
}
