import 'package:bloc/bloc.dart';
import 'package:fasq/fasq.dart';

/// Cubit that manages query prefetching.
///
/// Provides methods to prefetch queries without exposing loading states.
class PrefetchQueryCubit extends Cubit<void> {
  final QueryClient _client;
  
  PrefetchQueryCubit({QueryClient? client})
      : _client = client ?? QueryClient(),
        super(null);
  
  /// Prefetch a single query.
  Future<void> prefetch<T>(
    String key,
    Future<T> Function() queryFn, {
    QueryOptions? options,
  }) async {
    await _client.prefetchQuery(key, queryFn, options: options);
  }
  
  /// Prefetch multiple queries in parallel.
  Future<void> prefetchAll(List<PrefetchConfig> configs) async {
    await _client.prefetchQueries(configs);
  }
}
