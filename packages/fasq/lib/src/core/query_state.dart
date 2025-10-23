import 'query_status.dart';

/// Represents the current state of a query.
///
/// A [QueryState] contains all information about an async operation:
/// the current data, any error that occurred, and the current status.
///
/// Use the computed properties ([isLoading], [hasData], [hasError]) to
/// easily check the query state in your UI.
///
/// Example:
/// ```dart
/// builder: (context, state) {
///   if (state.isLoading) return CircularProgressIndicator();
///   if (state.hasError) return Text('Error: ${state.error}');
///   if (state.hasData) return Text('Data: ${state.data}');
///   return SizedBox();
/// }
/// ```
class QueryState<T> {
  /// The data returned by the async operation, or null if not yet loaded.
  final T? data;

  /// The error that occurred during the async operation, or null if no error.
  final Object? error;

  /// The stack trace associated with the error, if any.
  final StackTrace? stackTrace;

  /// The current status of the query.
  final QueryStatus status;

  /// Whether a background refetch is in progress.
  ///
  /// True when serving stale data and refetching in background.
  /// Different from [isLoading] which indicates initial fetch.
  final bool isFetching;

  /// When the data was last updated.
  final DateTime? dataUpdatedAt;

  /// Whether the data is stale (determined by cache).
  final bool isStale;

  const QueryState({
    this.data,
    this.error,
    this.stackTrace,
    required this.status,
    this.isFetching = false,
    this.dataUpdatedAt,
    this.isStale = false,
  });

  /// Creates an idle state (query not started yet).
  factory QueryState.idle() {
    return QueryState<T>(status: QueryStatus.idle);
  }

  /// Creates a loading state.
  ///
  /// Optionally includes [data] from a previous fetch to show while loading.
  factory QueryState.loading(
      {T? data, bool isFetching = false, bool isStale = false}) {
    return QueryState<T>(
      status: QueryStatus.loading,
      data: data,
      isFetching: isFetching,
      isStale: isStale,
    );
  }

  /// Creates a success state with [data].
  factory QueryState.success(T data,
      {DateTime? dataUpdatedAt,
      bool isFetching = false,
      bool isStale = false}) {
    return QueryState<T>(
      status: QueryStatus.success,
      data: data,
      dataUpdatedAt: dataUpdatedAt ?? DateTime.now(),
      isFetching: isFetching,
      isStale: isStale,
    );
  }

  /// Creates an error state with [error] and optional [stackTrace].
  factory QueryState.error(Object error, [StackTrace? stackTrace]) {
    return QueryState<T>(
      status: QueryStatus.error,
      error: error,
      stackTrace: stackTrace,
    );
  }

  /// Whether the query is currently loading.
  bool get isLoading => status == QueryStatus.loading;

  /// Whether an error has occurred.
  bool get hasError => error != null;

  /// Whether data is available.
  bool get hasData => data != null;

  /// Whether the query completed successfully.
  bool get isSuccess => status == QueryStatus.success;

  /// Whether the query is in idle state (not started).
  bool get isIdle => status == QueryStatus.idle;

  QueryState<T> copyWith({
    T? data,
    Object? error,
    StackTrace? stackTrace,
    QueryStatus? status,
    bool? isFetching,
    DateTime? dataUpdatedAt,
    bool? isStale,
  }) {
    return QueryState<T>(
      data: data ?? this.data,
      error: error ?? this.error,
      stackTrace: stackTrace ?? this.stackTrace,
      status: status ?? this.status,
      isFetching: isFetching ?? this.isFetching,
      dataUpdatedAt: dataUpdatedAt ?? this.dataUpdatedAt,
      isStale: isStale ?? this.isStale,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is QueryState<T> &&
        other.data == data &&
        other.error == error &&
        other.stackTrace == stackTrace &&
        other.status == status &&
        other.isFetching == isFetching &&
        other.isStale == isStale;
  }

  @override
  int get hashCode {
    return Object.hash(
      data,
      error,
      stackTrace,
      status,
      isFetching,
      isStale,
    );
  }

  @override
  String toString() {
    return 'QueryState<$T>(status: $status, hasData: $hasData, hasError: $hasError)';
  }
}
