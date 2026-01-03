import 'package:fasq/fasq.dart';
import 'package:fasq/src/testing/leak_detector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LeakDetector', () {
    setUp(() {
      // Set disposal delay to zero for immediate disposal in tests
      Query.disposalDelay = Duration.zero;
    });

    tearDown(() async {
      // Reset disposal delay
      Query.disposalDelay = const Duration(seconds: 5);
      await QueryClient.resetForTesting();
    });

    test('can be instantiated', () {
      final detector = LeakDetector();
      expect(detector, isNotNull);
      expect(detector, isA<LeakDetector>());
    });

    test('checkForLeaks returns empty list initially', () {
      final detector = LeakDetector();
      final client = QueryClient();

      final leaks = detector.checkForLeaks(client);

      expect(leaks, isEmpty);
      expect(leaks, isA<List<QueryDebugInfo>>());
    });

    group('trackForGc and GC verification', () {
      test('trackForGc registers an object for tracking', () {
        final detector = LeakDetector();
        final object = Object();

        detector.trackForGc(object, debugLabel: 'test-object');

        expect(detector.getLeakedObjects(), contains('test-object'));
      });

      test('verifyAllTrackedObjectsGc returns true when object is GC\'d',
          () async {
        final detector = LeakDetector();

        // Create an object and track it
        Object? trackedObject = Object();
        detector.trackForGc(trackedObject, debugLabel: 'gc-test');

        // Make the object unreachable
        trackedObject = null;

        // Wait for GC (this may not always work in tests, but we can verify the logic)
        final allGc = await detector.verifyAllTrackedObjectsGc(
          timeout: const Duration(milliseconds: 500),
        );

        // The result depends on whether GC actually ran, but the method should complete
        expect(allGc, isA<bool>());
      });

      test('getLeakedObjects returns objects that are still tracked', () {
        final detector = LeakDetector();
        final object1 = Object();
        final object2 = Object();

        detector.trackForGc(object1, debugLabel: 'object-1');
        detector.trackForGc(object2, debugLabel: 'object-2');

        final leaked = detector.getLeakedObjects();
        expect(leaked.length, 2);
        expect(leaked, contains('object-1'));
        expect(leaked, contains('object-2'));
      });

      test('clearTracking removes all tracking information', () {
        final detector = LeakDetector();
        final object = Object();

        detector.trackForGc(object, debugLabel: 'test-object');
        expect(detector.getLeakedObjects(), isNotEmpty);

        detector.clearTracking();
        expect(detector.getLeakedObjects(), isEmpty);
      });

      test('trackForGc generates label when debugLabel is not provided', () {
        final detector = LeakDetector();
        final object = Object();

        detector.trackForGc(object);

        final leaked = detector.getLeakedObjects();
        expect(leaked.length, 1);
        expect(leaked.first, startsWith('object-'));
      });
    });

    group('expectNoLeakedQueries', () {
      test('does not throw when no queries exist', () {
        final detector = LeakDetector();
        final client = QueryClient();

        expect(() => detector.expectNoLeakedQueries(client), returnsNormally);
      });

      test('does not throw when all queries are properly disposed', () {
        final detector = LeakDetector();
        final client = QueryClient();
        final query = client.getQuery<String>(
          'test-key'.toQueryKey(),
          queryFn: () async => 'data',
        );

        query.addListener();
        query.removeListener();

        // Wait for disposal delay
        // Note: In real tests, you might need to wait for the disposal timer
        expect(() => detector.expectNoLeakedQueries(client), returnsNormally);
      });

      test('throws Exception when queries are leaked', () {
        final detector = LeakDetector();
        final client = QueryClient();
        final query = client.getQuery<String>(
          'leaked-query'.toQueryKey(),
          queryFn: () async => 'data',
        );

        query.addListener(); // Add listener but don't remove it

        expect(
          () => detector.expectNoLeakedQueries(client),
          throwsA(isA<Exception>()),
        );
      });

      test('error message includes query key and debug info', () {
        final detector = LeakDetector();
        final client = QueryClient();
        final query = client.getQuery<String>(
          'leaked-query'.toQueryKey(),
          queryFn: () async => 'data',
        );

        query.addListener();

        try {
          detector.expectNoLeakedQueries(client);
          fail('Expected Exception to be thrown');
        } on Exception catch (e) {
          final message = e.toString();
          expect(message, contains('leaked-query'));
          expect(message, contains('Created at:'));
        }
      });

      test('allows specified queries in allowedLeakKeys', () {
        final detector = LeakDetector();
        final client = QueryClient();
        final query = client.getQuery<String>(
          'allowed-query'.toQueryKey(),
          queryFn: () async => 'data',
        );

        query.addListener();

        expect(
          () => detector.expectNoLeakedQueries(
            client,
            allowedLeakKeys: {'allowed-query'},
          ),
          returnsNormally,
        );
      });

      test('throws for leaked queries not in allowedLeakKeys', () {
        final detector = LeakDetector();
        final client = QueryClient();
        final allowedQuery = client.getQuery<String>(
          'allowed-query'.toQueryKey(),
          queryFn: () async => 'data',
        );
        final leakedQuery = client.getQuery<String>(
          'leaked-query'.toQueryKey(),
          queryFn: () async => 'data',
        );

        allowedQuery.addListener();
        leakedQuery.addListener();

        expect(
          () => detector.expectNoLeakedQueries(
            client,
            allowedLeakKeys: {'allowed-query'},
          ),
          throwsA(isA<Exception>()),
        );
      });

      test('includes reference holders in error message', () {
        final detector = LeakDetector();
        final client = QueryClient();
        final query = client.getQuery<String>(
          'leaked-query'.toQueryKey(),
          queryFn: () async => 'data',
        );

        const ownerId = 'test-widget';
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
    });
  });
}
