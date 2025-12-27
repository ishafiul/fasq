/// Configuration options for a circuit breaker.
///
/// Controls the thresholds and timeouts that determine when the circuit
/// breaker transitions between states, and which exceptions should be ignored.
class CircuitBreakerOptions {
  /// Number of consecutive failures required to open the circuit.
  ///
  /// When the failure count reaches this threshold, the circuit transitions
  /// from Closed to Open state. Defaults to 5.
  final int failureThreshold;

  /// Duration to wait before attempting to reset the circuit (transition to Half-Open).
  ///
  /// After the circuit opens, it waits for this duration before allowing
  /// a test request to check if the service has recovered. Defaults to 60 seconds.
  final Duration resetTimeout;

  /// Number of consecutive successes required in Half-Open state to close the circuit.
  ///
  /// When the success count reaches this threshold while in Half-Open state,
  /// the circuit transitions back to Closed state. Defaults to 1.
  final int successThreshold;

  /// List of exception types that should not trip the circuit breaker.
  ///
  /// When an exception of one of these types (or a subtype) is thrown,
  /// it will not be counted as a failure. This is useful for client errors
  /// like 404 (not found) that shouldn't cause the circuit to open.
  ///
  /// Defaults to an empty list (all exceptions count as failures).
  final List<Type> ignoreExceptions;

  const CircuitBreakerOptions({
    this.failureThreshold = 5,
    this.resetTimeout = const Duration(seconds: 60),
    this.successThreshold = 1,
    this.ignoreExceptions = const [],
  })  : assert(failureThreshold > 0, 'failureThreshold must be positive'),
        assert(successThreshold > 0, 'successThreshold must be positive');

  /// Creates a copy with updated values.
  CircuitBreakerOptions copyWith({
    int? failureThreshold,
    Duration? resetTimeout,
    int? successThreshold,
    List<Type>? ignoreExceptions,
  }) {
    return CircuitBreakerOptions(
      failureThreshold: failureThreshold ?? this.failureThreshold,
      resetTimeout: resetTimeout ?? this.resetTimeout,
      successThreshold: successThreshold ?? this.successThreshold,
      ignoreExceptions: ignoreExceptions ?? this.ignoreExceptions,
    );
  }

  /// Determines if an exception should be ignored by the circuit breaker.
  ///
  /// Returns `true` if the exception's type or any of its supertypes matches
  /// a type in [ignoreExceptions], `false` otherwise.
  ///
  /// This allows the circuit breaker to bypass tripping for specific errors
  /// (e.g., 404s, client errors) that shouldn't cause the circuit to open.
  ///
  /// The method checks both exact type matches and inheritance relationships.
  /// For example, if [ArgumentError] is in [ignoreExceptions], then any
  /// [ArgumentError] instance will be ignored, and if [Exception] is in the
  /// list, all exceptions will be ignored.
  bool isIgnored(Object exception) {
    if (ignoreExceptions.isEmpty) {
      return false;
    }

    for (final ignoredType in ignoreExceptions) {
      if (_isTypeMatch(exception, ignoredType)) {
        return true;
      }
    }

    return false;
  }

  /// Checks if [exception] matches [type].
  ///
  /// This handles:
  /// 1. Exact runtime type match
  /// 2. Subtype check for core Exception/Error types
  bool _isTypeMatch(Object exception, Type type) {
    if (exception.runtimeType == type) return true;

    // Handle common base types support since we can't do `is Type` dynamically
    if (type == Exception) return exception is Exception;
    if (type == Error) return exception is Error;
    if (type == ArgumentError) return exception is ArgumentError;
    if (type == StateError) return exception is StateError;
    if (type == RangeError) return exception is RangeError;
    if (type == TypeError) return exception is TypeError;
    if (type == UnimplementedError) return exception is UnimplementedError;
    if (type == UnsupportedError) return exception is UnsupportedError;
    if (type == FormatException) return exception is FormatException;
    if (type == NoSuchMethodError) return exception is NoSuchMethodError;

    return false;
  }

  @override
  String toString() {
    return 'CircuitBreakerOptions('
        'failureThreshold: $failureThreshold, '
        'resetTimeout: ${resetTimeout.inSeconds}s, '
        'successThreshold: $successThreshold, '
        'ignoreExceptions: ${ignoreExceptions.length})';
  }
}
