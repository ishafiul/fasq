import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/client_provider.dart';

/// Riverpod-native [AutoDisposeAsyncNotifier] that wraps a FASQ [InfiniteQuery].
///
/// This is the v2 implementation that returns [AsyncValue<InfiniteQueryState<TData, TParam>>]
/// instead of raw [InfiniteQueryState], providing a more idiomatic Riverpod API.
///
/// The state contains all pagination metadata (`pages`, `hasNextPage`, `hasPreviousPage`, etc.)
/// wrapped in [AsyncValue] for loading/error handling.
///
/// The notifier gets the [QueryClient] from [fasqClientProvider], enabling
/// full dependency injection and testability.
///
/// Example:
/// ```dart
/// final postsProvider = infiniteQueryProviderV2<Post, int>(
///   QueryKeys.posts,
///   (pageParam) => api.fetchPosts(page: pageParam),
///   options: InfiniteQueryOptions(
///     initialParam: 0,
///     getNextPageParam: (lastPage, allPages) => allPages.length,
///   ),
/// );
///
/// // In your widget:
/// final postsAsync = ref.watch(postsProvider);
///
/// postsAsync.when(
///   data: (infiniteState) {
///     final allPosts = infiniteState.pages.expand((p) => p).toList();
///     return ListView.builder(
///       itemCount: allPosts.length,
///       itemBuilder: (context, index) => PostTile(allPosts[index]),
///     );
///   },
///   loading: () => CircularProgressIndicator(),
///   error: (error, stack) => Text('Error: $error'),
/// );
///
/// // Load more:
/// if (infiniteState.hasNextPage) {
///   ref.read(postsProvider.notifier).fetchNextPage();
/// }
/// ```
class InfiniteQueryNotifier<TData, TParam>
    extends AutoDisposeAsyncNotifier<InfiniteQueryState<TData, TParam>> {
  late final QueryKey _queryKey;
  late final Future<TData> Function(TParam param) _queryFn;
  late final InfiniteQueryOptions<TData, TParam>? _options;

  late InfiniteQuery<TData, TParam> _query;
  StreamSubscription<InfiniteQueryState<TData, TParam>>? _subscription;

  /// Initializes the notifier with the infinite query configuration.
  ///
  /// This should be called from the provider factory before returning the notifier.
  void configure({
    required QueryKey queryKey,
    required Future<TData> Function(TParam param) queryFn,
    InfiniteQueryOptions<TData, TParam>? options,
  }) {
    _queryKey = queryKey;
    _queryFn = queryFn;
    _options = options;
  }

  @override
  FutureOr<InfiniteQueryState<TData, TParam>> build() {
    // Get the QueryClient from the provider
    final client = ref.watch(fasqClientProvider);

    // Create or get the infinite query
    _query = client.getInfiniteQuery<TData, TParam>(
      _queryKey,
      _queryFn,
      options: _options,
    );

    // Register cleanup callback
    ref.onDispose(_cleanup);

    // Listen to query state changes and map to AsyncValue
    _subscription = _query.stream.listen((infiniteState) {
      state = _mapToAsyncValue(infiniteState);
    });

    // Trigger initial fetch if no data is available
    final initialState = _query.state;
    if (initialState.pages.isEmpty && initialState.error == null) {
      _query.fetchNextPage();
    }

    // Return initial state
    if (initialState.pages.isNotEmpty) {
      return initialState;
    } else if (initialState.error != null) {
      throw initialState.error!;
    } else {
      // If loading, return a future that completes when data arrives
      return _waitForData();
    }
  }

  /// Waits for the infinite query to complete and return data.
  Future<InfiniteQueryState<TData, TParam>> _waitForData() async {
    final completer = Completer<InfiniteQueryState<TData, TParam>>();
    StreamSubscription<InfiniteQueryState<TData, TParam>>? subscription;

    subscription = _query.stream.listen((infiniteState) {
      if (infiniteState.pages.isNotEmpty) {
        if (!completer.isCompleted) {
          completer.complete(infiniteState);
        }
        subscription?.cancel();
      } else if (infiniteState.error != null) {
        if (!completer.isCompleted) {
          completer.completeError(
            infiniteState.error!,
            StackTrace.current,
          );
        }
        subscription?.cancel();
      }
    });

    return completer.future;
  }

  /// Maps FASQ's [InfiniteQueryState] to Riverpod's [AsyncValue].
  AsyncValue<InfiniteQueryState<TData, TParam>> _mapToAsyncValue(
    InfiniteQueryState<TData, TParam> infiniteState,
  ) {
    if (infiniteState.pages.isNotEmpty) {
      // If we have data (even if loading more pages), return AsyncData
      return AsyncData<InfiniteQueryState<TData, TParam>>(infiniteState);
    } else if (infiniteState.error != null) {
      // If we have an error, return AsyncError
      return AsyncError<InfiniteQueryState<TData, TParam>>(
        infiniteState.error!,
        StackTrace.current,
      );
    } else {
      // If we're loading initial page, return AsyncLoading
      return const AsyncLoading<Never>()
          as AsyncValue<InfiniteQueryState<TData, TParam>>;
    }
  }

  /// Fetches the next page of data.
  ///
  /// Optionally provide a custom [param] to override the automatically
  /// calculated next page parameter.
  Future<void> fetchNextPage([TParam? param]) async {
    await _query.fetchNextPage(param);
  }

  /// Fetches the previous page of data.
  ///
  /// Only works if `getPreviousPageParam` was configured in options.
  Future<void> fetchPreviousPage() async {
    await _query.fetchPreviousPage();
  }

  /// Refetches a specific page by index.
  ///
  /// This will only refetch the specified page, not all pages.
  Future<void> refetchPage(int index) async {
    await _query.refetchPage(index);
  }

  /// Resets the infinite query to its initial state.
  ///
  /// This clears all pages and triggers a fresh fetch of the first page.
  void reset() {
    _query.reset();
  }

  /// Invalidates the infinite query, removing it from cache and refetching.
  void invalidate() {
    final client = ref.read(fasqClientProvider);
    client.invalidateQuery(_queryKey);
  }

  /// Cleanup method called by Riverpod framework.
  void _cleanup() {
    _subscription?.cancel();
    _query.removeListener();
  }
}
