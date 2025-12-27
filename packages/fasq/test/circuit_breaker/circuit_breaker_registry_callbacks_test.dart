import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircuitBreakerRegistry - Circuit Open Callbacks', () {
    group('registerCircuitOpenCallback', () {
      test('registers a callback', () {
        final registry = CircuitBreakerRegistry();

        registry.registerCircuitOpenCallback((event) {
          // Callback registered successfully
        });

        expect(registry.callbackCount, 1);
      });

      test('allows registering multiple callbacks', () {
        final registry = CircuitBreakerRegistry();
        final events = <CircuitOpenEvent>[];

        registry.registerCircuitOpenCallback((event) {
          events.add(event);
        });
        registry.registerCircuitOpenCallback((event) {
          events.add(event);
        });

        expect(registry.callbackCount, 2);
      });

      test('invokes registered callbacks when circuit opens', () {
        final registry = CircuitBreakerRegistry();
        final events = <CircuitOpenEvent>[];

        registry.registerCircuitOpenCallback((event) {
          events.add(event);
        });

        final options = CircuitBreakerOptions(failureThreshold: 2);
        final breaker = registry.getOrCreate('api.example.com', options);

        breaker.recordFailure();
        breaker.recordFailure();

        expect(events.length, 1);
        expect(events[0].circuitId, 'api.example.com');
        expect(events[0].openedAt, isNotNull);
      });

      test('invokes all registered callbacks', () {
        final registry = CircuitBreakerRegistry();
        final events1 = <CircuitOpenEvent>[];
        final events2 = <CircuitOpenEvent>[];

        registry.registerCircuitOpenCallback((event) {
          events1.add(event);
        });
        registry.registerCircuitOpenCallback((event) {
          events2.add(event);
        });

        final options = CircuitBreakerOptions(failureThreshold: 1);
        final breaker = registry.getOrCreate('api.example.com', options);

        breaker.recordFailure();

        expect(events1.length, 1);
        expect(events2.length, 1);
        expect(events1[0].circuitId, events2[0].circuitId);
      });

      test('invokes callbacks only when transitioning to open', () {
        final registry = CircuitBreakerRegistry();
        final events = <CircuitOpenEvent>[];

        registry.registerCircuitOpenCallback((event) {
          events.add(event);
        });

        final options = CircuitBreakerOptions(failureThreshold: 3);
        final breaker = registry.getOrCreate('api.example.com', options);

        breaker.recordFailure();
        expect(events.length, 0);

        breaker.recordFailure();
        expect(events.length, 0);

        breaker.recordFailure();
        expect(events.length, 1);
      });

      test('invokes callbacks when transitioning from half-open to open',
          () async {
        final registry = CircuitBreakerRegistry();
        final events = <CircuitOpenEvent>[];

        registry.registerCircuitOpenCallback((event) {
          events.add(event);
        });

        final options = CircuitBreakerOptions(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 10),
        );
        final breaker = registry.getOrCreate('api.example.com', options);

        breaker.recordFailure();
        expect(events.length, 1);

        events.clear();

        await Future.delayed(const Duration(milliseconds: 20));
        breaker.allowRequest();
        breaker.recordFailure();

        expect(events.length, 1);
        expect(events[0].circuitId, 'api.example.com');
      });

      test('does not invoke callback when already in open state', () {
        final registry = CircuitBreakerRegistry();
        final events = <CircuitOpenEvent>[];

        registry.registerCircuitOpenCallback((event) {
          events.add(event);
        });

        final options = CircuitBreakerOptions(failureThreshold: 1);
        final breaker = registry.getOrCreate('api.example.com', options);

        breaker.recordFailure();
        expect(events.length, 1);

        events.clear();

        breaker.recordFailure();
        expect(events.length, 0);
      });
    });

    group('unregisterCircuitOpenCallback', () {
      test('removes a registered callback', () {
        final registry = CircuitBreakerRegistry();
        final events = <CircuitOpenEvent>[];

        void callback(CircuitOpenEvent event) {
          events.add(event);
        }

        registry.registerCircuitOpenCallback(callback);
        expect(registry.callbackCount, 1);

        final removed = registry.unregisterCircuitOpenCallback(callback);
        expect(removed, true);
        expect(registry.callbackCount, 0);
      });

      test('returns false if callback was not registered', () {
        final registry = CircuitBreakerRegistry();

        void callback(CircuitOpenEvent event) {}

        final removed = registry.unregisterCircuitOpenCallback(callback);
        expect(removed, false);
      });

      test('prevents callback from being invoked after unregistration', () {
        final registry = CircuitBreakerRegistry();
        final events = <CircuitOpenEvent>[];

        void callback(CircuitOpenEvent event) {
          events.add(event);
        }

        registry.registerCircuitOpenCallback(callback);
        registry.unregisterCircuitOpenCallback(callback);

        final options = CircuitBreakerOptions(failureThreshold: 1);
        final breaker = registry.getOrCreate('api.example.com', options);

        breaker.recordFailure();

        expect(events.length, 0);
      });

      test('removes only the first occurrence of duplicate callbacks', () {
        final registry = CircuitBreakerRegistry();
        final events = <CircuitOpenEvent>[];

        void callback(CircuitOpenEvent event) {
          events.add(event);
        }

        registry.registerCircuitOpenCallback(callback);
        registry.registerCircuitOpenCallback(callback);
        expect(registry.callbackCount, 2);

        registry.unregisterCircuitOpenCallback(callback);
        expect(registry.callbackCount, 1);

        final options = CircuitBreakerOptions(failureThreshold: 1);
        final breaker = registry.getOrCreate('api.example.com', options);

        breaker.recordFailure();

        expect(events.length, 1);
      });
    });

    group('clearCircuitOpenCallbacks', () {
      test('removes all registered callbacks', () {
        final registry = CircuitBreakerRegistry();

        registry.registerCircuitOpenCallback((event) {});
        registry.registerCircuitOpenCallback((event) {});
        registry.registerCircuitOpenCallback((event) {});

        expect(registry.callbackCount, 3);

        registry.clearCircuitOpenCallbacks();

        expect(registry.callbackCount, 0);
      });

      test('prevents all callbacks from being invoked after clearing', () {
        final registry = CircuitBreakerRegistry();
        final events = <CircuitOpenEvent>[];

        registry.registerCircuitOpenCallback((event) {
          events.add(event);
        });
        registry.registerCircuitOpenCallback((event) {
          events.add(event);
        });

        registry.clearCircuitOpenCallbacks();

        final options = CircuitBreakerOptions(failureThreshold: 1);
        final breaker = registry.getOrCreate('api.example.com', options);

        breaker.recordFailure();

        expect(events.length, 0);
      });
    });

    group('callbackCount', () {
      test('returns zero for new registry', () {
        final registry = CircuitBreakerRegistry();
        expect(registry.callbackCount, 0);
      });

      test('returns correct count after registrations', () {
        final registry = CircuitBreakerRegistry();

        registry.registerCircuitOpenCallback((event) {});
        expect(registry.callbackCount, 1);

        registry.registerCircuitOpenCallback((event) {});
        expect(registry.callbackCount, 2);

        registry.clearCircuitOpenCallbacks();
        expect(registry.callbackCount, 0);
      });
    });

    group('error handling in callbacks', () {
      test('continues invoking other callbacks if one throws', () {
        final registry = CircuitBreakerRegistry();
        final events = <CircuitOpenEvent>[];

        registry.registerCircuitOpenCallback((event) {
          throw Exception('Callback error');
        });
        registry.registerCircuitOpenCallback((event) {
          events.add(event);
        });

        final options = CircuitBreakerOptions(failureThreshold: 1);
        final breaker = registry.getOrCreate('api.example.com', options);

        expect(() => breaker.recordFailure(), returnsNormally);

        expect(events.length, 1);
      });

      test('handles multiple callback errors gracefully', () {
        final registry = CircuitBreakerRegistry();
        final events = <CircuitOpenEvent>[];

        registry.registerCircuitOpenCallback((event) {
          throw Exception('Error 1');
        });
        registry.registerCircuitOpenCallback((event) {
          throw Exception('Error 2');
        });
        registry.registerCircuitOpenCallback((event) {
          events.add(event);
        });

        final options = CircuitBreakerOptions(failureThreshold: 1);
        final breaker = registry.getOrCreate('api.example.com', options);

        expect(() => breaker.recordFailure(), returnsNormally);

        expect(events.length, 1);
      });
    });

    group('circuitId in CircuitBreaker', () {
      test('circuit breaker stores circuitId from registry', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        final breaker = registry.getOrCreate('api.example.com', options);

        expect(breaker.circuitId, 'api.example.com');
      });

      test('circuit breaker can be created without circuitId', () {
        final breaker = CircuitBreaker();

        expect(breaker.circuitId, isNull);
      });

      test('circuit breaker with circuitId invokes callback correctly', () {
        CircuitOpenEvent? receivedEvent;

        final breaker = CircuitBreaker(
          circuitId: 'test-circuit',
          options: const CircuitBreakerOptions(failureThreshold: 1),
          onCircuitOpen: (circuitId, openedAt) {
            receivedEvent = CircuitOpenEvent(
              circuitId: circuitId,
              openedAt: openedAt,
            );
          },
        );

        breaker.recordFailure();

        expect(receivedEvent, isNotNull);
        expect(receivedEvent!.circuitId, 'test-circuit');
      });
    });

    group('toString includes callback count', () {
      test('includes callback count in string representation', () {
        final registry = CircuitBreakerRegistry();

        expect(registry.toString(),
            'CircuitBreakerRegistry(count: 0, callbacks: 0)');

        registry.registerCircuitOpenCallback((event) {});
        expect(registry.toString(),
            'CircuitBreakerRegistry(count: 0, callbacks: 1)');

        registry.getOrCreate('api.example.com', const CircuitBreakerOptions());
        expect(registry.toString(),
            'CircuitBreakerRegistry(count: 1, callbacks: 1)');
      });
    });
  });
}
