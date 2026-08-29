import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:fasq/fasq.dart';

/// Mixin for managing fasq query subscriptions within Bloc/Cubit.
///
/// This mixin provides automatic subscription management for fasq queries,
/// handling subscription lifecycle and cleanup when the cubit is closed.
///
/// Example:
/// ```dart
/// class MyCubit extends Cubit<QueryState<User>> with FasqSubscriptionMixin {
///   MyCubit() : super(QueryState<User>.idle()) {
///     final query = QueryClient().getQuery<User>(
///       'user'.toQueryKey(),
///       queryFn: () => api.fetchUser(),
///     );
///
///     subscribeToQuery<User>(
///       query,
///       (state) => emit(state),
///     );
///   }
/// }
/// ```
mixin FasqSubscriptionMixin<State> on Cubit<State> {
  /// Internal set of active stream subscriptions managed by this mixin.
  ///
  /// Using a Set prevents duplicate subscriptions and allows efficient
  /// cancellation when the cubit is closed.
  final Set<StreamSubscription> _subscriptions = {};

  /// Cleanup for the query reference owned by a subscription.
  ///
  /// A stream subscription and a query reference are separate resources in
  /// FASQ. Keeping their cleanup together prevents a Bloc subscription from
  /// leaking the query's reference-counted lifecycle.
  final Map<StreamSubscription, void Function()> _subscriptionCleanup = {};

  /// Returns the number of active subscriptions.
  ///
  /// Useful for testing and debugging purposes.
  int get subscriptionCount => _subscriptions.length;

  /// Subscribes to a fasq query's stream and manages the subscription lifecycle.
  ///
  /// The subscription is automatically cancelled when the cubit is closed.
  /// If the query is null, this method does nothing.
  ///
  /// [query] - The fasq Query instance to subscribe to.
  /// [onState] - Callback function that receives QueryState updates.
  ///   This is where the cubit should update its state using `emit()`.
  ///
  /// Example:
  /// ```dart
  /// subscribeToQuery<User>(
  ///   query,
  ///   (state) {
  ///     if (!isClosed) {
  ///       emit(state);
  ///     }
  ///   },
  /// );
  /// ```
  StreamSubscription<QueryState<T>>? subscribeToQuery<T>(
    Query<T>? query,
    void Function(QueryState<T>) onState, {
    bool addListener = true,
  }) {
    if (query == null) {
      return null;
    }

    final subscription = query.stream.listen((state) {
      if (!isClosed) {
        onState(state);
      }
    });

    _subscriptions.add(subscription);
    if (addListener) {
      _subscriptionCleanup[subscription] = query.removeListener;
      query.addListener();
    }
    return subscription;
  }

  /// Subscribes to a fasq infinite query's stream and manages the subscription lifecycle.
  ///
  /// The subscription is automatically cancelled when the cubit is closed.
  /// If the query is null, this method does nothing.
  ///
  /// [query] - The fasq InfiniteQuery instance to subscribe to.
  /// [onState] - Callback function that receives InfiniteQueryState updates.
  ///   This is where the cubit should update its state using `emit()`.
  ///
  /// Example:
  /// ```dart
  /// subscribeToInfiniteQuery<List<Post>, String?>(
  ///   query,
  ///   (state) {
  ///     if (!isClosed) {
  ///       emit(state);
  ///     }
  ///   },
  /// );
  /// ```
  StreamSubscription<InfiniteQueryState<TData, TParam>>?
  subscribeToInfiniteQuery<TData, TParam>(
    InfiniteQuery<TData, TParam>? query,
    void Function(InfiniteQueryState<TData, TParam>) onState, {
    bool addListener = true,
  }) {
    if (query == null) {
      return null;
    }

    final subscription = query.stream.listen((state) {
      if (!isClosed) {
        onState(state);
      }
    });

    _subscriptions.add(subscription);
    if (addListener) {
      _subscriptionCleanup[subscription] = query.removeListener;
      // InfiniteQuery.addListener() is async because it may prefetch the
      // first page. It increments the reference count synchronously, while
      // errors are already represented in the query state.
      unawaited(query.addListener().catchError((_) {}));
    }
    return subscription;
  }

  /// Cancels all active subscriptions and clears the internal set.
  ///
  /// This method is automatically called when the cubit is closed.
  /// Overrides [Cubit.close] to ensure proper resource cleanup.
  /// Cancels and removes a specific subscription.
  void unsubscribe(StreamSubscription? subscription) {
    if (subscription != null) {
      unawaited(subscription.cancel());
      _subscriptionCleanup.remove(subscription)?.call();
      _subscriptions.remove(subscription);
    }
  }

  @override
  Future<void> close() {
    for (final subscription in _subscriptions.toList()) {
      unawaited(subscription.cancel());
      _subscriptionCleanup.remove(subscription)?.call();
    }
    _subscriptions.clear();
    _subscriptionCleanup.clear();
    return super.close();
  }
}
