/// Lifecycle status of a mutation operation.
enum MutationStatus {
  /// No mutation is currently running.
  idle,

  /// Mutation is in progress.
  loading,

  /// Mutation completed successfully.
  success,

  /// Mutation completed with an error.
  error,
}
