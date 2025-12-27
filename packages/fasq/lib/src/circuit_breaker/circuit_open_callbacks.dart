import 'circuit_open_event.dart';

/// Default logging callback for circuit open events.
///
/// This callback logs circuit open events to the console with a formatted
/// message indicating which circuit opened and when. It can be registered
/// with a [CircuitBreakerRegistry] to provide immediate visibility into
/// circuit open events.
///
/// Example:
/// ```dart
/// final registry = CircuitBreakerRegistry();
/// registry.registerCircuitOpenCallback(logCircuitOpenEvent);
/// ```
void logCircuitOpenEvent(CircuitOpenEvent event) {
  // ignore: avoid_print
  print(
    '[Circuit Breaker] Circuit "${event.circuitId}" opened at '
    '${event.openedAt.toIso8601String()}',
  );
}
