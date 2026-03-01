import 'dart:developer' as developer;

import 'package:fasq/fasq.dart';

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
  developer.log(
    '[Circuit Breaker] Circuit "${event.circuitId}" opened at '
    '${event.openedAt.toIso8601String()}',
    name: 'fasq.circuit_breaker',
  );
}
