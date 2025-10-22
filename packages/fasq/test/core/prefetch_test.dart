import 'package:flutter_test/flutter_test.dart';
import 'package:fasq/fasq.dart';

void main() {
  group('QueryClient Prefetch', () {
    setUp(() {
      QueryClient.resetForTesting();
    });

    test('prefetchQuery populates cache correctly', () async {
      final client = QueryClient();

      Future<String> fetchData() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'prefetched data';
      }

      await client.prefetchQuery('test-key', fetchData);

      final cache = client.cache;
      final entry = cache.get<String>('test-key');

      expect(entry, isNotNull);
      expect(entry!.data, equals('prefetched data'));
      expect(entry.isFresh, isTrue);
    });

    test('prefetchQuery skips if cache is fresh', () async {
      final client = QueryClient();
      int fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data';
      }

      await client.prefetchQuery('test-key', fetchData);
      expect(fetchCount, equals(1));

      await client.prefetchQuery('test-key', fetchData);
      expect(fetchCount, equals(1));
    });

    test('prefetchQuery updates stale cache', () async {
      final client = QueryClient(
        config: CacheConfig(
          defaultStaleTime: const Duration(milliseconds: 100),
        ),
      );

      int fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        await Future.delayed(const Duration(milliseconds: 10));
        return 'data-$fetchCount';
      }

      await client.prefetchQuery('test-key', fetchData);
      expect(fetchCount, equals(1));

      final cache = client.cache;
      final entry1 = cache.get<String>('test-key');
      expect(entry1!.data, equals('data-1'));

      await Future.delayed(const Duration(milliseconds: 150));

      await client.prefetchQuery('test-key', fetchData);
      expect(fetchCount, equals(2));

      final entry2 = cache.get<String>('test-key');
      expect(entry2!.data, equals('data-2'));
    });

    test('prefetchQuery works with query options', () async {
      final client = QueryClient();

      Future<String> fetchData() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data';
      }

      await client.prefetchQuery(
        'test-key',
        fetchData,
        options: QueryOptions(
          staleTime: const Duration(minutes: 5),
          cacheTime: const Duration(minutes: 10),
        ),
      );

      final cache = client.cache;
      final entry = cache.get<String>('test-key');

      expect(entry, isNotNull);
      expect(entry!.data, equals('data'));
      expect(entry.staleTime, equals(const Duration(minutes: 5)));
      expect(entry.cacheTime, equals(const Duration(minutes: 10)));
    });

    test('prefetchQuery handles errors gracefully', () async {
      final client = QueryClient();

      Future<String> fetchError() async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw Exception('Prefetch error');
      }

      expect(
          () => client.prefetchQuery('test-key', fetchError), throwsException);
    });

    test('prefetched data is used by subsequent queries', () async {
      final client = QueryClient();

      Future<String> fetchData() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'prefetched data';
      }

      await client.prefetchQuery('test-key', fetchData);

      final query = client.getQuery<String>('test-key', fetchData);
      query.addListener();

      await Future.delayed(const Duration(milliseconds: 10));

      expect(query.state.hasData, isTrue);
      expect(query.state.data, equals('prefetched data'));

      query.removeListener();
    });

    test('prefetch does not create persistent query', () async {
      final client = QueryClient();

      Future<String> fetchData() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data';
      }

      expect(client.hasQuery('test-key'), isFalse);

      await client.prefetchQuery('test-key', fetchData);

      expect(client.hasQuery('test-key'), isFalse);
    });
  });

  group('QueryClient Prefetch Multiple', () {
    setUp(() {
      QueryClient.resetForTesting();
    });

    test('prefetchQueries executes all prefetches in parallel', () async {
      final client = QueryClient();
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

      final start = DateTime.now();

      await client.prefetchQueries([
        PrefetchConfig(key: 'key1', queryFn: fetchData1),
        PrefetchConfig(key: 'key2', queryFn: fetchData2),
        PrefetchConfig(key: 'key3', queryFn: fetchData3),
      ]);

      final duration = DateTime.now().difference(start);

      expect(results, contains('data1'));
      expect(results, contains('data2'));
      expect(results, contains('data3'));

      expect(duration.inMilliseconds, lessThan(150));

      final cache = client.cache;
      expect(cache.get<String>('key1')!.data, equals('data1'));
      expect(cache.get<String>('key2')!.data, equals('data2'));
      expect(cache.get<String>('key3')!.data, equals('data3'));
    });

    test('prefetchQueries handles partial failures', () async {
      final client = QueryClient();

      Future<String> fetchSuccess() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'success';
      }

      Future<String> fetchError() async {
        await Future.delayed(const Duration(milliseconds: 50));
        throw Exception('Error');
      }

      try {
        await client.prefetchQueries([
          PrefetchConfig(key: 'success', queryFn: fetchSuccess),
          PrefetchConfig(key: 'error', queryFn: fetchError),
        ]);
      } catch (e) {
        // Expected error, test passed
      }

      final cache = client.cache;
      expect(cache.get<String>('success')?.data, equals('success'));
    });

    test('prefetchQueries works with empty list', () async {
      final client = QueryClient();

      await client.prefetchQueries([]);

      expect(client.queryCount, equals(0));
    });

    test('prefetchQueries respects individual query options', () async {
      final client = QueryClient();

      Future<String> fetchData() async {
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data';
      }

      await client.prefetchQueries([
        PrefetchConfig(
          key: 'key1',
          queryFn: fetchData,
          options: QueryOptions(staleTime: const Duration(minutes: 1)),
        ),
        PrefetchConfig(
          key: 'key2',
          queryFn: fetchData,
          options: QueryOptions(staleTime: const Duration(minutes: 5)),
        ),
      ]);

      final cache = client.cache;
      expect(cache.get<String>('key1')!.staleTime,
          equals(const Duration(minutes: 1)));
      expect(cache.get<String>('key2')!.staleTime,
          equals(const Duration(minutes: 5)));
    });

    test('prefetchQueries skips fresh entries', () async {
      final client = QueryClient();
      int fetchCount = 0;

      Future<String> fetchData() async {
        fetchCount++;
        await Future.delayed(const Duration(milliseconds: 50));
        return 'data-$fetchCount';
      }

      await client.prefetchQueries([
        PrefetchConfig(key: 'key1', queryFn: fetchData),
        PrefetchConfig(key: 'key2', queryFn: fetchData),
      ]);

      expect(fetchCount, equals(2));

      await client.prefetchQueries([
        PrefetchConfig(key: 'key1', queryFn: fetchData),
        PrefetchConfig(key: 'key2', queryFn: fetchData),
      ]);

      expect(fetchCount, equals(2));
    });
  });

  group('PrefetchConfig', () {
    test('creates config with required fields', () {
      final config = PrefetchConfig(
        key: 'test',
        queryFn: () async => 'data',
      );

      expect(config.key, equals('test'));
      expect(config.queryFn, isNotNull);
      expect(config.options, isNull);
    });

    test('creates config with options', () {
      final options = QueryOptions(staleTime: const Duration(minutes: 5));
      final config = PrefetchConfig(
        key: 'test',
        queryFn: () async => 'data',
        options: options,
      );

      expect(config.key, equals('test'));
      expect(config.queryFn, isNotNull);
      expect(config.options, equals(options));
    });
  });
}
