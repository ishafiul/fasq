import 'package:fasq/fasq.dart';
import 'package:fasq/src/testing/leak_detector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Leak Detection Integration Tests', () {
    late QueryClient client;
    late LeakDetector detector;

    setUp(() async {
      await QueryClient.resetForTesting();
      // Set disposal delay to zero for immediate disposal in tests
      Query.disposalDelay = Duration.zero;
      client = QueryClient();
      detector = LeakDetector();
    });

    tearDown(() async {
      // Reset disposal delay
      Query.disposalDelay = const Duration(seconds: 5);
      await QueryClient.resetForTesting();
    });

    test('detects leaked query with active listener', () {
      final query = client.getQuery<String>(
        'leaked-query'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.addListener('test-widget');

      expect(
        () => detector.expectNoLeakedQueries(client),
        throwsA(isA<Exception>()),
      );
    });

    test('passes when query is disposed after removing listener', () {
      final query = client.getQuery<String>(
        'auto-disposed-query'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.addListener('test-widget');
      query.removeListener('test-widget');
      // With disposalDelay = Duration.zero, query should be disposed immediately

      expect(
        () => detector.expectNoLeakedQueries(client),
        returnsNormally,
      );
    });

    test('passes when query is properly disposed', () {
      final query = client.getQuery<String>(
        'properly-disposed-query'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.addListener('test-widget');
      query.removeListener('test-widget');
      query.dispose();

      expect(
        () => detector.expectNoLeakedQueries(client),
        returnsNormally,
      );
    });

    test('passes when all queries are removed from client', () {
      final query = client.getQuery<String>(
        'removed-query'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.addListener('test-widget');
      query.removeListener('test-widget');
      client.removeQuery('removed-query'.toQueryKey());

      expect(
        () => detector.expectNoLeakedQueries(client),
        returnsNormally,
      );
    });

    test('error message includes query key', () {
      final query = client.getQuery<String>(
        'test-leak-key'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.addListener('test-widget');

      try {
        detector.expectNoLeakedQueries(client);
        fail('Expected Exception to be thrown');
      } on Exception catch (e) {
        final message = e.toString();
        expect(message, contains('test-leak-key'));
      }
    });

    test('error message includes creation stack trace', () {
      final query = client.getQuery<String>(
        'stack-trace-test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.addListener('test-widget');

      try {
        detector.expectNoLeakedQueries(client);
        fail('Expected Exception to be thrown');
      } on Exception catch (e) {
        final message = e.toString();
        expect(message, contains('Created at:'));
        expect(message, contains('leak_detection_test.dart'));
      }
    });

    test('error message includes reference holders', () {
      final query = client.getQuery<String>(
        'holder-test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      const ownerId = 'my-test-widget';
      query.addListener(ownerId);

      try {
        detector.expectNoLeakedQueries(client);
        fail('Expected Exception to be thrown');
      } on Exception catch (e) {
        final message = e.toString();
        expect(message, contains('Held by'));
        expect(message, contains(ownerId));
      }
    });

    test('allows specified queries in allowedLeakKeys', () {
      final persistentQuery = client.getQuery<String>(
        'persistent-query'.toQueryKey(),
        queryFn: () async => 'data',
      );

      persistentQuery.addListener('test-widget');

      expect(
        () => detector.expectNoLeakedQueries(
          client,
          allowedLeakKeys: {'persistent-query'},
        ),
        returnsNormally,
      );
    });

    test('detects multiple leaked queries', () {
      final query1 = client.getQuery<String>(
        'leak-1'.toQueryKey(),
        queryFn: () async => 'data1',
      );
      final query2 = client.getQuery<String>(
        'leak-2'.toQueryKey(),
        queryFn: () async => 'data2',
      );

      query1.addListener('widget-1');
      query2.addListener('widget-2');

      try {
        detector.expectNoLeakedQueries(client);
        fail('Expected Exception to be thrown');
      } on Exception catch (e) {
        final message = e.toString();
        expect(message, contains('Found 2 leaked query(ies)'));
        expect(message, contains('leak-1'));
        expect(message, contains('leak-2'));
      }
    });

    testWidgets('passes when widget properly disposes query automatically',
        (tester) async {
      // QueryBuilder uses QueryClient.maybeInstance, so we need to ensure
      // the singleton is set. Since we create QueryClient() in setUp, it's already set.
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: QueryBuilder<String>(
              queryKey: 'widget-auto-dispose-test'.toQueryKey(),
              queryFn: () async => 'widget data',
              builder: (context, state) {
                return Text(state.data ?? 'loading');
              },
            ),
          ),
        ),
      );

      // Wait for QueryBuilder to initialize and fetch data
      await tester.pumpAndSettle();

      // Get the client instance that QueryBuilder is using
      final queryClient = QueryClient.maybeInstance ?? client;

      // Remove widget - QueryBuilder should automatically remove listener in dispose()
      await tester.pumpWidget(Container());

      // Wait for disposal to complete (with disposalDelay = Duration.zero, it's immediate)
      await tester.pump();

      // Verify no leaks - QueryBuilder should have cleaned up properly
      expect(
        () => detector.expectNoLeakedQueries(queryClient),
        returnsNormally,
        reason: 'Query should be disposed after widget removal',
      );
    });

    testWidgets('detects leaked query when manually created and not disposed',
        (tester) async {
      // Manually create a query without using QueryBuilder
      final query = client.getQuery<String>(
        'manual-query-leak'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.addListener('manual-listener');

      // Don't remove listener or dispose - this should be detected as a leak
      expect(
        () => detector.expectNoLeakedQueries(client),
        throwsA(isA<Exception>()),
      );
    });
  });
}
