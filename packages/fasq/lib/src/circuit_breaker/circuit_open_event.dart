/// Event data structure for circuit open events.
///
/// Contains information about a circuit breaker that has transitioned
/// to the 'Open' state, including the circuit's scope identifier and
/// the timestamp when the circuit opened.
class CircuitOpenEvent {
  /// The scope identifier (e.g., hostname, endpoint) of the circuit breaker
  /// that opened.
  final String circuitId;

  /// The timestamp when the circuit transitioned to the 'Open' state.
  final DateTime openedAt;

  /// Creates a new [CircuitOpenEvent] instance.
  const CircuitOpenEvent({
    required this.circuitId,
    required this.openedAt,
  });

  @override
  String toString() {
    return 'CircuitOpenEvent(circuitId: $circuitId, openedAt: $openedAt)';
  }
}

/// Callback function signature for circuit open events.
///
/// This callback is invoked whenever a circuit breaker transitions
/// from 'Closed' or 'Half-Open' to 'Open' state. The callback receives
/// an [CircuitOpenEvent] containing the circuit identifier and timestamp.
///
/// Example:
/// ```dart
/// void onCircuitOpen(CircuitOpenEvent event) {
///   print('Circuit ${event.circuitId} opened at ${event.openedAt}');
/// }
/// ```
typedef CircuitOpenCallback = void Function(CircuitOpenEvent event);
