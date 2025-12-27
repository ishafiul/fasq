import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircuitBreakerRegistry', () {
    test('initializes with empty registry', () {
      final registry = CircuitBreakerRegistry();

      expect(registry.count, 0);
      expect(registry.contains('test'), false);
      expect(registry.get('test'), isNull);
    });

    group('getOrCreate', () {
      test('creates new circuit breaker for new scope key', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions(
          failureThreshold: 10,
          resetTimeout: const Duration(seconds: 30),
          successThreshold: 2,
        );

        final breaker = registry.getOrCreate('api.example.com', options);

        expect(breaker, isNotNull);
        expect(breaker.state, CircuitState.closed);
        expect(breaker.options.failureThreshold, 10);
        expect(breaker.options.resetTimeout, const Duration(seconds: 30));
        expect(breaker.options.successThreshold, 2);
        expect(registry.count, 1);
        expect(registry.contains('api.example.com'), true);
      });

      test('returns same instance for same scope key', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions(failureThreshold: 5);

        final breaker1 = registry.getOrCreate('api.example.com', options);
        final breaker2 = registry.getOrCreate('api.example.com', options);

        expect(identical(breaker1, breaker2), true);
        expect(registry.count, 1);
      });

      test('returns different instances for different scope keys', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions(failureThreshold: 5);

        final breaker1 = registry.getOrCreate('api.example.com', options);
        final breaker2 = registry.getOrCreate('api.other.com', options);

        expect(identical(breaker1, breaker2), false);
        expect(registry.count, 2);
      });

      test('uses provided options only when creating new breaker', () {
        final registry = CircuitBreakerRegistry();
        final options1 = CircuitBreakerOptions(failureThreshold: 5);
        final options2 = CircuitBreakerOptions(failureThreshold: 10);

        final breaker1 = registry.getOrCreate('api.example.com', options1);
        final breaker2 = registry.getOrCreate('api.example.com', options2);

        expect(identical(breaker1, breaker2), true);
        expect(breaker1.options.failureThreshold, 5);
        expect(breaker2.options.failureThreshold, 5);
      });

      test('maintains isolation between different scopes', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions(
          failureThreshold: 2,
          resetTimeout: const Duration(seconds: 1),
        );

        final breaker1 = registry.getOrCreate('api.example.com', options);
        final breaker2 = registry.getOrCreate('api.other.com', options);

        breaker1.recordFailure();
        breaker1.recordFailure();

        expect(breaker1.state, CircuitState.open);
        expect(breaker2.state, CircuitState.closed);
        expect(breaker2.stats.failureCount, 0);
      });
    });

    group('clearAll', () {
      test('removes all circuit breakers from registry', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        registry.getOrCreate('api.example.com', options);
        registry.getOrCreate('api.other.com', options);

        expect(registry.count, 2);

        registry.clearAll();

        expect(registry.count, 0);
        expect(registry.contains('api.example.com'), false);
        expect(registry.contains('api.other.com'), false);
      });

      test('allows creating new breakers after clearing', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        registry.getOrCreate('api.example.com', options);
        registry.clearAll();

        final newBreaker = registry.getOrCreate('api.example.com', options);

        expect(newBreaker, isNotNull);
        expect(registry.count, 1);
      });
    });

    group('reset', () {
      test('resets circuit breaker to closed state', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions(
          failureThreshold: 2,
          resetTimeout: const Duration(seconds: 1),
        );

        final breaker = registry.getOrCreate('api.example.com', options);

        breaker.recordFailure();
        breaker.recordFailure();

        expect(breaker.state, CircuitState.open);
        expect(breaker.stats.failureCount, 2);

        registry.reset('api.example.com');

        expect(breaker.state, CircuitState.closed);
        expect(breaker.stats.failureCount, 0);
        expect(breaker.stats.successCount, 0);
        expect(breaker.stats.lastFailureTimestamp, isNull);
      });

      test('does nothing if scope key does not exist', () {
        final registry = CircuitBreakerRegistry();

        expect(() => registry.reset('nonexistent'), returnsNormally);
        expect(registry.count, 0);
      });

      test('resets only the specified circuit breaker', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions(failureThreshold: 2);

        final breaker1 = registry.getOrCreate('api.example.com', options);
        final breaker2 = registry.getOrCreate('api.other.com', options);

        breaker1.recordFailure();
        breaker1.recordFailure();
        breaker2.recordFailure();

        expect(breaker1.state, CircuitState.open);
        expect(breaker2.state, CircuitState.closed);

        registry.reset('api.example.com');

        expect(breaker1.state, CircuitState.closed);
        expect(breaker2.state, CircuitState.closed);
        expect(breaker2.stats.failureCount, 1);
      });
    });

    group('contains', () {
      test('returns true for existing scope key', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        registry.getOrCreate('api.example.com', options);

        expect(registry.contains('api.example.com'), true);
      });

      test('returns false for non-existent scope key', () {
        final registry = CircuitBreakerRegistry();

        expect(registry.contains('api.example.com'), false);
      });
    });

    group('get', () {
      test('returns circuit breaker for existing scope key', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        final created = registry.getOrCreate('api.example.com', options);
        final retrieved = registry.get('api.example.com');

        expect(retrieved, isNotNull);
        expect(identical(created, retrieved), true);
      });

      test('returns null for non-existent scope key', () {
        final registry = CircuitBreakerRegistry();

        expect(registry.get('api.example.com'), isNull);
      });
    });

    group('count', () {
      test('returns correct count after operations', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        expect(registry.count, 0);

        registry.getOrCreate('api.example.com', options);
        expect(registry.count, 1);

        registry.getOrCreate('api.other.com', options);
        expect(registry.count, 2);

        registry.getOrCreate('api.example.com', options);
        expect(registry.count, 2);

        registry.clearAll();
        expect(registry.count, 0);
      });
    });

    group('toString', () {
      test('returns string representation with count', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        expect(registry.toString(),
            'CircuitBreakerRegistry(count: 0, callbacks: 0)');

        registry.getOrCreate('api.example.com', options);
        expect(registry.toString(),
            'CircuitBreakerRegistry(count: 1, callbacks: 0)');
      });
    });

    group('edge cases and advanced scenarios', () {
      test('handles empty string scope key', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        final breaker = registry.getOrCreate('', options);

        expect(breaker, isNotNull);
        expect(registry.contains(''), true);
        expect(breaker.circuitId, '');
      });

      test('handles very long scope keys', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();
        final longKey = 'a' * 1000;

        final breaker = registry.getOrCreate(longKey, options);

        expect(breaker, isNotNull);
        expect(registry.contains(longKey), true);
        expect(breaker.circuitId, longKey);
      });

      test('maintains isolation with many circuit breakers', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions(
          failureThreshold: 1,
        );

        final breakers = <CircuitBreaker>[];
        for (int i = 0; i < 100; i++) {
          final breaker = registry.getOrCreate('scope-$i', options);
          breakers.add(breaker);
        }

        expect(registry.count, 100);

        breakers[0].recordFailure();
        expect(breakers[0].state, CircuitState.open);
        expect(breakers[1].state, CircuitState.closed);
        expect(breakers[99].state, CircuitState.closed);
      });

      test('getOrCreate with same key returns same instance after clearAll',
          () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        final breaker1 = registry.getOrCreate('api.example.com', options);
        registry.clearAll();
        final breaker2 = registry.getOrCreate('api.example.com', options);

        expect(identical(breaker1, breaker2), false);
        expect(registry.count, 1);
      });

      test('reset works on breaker retrieved after getOrCreate', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions(
          failureThreshold: 1,
        );

        final breaker = registry.getOrCreate('api.example.com', options);
        breaker.recordFailure();
        expect(breaker.state, CircuitState.open);

        registry.reset('api.example.com');
        expect(breaker.state, CircuitState.closed);

        final retrieved = registry.get('api.example.com');
        expect(retrieved, isNotNull);
        expect(retrieved!.state, CircuitState.closed);
      });

      test('handles concurrent getOrCreate calls for same key', () async {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        final futures = <Future<CircuitBreaker>>[];
        for (int i = 0; i < 10; i++) {
          futures.add(
              Future(() => registry.getOrCreate('api.example.com', options)));
        }

        final breakers = await Future.wait(futures);

        final firstBreaker = breakers[0];
        for (final breaker in breakers) {
          expect(identical(firstBreaker, breaker), true);
        }
        expect(registry.count, 1);
      });

      test('handles concurrent getOrCreate calls for different keys', () async {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        final futures = <Future<CircuitBreaker>>[];
        for (int i = 0; i < 10; i++) {
          futures.add(Future(
              () => registry.getOrCreate('api-$i.example.com', options)));
        }

        final breakers = await Future.wait(futures);

        for (int i = 0; i < breakers.length; i++) {
          for (int j = i + 1; j < breakers.length; j++) {
            expect(identical(breakers[i], breakers[j]), false);
          }
        }
        expect(registry.count, 10);
      });

      test('get returns null after clearAll', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        registry.getOrCreate('api.example.com', options);
        expect(registry.get('api.example.com'), isNotNull);

        registry.clearAll();
        expect(registry.get('api.example.com'), isNull);
      });

      test('contains returns false after clearAll', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        registry.getOrCreate('api.example.com', options);
        expect(registry.contains('api.example.com'), true);

        registry.clearAll();
        expect(registry.contains('api.example.com'), false);
      });

      test('count is accurate after mixed operations', () {
        final registry = CircuitBreakerRegistry();
        final options = CircuitBreakerOptions();

        expect(registry.count, 0);

        registry.getOrCreate('scope1', options);
        registry.getOrCreate('scope2', options);
        expect(registry.count, 2);

        registry.getOrCreate('scope1', options);
        expect(registry.count, 2);

        registry.reset('scope1');
        expect(registry.count, 2);

        registry.clearAll();
        expect(registry.count, 0);

        registry.getOrCreate('scope3', options);
        expect(registry.count, 1);
      });
    });
  });
}
