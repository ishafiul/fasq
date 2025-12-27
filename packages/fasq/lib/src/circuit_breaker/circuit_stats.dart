/// Statistics tracked by a circuit breaker for state transition decisions.
///
/// This class maintains counters for failures and successes, along with
/// the timestamp of the last failure, which are used to determine when
/// the circuit breaker should transition between states.
class CircuitStats {
  /// Number of consecutive failures that have occurred.
  int failureCount;

  /// Number of consecutive successes in half-open state.
  int successCount;

  /// Timestamp of the last failure, or null if no failures have occurred.
  DateTime? lastFailureTimestamp;

  /// Creates a new [CircuitStats] instance with default values.
  CircuitStats({
    this.failureCount = 0,
    this.successCount = 0,
    this.lastFailureTimestamp,
  });

  /// Resets all statistics to their initial default values.
  ///
  /// This method is called when transitioning states, particularly when
  /// moving from Open to Half-Open or when closing the circuit.
  void reset() {
    failureCount = 0;
    successCount = 0;
    lastFailureTimestamp = null;
  }

  /// Creates a copy of this [CircuitStats] with updated values.
  CircuitStats copyWith({
    int? failureCount,
    int? successCount,
    DateTime? lastFailureTimestamp,
  }) {
    return CircuitStats(
      failureCount: failureCount ?? this.failureCount,
      successCount: successCount ?? this.successCount,
      lastFailureTimestamp: lastFailureTimestamp ?? this.lastFailureTimestamp,
    );
  }

  @override
  String toString() {
    return 'CircuitStats(failureCount: $failureCount, '
        'successCount: $successCount, '
        'lastFailureTimestamp: $lastFailureTimestamp)';
  }
}
