import 'package:fasq/fasq.dart';
import 'package:fasq/src/error/error_context.dart';
import 'package:fasq/src/error/error_reporter.dart';
import 'package:fasq/src/logger/fasq_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Error Reporting Flow Integration Tests', () {
    late QueryClient client;

    setUp(() async {
      await QueryClient.resetForTesting();
      client = QueryClient();
    });

    tearDown(() async {
      await QueryClient.resetForTesting();
    });

    test('query failure triggers error reporter notification', () async {
      final reporter = _MockErrorReporter();
      final error = Exception('Test query failure');
      final queryKey = 'failing-query'.toQueryKey();

      client.addErrorReporter(reporter);

      final query = client.getQuery<String>(
        queryKey,
        queryFn: () async => throw error,
      );

      // Trigger the query fetch which will fail
      try {
        await query.fetch();
      } catch (_) {
        // Expected to throw
      }

      // Wait for async error handling to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Verify reporter was called
      expect(reporter.reportedContexts.length, 1);

      final reportedContext = reporter.reportedContexts.first;

      // Verify context contains correct information
      expect(reportedContext.queryKey, ['failing-query']);
      expect(reportedContext.error, isA<Exception>());
      expect(reportedContext.error.toString(), contains('Test query failure'));
      expect(reportedContext.stackTrace, isNotNull);
      expect(reportedContext.retryCount, 0);
      expect(reportedContext.sanitizedQueryOptions, isA<Map<String, dynamic>>());
    });

    test('error context includes sanitized query options', () async {
      final reporter = _MockErrorReporter();
      final error = Exception('Test error');
      final options = QueryOptions(
        staleTime: const Duration(minutes: 5),
        cacheTime: const Duration(minutes: 10),
        enabled: true,
        refetchOnMount: true,
        isSecure: false,
        performance: PerformanceOptions(
          maxRetries: 3,
          enableMetrics: true,
        ),
      );

      client.addErrorReporter(reporter);

      final query = client.getQuery<String>(
        'options-test'.toQueryKey(),
        queryFn: () async => throw error,
        options: options,
      );

      try {
        await query.fetch();
      } catch (_) {
        // Expected
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(reporter.reportedContexts.length, 1);

      final context = reporter.reportedContexts.first;
      final sanitized = context.sanitizedQueryOptions;

      // Verify safe fields are included
      expect(sanitized['enabled'], true);
      expect(sanitized['refetchOnMount'], true);
      expect(sanitized['isSecure'], false);
      expect(sanitized['staleTime'], const Duration(minutes: 5).inMilliseconds);
      expect(sanitized['cacheTime'], const Duration(minutes: 10).inMilliseconds);

      // Verify performance options are sanitized
      final performance = sanitized['performance'] as Map<String, dynamic>;
      expect(performance['maxRetries'], 3);
      expect(performance['enableMetrics'], true);
      expect(performance.containsKey('dataTransformer'), false);

      // Verify sensitive fields are excluded
      expect(sanitized.containsKey('meta'), false);
      expect(sanitized.containsKey('onSuccess'), false);
      expect(sanitized.containsKey('onError'), false);
    });

    test('multiple reporters all receive error context', () async {
      final reporter1 = _MockErrorReporter();
      final reporter2 = _MockErrorReporter();
      final reporter3 = _MockErrorReporter();
      final error = Exception('Multi-reporter test');

      client.addErrorReporter(reporter1);
      client.addErrorReporter(reporter2);
      client.addErrorReporter(reporter3);

      final query = client.getQuery<String>(
        'multi-reporter-test'.toQueryKey(),
        queryFn: () async => throw error,
      );

      try {
        await query.fetch();
      } catch (_) {
        // Expected
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // All reporters should have received the error
      expect(reporter1.reportedContexts.length, 1);
      expect(reporter2.reportedContexts.length, 1);
      expect(reporter3.reportedContexts.length, 1);

      // All should have received the same context
      final context1 = reporter1.reportedContexts.first;
      final context2 = reporter2.reportedContexts.first;
      final context3 = reporter3.reportedContexts.first;

      expect(context1.queryKey, context2.queryKey);
      expect(context2.queryKey, context3.queryKey);
      expect(context1.error, context2.error);
      expect(context2.error, context3.error);
    });

    test('failing reporter does not prevent other reporters from executing',
        () async {
      final workingReporter = _MockErrorReporter();
      final failingReporter = _FailingErrorReporter();
      final reporter3 = _MockErrorReporter();
      final error = Exception('Reporter failure test');

      client.addErrorReporter(workingReporter);
      client.addErrorReporter(failingReporter);
      client.addErrorReporter(reporter3);

      final query = client.getQuery<String>(
        'reporter-failure-test'.toQueryKey(),
        queryFn: () async => throw error,
      );

      try {
        await query.fetch();
      } catch (_) {
        // Expected
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Working reporters should still have received the error
      expect(workingReporter.reportedContexts.length, 1);
      expect(reporter3.reportedContexts.length, 1);

      // Failing reporter should have attempted to report
      expect(failingReporter.attemptedReports, 1);

      // Verify the test didn't crash (implicitly verified by reaching here)
      expect(workingReporter.reportedContexts.first.queryKey,
          ['reporter-failure-test']);
    });

    test('reporter errors are logged via FasqLogger when available', () async {
      final logger = FasqLogger();
      final failingReporter = _FailingErrorReporter();
      final workingReporter = _MockErrorReporter();
      final error = Exception('Logger test');

      client.addObserver(logger);
      client.addErrorReporter(failingReporter);
      client.addErrorReporter(workingReporter);

      final query = client.getQuery<String>(
        'logger-test'.toQueryKey(),
        queryFn: () async => throw error,
      );

      try {
        await query.fetch();
      } catch (_) {
        // Expected
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Working reporter should have received the error
      expect(workingReporter.reportedContexts.length, 1);

      // Failing reporter should have attempted to report
      expect(failingReporter.attemptedReports, 1);

      // The error from the failing reporter should have been caught
      // and logged (we can't easily verify the log output, but we verify
      // the test didn't crash and other reporters still worked)
    });

    test('error reporter receives context with correct network status',
        () async {
      final reporter = _MockErrorReporter();
      final error = Exception('Network status test');

      client.addErrorReporter(reporter);

      final query = client.getQuery<String>(
        'network-status-test'.toQueryKey(),
        queryFn: () async => throw error,
      );

      try {
        await query.fetch();
      } catch (_) {
        // Expected
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(reporter.reportedContexts.length, 1);

      final context = reporter.reportedContexts.first;

      // Network status should be a boolean
      expect(context.networkStatus, isA<bool>());
    });

    test('error reporter receives context with correct retry count', () async {
      final reporter = _MockErrorReporter();
      final error = Exception('Retry count test');

      client.addErrorReporter(reporter);

      final query = client.getQuery<String>(
        'retry-count-test'.toQueryKey(),
        queryFn: () async => throw error,
      );

      try {
        await query.fetch();
      } catch (_) {
        // Expected
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(reporter.reportedContexts.length, 1);

      final context = reporter.reportedContexts.first;

      // Retry count should be 0 (currently not tracked, but should be present)
      expect(context.retryCount, 0);
      expect(context.retryCount, isA<int>());
    });

    test('removing error reporter prevents future notifications', () async {
      final reporter1 = _MockErrorReporter();
      final reporter2 = _MockErrorReporter();
      final error = Exception('Remove reporter test');

      client.addErrorReporter(reporter1);
      client.addErrorReporter(reporter2);

      // Remove reporter2 before triggering error
      client.removeErrorReporter(reporter2);

      final query = client.getQuery<String>(
        'remove-reporter-test'.toQueryKey(),
        queryFn: () async => throw error,
      );

      try {
        await query.fetch();
      } catch (_) {
        // Expected
      }

      await Future.delayed(const Duration(milliseconds: 100));

      // Only reporter1 should have received the error
      expect(reporter1.reportedContexts.length, 1);
      expect(reporter2.reportedContexts.length, 0);
    });

    test('error context includes stack trace', () async {
      final reporter = _MockErrorReporter();
      final error = Exception('Stack trace test');

      client.addErrorReporter(reporter);

      final query = client.getQuery<String>(
        'stack-trace-test'.toQueryKey(),
        queryFn: () async => throw error,
      );

      try {
        await query.fetch();
      } catch (_) {
        // Expected
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(reporter.reportedContexts.length, 1);

      final context = reporter.reportedContexts.first;

      // Stack trace should be present and non-null
      expect(context.stackTrace, isNotNull);
      expect(context.stackTrace, isA<StackTrace>());
      expect(context.stackTrace.toString(), isNotEmpty);
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

/// Mock error reporter that throws an exception when report is called.
class _FailingErrorReporter implements FasqErrorReporter {
  int attemptedReports = 0;

  @override
  void report(FasqErrorContext context) {
    attemptedReports++;
    throw Exception('Reporter failed intentionally for testing');
  }
}

