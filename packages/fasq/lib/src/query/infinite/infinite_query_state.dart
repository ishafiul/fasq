import 'package:fasq/src/query/infinite/infinite_query_options.dart';
import 'package:fasq/src/query/query_status.dart';

/// Immutable state for an infinite query.
///
/// Stores loaded pages, pagination availability, in-flight flags, status, and
/// optional error/update metadata.
class InfiniteQueryState<TData, TParam> {
  /// Creates an infinite query state snapshot.
  const InfiniteQueryState({
    required this.pages,
    required this.hasNextPage,
    required this.hasPreviousPage,
    required this.isFetchingNextPage,
    required this.isFetchingPreviousPage,
    required this.status,
    this.error,
    this.dataUpdatedAt,
  });

  /// Returns the initial idle state with no pages loaded.
  factory InfiniteQueryState.idle() {
    return InfiniteQueryState<TData, TParam>(
      pages: const [],
      hasNextPage: false,
      hasPreviousPage: false,
      isFetchingNextPage: false,
      isFetchingPreviousPage: false,
      status: QueryStatus.idle,
    );
  }

  /// All loaded pages in fetch order.
  final List<Page<TData, TParam>> pages;

  /// Whether a next page can be fetched.
  final bool hasNextPage;

  /// Whether a previous page can be fetched.
  final bool hasPreviousPage;

  /// Whether a next-page fetch is currently running.
  final bool isFetchingNextPage;

  /// Whether a previous-page fetch is currently running.
  final bool isFetchingPreviousPage;

  /// Overall query status.
  final QueryStatus status;

  /// Last error encountered by the query, if any.
  final Object? error;

  /// Timestamp of the latest successful data update.
  final DateTime? dataUpdatedAt;

  /// Returns a copy of this state with selective overrides.
  ///
  /// Pass `error: null` to clear an error. Omitting [error] preserves the
  /// current value.
  InfiniteQueryState<TData, TParam> copyWith({
    List<Page<TData, TParam>>? pages,
    bool? hasNextPage,
    bool? hasPreviousPage,
    bool? isFetchingNextPage,
    bool? isFetchingPreviousPage,
    QueryStatus? status,
    Object? error = _sentinel,
    DateTime? dataUpdatedAt,
  }) {
    return InfiniteQueryState<TData, TParam>(
      pages: pages ?? this.pages,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      hasPreviousPage: hasPreviousPage ?? this.hasPreviousPage,
      isFetchingNextPage: isFetchingNextPage ?? this.isFetchingNextPage,
      isFetchingPreviousPage:
          isFetchingPreviousPage ?? this.isFetchingPreviousPage,
      status: status ?? this.status,
      error: identical(error, _sentinel) ? this.error : error,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
    );
  }
}

const Object _sentinel = Object();
