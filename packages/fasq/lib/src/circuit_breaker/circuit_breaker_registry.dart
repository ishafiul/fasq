import 'circuit_breaker.dart';
import 'circuit_breaker_options.dart';
import 'circuit_open_event.dart';

/// Registry for managing multiple circuit breaker instances with per-endpoint isolation.
///
/// This registry ensures that circuit breakers are isolated by scope key (e.g., hostname,
/// endpoint), preventing failures in one service from affecting others. Each scope
/// maintains its own independent circuit breaker state.
class CircuitBreakerRegistry {
  /// Internal storage for circuit breaker instances, keyed by scope identifier.
  final Map<String, CircuitBreaker> _breakers = {};

  /// Registered callbacks for circuit open events.
  final List<CircuitOpenCallback> _callbacks = [];

  /// Retrieves an existing circuit breaker for the given [scopeKey], or creates
  /// a new one using the provided [options] if none exists.
  ///
  /// The [scopeKey] uniquely identifies the service or endpoint (e.g., hostname,
  /// URL prefix). The [options] parameter is used only when creating a new
  /// circuit breaker instance.
  ///
  /// Returns the same [CircuitBreaker] instance for the same [scopeKey] on
  /// subsequent calls, ensuring state persistence across requests.
  ///
  /// Example:
  /// ```dart
  /// final registry = CircuitBreakerRegistry();
  /// final options = CircuitBreakerOptions(failureThreshold: 5);
  /// final breaker = registry.getOrCreate('api.example.com', options);
  /// ```
  CircuitBreaker getOrCreate(
    String scopeKey,
    CircuitBreakerOptions options,
  ) {
    return _breakers.putIfAbsent(
      scopeKey,
      () => CircuitBreaker(
        options: options,
        circuitId: scopeKey,
        onCircuitOpen: (circuitId, openedAt) {
          _notifyCircuitOpen(CircuitOpenEvent(
            circuitId: circuitId,
            openedAt: openedAt,
          ));
        },
      ),
    );
  }

  /// Removes all circuit breaker instances from the registry.
  ///
  /// After calling this method, the registry will be empty and all previously
  /// stored circuit breakers will be discarded. New circuit breakers will be
  /// created on subsequent [getOrCreate] calls.
  ///
  /// Example:
  /// ```dart
  /// registry.clearAll();
  /// ```
  void clearAll() {
    _breakers.clear();
  }

  /// Resets the state of a specific circuit breaker identified by [scopeKey].
  ///
  /// If a circuit breaker exists for the given [scopeKey], it will be reset
  /// to its initial state (Closed) with all statistics cleared. If no circuit
  /// breaker exists for the given [scopeKey], this method does nothing.
  ///
  /// Example:
  /// ```dart
  /// registry.reset('api.example.com');
  /// ```
  void reset(String scopeKey) {
    final breaker = _breakers[scopeKey];
    breaker?.reset();
  }

  /// Returns the number of circuit breakers currently registered.
  ///
  /// This can be useful for monitoring and debugging purposes.
  int get count => _breakers.length;

  /// Checks if a circuit breaker exists for the given [scopeKey].
  ///
  /// Returns `true` if a circuit breaker is registered for [scopeKey],
  /// `false` otherwise.
  bool contains(String scopeKey) => _breakers.containsKey(scopeKey);

  /// Retrieves a circuit breaker for the given [scopeKey] without creating one.
  ///
  /// Returns the [CircuitBreaker] instance if it exists, or `null` if no
  /// circuit breaker is registered for the given [scopeKey].
  CircuitBreaker? get(String scopeKey) => _breakers[scopeKey];

  /// Registers a callback function to be invoked when any circuit breaker
  /// transitions to the 'Open' state.
  ///
  /// The [callback] will be called with a [CircuitOpenEvent] containing the
  /// circuit identifier and timestamp whenever a circuit opens. Multiple
  /// callbacks can be registered, and all will be invoked for each event.
  ///
  /// Example:
  /// ```dart
  /// registry.registerCircuitOpenCallback((event) {
  ///   print('Circuit ${event.circuitId} opened at ${event.openedAt}');
  /// });
  /// ```
  void registerCircuitOpenCallback(CircuitOpenCallback callback) {
    _callbacks.add(callback);
  }

  /// Unregisters a previously registered circuit open callback.
  ///
  /// Removes the first occurrence of [callback] from the registered callbacks.
  /// If the callback was not registered, this method does nothing.
  ///
  /// Returns `true` if the callback was found and removed, `false` otherwise.
  bool unregisterCircuitOpenCallback(CircuitOpenCallback callback) {
    return _callbacks.remove(callback);
  }

  /// Removes all registered circuit open callbacks.
  ///
  /// After calling this method, no callbacks will be invoked for circuit
  /// open events until new callbacks are registered.
  void clearCircuitOpenCallbacks() {
    _callbacks.clear();
  }

  /// Returns the number of registered circuit open callbacks.
  int get callbackCount => _callbacks.length;

  /// Invokes all registered circuit open callbacks with the given event.
  ///
  /// This method is called internally when a circuit breaker transitions
  /// to the 'Open' state. It iterates through all registered callbacks and
  /// invokes each one with the provided [event].
  ///
  /// If a callback throws an exception, it is caught and logged, but does
  /// not prevent other callbacks from being invoked.
  void _notifyCircuitOpen(CircuitOpenEvent event) {
    for (final callback in _callbacks) {
      try {
        callback(event);
      } catch (e) {
        // Log error but continue invoking other callbacks
        // In production, this could use a proper logging mechanism
        // ignore: avoid_print
        print('Error in circuit open callback: $e');
      }
    }
  }

  @override
  String toString() {
    return 'CircuitBreakerRegistry(count: ${_breakers.length}, '
        'callbacks: ${_callbacks.length})';
  }
}
