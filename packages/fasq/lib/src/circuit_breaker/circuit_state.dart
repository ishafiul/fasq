/// The state of a circuit breaker.
///
/// A circuit breaker progresses through these states:
/// - [closed] - Normal operation, allowing requests through
/// - [open] - Circuit is open, failing fast without attempting requests
/// - [halfOpen] - Testing if service has recovered, allowing limited requests
enum CircuitState {
  /// Circuit is closed - normal operation allowing all requests through.
  ///
  /// In this state, the circuit breaker monitors failures but allows
  /// all requests to proceed normally.
  closed,

  /// Circuit is open - failing fast without attempting requests.
  ///
  /// In this state, the circuit breaker immediately rejects requests
  /// without attempting to execute them, preserving system resources.
  open,

  /// Circuit is half-open - testing if service has recovered.
  ///
  /// In this state, the circuit breaker allows a limited number of
  /// requests to test if the service has recovered. If successful,
  /// it transitions to closed; if failed, it transitions back to open.
  halfOpen,
}
