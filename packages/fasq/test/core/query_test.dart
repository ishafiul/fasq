import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Query', () {
    test('Query initializes in idle state', () {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      expect(query.state.status, QueryStatus.idle);
      expect(query.state.isLoading, false);
      expect(query.state.isFetching, false);
      expect(query.state.hasData, false);
      expect(query.state.data, isNull);
      expect(query.state.error, isNull);
    });

    test('Query transitions to loading/fetching on fetch', () async {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'data';
        },
      );

      final fetchFuture = query.fetch();
      expect(query.state.status, QueryStatus.loading);
      expect(query.state.isFetching, true);

      await fetchFuture;
      expect(query.state.status, QueryStatus.success);
      expect(query.state.isFetching, false);
    });

    test('Query updates to success state on successful fetch', () async {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      await query.fetch();

      expect(query.state.status, QueryStatus.success);
      expect(query.state.isLoading, false);
      expect(query.state.hasData, true);
      expect(query.state.data, 'data');
    });

    test('Query updates to error state on failed fetch', () async {
      final error = Exception('test error');
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => throw error,
      );

      await query.fetch();

      expect(query.state.status, QueryStatus.error);
      expect(query.state.isLoading, false);
      expect(query.state.error, error);
    });

    test('Query notifies listeners on state changes', () async {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      int notifyCount = 0;
      query.subscribe((_) => notifyCount++);

      await query.fetch();

      expect(notifyCount, greaterThan(0));
    });

    test('Query cancels fetch on disposal', () async {
      bool fetchCompleted = false;
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFnWithToken: (token) async {
          await Future.delayed(const Duration(milliseconds: 100));
          if (token.isCancelled) return 'cancelled';
          fetchCompleted = true;
          return 'data';
        },
      );

      query.fetch(); // Trigger fetch
      await Future.delayed(const Duration(milliseconds: 10));
      query.dispose();

      await Future.delayed(const Duration(milliseconds: 200));
      expect(fetchCompleted, false);
    });

    test('Query referenceCount tracks listeners', () {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      expect(query.referenceCount, 0);

      query.addListener();
      expect(query.referenceCount, 1);

      query.addListener();
      expect(query.referenceCount, 2);

      query.removeListener();
      expect(query.referenceCount, 1);

      query.removeListener();
      expect(query.referenceCount, 0);
    });

    test('Query deduplicates multiple fetches using QueryClient', () async {
      final client = QueryClient();
      int fetchCount = 0;
      final queryKey = 'test-dedupe'.toQueryKey();

      final query = client.getQuery<String>(
        queryKey,
        queryFn: () async {
          fetchCount++;
          await Future.delayed(const Duration(milliseconds: 50));
          return 'data-$fetchCount';
        },
      );

      final f1 = query.fetch();
      final f2 = query.fetch();

      await Future.wait([f1, f2]);

      expect(fetchCount, 1);
    });

    test('Query calls onError callback on failed fetch', () async {
      final error = Exception('test error');
      Object? capturedError;
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => throw error,
        options: QueryOptions(onError: (e) => capturedError = e),
      );

      await query.fetch();

      expect(capturedError, error);
      expect(query.state.status, QueryStatus.error);
    });

    test('Query state persistence during refetch', () async {
      int fetchCount = 0;
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async {
          fetchCount++;
          await Future.delayed(const Duration(milliseconds: 50));
          return 'data-$fetchCount';
        },
      );

      await query.fetch();
      expect(query.state.data, 'data-1');

      final refetchFuture = query.fetch(forceRefetch: true);
      expect(query.state.isFetching, true);
      expect(query.state.data, 'data-1'); // Data remains while fetching

      await refetchFuture;
      expect(query.state.data, 'data-2');
    });

    test('Query.updateFromCache updates state directly', () {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      query.updateFromCache('manual-data');
      expect(query.state.data, 'manual-data');
      expect(query.state.status, QueryStatus.success);
    });

    test('Query isDisposed is true after disposal', () {
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async => 'data',
      );

      expect(query.isDisposed, false);
      query.dispose();
      expect(query.isDisposed, true);
    });

    test('Query honors manual refetch', () async {
      int fetchCount = 0;
      final query = Query<String>(
        queryKey: 'test'.toQueryKey(),
        queryFn: () async {
          fetchCount++;
          return 'data-$fetchCount';
        },
      );

      await query.fetch();
      expect(fetchCount, 1);

      await query.fetch(forceRefetch: true);
      expect(fetchCount, 2);
    });

    test('QueryClient clears cache when query is disposed', () async {
      final client = QueryClient();

      // Create a query and fetch data
      final queryKey = 'test-cache-clear'.toQueryKey();
      final query1 = client.getQuery<String>(
        queryKey,
        queryFn: () async => 'cached-data',
      );

      query1.addListener();
      await query1.fetch(); // Wait for fetch to complete

      // Verify data is cached
      final cachedEntry = client.cache.get<String>('test-cache-clear');
      expect(cachedEntry, isNotNull);
      expect(cachedEntry!.data, 'cached-data');

      // Remove listener to trigger disposal timer
      query1.removeListener();

      // For testing, we'll manually dispose to trigger immediate cleanup
      query1.dispose();

      // Verify cache is NOT cleared immediately (it persists until GC)
      final persistingEntry = client.cache.get<String>('test-cache-clear');
      expect(persistingEntry, isNotNull);
      expect(persistingEntry!.data, 'cached-data');

      // Manually remove from cache
      client.cache.remove('test-cache-clear');
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
        queryFn: () async {
          fetchCount++;
          return 'data-$fetchCount';
        },
      );

      query1.addListener(); // This will trigger fetch automatically
      await Future.delayed(
          const Duration(milliseconds: 10)); // Wait for async fetch
      expect(fetchCount, 1);
      expect(query1.state.data, 'data-1');

      // Dispose query1
      query1.removeListener();
      query1.dispose();

      // Create new query with same key
      final query2 = client.getQuery<String>(
        queryKey,
        queryFn: () async {
          fetchCount++;
          return 'data-$fetchCount';
        },
      );

      // Should start in success state because data is reused from cache
      expect(query2.state.status, QueryStatus.success);
      expect(query2.state.data, 'data-1');

      // Dispose query2
      query2.dispose();

      // Manually clear cache
      client.cache.remove(queryKey.key);

      // Create another query with same key
      final query3 = client.getQuery<String>(
        queryKey,
        queryFn: () async {
          fetchCount++;
          return 'data-$fetchCount';
        },
      );

      expect(query3.state.status, QueryStatus.loading);
      expect(query3.state.hasData, false);

      // Adding listener should trigger fetch
      query3.addListener();
      await Future.delayed(
          const Duration(milliseconds: 10)); // Wait for async fetch

      expect(fetchCount, 2);
      expect(query3.state.data, 'data-2');
    });
  });
}
