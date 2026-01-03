import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FasqErrorReporter', () {
    test('can be implemented and called', () async {
      await QueryClient.resetForTesting();
      final reporter = _MockErrorReporter();
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      final query = QueryClient().getQuery<String>(
        'test-key'.toQueryKey(),
        queryFn: () async => 'data',
      );

      final context = FasqErrorContext.fromQueryFailure(
        query,
        null,
        error,
        stackTrace,
      );

      expect(() => reporter.report(context), returnsNormally);
      expect(reporter.reportedContexts.length, 1);
      expect(reporter.reportedContexts.first, context);
    });

    test('can handle multiple reports', () async {
      await QueryClient.resetForTesting();
      final reporter = _MockErrorReporter();
      final error1 = Exception('Error 1');
      final error2 = Exception('Error 2');
      final stackTrace = StackTrace.current;

      final query1 = QueryClient().getQuery<String>(
        'key1'.toQueryKey(),
        queryFn: () async => 'data1',
      );
      final query2 = QueryClient().getQuery<String>(
        'key2'.toQueryKey(),
        queryFn: () async => 'data2',
      );

      final context1 = FasqErrorContext.fromQueryFailure(
        query1,
        null,
        error1,
        stackTrace,
      );
      final context2 = FasqErrorContext.fromQueryFailure(
        query2,
        null,
        error2,
        stackTrace,
      );

      reporter.report(context1);
      reporter.report(context2);

      expect(reporter.reportedContexts.length, 2);
      expect(reporter.reportedContexts[0].queryKey, ['key1']);
      expect(reporter.reportedContexts[1].queryKey, ['key2']);
    });

    test('can access all context fields in report method', () async {
      await QueryClient.resetForTesting();
      final reporter = _MockErrorReporter();
      final error = Exception('Test error');
      final stackTrace = StackTrace.current;

      final options = QueryOptions(
        staleTime: const Duration(minutes: 5),
        enabled: true,
      );

      final query = QueryClient().getQuery<String>(
        'test-key'.toQueryKey(),
        queryFn: () async => 'data',
        options: options,
      );

      final context = FasqErrorContext.fromQueryFailure(
        query,
        options,
        error,
        stackTrace,
      );

      reporter.report(context);

      final reportedContext = reporter.reportedContexts.first;

      expect(reportedContext.queryKey, ['test-key']);
      expect(reportedContext.retryCount, 0);
      expect(reportedContext.staleTime, const Duration(minutes: 5));
      expect(reportedContext.error, error);
      expect(reportedContext.stackTrace, stackTrace);
      expect(
          reportedContext.sanitizedQueryOptions, isA<Map<String, dynamic>>());
    });

    test('can be used with QueryClient.addErrorReporter', () async {
      await QueryClient.resetForTesting();
      final client = QueryClient();
      final reporter = _MockErrorReporter();
      final error = Exception('Test error');

      client.addErrorReporter(reporter);

      final query = client.getQuery<String>(
        'test-key'.toQueryKey(),
        queryFn: () async => throw error,
      );

      // Trigger an error by fetching
      try {
        await query.fetch();
      } catch (_) {
        // Expected to throw
      }

      // Wait for async error handling to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify reporter was called with the error
      expect(reporter.reportedContexts.length, 1);
      expect(reporter.reportedContexts.first.queryKey, ['test-key']);
      expect(reporter.reportedContexts.first.error, isA<Exception>());
    });
  });
}

/// Mock implementation of FasqErrorReporter for testing.
class _MockErrorReporter implements FasqErrorReporter {
  final List<FasqErrorContext> reportedContexts = [];

  @override
  void report(FasqErrorContext context) {
    reportedContexts.add(context);
  }
}
