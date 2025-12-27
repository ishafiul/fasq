import 'package:fasq/fasq.dart';
import 'package:fasq/src/core/utils/fasq_time.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Fasq Circuit Breaker Integration Tests', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      FasqTime.reset();
      await QueryClient.resetForTesting();
    });

    tearDown(() async {
      FasqTime.reset();
      await QueryClient.resetForTesting();
    });

    group('Subtask 1: Setup Integration Test Environment', () {
      test('test environment is correctly configured', () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        bool shouldFail = false;

        final query = client.getQuery<String>(
          'test-env'.toQueryKey(),
          () async {
            if (shouldFail) {
              throw StateError('Simulated network error');
            }
            return 'success';
          },
        );

        await query.fetch();
        expect(query.state.data, 'success');
        expect(query.state.status, QueryStatus.success);

        await client.dispose();
      });

      test('mock backend can simulate success and failure modes', () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        bool shouldFail = false;
        int callCount = 0;

        final query = client.getQuery<String>(
          'mock-backend'.toQueryKey(),
          () async {
            callCount++;
            if (shouldFail) {
              throw StateError('Network error');
            }
            return 'data-$callCount';
          },
        );

        await query.fetch();
        expect(query.state.data, 'data-1');
        expect(callCount, 1);

        shouldFail = true;
        client.invalidateQuery('mock-backend'.toQueryKey());
        await query.fetch();
        expect(query.state.error, isA<StateError>());
        expect(callCount, 2);

        shouldFail = false;
        client.invalidateQuery('mock-backend'.toQueryKey());
        await query.fetch();
        expect(query.state.data, 'data-3');
        expect(callCount, 3);

        await client.dispose();
      });
    });

    group(
        'Subtask 2: Test Successful Queries with Circuit Breaker in Closed State',
        () {
      test('successful queries update circuit breaker metrics correctly',
          () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);

        final query = client.getQuery<String>(
          'success-test'.toQueryKey(),
          () async => 'data',
        );

        await query.fetch();
        expect(query.state.data, 'data');
        expect(query.state.status, QueryStatus.success);

        final breaker = registry.get('success-test');
        expect(breaker, isNotNull);
        expect(breaker!.state, CircuitState.closed);
        expect(breaker.stats.failureCount, 0);

        await client.dispose();
      });

      test('multiple successful queries keep circuit in closed state',
          () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);

        final query = client.getQuery<String>(
          'multi-success'.toQueryKey(),
          () async => 'data',
        );

        for (int i = 0; i < 5; i++) {
          await query.fetch();
          expect(query.state.data, 'data');
          expect(query.state.status, QueryStatus.success);

          final breaker = registry.get('multi-success');
          expect(breaker!.state, CircuitState.closed);
        }

        await client.dispose();
      });

      test('successful queries do not raise CircuitBreakerOpenException',
          () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);

        final query = client.getQuery<String>(
          'no-exception'.toQueryKey(),
          () async => 'data',
        );

        await query.fetch();
        expect(query.state.error, isNull);
        expect(query.state.data, 'data');

        await expectLater(
          query.fetch(),
          completes,
        );

        await client.dispose();
      });
    });

    group(
        'Subtask 3: Test Circuit Transition from Closed to Open on Consecutive Failures',
        () {
      test('circuit opens after reaching failure threshold', () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 3,
          resetTimeout: const Duration(seconds: 60),
        );

        final query = client.getQuery<String>(
          'failure-threshold'.toQueryKey(),
          () async {
            throw StateError('Network error');
          },
          options: QueryOptions(
            circuitBreaker: breakerOptions,
          ),
        );

        for (int i = 0; i < 3; i++) {
          await query.fetch();
          final breaker = registry.get('failure-threshold');
          expect(query.state.error, isA<StateError>());
          expect(
              breaker!.state, i < 2 ? CircuitState.closed : CircuitState.open);
        }

        final breaker = registry.get('failure-threshold');
        expect(breaker!.state, CircuitState.open);
        expect(breaker.stats.failureCount, 3);

        await expectLater(
          query.fetch(),
          throwsA(isA<CircuitBreakerOpenException>()),
        );

        await client.dispose();
      });

      test('queries fail immediately when circuit is open', () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 1,
          resetTimeout: const Duration(seconds: 60),
        );

        final query = client.getQuery<String>(
          'immediate-fail'.toQueryKey(),
          () async => 'data',
          options: QueryOptions(
            circuitBreaker: breakerOptions,
          ),
        );

        final breaker = registry.getOrCreate('immediate-fail', breakerOptions);
        breaker.recordFailure();

        expect(breaker.state, CircuitState.open);
        expect(breaker.allowRequest(), isFalse);

        await expectLater(
          query.fetch(),
          throwsA(isA<CircuitBreakerOpenException>()),
        );

        expect(query.state.error, isA<CircuitBreakerOpenException>());

        await client.dispose();
      });

      test('open circuit prevents backend service calls', () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 2,
          resetTimeout: const Duration(seconds: 60),
        );

        int backendCallCount = 0;
        final query = client.getQuery<String>(
          'no-backend-call'.toQueryKey(),
          () async {
            backendCallCount++;
            throw StateError('Network error');
          },
          options: QueryOptions(
            circuitBreaker: breakerOptions,
          ),
        );

        for (int i = 0; i < 2; i++) {
          await query.fetch();
        }

        expect(backendCallCount, 2);

        final breaker = registry.get('no-backend-call');
        expect(breaker!.state, CircuitState.open);

        await expectLater(
          query.fetch(),
          throwsA(isA<CircuitBreakerOpenException>()),
        );

        expect(backendCallCount, 2);

        await client.dispose();
      });
    });

    group(
        'Subtask 4: Test Circuit Transition from Open to Half-Open and Final State',
        () {
      test('circuit transitions to half-open after reset timeout', () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 50),
          successThreshold: 1,
        );

        bool shouldFail = true;
        final query = client.getQuery<String>(
          'half-open-test'.toQueryKey(),
          () async {
            if (shouldFail) throw StateError('Network error');
            return 'success';
          },
          options: QueryOptions(
            circuitBreaker: breakerOptions,
          ),
        );

        // First fetch - should fail and open circuit
        try {
          await query.fetch();
        } catch (_) {}

        final breaker = registry.get('half-open-test');
        expect(breaker, isNotNull);
        expect(breaker!.state, CircuitState.open);

        // Wait for reset timeout
        await Future.delayed(const Duration(milliseconds: 100));

        shouldFail = false;
        // Second fetch - should trigger transition to half-open
        await query.fetch();

        expect(
            breaker.state,
            CircuitState
                .closed); // transitioned to half-open then closed because successThreshold=1
        expect(breaker.stats.successCount, 0); // reset after closing

        await client.dispose();
      });

      test('circuit closes after success threshold in half-open state',
          () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 50),
          successThreshold: 2,
        );

        bool shouldFail = true;
        final query = client.getQuery<String>(
          'close-test'.toQueryKey(),
          () async {
            if (shouldFail) throw StateError('Network error');
            return 'success';
          },
          options: QueryOptions(
            circuitBreaker: breakerOptions,
          ),
        );

        try {
          await query.fetch();
        } catch (_) {}

        final breaker = registry.get('close-test');
        expect(breaker!.state, CircuitState.open);

        await Future.delayed(const Duration(milliseconds: 100));

        shouldFail = false;
        await query.fetch();
        expect(breaker.state, CircuitState.halfOpen);
        expect(breaker.stats.successCount, 1);

        client.invalidateQuery('close-test'.toQueryKey());
        await query.fetch();
        expect(breaker.state, CircuitState.closed);
        expect(breaker.stats.successCount, 0);

        await client.dispose();
      });

      test(
          'circuit transitions back to open if failure occurs in half-open state',
          () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 50),
          successThreshold: 2,
        );

        bool shouldFail = true;
        final query = client.getQuery<String>(
          'reopen-test'.toQueryKey(),
          () async {
            if (shouldFail) throw StateError('Network error');
            return 'success';
          },
          options: QueryOptions(
            circuitBreaker: breakerOptions,
          ),
        );

        try {
          await query.fetch();
        } catch (_) {}

        final breaker = registry.get('reopen-test');
        expect(breaker!.state, CircuitState.open);

        await Future.delayed(const Duration(milliseconds: 100));

        shouldFail = false;
        await query.fetch();
        expect(breaker.state, CircuitState.halfOpen);

        shouldFail = true;
        client.invalidateQuery('reopen-test'.toQueryKey());
        try {
          await query.fetch();
        } catch (_) {}
        expect(breaker.state, CircuitState.open);

        await expectLater(
          query.fetch(),
          throwsA(isA<CircuitBreakerOpenException>()),
        );

        await client.dispose();
      });

      test('success counter increments correctly in half-open state', () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 50),
          successThreshold: 3,
        );

        bool shouldFail = true;
        final query = client.getQuery<String>(
          'counter-test'.toQueryKey(),
          () async {
            if (shouldFail) throw StateError('Network error');
            return 'success';
          },
          options: QueryOptions(
            circuitBreaker: breakerOptions,
          ),
        );

        try {
          await query.fetch();
        } catch (_) {}

        final breaker = registry.get('counter-test');
        expect(breaker!.state, CircuitState.open);

        await Future.delayed(const Duration(milliseconds: 100));
        shouldFail = false;

        for (int i = 1; i <= 3; i++) {
          client.invalidateQuery('counter-test'.toQueryKey());
          await query.fetch();
          expect(breaker.state,
              i < 3 ? CircuitState.halfOpen : CircuitState.closed);
          expect(breaker.stats.successCount, i < 3 ? i : 0);
        }

        expect(breaker.state, CircuitState.closed);
        expect(breaker.stats.successCount, 0);

        await client.dispose();
      });
    });

    group(
        'Subtask 5: Verify CircuitBreakerOpenException Propagation and Error Handling',
        () {
      test('CircuitBreakerOpenException is correctly propagated', () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 1,
          resetTimeout: const Duration(seconds: 60),
        );

        final breaker = registry.getOrCreate('exception-test', breakerOptions);
        breaker.recordFailure();

        final query = client.getQuery<String>(
          'exception-test'.toQueryKey(),
          () async => 'data',
          options: QueryOptions(
            circuitBreakerScope: 'exception-test',
            circuitBreaker: breakerOptions,
          ),
        );

        CircuitBreakerOpenException? caughtException;
        try {
          await query.fetch();
        } on CircuitBreakerOpenException catch (e) {
          caughtException = e;
        }

        expect(caughtException, isNotNull);
        expect(caughtException!.circuitScope, 'exception-test');
        expect(caughtException.message, contains('exception-test'));

        await client.dispose();
      });

      test(
          'calling applications can catch and handle CircuitBreakerOpenException',
          () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 1,
          resetTimeout: const Duration(seconds: 60),
        );

        final breaker = registry.getOrCreate('catch-test', breakerOptions);
        breaker.recordFailure();

        final query = client.getQuery<String>(
          'catch-test'.toQueryKey(),
          () async => 'data',
          options: QueryOptions(
            circuitBreakerScope: 'catch-test',
            circuitBreaker: breakerOptions,
          ),
        );

        bool exceptionCaught = false;
        String? exceptionScope;

        try {
          await query.fetch();
        } on CircuitBreakerOpenException catch (e) {
          exceptionCaught = true;
          exceptionScope = e.circuitScope;
        }

        expect(exceptionCaught, isTrue);
        expect(exceptionScope, 'catch-test');

        await client.dispose();
      });

      test('CircuitBreakerOpenException contains correct scope information',
          () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 1,
          resetTimeout: const Duration(seconds: 60),
        );

        final customScope = 'api.example.com/users';
        final breaker = registry.getOrCreate(customScope, breakerOptions);
        breaker.recordFailure();

        final query = client.getQuery<String>(
          'scope-test'.toQueryKey(),
          () async => 'data',
          options: QueryOptions(
            circuitBreakerScope: customScope,
            circuitBreaker: breakerOptions,
          ),
        );

        await expectLater(
          query.fetch(),
          throwsA(
            predicate<CircuitBreakerOpenException>(
              (e) => e.circuitScope == customScope,
            ),
          ),
        );

        await client.dispose();
      });
    });

    group('Cross-Query Isolation Tests', () {
      test('multiple queries with same scope share circuit breaker state',
          () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 2,
          resetTimeout: const Duration(seconds: 60),
        );

        final sharedScope = 'api.example.com';
        bool shouldFail = true;

        final query1 = client.getQuery<String>(
          'query1'.toQueryKey(),
          () async {
            if (shouldFail) throw StateError('Network error');
            return 'data1';
          },
          options: QueryOptions(
            circuitBreakerScope: sharedScope,
            circuitBreaker: breakerOptions,
          ),
        );

        final query2 = client.getQuery<String>(
          'query2'.toQueryKey(),
          () async {
            if (shouldFail) throw StateError('Network error');
            return 'data2';
          },
          options: QueryOptions(
            circuitBreakerScope: sharedScope,
            circuitBreaker: breakerOptions,
          ),
        );

        await query1.fetch();
        expect(query1.state.error, isA<StateError>());

        await query2.fetch();
        expect(query2.state.error, isA<StateError>());

        final breaker = registry.get(sharedScope);
        expect(breaker!.state, CircuitState.open);

        await expectLater(
          query1.fetch(),
          throwsA(isA<CircuitBreakerOpenException>()),
        );

        await expectLater(
          query2.fetch(),
          throwsA(isA<CircuitBreakerOpenException>()),
        );

        await client.dispose();
      });

      test(
          'queries with different scopes maintain independent circuit breakers',
          () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 1,
          resetTimeout: const Duration(seconds: 60),
        );

        final query1 = client.getQuery<String>(
          'query1'.toQueryKey(),
          () async => 'data1',
          options: QueryOptions(
            circuitBreakerScope: 'api1.example.com',
            circuitBreaker: breakerOptions,
          ),
        );

        final query2 = client.getQuery<String>(
          'query2'.toQueryKey(),
          () async => 'data2',
          options: QueryOptions(
            circuitBreakerScope: 'api2.example.com',
            circuitBreaker: breakerOptions,
          ),
        );

        final breaker1 =
            registry.getOrCreate('api1.example.com', breakerOptions);
        breaker1.recordFailure();

        final breaker2 =
            registry.getOrCreate('api2.example.com', breakerOptions);

        expect(breaker1.state, CircuitState.open);
        expect(breaker2.state, CircuitState.closed);

        await expectLater(
          query1.fetch(),
          throwsA(isA<CircuitBreakerOpenException>()),
        );

        await query2.fetch();
        expect(query2.state.data, 'data2');

        await client.dispose();
      });
    });

    group('Widget Integration Tests', () {
      testWidgets('QueryBuilder displays error when circuit is open',
          (tester) async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 1,
          resetTimeout: const Duration(seconds: 60),
        );

        final breaker = registry.getOrCreate('widget-test', breakerOptions);
        breaker.recordFailure();

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: QueryBuilder<String>(
                queryKey: 'widget-test'.toQueryKey(),
                queryFn: () async => 'data',
                options: QueryOptions(
                  circuitBreakerScope: 'widget-test',
                  circuitBreaker: breakerOptions,
                ),
                builder: (context, state) {
                  if (state.isLoading) {
                    return const CircularProgressIndicator();
                  }
                  if (state.hasError) {
                    if (state.error is CircuitBreakerOpenException) {
                      return const Text('Service Temporarily Unavailable');
                    }
                    return Text('Error: ${state.error}');
                  }
                  if (state.hasData) {
                    return Text('Data: ${state.data}');
                  }
                  return const Text('Idle');
                },
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.text('Service Temporarily Unavailable'), findsOneWidget);

        await client.dispose();
      });

      test('Query recovers when circuit closes', () async {
        final registry = CircuitBreakerRegistry();
        final client = QueryClient(circuitBreakerRegistry: registry);
        final breakerOptions = CircuitBreakerOptions(
          failureThreshold: 1,
          resetTimeout: const Duration(milliseconds: 50),
          successThreshold: 1,
        );

        bool shouldFail = true;
        final query = client.getQuery<String>(
          'recovery-test'.toQueryKey(),
          () async {
            if (shouldFail) throw StateError('Network error');
            return 'recovered data';
          },
          options: QueryOptions(
            circuitBreaker: breakerOptions,
          ),
        );

        try {
          await query.fetch();
        } catch (_) {}

        final breaker = registry.get('recovery-test');
        expect(breaker!.state, CircuitState.open);

        await Future.delayed(const Duration(milliseconds: 100));
        shouldFail = false;

        await query.fetch();
        expect(breaker.state, CircuitState.closed);
        expect(query.state.data, 'recovered data');

        await client.dispose();
      });
    });
  });
}
