/// Custom exception classes for circuit breaker functionality.
library;

/// Exception thrown when a request is made to an open circuit breaker.
///
/// This exception is thrown immediately when the circuit breaker is in the
/// [CircuitState.open] state, providing a clear signal to the calling
/// application that the request was rejected without attempting execution.
///
/// Example:
/// ```dart
/// if (!circuitBreaker.allowRequest()) {
///   throw CircuitBreakerOpenException(
///     'Circuit breaker is open for endpoint',
///     circuitScope: 'api.example.com/users',
///   );
/// }
/// ```
class CircuitBreakerOpenException implements Exception {
  /// Descriptive message explaining why the exception was thrown.
  final String message;

  /// Optional scope or identifier of the circuit that is currently open.
  ///
  /// This can be used to identify which endpoint or service has an open
  /// circuit, useful for logging and debugging purposes.
  final String? circuitScope;

  /// Creates a new [CircuitBreakerOpenException] instance.
  ///
  /// The [message] parameter is required and should describe why the
  /// exception was thrown. The [circuitScope] parameter is optional and
  /// can be used to identify the specific circuit that is open.
  CircuitBreakerOpenException(
    this.message, {
    this.circuitScope,
  });

  @override
  String toString() {
    if (circuitScope != null) {
      return 'CircuitBreakerOpenException: $message (scope: $circuitScope)';
    }
    return 'CircuitBreakerOpenException: $message';
  }
}
