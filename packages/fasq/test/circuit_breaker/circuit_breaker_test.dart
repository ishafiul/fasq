import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CircuitBreaker', () {
    test('initializes with closed state and default stats', () {
      final breaker = CircuitBreaker();

      expect(breaker.state, CircuitState.closed);
      expect(breaker.stats.failureCount, 0);
      expect(breaker.stats.successCount, 0);
      expect(breaker.stats.lastFailureTimestamp, isNull);
    });

    test('initializes with custom options', () {
      final options = CircuitBreakerOptions(
        failureThreshold: 10,
        resetTimeout: const Duration(seconds: 30),
        successThreshold: 2,
      );

      final breaker = CircuitBreaker(options: options);

      expect(breaker.options.failureThreshold, 10);
      expect(breaker.options.resetTimeout, const Duration(seconds: 30));
      expect(breaker.options.successThreshold, 2);
    });

    group('recordSuccess', () {
      test('resets counters in closed state', () {
        final breaker = CircuitBreaker();
        breaker.stats.failureCount = 3;
        breaker.stats.successCount = 2;

        breaker.recordSuccess();

        expect(breaker.stats.failureCount, 0);
        expect(breaker.stats.successCount, 0);
        expect(breaker.state, CircuitState.closed);
      });

      test('increments success count in halfOpen state', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            successThreshold: 2,
            resetTimeout: const Duration(milliseconds: 1),
          ),
        );

        breaker.recordFailure();
        await Future.delayed(const Duration(milliseconds: 10));
        breaker.allowRequest();
        expect(breaker.state, CircuitState.halfOpen);

        breaker.recordSuccess();

        expect(breaker.stats.successCount, 1);
        expect(breaker.state, CircuitState.halfOpen);
      });

      test('stays in halfOpen when success count is below threshold (N-1)',
          () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 10),
            successThreshold: 3,
          ),
        );

        breaker.recordFailure();
        await Future.delayed(const Duration(milliseconds: 20));
        breaker.allowRequest();
        expect(breaker.state, CircuitState.halfOpen);

        breaker.recordSuccess();
        expect(breaker.stats.successCount, 1);
        expect(breaker.state, CircuitState.halfOpen);

        breaker.recordSuccess();
        expect(breaker.stats.successCount, 2);
        expect(breaker.state, CircuitState.halfOpen);
      });

      test('transitions to closed exactly when success threshold is met (N)',
          () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 10),
            successThreshold: 3,
          ),
        );

        breaker.recordFailure();
        await Future.delayed(const Duration(milliseconds: 20));
        breaker.allowRequest();
        expect(breaker.state, CircuitState.halfOpen);

        breaker.stats.successCount = 2;
        breaker.recordSuccess();

        expect(breaker.state, CircuitState.closed);
        expect(breaker.stats.successCount, 0);
        expect(breaker.stats.failureCount, 0);
      });

      test('transitions from halfOpen to closed when threshold met', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 1),
            successThreshold: 2,
          ),
        );

        breaker.recordFailure();
        await Future.delayed(const Duration(milliseconds: 10));
        breaker.allowRequest();
        expect(breaker.state, CircuitState.halfOpen);
        breaker.stats.successCount = 1;
        breaker.stats.failureCount = 5;
        final oldTimestamp = DateTime.now();
        breaker.stats.lastFailureTimestamp = oldTimestamp;

        breaker.recordSuccess();

        expect(breaker.state, CircuitState.closed);
        expect(breaker.stats.successCount, 0);
        expect(breaker.stats.failureCount, 0);
        expect(breaker.stats.lastFailureTimestamp, isNull);
      });

      test('handles successThreshold of 1', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 10),
            successThreshold: 1,
          ),
        );

        breaker.recordFailure();
        await Future.delayed(const Duration(milliseconds: 20));
        breaker.allowRequest();
        expect(breaker.state, CircuitState.halfOpen);

        breaker.recordSuccess();

        expect(breaker.state, CircuitState.closed);
        expect(breaker.stats.successCount, 0);
      });
    });

    group('recordFailure', () {
      test('increments failure count in closed state', () {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(failureThreshold: 3),
        );

        breaker.recordFailure();

        expect(breaker.stats.failureCount, 1);
        expect(breaker.stats.lastFailureTimestamp, isNotNull);
        expect(breaker.state, CircuitState.closed);
      });

      test('stays closed when failure count is below threshold (N-1)', () {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 3,
            resetTimeout: const Duration(seconds: 60),
          ),
        );
        breaker.stats.failureCount = 1;

        breaker.recordFailure();

        expect(breaker.state, CircuitState.closed);
        expect(breaker.stats.failureCount, 2);
      });

      test('transitions to open exactly when threshold is met (N)', () {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 3,
            resetTimeout: const Duration(seconds: 60),
          ),
        );
        breaker.stats.failureCount = 2;

        breaker.recordFailure();

        expect(breaker.state, CircuitState.open);
        expect(breaker.stats.failureCount, 3);
        expect(breaker.stats.lastFailureTimestamp, isNotNull);
      });

      test('transitions from closed to open when threshold met', () {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 2,
            resetTimeout: const Duration(seconds: 60),
          ),
        );
        breaker.stats.failureCount = 1;

        breaker.recordFailure();

        expect(breaker.state, CircuitState.open);
        expect(breaker.stats.failureCount, 2);
        expect(breaker.stats.lastFailureTimestamp, isNotNull);
      });

      test('handles threshold of 1', () {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(seconds: 60),
          ),
        );

        breaker.recordFailure();

        expect(breaker.state, CircuitState.open);
        expect(breaker.stats.failureCount, 1);
      });

      test('transitions from halfOpen to open immediately', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 1),
          ),
        );

        breaker.recordFailure();
        await Future.delayed(const Duration(milliseconds: 10));
        breaker.allowRequest();
        expect(breaker.state, CircuitState.halfOpen);
        breaker.stats.failureCount = 0;

        breaker.recordFailure();

        expect(breaker.state, CircuitState.open);
        expect(breaker.stats.failureCount, 1);
        expect(breaker.stats.lastFailureTimestamp, isNotNull);
      });

      test('only updates timestamp in open state', () {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(seconds: 60),
          ),
        );

        breaker.recordFailure();
        expect(breaker.state, CircuitState.open);
        breaker.stats.failureCount = 5;
        final oldTimestamp = breaker.stats.lastFailureTimestamp!;

        breaker.recordFailure();

        expect(breaker.state, CircuitState.open);
        expect(breaker.stats.failureCount, 6);
        expect(breaker.stats.lastFailureTimestamp, isNot(oldTimestamp));
      });
    });

    group('allowRequest', () {
      test('always returns true in closed state', () {
        final breaker = CircuitBreaker();

        expect(breaker.allowRequest(), isTrue);
        expect(breaker.state, CircuitState.closed);
      });

      test('returns false in open state before timeout', () {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(seconds: 60),
          ),
        );

        breaker.recordFailure();
        expect(breaker.state, CircuitState.open);

        expect(breaker.allowRequest(), isFalse);
        expect(breaker.state, CircuitState.open);
      });

      test('transitions to halfOpen and returns true after timeout', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 100),
          ),
        );

        breaker.recordFailure();
        expect(breaker.state, CircuitState.open);
        breaker.stats.failureCount = 5;

        await Future.delayed(const Duration(milliseconds: 150));

        expect(breaker.allowRequest(), isTrue);
        expect(breaker.state, CircuitState.halfOpen);
        expect(breaker.stats.failureCount, 0);
        expect(breaker.stats.successCount, 0);
      });

      test('uses Future.delayed for timing control', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 50),
          ),
        );

        breaker.recordFailure();
        expect(breaker.state, CircuitState.open);
        expect(breaker.allowRequest(), isFalse);

        await Future.delayed(const Duration(milliseconds: 40));
        expect(breaker.allowRequest(), isFalse);
        expect(breaker.state, CircuitState.open);

        await Future.delayed(const Duration(milliseconds: 20));
        expect(breaker.allowRequest(), isTrue);
        expect(breaker.state, CircuitState.halfOpen);
      });

      test('precise moment of resetTimeout expiration', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 100),
          ),
        );

        breaker.recordFailure();
        expect(breaker.state, CircuitState.open);

        await Future.delayed(const Duration(milliseconds: 90));
        expect(breaker.allowRequest(), isFalse);

        await Future.delayed(const Duration(milliseconds: 20));
        expect(breaker.allowRequest(), isTrue);
        expect(breaker.state, CircuitState.halfOpen);
      });

      test('allows only first request in halfOpen state', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 1),
          ),
        );

        breaker.recordFailure();
        await Future.delayed(const Duration(milliseconds: 10));

        expect(breaker.allowRequest(), isTrue);
        expect(breaker.state, CircuitState.halfOpen);

        expect(breaker.allowRequest(), isFalse);
        expect(breaker.allowRequest(), isFalse);
      });

      test('returns false for subsequent requests in halfOpen', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 1),
          ),
        );

        breaker.recordFailure();
        await Future.delayed(const Duration(milliseconds: 10));
        breaker.allowRequest();

        expect(breaker.allowRequest(), isFalse);
      });

      test('allows requests in halfOpen when successCount > 0 and < threshold',
          () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 10),
            successThreshold: 3,
          ),
        );

        breaker.recordFailure();
        await Future.delayed(const Duration(milliseconds: 20));
        expect(breaker.allowRequest(), isTrue);
        expect(breaker.state, CircuitState.halfOpen);

        breaker.recordSuccess();
        expect(breaker.stats.successCount, 1);
        expect(breaker.allowRequest(), isTrue);

        breaker.recordSuccess();
        expect(breaker.stats.successCount, 2);
        expect(breaker.allowRequest(), isTrue);

        breaker.recordSuccess();
        expect(breaker.stats.successCount, 0);
        expect(breaker.state, CircuitState.closed);
      });

      test('returns false in halfOpen when no successes recorded yet',
          () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 10),
            successThreshold: 2,
          ),
        );

        breaker.recordFailure();
        await Future.delayed(const Duration(milliseconds: 20));
        expect(breaker.allowRequest(), isTrue);
        expect(breaker.state, CircuitState.halfOpen);

        expect(breaker.allowRequest(), isFalse);
      });

      test('handles halfOpen with successThreshold of 1', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 10),
            successThreshold: 1,
          ),
        );

        breaker.recordFailure();
        await Future.delayed(const Duration(milliseconds: 20));
        expect(breaker.allowRequest(), isTrue);
        expect(breaker.state, CircuitState.halfOpen);

        expect(breaker.allowRequest(), isFalse);
      });
    });

    group('state transitions', () {
      test('full cycle: closed -> open -> halfOpen -> closed', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 2,
            resetTimeout: const Duration(milliseconds: 100),
            successThreshold: 1,
          ),
        );

        expect(breaker.state, CircuitState.closed);

        breaker.recordFailure();
        expect(breaker.state, CircuitState.closed);

        breaker.recordFailure();
        expect(breaker.state, CircuitState.open);

        expect(breaker.allowRequest(), isFalse);

        await Future.delayed(const Duration(milliseconds: 150));

        expect(breaker.allowRequest(), isTrue);
        expect(breaker.state, CircuitState.halfOpen);

        breaker.recordSuccess();
        expect(breaker.state, CircuitState.closed);
      });

      test('halfOpen -> open on failure', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 1),
          ),
        );

        breaker.recordFailure();
        await Future.delayed(const Duration(milliseconds: 10));
        breaker.allowRequest();
        expect(breaker.state, CircuitState.halfOpen);

        breaker.recordFailure();

        expect(breaker.state, CircuitState.open);
      });
    });

    test('toString includes state and stats', () {
      final breaker = CircuitBreaker();
      final string = breaker.toString();

      expect(string, contains('CircuitBreaker'));
      expect(string, contains('state:'));
      expect(string, contains('stats:'));
    });

    group('async interleaving scenarios', () {
      test('handles rapid success/failure interleaving in closed state',
          () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 5,
            successThreshold: 1,
          ),
        );

        final futures = <Future>[];
        for (int i = 0; i < 10; i++) {
          if (i % 2 == 0) {
            futures.add(Future(() => breaker.recordSuccess()));
          } else {
            futures.add(Future(() => breaker.recordFailure()));
          }
        }

        await Future.wait(futures);

        expect(breaker.state, CircuitState.closed);
        expect(breaker.stats.failureCount, lessThanOrEqualTo(1));
        expect(breaker.stats.successCount, 0);
      });

      test('handles concurrent allowRequest calls in closed state', () async {
        final breaker = CircuitBreaker();

        final results = await Future.wait([
          Future(() => breaker.allowRequest()),
          Future(() => breaker.allowRequest()),
          Future(() => breaker.allowRequest()),
        ]);

        expect(results, everyElement(isTrue));
        expect(breaker.state, CircuitState.closed);
      });

      test('handles state transition during async operation', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 2,
            resetTimeout: const Duration(seconds: 1),
          ),
        );

        breaker.recordFailure();

        final future1 = Future(() async {
          await Future.delayed(const Duration(milliseconds: 10));
          return breaker.allowRequest();
        });

        final future2 = Future(() async {
          await Future.delayed(const Duration(milliseconds: 20));
          breaker.recordFailure();
          return breaker.state;
        });

        final results = await Future.wait([future1, future2]);

        expect(results[0], isTrue);
        expect(results[1], CircuitState.open);
      });
    });

    group('onCircuitOpen callback', () {
      test('invokes callback when circuit opens from closed state', () {
        String? capturedCircuitId;
        DateTime? capturedOpenedAt;

        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 2,
            resetTimeout: const Duration(seconds: 60),
          ),
          circuitId: 'test-circuit',
          onCircuitOpen: (circuitId, openedAt) {
            capturedCircuitId = circuitId;
            capturedOpenedAt = openedAt;
          },
        );

        breaker.stats.failureCount = 1;
        breaker.recordFailure();

        expect(capturedCircuitId, 'test-circuit');
        expect(capturedOpenedAt, isNotNull);
        expect(breaker.state, CircuitState.open);
      });

      test('invokes callback when circuit opens from halfOpen state', () async {
        String? capturedCircuitId;
        DateTime? capturedOpenedAt;

        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 10),
          ),
          circuitId: 'test-circuit-2',
          onCircuitOpen: (circuitId, openedAt) {
            capturedCircuitId = circuitId;
            capturedOpenedAt = openedAt;
          },
        );

        breaker.recordFailure();
        await Future.delayed(const Duration(milliseconds: 20));
        breaker.allowRequest();
        expect(breaker.state, CircuitState.halfOpen);

        capturedCircuitId = null;
        capturedOpenedAt = null;

        breaker.recordFailure();

        expect(capturedCircuitId, 'test-circuit-2');
        expect(capturedOpenedAt, isNotNull);
        expect(breaker.state, CircuitState.open);
      });

      test('does not invoke callback when already in open state', () {
        int callbackCount = 0;

        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(seconds: 60),
          ),
          circuitId: 'test-circuit',
          onCircuitOpen: (_, __) {
            callbackCount++;
          },
        );

        breaker.recordFailure();
        expect(callbackCount, 1);

        breaker.recordFailure();
        expect(callbackCount, 1);
      });

      test('works without callback', () {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(seconds: 60),
          ),
        );

        expect(() => breaker.recordFailure(), returnsNormally);
        expect(breaker.state, CircuitState.open);
      });

      test('works without circuitId', () {
        int callbackCount = 0;

        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(seconds: 60),
          ),
          onCircuitOpen: (_, __) {
            callbackCount++;
          },
        );

        breaker.recordFailure();

        expect(callbackCount, 0);
        expect(breaker.state, CircuitState.open);
      });
    });

    group('reset', () {
      test('resets circuit breaker to initial state', () {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 2,
            resetTimeout: const Duration(seconds: 1),
          ),
        );

        breaker.recordFailure();
        breaker.recordFailure();

        expect(breaker.state, CircuitState.open);
        expect(breaker.stats.failureCount, 2);
        expect(breaker.stats.lastFailureTimestamp, isNotNull);

        breaker.reset();

        expect(breaker.state, CircuitState.closed);
        expect(breaker.stats.failureCount, 0);
        expect(breaker.stats.successCount, 0);
        expect(breaker.stats.lastFailureTimestamp, isNull);
      });

      test('resets from halfOpen state', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(milliseconds: 1),
          ),
        );

        breaker.recordFailure();
        expect(breaker.state, CircuitState.open);

        await Future.delayed(const Duration(milliseconds: 10));
        breaker.allowRequest();

        expect(breaker.state, CircuitState.halfOpen);

        breaker.reset();

        expect(breaker.state, CircuitState.closed);
        expect(breaker.stats.failureCount, 0);
        expect(breaker.stats.successCount, 0);
      });

      test('resets from closed state', () {
        final breaker = CircuitBreaker();
        breaker.stats.failureCount = 3;
        breaker.stats.successCount = 2;

        breaker.reset();

        expect(breaker.state, CircuitState.closed);
        expect(breaker.stats.failureCount, 0);
        expect(breaker.stats.successCount, 0);
      });

      test('reset clears resetTimeout', () {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(seconds: 60),
          ),
        );

        breaker.recordFailure();
        expect(breaker.state, CircuitState.open);

        breaker.reset();

        expect(breaker.state, CircuitState.closed);
        expect(breaker.allowRequest(), isTrue);
      });
    });

    group('edge cases and boundary conditions', () {
      test('handles multiple rapid failures without opening prematurely', () {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 5,
            resetTimeout: const Duration(seconds: 60),
          ),
        );

        for (int i = 0; i < 4; i++) {
          breaker.recordFailure();
          expect(breaker.state, CircuitState.closed);
        }

        breaker.recordFailure();
        expect(breaker.state, CircuitState.open);
      });

      test('handles success after failures resets failure count in closed', () {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 5,
          ),
        );

        breaker.recordFailure();
        breaker.recordFailure();
        expect(breaker.stats.failureCount, 2);

        breaker.recordSuccess();

        expect(breaker.stats.failureCount, 0);
        expect(breaker.stats.successCount, 0);
        expect(breaker.state, CircuitState.closed);
      });

      test('handles open state with null resetTimeout', () {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 1,
            resetTimeout: const Duration(seconds: 60),
          ),
        );

        breaker.recordFailure();
        expect(breaker.state, CircuitState.open);

        final allowRequestResult = breaker.allowRequest();
        expect(allowRequestResult, isFalse);
      });

      test('statistics reset correctly on state transitions', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 2,
            resetTimeout: const Duration(milliseconds: 10),
            successThreshold: 2,
          ),
        );

        breaker.recordFailure();
        breaker.recordFailure();
        expect(breaker.state, CircuitState.open);
        expect(breaker.stats.failureCount, 2);

        await Future.delayed(const Duration(milliseconds: 20));
        breaker.allowRequest();
        expect(breaker.state, CircuitState.halfOpen);
        expect(breaker.stats.failureCount, 0);
        expect(breaker.stats.successCount, 0);

        breaker.recordSuccess();
        breaker.recordSuccess();
        expect(breaker.state, CircuitState.closed);
        expect(breaker.stats.successCount, 0);
        expect(breaker.stats.failureCount, 0);
      });

      test('lastFailureTimestamp updates on each failure', () async {
        final breaker = CircuitBreaker(
          options: CircuitBreakerOptions(
            failureThreshold: 3,
          ),
        );

        breaker.recordFailure();
        final timestamp1 = breaker.stats.lastFailureTimestamp;

        await Future.delayed(const Duration(milliseconds: 10));

        breaker.recordFailure();
        final timestamp2 = breaker.stats.lastFailureTimestamp;

        expect(timestamp2, isNot(equals(timestamp1)));
        expect(timestamp2!.isAfter(timestamp1!), isTrue);
      });
    });
  });
}
