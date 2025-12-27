import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await QueryClient.resetForTesting();
  });

  group('Query Circuit Breaker Integration', () {
    test('skips circuit breaker when registry is not provided', () async {
      final client = QueryClient();
      final query = client.getQuery<String>(
        'test'.toQueryKey(),
        () async => 'data',
      );

      await query.fetch();

      expect(query.state.data, 'data');
      expect(query.state.status, QueryStatus.success);

      await client.dispose();
    });

    test('uses query key as scope key by default', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);
      final query = client.getQuery<String>(
        'test-key'.toQueryKey(),
        () async => 'data',
      );

      await query.fetch();

      expect(query.state.data, 'data');
      expect(registry.contains('test-key'), isTrue);
      final breaker = registry.get('test-key');
      expect(breaker, isNotNull);
      expect(breaker!.stats.successCount, 0);

      await client.dispose();
    });

    test('uses custom circuitBreakerScope when provided', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);
      final query = client.getQuery<String>(
        'test-key'.toQueryKey(),
        () async => 'data',
        options: QueryOptions(
          circuitBreakerScope: 'api.example.com',
        ),
      );

      await query.fetch();

      expect(query.state.data, 'data');
      expect(registry.contains('api.example.com'), isTrue);
      expect(registry.contains('test-key'), isFalse);

      await client.dispose();
    });

    test('throws CircuitBreakerOpenException when circuit is open', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);
      final breakerOptions = CircuitBreakerOptions(
        failureThreshold: 1,
        resetTimeout: const Duration(seconds: 60),
      );

      final breaker = registry.getOrCreate('test-scope', breakerOptions);
      breaker.recordFailure();

      expect(breaker.state, CircuitState.open);
      expect(breaker.allowRequest(), isFalse);

      final query = client.getQuery<String>(
        'test'.toQueryKey(),
        () async => 'data',
        options: QueryOptions(
          circuitBreakerScope: 'test-scope',
          circuitBreaker: breakerOptions,
        ),
      );

      await expectLater(
        query.fetch(),
        throwsA(isA<CircuitBreakerOpenException>()),
      );

      expect(query.state.status, QueryStatus.error);
      expect(query.state.error, isA<CircuitBreakerOpenException>());

      await client.dispose();
    });

    test('records success when query completes successfully', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);
      final query = client.getQuery<String>(
        'test'.toQueryKey(),
        () async => 'data',
      );

      await query.fetch();

      final breaker = registry.get('test');
      expect(breaker, isNotNull);
      expect(breaker!.state, CircuitState.closed);
      expect(breaker.stats.failureCount, 0);
      expect(breaker.stats.successCount, 0);

      await client.dispose();
    });

    test('records failure for non-ignored exceptions', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);
      final query = client.getQuery<String>(
        'test'.toQueryKey(),
        () async {
          throw StateError('Network error');
        },
      );

      // Query.fetch() catches exceptions and stores them in state
      // It only rethrows CircuitBreakerOpenException
      await query.fetch();
      expect(query.state.error, isA<StateError>());

      final breaker = registry.get('test');
      expect(breaker, isNotNull);
      expect(breaker!.stats.failureCount, 1);
      expect(breaker.stats.lastFailureTimestamp, isNotNull);

      await client.dispose();
    });

    test('does not record failure for ignored exceptions', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);
      final breakerOptions = CircuitBreakerOptions(
        ignoreExceptions: [ArgumentError],
      );

      final query = client.getQuery<String>(
        'test'.toQueryKey(),
        () async {
          throw ArgumentError('Client error');
        },
        options: QueryOptions(
          circuitBreaker: breakerOptions,
        ),
      );

      // Query.fetch() catches exceptions and stores them in state
      // It only rethrows CircuitBreakerOpenException
      await query.fetch();
      expect(query.state.error, isA<ArgumentError>());

      final breaker = registry.get('test');
      expect(breaker, isNotNull);
      expect(breaker!.stats.failureCount, 0);

      await client.dispose();
    });

    test('uses custom circuit breaker options when provided', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);
      final customOptions = CircuitBreakerOptions(
        failureThreshold: 10,
        resetTimeout: const Duration(seconds: 30),
        successThreshold: 2,
      );

      final query = client.getQuery<String>(
        'test'.toQueryKey(),
        () async => 'data',
        options: QueryOptions(
          circuitBreaker: customOptions,
        ),
      );

      await query.fetch();

      final breaker = registry.get('test');
      expect(breaker, isNotNull);
      expect(breaker!.options.failureThreshold, 10);
      expect(breaker.options.resetTimeout, const Duration(seconds: 30));
      expect(breaker.options.successThreshold, 2);

      await client.dispose();
    });

    test('multiple queries with same scope share circuit breaker', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);
      final sharedScope = 'api.example.com';

      final query1 = client.getQuery<String>(
        'query1'.toQueryKey(),
        () async => 'data1',
        options: QueryOptions(
          circuitBreakerScope: sharedScope,
        ),
      );

      final query2 = client.getQuery<String>(
        'query2'.toQueryKey(),
        () async => 'data2',
        options: QueryOptions(
          circuitBreakerScope: sharedScope,
        ),
      );

      await query1.fetch();
      await query2.fetch();

      expect(registry.contains(sharedScope), isTrue);
      expect(registry.contains('query1'), isFalse);
      expect(registry.contains('query2'), isFalse);

      final breaker = registry.get(sharedScope);
      expect(breaker, isNotNull);

      await client.dispose();
    });

    test('circuit opens after threshold failures', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);
      final breakerOptions = CircuitBreakerOptions(
        failureThreshold: 3,
        resetTimeout: const Duration(seconds: 60),
      );

      final query = client.getQuery<String>(
        'test'.toQueryKey(),
        () async {
          throw StateError('Network error');
        },
        options: QueryOptions(
          circuitBreaker: breakerOptions,
        ),
      );

      for (int i = 0; i < 3; i++) {
        await query.fetch();
        expect(query.state.error, isA<StateError>());
      }

      final breaker = registry.get('test');
      expect(breaker, isNotNull);
      expect(breaker!.state, CircuitState.open);
      expect(breaker.stats.failureCount, 3);

      await expectLater(
        query.fetch(),
        throwsA(isA<CircuitBreakerOpenException>()),
      );

      await client.dispose();
    });

    test('circuit transitions to half-open after timeout', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);
      final breakerOptions = CircuitBreakerOptions(
        failureThreshold: 1,
        resetTimeout: const Duration(milliseconds: 50),
        // Use successThreshold > 1 so we can observe half-open state
        successThreshold: 2,
      );

      bool shouldFail = true;
      final query = client.getQuery<String>(
        'test'.toQueryKey(),
        () async {
          if (shouldFail) throw StateError('Network error');
          return 'success';
        },
        options: QueryOptions(
          circuitBreaker: breakerOptions,
        ),
      );

      await query.fetch();
      expect(query.state.error, isA<StateError>());

      final breaker = registry.get('test');
      expect(breaker, isNotNull);
      expect(breaker!.state, CircuitState.open);

      // Wait for reset timeout
      await Future.delayed(const Duration(milliseconds: 100));

      // Simulate recovery
      shouldFail = false;

      // First success in half-open state (allowRequest transitions to halfOpen)
      await query.fetch();
      expect(query.state.data, 'success');

      // After one success with successThreshold=2, should still be in halfOpen
      expect(breaker.state, CircuitState.halfOpen);
      expect(breaker.stats.successCount, 1);

      await client.dispose();
    });

    test('circuit closes after success threshold in half-open state', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);
      final breakerOptions = CircuitBreakerOptions(
        failureThreshold: 1,
        resetTimeout: const Duration(milliseconds: 50),
        successThreshold: 2,
      );

      bool shouldFail = true;
      final query = client.getQuery<String>(
        'test'.toQueryKey(),
        () async {
          if (shouldFail) throw StateError('Network error');
          return 'success';
        },
        options: QueryOptions(
          circuitBreaker: breakerOptions,
        ),
      );

      // Trigger failure to open the circuit
      await query.fetch();
      expect(query.state.error, isA<StateError>());

      final breaker = registry.get('test');
      expect(breaker, isNotNull);
      expect(breaker!.state, CircuitState.open);

      // Wait for reset timeout
      await Future.delayed(const Duration(milliseconds: 100));

      shouldFail = false;

      // First success - transitions to halfOpen then records success
      await query.fetch();
      expect(query.state.data, 'success');
      expect(breaker.state, CircuitState.halfOpen);
      expect(breaker.stats.successCount, 1);

      // Invalidate cache so second fetch goes through foreground path
      // (not unawaited background refetch)
      client.invalidateQuery('test'.toQueryKey());

      // Second success - should close the circuit
      await query.fetch();
      expect(breaker.state, CircuitState.closed);
      expect(breaker.stats.successCount, 0);

      await client.dispose();
    });

    test('works with retry logic', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);
      int attemptCount = 0;

      final query = client.getQuery<String>(
        'test'.toQueryKey(),
        () async {
          attemptCount++;
          if (attemptCount < 2) {
            throw StateError('Temporary error');
          }
          return 'success';
        },
        options: QueryOptions(
          performance: PerformanceOptions(
            maxRetries: 3,
            initialRetryDelay: const Duration(milliseconds: 10),
          ),
        ),
      );

      await query.fetch();

      expect(query.state.data, 'success');
      expect(attemptCount, 2);

      final breaker = registry.get('test');
      expect(breaker, isNotNull);
      expect(breaker!.stats.failureCount, 0);

      await client.dispose();
    });

    test('records failure after all retries exhausted', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);

      final query = client.getQuery<String>(
        'test'.toQueryKey(),
        () async {
          throw StateError('Persistent error');
        },
        options: QueryOptions(
          performance: PerformanceOptions(
            maxRetries: 2,
            initialRetryDelay: const Duration(milliseconds: 10),
          ),
        ),
      );

      await query.fetch();
      expect(query.state.error, isA<StateError>());

      final breaker = registry.get('test');
      expect(breaker, isNotNull);
      expect(breaker!.stats.failureCount, 1);

      await client.dispose();
    });

    test('CircuitBreakerOpenException includes scope information', () async {
      final registry = CircuitBreakerRegistry();
      final client = QueryClient(circuitBreakerRegistry: registry);
      final breakerOptions = CircuitBreakerOptions(
        failureThreshold: 1,
        resetTimeout: const Duration(seconds: 60),
      );

      final breaker = registry.getOrCreate('custom-scope', breakerOptions);
      breaker.recordFailure();

      final query = client.getQuery<String>(
        'test'.toQueryKey(),
        () async => 'data',
        options: QueryOptions(
          circuitBreakerScope: 'custom-scope',
          circuitBreaker: breakerOptions,
        ),
      );

      try {
        await query.fetch();
        fail('Expected CircuitBreakerOpenException');
      } on CircuitBreakerOpenException catch (e) {
        expect(e.circuitScope, 'custom-scope');
        expect(e.message, contains('custom-scope'));
      }

      await client.dispose();
    });
  });
}
