import 'dart:async';

import 'package:fasq_riverpod/fasq_riverpod.dart';

class InfiniteQueryNotifier<TData, TParam>
    extends StateNotifier<InfiniteQueryState<TData, TParam>> {
  final String key;
  final Future<TData> Function(TParam param) queryFn;
  final InfiniteQueryOptions<TData, TParam>? options;

  late final InfiniteQuery<TData, TParam> _query;
  StreamSubscription<InfiniteQueryState<TData, TParam>>? _subscription;

  InfiniteQueryNotifier({
    required this.key,
    required this.queryFn,
    this.options,
  }) : super(InfiniteQueryState<TData, TParam>.idle()) {
    _initialize();
  }

  void _initialize() {
    final client = QueryClient();
    _query =
        client.getInfiniteQuery<TData, TParam>(key, queryFn, options: options);

    _subscription = _query.stream.listen((newState) {
      if (mounted) {
        state = newState;
      }
    });

    state = _query.state;
  }

  Future<void> fetchNextPage([TParam? param]) => _query.fetchNextPage(param);
  Future<void> fetchPreviousPage() => _query.fetchPreviousPage();
  Future<void> refetchPage(int index) => _query.refetchPage(index);
  void reset() => _query.reset();

  @override
  void dispose() {
    _subscription?.cancel();
    _query.removeListener();
    super.dispose();
  }
}
