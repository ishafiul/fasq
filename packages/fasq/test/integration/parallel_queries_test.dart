import 'package:flutter_test/flutter_test.dart';
import 'package:fasq/fasq.dart';

void main() {
  group('Parallel Queries - Core Behavior', () {
    setUp(() async {
      await QueryClient.resetForTesting();
    });

    test('all queries execute independently', () async {
      final results = <String>[];

      Future<String> fetchData1() async {
        await Future.delayed(const Duration(milliseconds: 100));
        results.add('data1');
        return 'data1';
      }

      Future<String> fetchData2() async {
        await Future.delayed(const Duration(milliseconds: 50));
        results.add('data2');
        return 'data2';
      }

      Future<String> fetchData3() async {
        await Future.delayed(const Duration(milliseconds: 75));
        results.add('data3');
        return 'data3';
      }

      final client = QueryClient();

      // Create multiple queries simultaneously
      final query1 = client.getQuery('query1'.toQueryKey(), queryFn: fetchData1);
      final query2 = client.getQuery('query2'.toQueryKey(), queryFn: fetchData2);
      final query3 = client.getQuery('query3'.toQueryKey(), queryFn: fetchData3);

      // Add listeners to trigger execution
      query1.addListener();
      query2.addListener();
      query3.addListener();

      // Wait for all queries to complete
      await Future.delayed(const Duration(milliseconds: 200));

      // Verify all queries executed independently
      expect(results, contains('data1'));
      expect(results, contains('data2'));
      expect(results, contains('data3'));

      // Verify all queries have data
      expect(query1.state.hasData, isTrue);
      expect(query2.state.hasData, isTrue);
      expect(query3.state.hasData, isTrue);

      // Cleanup
      query1.removeListener();
      query2.removeListener();
      query3.removeListener();
    });

    test('queries share cache when using same key', () async {
      int fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return 'shared-data';
      }

      final client = QueryClient();

      // Create multiple queries with the same key
      final queryKey = 'shared'.toQueryKey();
      final query1 = client.getQuery(queryKey, queryFn: fetchData);
      final query2 = client.getQuery(queryKey, queryFn: fetchData);
      final query3 = client.getQuery(queryKey, queryFn: fetchData);

      // Add listeners to trigger execution
      query1.addListener();
      query2.addListener();
      query3.addListener();

      // Wait for query to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Only one fetch should have happened due to deduplication
      expect(fetchCount, equals(1));

      // All queries should have the same data
      expect(query1.state.data, equals('shared-data'));
      expect(query2.state.data, equals('shared-data'));
      expect(query3.state.data, equals('shared-data'));

      // Cleanup
      query1.removeListener();
      query2.removeListener();
      query3.removeListener();
    });

    test('error in one query does not affect others', () async {
      final results = <String>[];

      Future<String> fetchSuccess() async {
        await Future.delayed(const Duration(milliseconds: 50));
        results.add('success');
        return 'success';
      }

      Future<String> fetchError() async {
        await Future.delayed(const Duration(milliseconds: 50));
        results.add('error');
        throw Exception('Test error');
      }

      Future<String> fetchSuccess2() async {
        await Future.delayed(const Duration(milliseconds: 50));
        results.add('success2');
        return 'success2';
      }

      final client = QueryClient();

      // Create queries with mixed success/error
      final query1 = client.getQuery('success1'.toQueryKey(), queryFn: fetchSuccess);
      final query2 = client.getQuery('error'.toQueryKey(), queryFn: fetchError);
      final query3 = client.getQuery('success2'.toQueryKey(), queryFn: fetchSuccess2);

      // Add listeners to trigger execution
      query1.addListener();
      query2.addListener();
      query3.addListener();

      // Wait for all queries to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // All queries should have executed
      expect(results, contains('success'));
      expect(results, contains('error'));
      expect(results, contains('success2'));

      // First and third queries should succeed
      expect(query1.state.hasData, isTrue);
      expect(query1.state.data, equals('success'));
      expect(query1.state.hasError, isFalse);

      expect(query3.state.hasData, isTrue);
      expect(query3.state.data, equals('success2'));
      expect(query3.state.hasError, isFalse);

      // Second query should have error
      expect(query2.state.hasData, isFalse);
      expect(query2.state.hasError, isTrue);

      // Cleanup
      query1.removeListener();
      query2.removeListener();
      query3.removeListener();
    });

    test('partial loading states are independent', () async {
      final states = <String>[];

      Future<String> fetchFast() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'fast';
      }

      Future<String> fetchSlow() async {
        await Future.delayed(const Duration(milliseconds: 150));
        return 'slow';
      }

      Future<String> fetchError() async {
        await Future.delayed(const Duration(milliseconds: 100));
        throw Exception('Test error');
      }

      final client = QueryClient();

      // Create queries with different timing
      final query1 = client.getQuery('fast'.toQueryKey(), queryFn: fetchFast);
      final query2 = client.getQuery('slow'.toQueryKey(), queryFn: fetchSlow);
      final query3 = client.getQuery('error'.toQueryKey(), queryFn: fetchError);

      // Track state changes
      query1.stream.listen((state) {
        if (state.isLoading) states.add('fast-loading');
        if (state.hasData) states.add('fast-success');
      });

      query2.stream.listen((state) {
        if (state.isLoading) states.add('slow-loading');
        if (state.hasData) states.add('slow-success');
      });

      query3.stream.listen((state) {
        if (state.isLoading) states.add('error-loading');
        if (state.hasError) states.add('error-failed');
      });

      // Add listeners to trigger execution
      query1.addListener();
      query2.addListener();
      query3.addListener();

      // Wait for fast query to complete
      await Future.delayed(const Duration(milliseconds: 75));

      // Fast query should be done, others still loading
      expect(query1.state.hasData, isTrue);
      expect(query2.state.isLoading, isTrue);
      expect(query3.state.isLoading, isTrue);

      // Wait for error query to complete
      await Future.delayed(const Duration(milliseconds: 50));

      // Error query should be done, slow still loading
      expect(query1.state.hasData, isTrue);
      expect(query2.state.isLoading, isTrue);
      expect(query3.state.hasError, isTrue);

      // Wait for slow query to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // All queries should be done
      expect(query1.state.hasData, isTrue);
      expect(query2.state.hasData, isTrue);
      expect(query3.state.hasError, isTrue);

      // Cleanup
      query1.removeListener();
      query2.removeListener();
      query3.removeListener();
    });

    test('queries maintain independent lifecycle', () async {
      final client = QueryClient();

      Future<String> fetchData(String key) async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data-$key';
      }

      // Create queries
      final query1 =
          client.getQuery('query1'.toQueryKey(), queryFn: () => fetchData('1'));
      final query2 =
          client.getQuery('query2'.toQueryKey(), queryFn: () => fetchData('2'));
      final query3 =
          client.getQuery('query3'.toQueryKey(), queryFn: () => fetchData('3'));

      // Add listeners to some queries
      query1.addListener();
      query2.addListener();
      // query3 has no listeners

      // Wait for queries to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Queries with listeners should have data
      expect(query1.state.hasData, isTrue);
      expect(query2.state.hasData, isTrue);

      // Query without listeners should not have executed
      expect(query3.state.isIdle, isTrue);

      // Add listener to third query
      query3.addListener();

      // Wait for third query to complete
      await Future.delayed(const Duration(milliseconds: 100));

      // Now all queries should have data
      expect(query1.state.hasData, isTrue);
      expect(query2.state.hasData, isTrue);
      expect(query3.state.hasData, isTrue);

      // Remove listeners
      query1.removeListener();
      query2.removeListener();
      query3.removeListener();

      // Wait for cleanup
      await Future.delayed(const Duration(milliseconds: 200));

      // Queries should be cleaned up
      expect(client.hasQuery('query1'.toQueryKey()), isFalse);
      expect(client.hasQuery('query2'.toQueryKey()), isFalse);
      expect(client.hasQuery('query3'.toQueryKey()), isFalse);
    });

    test('cache invalidation affects all queries with same key', () async {
      int fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data-$fetchCount';
      }

      final client = QueryClient();

      // Create multiple queries with same key
      final queryKey = 'shared'.toQueryKey();
      final query1 = client.getQuery(queryKey, queryFn: fetchData);
      final query2 = client.getQuery(queryKey, queryFn: fetchData);

      // Add listeners
      query1.addListener();
      query2.addListener();

      // Wait for initial fetch
      await Future.delayed(const Duration(milliseconds: 100));

      // Should have fetched once
      expect(fetchCount, equals(1));
      expect(query1.state.data, equals('data-1'));
      expect(query2.state.data, equals('data-1'));

      // Invalidate cache
      client.invalidateQuery(queryKey);

      // Wait for refetch
      await Future.delayed(const Duration(milliseconds: 100));

      // Should have fetched again
      expect(fetchCount, equals(2));
      expect(query1.state.data, equals('data-2'));
      expect(query2.state.data, equals('data-2'));

      // Cleanup
      query1.removeListener();
      query2.removeListener();
    });
  });
}
