import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await QueryClient.resetForTesting();
  });

  group('Query', () {
    test('initializes with idle state', () {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      expect(query.state.status, QueryStatus.idle);
      expect(query.state.data, isNull);
      expect(query.referenceCount, 0);
      expect(query.isDisposed, isFalse);

      query.dispose();
    });

    test('does not transform data when data transform disabled', () async {
      final query = Query<String>(
        queryKey: 'transform-default'.toQueryKey(),
        queryFn: () async => 'raw',
      );

      await query.fetch();

      expect(query.state.data, 'raw');

      query.dispose();
    });

    test('applies custom data transformer when enabled', () async {
      final query = Query<String>(
        queryKey: 'transform-enabled'.toQueryKey(),
        queryFn: () async => 'raw',
        options: QueryOptions(
          performance: PerformanceOptions(
            enableDataTransform: true,
            dataTransformer: (value) => '${value}_transformed',
          ),
        ),
      );

      await query.fetch();

      expect(query.state.data, 'raw_transformed');

      query.dispose();
    });

    test('falls back to original data when transformer throws', () async {
      final query = Query<String>(
        queryKey: 'transform-error'.toQueryKey(),
        queryFn: () async => 'raw',
        options: QueryOptions(
          performance: PerformanceOptions(
            enableDataTransform: true,
            dataTransformer: (value) {
              throw StateError('bad transform');
            },
          ),
        ),
      );

      await query.fetch();

      expect(query.state.data, 'raw');

      query.dispose();
    });

    test('addListener increments reference count', () {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.addListener();
      expect(query.referenceCount, 1);

      query.addListener();
      expect(query.referenceCount, 2);

      query.dispose();
    });

    test('removeListener decrements reference count', () {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.addListener();
      query.addListener();
      expect(query.referenceCount, 2);

      query.removeListener();
      expect(query.referenceCount, 1);

      query.dispose();
    });

    test('removeListener prevents negative reference count', () {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      // Start with 0 references
      expect(query.referenceCount, 0);

      // Try to remove listener when count is already 0
      query.removeListener();
      expect(query.referenceCount, 0); // Should remain 0, not go negative

      // Add one listener
      query.addListener();
      expect(query.referenceCount, 1);

      // Remove listener twice (more removes than adds)
      query.removeListener();
      expect(query.referenceCount, 0);

      query.removeListener(); // This should not make it negative
      expect(query.referenceCount, 0); // Should remain 0

      query.dispose();
    });

    test('fetch transitions from idle to loading to success', () async {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async {
          await Future.delayed(Duration(milliseconds: 10));
          return 'data';
        },
      );

      final states = <QueryState<String>>[];
      query.stream.listen(states.add);

      final fetchFuture = query.fetch();
      await Future.delayed(Duration(milliseconds: 5));

      expect(states.length, greaterThanOrEqualTo(1));
      expect(states.first.status, QueryStatus.loading);

      await fetchFuture;
      await Future.delayed(Duration(milliseconds: 10));

      expect(states.last.status, QueryStatus.success);
      expect(states.last.data, 'data');

      query.dispose();
    });

    test('fetch transitions from idle to loading to error', () async {
      final error = Exception('test error');
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async {
          await Future.delayed(Duration(milliseconds: 10));
          throw error;
        },
      );

      final states = <QueryState<String>>[];
      query.stream.listen(states.add);

      final fetchFuture = query.fetch();
      await Future.delayed(Duration(milliseconds: 5));

      expect(states.first.status, QueryStatus.loading);

      await fetchFuture;
      await Future.delayed(Duration(milliseconds: 10));

      expect(states.last.status, QueryStatus.error);
      expect(states.last.error, error);

      query.dispose();
    });

    test('auto-fetches on first listener when no data', () async {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      final states = <QueryState<String>>[];
      query.stream.listen(states.add);

      query.addListener();

      await Future.delayed(Duration(milliseconds: 100));

      expect(states.length, greaterThanOrEqualTo(1));
      expect(query.state.status, QueryStatus.success);
      expect(query.state.data, 'data');

      query.dispose();
    });

    test('does not auto-fetch if already has data', () async {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'new data',
      );

      await query.fetch();
      expect(query.state.data, 'new data');

      final initialStateCount = query.state.status;
      query.addListener();

      await Future.delayed(Duration(milliseconds: 100));

      expect(query.state.status, initialStateCount);

      query.dispose();
    });

    test('does not fetch when enabled is false', () async {
      var callCount = 0;
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async {
          callCount++;
          return 'data';
        },
        options: QueryOptions(enabled: false),
      );

      await query.fetch();

      expect(callCount, 0);
      expect(query.state.status, QueryStatus.idle);

      query.dispose();
    });

    test('calls onSuccess callback on successful fetch', () async {
      var successCalled = false;
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
        options: QueryOptions(onSuccess: () => successCalled = true),
      );

      await query.fetch();

      expect(successCalled, isTrue);
      expect(query.state.status, QueryStatus.success);

      query.dispose();
    });

    test('calls onError callback on failed fetch', () async {
      Object? capturedError;
      final error = Exception('test error');
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => throw error,
        options: QueryOptions(onError: (e) => capturedError = e),
      );

      await query.fetch();

      expect(capturedError, error);
      expect(query.state.status, QueryStatus.error);

      query.dispose();
    });

    test('schedules disposal after removeListener brings count to zero',
        () async {
      Query.disposalDelay = const Duration(milliseconds: 100);
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.addListener();
      expect(query.isDisposed, isFalse);

      query.removeListener();
      expect(query.isDisposed, isFalse);

      await Future.delayed(Duration(milliseconds: 200));
      expect(query.isDisposed, isTrue);
    });

    test('cancels disposal if listener added before timeout', () async {
      Query.disposalDelay = const Duration(milliseconds: 200);
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.addListener();
      query.removeListener();

      await Future.delayed(Duration(milliseconds: 100));
      expect(query.isDisposed, isFalse);

      query.addListener();
      await Future.delayed(Duration(milliseconds: 200));
      expect(query.isDisposed, isFalse);

      query.dispose();
    });

    test('dispose closes stream controller', () async {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      var streamClosed = false;
      query.stream.listen(
        (_) {},
        onDone: () => streamClosed = true,
      );

      query.dispose();

      await Future.delayed(Duration(milliseconds: 100));
      expect(streamClosed, isTrue);
    });

    test('does not update state after disposal', () async {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async {
          await Future.delayed(Duration(milliseconds: 100));
          return 'data';
        },
      );

      final states = <QueryState<String>>[];
      query.stream.listen(states.add);

      final fetchFuture = query.fetch();
      await Future.delayed(Duration(milliseconds: 10));

      final statesBeforeDisposal = states.length;
      query.dispose();

      await fetchFuture;

      expect(states.length, statesBeforeDisposal);
    });

    test('ignores addListener after disposal', () {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.dispose();
      query.addListener();

      expect(query.referenceCount, 0);
    });

    test('ignores removeListener after disposal', () {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.addListener();
      final count = query.referenceCount;
      query.dispose();
      query.removeListener();

      expect(query.referenceCount, count);
    });

    test('QueryClient clears cache when query is disposed', () async {
      final client = QueryClient();

      // Create a query and fetch data
      final query1 = client.getQuery<String>(
        'test-cache-clear'.toQueryKey(),
        () async => 'cached-data',
      );

      query1.addListener();
      await query1.fetch(); // Wait for fetch to complete

      // Verify data is cached
      final cachedEntry = client.cache.get<String>('test-cache-clear');
      expect(cachedEntry, isNotNull);
      expect(cachedEntry!.data, 'cached-data');

      // Remove all listeners to trigger disposal
      query1.removeListener();

      // Wait for disposal to complete (disposal is scheduled after 5 seconds)
      // For testing, we'll manually dispose to trigger immediate cache clearing
      query1.dispose();

      // Verify cache is cleared
      final clearedEntry = client.cache.get<String>('test-cache-clear');
      expect(clearedEntry, isNull);
    });

    test('New query fetches data when cache is cleared', () async {
      final client = QueryClient();
      int fetchCount = 0;

      // Create first query
      final queryKey = 'test-fresh-fetch'.toQueryKey();
      final query1 = client.getQuery<String>(
        queryKey,
        () async {
          fetchCount++;
          return 'data-$fetchCount';
        },
      );

      query1.addListener(); // This will trigger fetch automatically
      await Future.delayed(
          const Duration(milliseconds: 10)); // Wait for async fetch
      expect(fetchCount, 1);
      expect(query1.state.data, 'data-1');

      // Dispose query (clears cache)
      query1.removeListener();
      query1.dispose();

      // Create new query with same key
      final query2 = client.getQuery<String>(
        queryKey,
        () async {
          fetchCount++;
          return 'data-$fetchCount';
        },
      );

      // Should start in loading state when no cached data
      expect(query2.state.status, QueryStatus.loading);
      expect(query2.state.hasData, false);

      // Adding listener should trigger fetch
      query2.addListener();
      await Future.delayed(
          const Duration(milliseconds: 10)); // Wait for async fetch

      expect(fetchCount, 2);
      expect(query2.state.data, 'data-2');
    });
  });
}
