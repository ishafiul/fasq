import 'query_key.dart';
import 'query_meta.dart';
import 'query_options.dart';
import 'query_state.dart';

class QuerySnapshot<T> {
  const QuerySnapshot({
    required this.queryKey,
    required this.previousState,
    required this.currentState,
    required this.options,
  });

  final QueryKey queryKey;
  final QueryState<T> previousState;
  final QueryState<T> currentState;
  final QueryOptions? options;

  QueryMeta? get meta => options?.meta;
}
