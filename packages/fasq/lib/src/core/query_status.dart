/// The status of a query's lifecycle.
///
/// A query progresses through these states:
/// - [idle] - Query has not started fetching yet
/// - [loading] - Query is currently fetching data
/// - [success] - Query completed successfully with data
/// - [error] - Query failed with an error
enum QueryStatus {
  /// Query has not started fetching yet.
  idle,

  /// Query is currently executing the async operation.
  loading,

  /// Query completed successfully and has data.
  success,

  /// Query failed with an error.
  error,
}

