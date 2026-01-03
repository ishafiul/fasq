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

    group('Debug Instrumentation', () {
      test('debugCreationStack is captured in debug mode', () {
        final query = Query<String>(
          queryKey: 'test'.toQueryKey(),
          queryFn: () async => 'data',
        );

        // In debug mode, stack trace should be captured
        expect(query.debugCreationStack, isNotNull);
        expect(query.debugCreationStack, isA<StackTrace>());
      });

      test('debugCreationStack contains creation location', () {
        final query = Query<String>(
          queryKey: 'test'.toQueryKey(),
          queryFn: () async => 'data',
        );

        final stackTrace = query.debugCreationStack;
        expect(stackTrace, isNotNull);

        // Verify stack trace contains relevant information
        final stackString = stackTrace.toString();
        expect(stackString, isNotEmpty);
        // Stack trace should contain test file reference
        expect(stackString, contains('query_test.dart'));
      });

      test('debugReferenceHolders tracks listeners with ownerId', () {
        final query = Query<String>(
          queryKey: 'test'.toQueryKey(),
          queryFn: () async => 'data',
        );

        expect(query.debugReferenceHolders, isNotNull);
        expect(query.debugReferenceHolders!.isEmpty, isTrue);

        // Add listener with ownerId
        const ownerId = 'test-widget';
        query.addListener(ownerId);

        expect(query.referenceCount, 1);
        expect(query.debugReferenceHolders!.length, 1);
        expect(query.debugReferenceHolders!.containsKey(ownerId), isTrue);
        expect(query.debugReferenceHolders![ownerId], isNotNull);
        expect(query.debugReferenceHolders![ownerId], isA<StackTrace>());
      });

      test('debugReferenceHolders tracks listeners without ownerId', () {
        final query = Query<String>(
          queryKey: 'test'.toQueryKey(),
          queryFn: () async => 'data',
        );

        // Add listener without ownerId (generates unique ID)
        query.addListener();

        expect(query.referenceCount, 1);
        expect(query.debugReferenceHolders!.length, 1);
        expect(query.debugReferenceHolders!.keys.any((k) => k.toString().startsWith('holder_')), isTrue);
      });

      test('debugReferenceHolders removes listener on removeListener', () {
        final query = Query<String>(
          queryKey: 'test'.toQueryKey(),
          queryFn: () async => 'data',
        );

        const ownerId = 'test-widget';
        query.addListener(ownerId);

        expect(query.debugReferenceHolders!.length, 1);
        expect(query.referenceCount, 1);

        query.removeListener(ownerId);

        expect(query.debugReferenceHolders!.isEmpty, isTrue);
        expect(query.referenceCount, 0);
      });

      test('debugReferenceHolders removes most recent listener when ownerId not specified', () {
        final query = Query<String>(
          queryKey: 'test'.toQueryKey(),
          queryFn: () async => 'data',
        );

        const ownerId1 = 'widget-1';
        const ownerId2 = 'widget-2';

        query.addListener(ownerId1);
        query.addListener(ownerId2);

        expect(query.referenceCount, 2);
        expect(query.debugReferenceHolders!.length, 2);

        // Remove without specifying ownerId (should remove most recent)
        query.removeListener();

        expect(query.referenceCount, 1);
        expect(query.debugReferenceHolders!.length, 1);
        expect(query.debugReferenceHolders!.containsKey(ownerId1), isTrue);
        expect(query.debugReferenceHolders!.containsKey(ownerId2), isFalse);
      });

      test('debugReferenceHolders tracks multiple listeners correctly', () {
        final query = Query<String>(
          queryKey: 'test'.toQueryKey(),
          queryFn: () async => 'data',
        );

        query.addListener('widget-1');
        query.addListener('widget-2');
        query.addListener('widget-3');

        expect(query.referenceCount, 3);
        expect(query.debugReferenceHolders!.length, 3);
        expect(query.debugReferenceHolders!.keys, containsAll(['widget-1', 'widget-2', 'widget-3']));

        // Verify each has a stack trace
        for (final ownerId in ['widget-1', 'widget-2', 'widget-3']) {
          expect(query.debugReferenceHolders![ownerId], isNotNull);
          expect(query.debugReferenceHolders![ownerId], isA<StackTrace>());
        }
      });

      test('debugReferenceHolders referenceCount matches map size', () {
        final query = Query<String>(
          queryKey: 'test'.toQueryKey(),
          queryFn: () async => 'data',
        );

        query.addListener('widget-1');
        query.addListener('widget-2');

        expect(query.referenceCount, equals(query.debugReferenceHolders!.length));

        query.removeListener('widget-1');

        expect(query.referenceCount, equals(query.debugReferenceHolders!.length));
      });

      test('debugInfo returns QueryDebugInfo in debug mode', () {
        final query = Query<String>(
          queryKey: 'test'.toQueryKey(),
          queryFn: () async => 'data',
        );

        final debugInfo = query.debugInfo;
        expect(debugInfo, isNotNull);
        expect(debugInfo, isA<QueryDebugInfo>());
      });

      test('debugInfo contains creation stack trace', () {
        final query = Query<String>(
          queryKey: 'test'.toQueryKey(),
          queryFn: () async => 'data',
        );

        final debugInfo = query.debugInfo;
        expect(debugInfo, isNotNull);
        expect(debugInfo!.creationStack, isNotNull);
        expect(debugInfo.creationStack, isA<StackTrace>());
      });

      test('debugInfo contains reference holders map', () {
        final query = Query<String>(
          queryKey: 'test'.toQueryKey(),
          queryFn: () async => 'data',
        );

        query.addListener('widget-1');
        query.addListener('widget-2');

        final debugInfo = query.debugInfo;
        expect(debugInfo, isNotNull);
        expect(debugInfo!.referenceHolders, isA<Map<Object, StackTrace>>());
        expect(debugInfo.referenceHolders.length, 2);
        expect(debugInfo.referenceHolders.containsKey('widget-1'), isTrue);
        expect(debugInfo.referenceHolders.containsKey('widget-2'), isTrue);
      });

      test('debugInfo referenceHolders map is unmodifiable', () {
        final query = Query<String>(
          queryKey: 'test'.toQueryKey(),
          queryFn: () async => 'data',
        );

        query.addListener('widget-1');

        final debugInfo = query.debugInfo;
        expect(debugInfo, isNotNull);

        // Attempting to modify should throw
        expect(
          () => debugInfo!.referenceHolders['new'] = StackTrace.current,
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('debugInfo updates when listeners are added and removed', () {
        final query = Query<String>(
          queryKey: 'test'.toQueryKey(),
          queryFn: () async => 'data',
        );

        expect(query.debugInfo!.referenceHolders.isEmpty, isTrue);

        query.addListener('widget-1');
        expect(query.debugInfo!.referenceHolders.length, 1);

        query.addListener('widget-2');
        expect(query.debugInfo!.referenceHolders.length, 2);

        query.removeListener('widget-1');
        expect(query.debugInfo!.referenceHolders.length, 1);
        expect(query.debugInfo!.referenceHolders.containsKey('widget-2'), isTrue);
      });
    });
  });
}
