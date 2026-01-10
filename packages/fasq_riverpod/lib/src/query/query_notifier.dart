import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../provider/client_provider.dart';

/// Riverpod-native [AutoDisposeAsyncNotifier] that wraps a FASQ [Query].
///
/// This is the v2 implementation that returns [AsyncValue<T>] instead of
/// [QueryState<T>], providing a more idiomatic Riverpod API.
///
/// It automatically maps FASQ's [QueryState] to Riverpod's [AsyncValue]:
/// - `isLoading` -> `AsyncLoading()`
/// - `isSuccess` -> `AsyncData(data)`
/// - `hasError` -> `AsyncError(error, stackTrace)`
/// - `isFetching` (background refetch) -> Preserves previous data via `AsyncValue.copyWithPrevious`
///
/// The notifier gets the [QueryClient] from [fasqClientProvider], enabling
/// full dependency injection and testability.
///
/// Example:
/// ```dart
/// final userProvider = queryProvider<User>(
///   QueryKeys.user(userId),
///   () => api.fetchUser(userId),
/// );
///
/// // In your widget:
/// final userAsync = ref.watch(userProvider);
/// userAsync.when(
///   data: (user) => Text(user.name),
///   loading: () => CircularProgressIndicator(),
///   error: (error, stack) => Text('Error: $error'),
/// );
/// ```
class QueryNotifier<T> extends AutoDisposeAsyncNotifier<T> {
  late final QueryKey _queryKey;
  late final Future<T> Function()? _queryFn;
  late final Future<T> Function(CancellationToken token)? _queryFnWithToken;
  late final QueryOptions? _options;
  late final QueryKey? _dependsOn;

  late Query<T> _query;
  StreamSubscription<QueryState<T>>? _subscription;

  /// Initializes the notifier with the query configuration.
  ///
  /// This should be called from the provider factory before returning the notifier.
  void configure({
    required QueryKey queryKey,
    Future<T> Function()? queryFn,
    Future<T> Function(CancellationToken token)? queryFnWithToken,
    QueryOptions? options,
    QueryKey? dependsOn,
  }) {
    _queryKey = queryKey;
    _queryFn = queryFn;
    _queryFnWithToken = queryFnWithToken;
    _options = options;
    _dependsOn = dependsOn;
  }

  @override
  FutureOr<T> build() {
    // Get the QueryClient from the provider
    final client = ref.watch(fasqClientProvider);

    // Create or get the query
    _query = client.getQuery<T>(
      _queryKey,
      queryFn: _queryFn,
      queryFnWithToken: _queryFnWithToken,
      options: _options,
      dependsOn: _dependsOn,
    );

    // Register cleanup callback
    ref.onDispose(_cleanup);

    // Listen to query state changes and map to AsyncValue
    _subscription = _query.stream.listen((queryState) {
      state = _mapQueryStateToAsyncValue(queryState);
    });

    // Trigger initial fetch if no data is available
    final initialState = _query.state;
    if (!initialState.hasData && !initialState.hasError) {
      _query.fetch();
    }

    // Return initial state
    if (initialState.hasData) {
      return initialState.data as T;
    } else if (initialState.hasError) {
      throw initialState.error!;
    } else {
      // If loading, return a future that completes when data arrives
      return _waitForData();
    }
  }

  /// Waits for the query to complete and return data.
  Future<T> _waitForData() async {
    final completer = Completer<T>();
    StreamSubscription<QueryState<T>>? subscription;

    subscription = _query.stream.listen((queryState) {
      if (queryState.hasData) {
        if (!completer.isCompleted) {
          completer.complete(queryState.data as T);
        }
        subscription?.cancel();
      } else if (queryState.hasError) {
        if (!completer.isCompleted) {
          completer.completeError(
            queryState.error!,
            queryState.stackTrace ?? StackTrace.current,
          );
        }
        subscription?.cancel();
      }
    });

    return completer.future;
  }

  /// Maps FASQ's [QueryState] to Riverpod's [AsyncValue].
  AsyncValue<T> _mapQueryStateToAsyncValue(QueryState<T> queryState) {
    if (queryState.hasData) {
      // If we have data, return AsyncData
      // If we're refetching in the background, use isLoading: true to show loading indicator
      return AsyncData<T>(
        queryState.data as T,
      );
    } else if (queryState.hasError) {
      // If we have an error, return AsyncError
      return AsyncError<T>(
        queryState.error!,
        queryState.stackTrace ?? StackTrace.current,
      );
    } else {
      // If we're loading, return AsyncLoading
      return const AsyncLoading<Never>() as AsyncValue<T>;
    }
  }

  /// Manually triggers a refetch of the query.
  ///
  /// This will update the state to loading and fetch fresh data from the network.
  Future<void> refetch() async {
    await _query.fetch();
  }

  /// Invalidates the query, removing it from the cache and triggering a refetch.
  ///
  /// This is useful when you know the data has changed and you want to force
  /// a fresh fetch.
  void invalidate() {
    final client = ref.read(fasqClientProvider);
    client.invalidateQuery(_queryKey);
  }

  /// Cleanup method called by Riverpod framework.
  ///
  /// Note: AutoDisposeAsyncNotifier doesn't have a dispose method override,
  /// but we can use ref.onDispose in the build method for cleanup.
  void _cleanup() {
    _subscription?.cancel();
    _query.removeListener();
  }
}
