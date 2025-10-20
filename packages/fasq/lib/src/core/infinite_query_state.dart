import 'query_status.dart';
import 'infinite_query_options.dart';

class InfiniteQueryState<TData, TParam> {
  final List<Page<TData, TParam>> pages;
  final bool hasNextPage;
  final bool hasPreviousPage;
  final bool isFetchingNextPage;
  final bool isFetchingPreviousPage;
  final QueryStatus status;
  final Object? error;
  final DateTime? dataUpdatedAt;

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
