import '../core/utils/fasq_time.dart';
import 'circuit_breaker_options.dart';
import 'circuit_state.dart';
import 'circuit_stats.dart';

/// A circuit breaker that prevents repeated execution of operations likely to fail.
///
/// The circuit breaker operates in three states:
/// - [CircuitState.closed]: Normal operation, allowing requests through
/// - [CircuitState.open]: Failing fast without attempting requests
/// - [CircuitState.halfOpen]: Testing if service has recovered
///
/// State transitions are managed based on failure counts and timeouts,
/// helping preserve system resources during backend outages.
class CircuitBreaker {
  /// Configuration options for this circuit breaker.
  final CircuitBreakerOptions options;

  /// Current state of the circuit breaker.
  CircuitState _state;

  /// Statistics tracked for state transition decisions.
  final CircuitStats _stats;

  /// Timestamp when the circuit can transition from Open to Half-Open.
  ///
  /// Set when the circuit opens. When the current time exceeds this timestamp,
  /// the circuit can transition to Half-Open state.
  DateTime? _resetTimeout;

  /// Optional callback invoked when the circuit transitions to 'Open' state.
  ///
  /// The callback receives the circuit identifier (scope key) and the timestamp
  /// when the circuit opened. This is typically set by the [CircuitBreakerRegistry]
  /// when creating circuit breaker instances.
  final void Function(String circuitId, DateTime openedAt)? onCircuitOpen;

  /// The circuit identifier (scope key) for this circuit breaker.
  ///
  /// This is set by the [CircuitBreakerRegistry] when creating the circuit
  /// breaker instance. It is used when invoking the [onCircuitOpen] callback.
  final String? circuitId;

  /// Creates a new [CircuitBreaker] instance.
  ///
  /// The circuit breaker starts in the [CircuitState.closed] state with
  /// default statistics (zero counts, no failure timestamp).
  ///
  /// The [onCircuitOpen] callback, if provided, will be invoked whenever
  /// the circuit transitions to the 'Open' state.
  ///
  /// The [circuitId] is the scope key that uniquely identifies this circuit
  /// breaker (e.g., hostname, endpoint). It is used when invoking callbacks.
  CircuitBreaker({
    CircuitBreakerOptions? options,
    this.onCircuitOpen,
    this.circuitId,
  })  : options = options ?? const CircuitBreakerOptions(),
        _state = CircuitState.closed,
        _stats = CircuitStats();

  /// The current state of the circuit breaker.
  ///
  /// Returns the current [CircuitState] (closed, open, or halfOpen).
  CircuitState get state => _state;

  /// The statistics tracked by this circuit breaker.
  ///
  /// Returns the [CircuitStats] object containing failure count, success
  /// count, and last failure timestamp. This object can be accessed for
  /// monitoring and state transition logic.
  CircuitStats get stats => _stats;

  /// Records a successful operation.
  ///
  /// Updates success metrics and handles state transitions:
  /// - In Half-Open state: increments success count. If success threshold
  ///   is met, transitions to Closed and resets all statistics.
  /// - In Closed state: resets failure counter and success counter.
  /// - In Open state: no action (should not be called in Open state).
  void recordSuccess() {
    if (_state == CircuitState.halfOpen) {
      _stats.successCount++;
      if (_stats.successCount >= options.successThreshold) {
        _state = CircuitState.closed;
        _stats.reset();
        _resetTimeout = null;
      }
    } else if (_state == CircuitState.closed) {
      _stats.failureCount = 0;
      _stats.successCount = 0;
    }
  }

  /// Records a failed operation.
  ///
  /// Updates failure metrics and handles state transitions:
  /// - In Closed state: increments failure count. If failure threshold
  ///   is met, transitions to Open and sets reset timeout.
  /// - In Half-Open state: immediately transitions to Open and sets
  ///   reset timeout.
  /// - In Open state: only updates last failure timestamp.
  ///
  /// When transitioning to Open state, the [onCircuitOpen] callback is
  /// invoked if provided and [circuitId] is set.
  void recordFailure() {
    final now = FasqTime.now;
    final previousState = _state;
    _stats.failureCount++;
    _stats.lastFailureTimestamp = now;

    if (_state == CircuitState.closed) {
      if (_stats.failureCount >= options.failureThreshold) {
        _state = CircuitState.open;
        _resetTimeout = now.add(options.resetTimeout);
        if (circuitId != null && previousState != CircuitState.open) {
          onCircuitOpen?.call(circuitId!, now);
        }
      }
    } else if (_state == CircuitState.halfOpen) {
      _state = CircuitState.open;
      _resetTimeout = now.add(options.resetTimeout);
      if (circuitId != null && previousState != CircuitState.open) {
        onCircuitOpen?.call(circuitId!, now);
      }
    }
  }

  /// Determines if a request is allowed based on the current circuit state.
  ///
  /// Returns `true` if the request should be allowed, `false` otherwise.
  ///
  /// Behavior by state:
  /// - **Closed**: Always returns `true` (normal operation).
  /// - **Open**: Returns `false` if reset timeout has not elapsed. If timeout
  ///   has elapsed, transitions to Half-Open and returns `true` (allowing
  ///   one test request).
  /// - **Half-Open**: Returns `true` only for the first request. Subsequent
  ///   calls return `false` until a success or failure is recorded.
  bool allowRequest() {
    if (_state == CircuitState.closed) {
      return true;
    }

    if (_state == CircuitState.open) {
      if (_resetTimeout == null) {
        return false;
      }

      final now = FasqTime.now;
      if (now.isBefore(_resetTimeout!)) {
        return false;
      }

      _state = CircuitState.halfOpen;
      _stats.reset();
      return true;
    }

    if (_state == CircuitState.halfOpen) {
      // Allow requests if we need more successes to close the circuit
      // We allow the first probe request when entering half-open (successCount == 0)
      if (_stats.successCount < options.successThreshold) {
        return true;
      }
      return false;
    }

    return false;
  }

  /// Resets the circuit breaker to its initial state.
  ///
  /// This method resets the circuit breaker to [CircuitState.closed] and
  /// clears all statistics (failure count, success count, last failure timestamp).
  /// The reset timeout is also cleared.
  ///
  /// This is useful for manual intervention or when resetting a circuit breaker
  /// through the registry.
  void reset() {
    _state = CircuitState.closed;
    _stats.reset();
    _resetTimeout = null;
  }

  @override
  String toString() {
    return 'CircuitBreaker(state: $_state, stats: $_stats, '
        'resetTimeout: $_resetTimeout)';
  }
}
