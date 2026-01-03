import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FasqErrorContext', () {
    late QueryClient client;
    late Query<String> query;
    late QueryOptions options;

    setUp(() {
      client = QueryClient();
      options = QueryOptions(
        staleTime: const Duration(minutes: 5),
        cacheTime: const Duration(minutes: 10),
        enabled: true,
        refetchOnMount: false,
        isSecure: false,
      );
      query = client.getQuery<String>(
        'test-key'.toQueryKey(),
        queryFn: () async => 'data',
        options: options,
      );
    });

    tearDown(() async {
      await QueryClient.resetForTesting();
    });

    test('fromQueryFailure creates context with all required fields', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      final context = FasqErrorContext.fromQueryFailure(
        query,
        options,
        error,
        stackTrace,
      );

      expect(context.queryKey, ['test-key']);
      expect(context.retryCount, 0);
      expect(context.staleTime, const Duration(minutes: 5));
      expect(context.error, error);
      expect(context.stackTrace, stackTrace);
      expect(context.sanitizedQueryOptions, isA<Map<String, dynamic>>());
    });

    test('fromQueryFailure converts QueryKey to list', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      final context = FasqErrorContext.fromQueryFailure(
        query,
        options,
        error,
        stackTrace,
      );

      expect(context.queryKey, isA<List<Object>>());
      expect(context.queryKey.length, 1);
      expect(context.queryKey.first, 'test-key');
    });

    test('fromQueryFailure captures network status', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      final context = FasqErrorContext.fromQueryFailure(
        query,
        options,
        error,
        stackTrace,
      );

      expect(context.networkStatus, isA<bool>());
    });

    test('fromQueryFailure handles null options', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      final context = FasqErrorContext.fromQueryFailure(
        query,
        null,
        error,
        stackTrace,
      );

      expect(context.staleTime, Duration.zero);
      expect(context.sanitizedQueryOptions, isEmpty);
    });

    group('PII Sanitization', () {
      test('sanitizes QueryOptions with only safe fields', () {
        final safeOptions = QueryOptions(
          enabled: true,
          refetchOnMount: true,
          isSecure: false,
          staleTime: const Duration(minutes: 5),
          cacheTime: const Duration(minutes: 10),
          maxAge: const Duration(hours: 1),
        );

        final error = Exception('Test error');
        final stackTrace = StackTrace.current;

        final context = FasqErrorContext.fromQueryFailure(
          query,
          safeOptions,
          error,
          stackTrace,
        );

        final sanitized = context.sanitizedQueryOptions;

        expect(sanitized['enabled'], true);
        expect(sanitized['refetchOnMount'], true);
        expect(sanitized['isSecure'], false);
        expect(
            sanitized['staleTime'], const Duration(minutes: 5).inMilliseconds);
        expect(
            sanitized['cacheTime'], const Duration(minutes: 10).inMilliseconds);
        expect(sanitized['maxAge'], const Duration(hours: 1).inMilliseconds);
      });

      test('excludes meta field from sanitized options', () {
        final optionsWithMeta = QueryOptions(
          staleTime: const Duration(minutes: 5),
          meta: QueryMeta(
            successMessage: 'User-specific message',
            errorMessage: 'Error with user data',
          ),
        );

        final error = Exception('Test error');
        final stackTrace = StackTrace.current;

        final context = FasqErrorContext.fromQueryFailure(
          query,
          optionsWithMeta,
          error,
          stackTrace,
        );

        final sanitized = context.sanitizedQueryOptions;

        expect(sanitized.containsKey('meta'), false);
        expect(
            sanitized['staleTime'], const Duration(minutes: 5).inMilliseconds);
      });

      test('excludes callbacks from sanitized options', () {
        final optionsWithCallbacks = QueryOptions(
          staleTime: const Duration(minutes: 5),
          onSuccess: () {},
          onError: (_) {},
        );

        final error = Exception('Test error');
        final stackTrace = StackTrace.current;

        final context = FasqErrorContext.fromQueryFailure(
          query,
          optionsWithCallbacks,
          error,
          stackTrace,
        );

        final sanitized = context.sanitizedQueryOptions;

        expect(sanitized.containsKey('onSuccess'), false);
        expect(sanitized.containsKey('onError'), false);
        expect(
            sanitized['staleTime'], const Duration(minutes: 5).inMilliseconds);
      });

      test('excludes circuit breaker fields from sanitized options', () {
        final optionsWithCircuitBreaker = QueryOptions(
          staleTime: const Duration(minutes: 5),
          circuitBreaker: const CircuitBreakerOptions(),
          circuitBreakerScope: 'api.example.com',
        );

        final error = Exception('Test error');
        final stackTrace = StackTrace.current;

        final context = FasqErrorContext.fromQueryFailure(
          query,
          optionsWithCircuitBreaker,
          error,
          stackTrace,
        );

        final sanitized = context.sanitizedQueryOptions;

        expect(sanitized.containsKey('circuitBreaker'), false);
        expect(sanitized.containsKey('circuitBreakerScope'), false);
        expect(
            sanitized['staleTime'], const Duration(minutes: 5).inMilliseconds);
      });

      test('sanitizes performance options excluding dataTransformer', () {
        final optionsWithPerformance = QueryOptions(
          staleTime: const Duration(minutes: 5),
          performance: PerformanceOptions(
            enableMetrics: true,
            maxRetries: 5,
            autoIsolate: true,
            enableHotCache: false,
            fetchTimeoutMs: 5000,
            isolateThreshold: 100,
            initialRetryDelay: const Duration(seconds: 2),
            retryBackoffMultiplier: 3.0,
            enableDataTransform: true,
            dataTransformer: (data) async => data, // Should be excluded
          ),
        );

        final error = Exception('Test error');
        final stackTrace = StackTrace.current;

        final context = FasqErrorContext.fromQueryFailure(
          query,
          optionsWithPerformance,
          error,
          stackTrace,
        );

        final sanitized = context.sanitizedQueryOptions;
        final performance = sanitized['performance'] as Map<String, dynamic>;

        expect(performance['enableMetrics'], true);
        expect(performance['maxRetries'], 5);
        expect(performance['autoIsolate'], true);
        expect(performance['enableHotCache'], false);
        expect(performance['fetchTimeoutMs'], 5000);
        expect(performance['isolateThreshold'], 100);
        expect(performance['initialRetryDelay'],
            const Duration(seconds: 2).inMilliseconds);
        expect(performance['retryBackoffMultiplier'], 3.0);
        expect(performance['enableDataTransform'], true);
        expect(performance.containsKey('dataTransformer'), false);
      });

      test('handles null performance options', () {
        final optionsWithoutPerformance = QueryOptions(
          staleTime: const Duration(minutes: 5),
        );

        final error = Exception('Test error');
        final stackTrace = StackTrace.current;

        final context = FasqErrorContext.fromQueryFailure(
          query,
          optionsWithoutPerformance,
          error,
          stackTrace,
        );

        final sanitized = context.sanitizedQueryOptions;

        expect(sanitized.containsKey('performance'), false);
      });
    });

    test('toString includes key information', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      final context = FasqErrorContext.fromQueryFailure(
        query,
        options,
        error,
        stackTrace,
      );

      final string = context.toString();

      expect(string, contains('FasqErrorContext'));
      expect(string, contains('test-key'));
      expect(string, contains('retryCount'));
      expect(string, contains('networkStatus'));
    });

    test('immutability - all fields are final', () {
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      final context = FasqErrorContext.fromQueryFailure(
        query,
        options,
        error,
        stackTrace,
      );

      expect(context.queryKey, isA<List<Object>>());
      expect(context.retryCount, isA<int>());
      expect(context.staleTime, isA<Duration>());
      expect(context.networkStatus, isA<bool>());
      expect(context.error, isA<Object>());
      expect(context.stackTrace, isA<StackTrace>());
      expect(context.sanitizedQueryOptions, isA<Map<String, dynamic>>());
    });
  });
}
