import 'query_options.dart';

class PrefetchConfig<T> {
  final String key;
  final Future<T> Function() queryFn;
  final QueryOptions? options;

  const PrefetchConfig({
    required this.key,
    required this.queryFn,
    this.options,
  });
}

