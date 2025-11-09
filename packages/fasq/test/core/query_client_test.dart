import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueryClient', () {
    tearDown(() async {
      await QueryClient.resetForTesting();
    });

    test('is a singleton', () {
      final client1 = QueryClient();
      final client2 = QueryClient();

      expect(client1, same(client2));
    });

    test('creates new query if key does not exist', () {
      final client = QueryClient();
      final query = client.getQuery<String>(
        'test-key'.toQueryKey(),
        () async => 'data',
      );

      expect(query, isNotNull);
      expect(query.key, 'test-key');
      expect(client.queryCount, 1);
    });

    test('returns existing query for same key', () {
      final client = QueryClient();
      final queryKey = 'test-key'.toQueryKey();
      final query1 = client.getQuery<String>(
        queryKey,
        () async => 'data',
      );
      final query2 = client.getQuery<String>(
        queryKey,
        () async => 'other data',
      );

      expect(query1, same(query2));
      expect(client.queryCount, 1);
    });

    test('creates different queries for different keys', () {
      final client = QueryClient();
      final query1 = client.getQuery<String>(
        'key1'.toQueryKey(),
        () async => 'data1',
      );
      final query2 = client.getQuery<String>(
        'key2'.toQueryKey(),
        () async => 'data2',
      );

      expect(query1, isNot(same(query2)));
      expect(client.queryCount, 2);
    });

    test('getQueryByKey returns existing query', () {
      final client = QueryClient();
      final queryKey = 'test-key'.toQueryKey();
      client.getQuery<String>(
        queryKey,
        () async => 'data',
      );

      final query = client.getQueryByKey<String>(queryKey);

      expect(query, isNotNull);
      expect(query!.key, 'test-key');
    });

    test('getQueryByKey returns null for non-existent key', () {
      final client = QueryClient();
      final query = client.getQueryByKey<String>('non-existent'.toQueryKey());

      expect(query, isNull);
    });

    test('removeQuery disposes and removes query', () {
      final client = QueryClient();
      final queryKey = 'test-key'.toQueryKey();
      final query = client.getQuery<String>(
        queryKey,
        () async => 'data',
      );

      expect(client.queryCount, 1);
      expect(query.isDisposed, isFalse);

      client.removeQuery(queryKey);

      expect(client.queryCount, 0);
      expect(query.isDisposed, isTrue);
    });

    test('removeQuery with non-existent key does not throw', () {
      final client = QueryClient();

      expect(() => client.removeQuery('non-existent'.toQueryKey()),
          returnsNormally);
    });

    test('clear disposes all queries', () {
      final client = QueryClient();
      final query1 = client.getQuery<String>(
        'key1'.toQueryKey(),
        () async => 'data1',
      );
      final query2 = client.getQuery<String>(
        'key2'.toQueryKey(),
        () async => 'data2',
      );

      expect(client.queryCount, 2);

      client.clear();

      expect(client.queryCount, 0);
      expect(query1.isDisposed, isTrue);
      expect(query2.isDisposed, isTrue);
    });

    test('hasQuery returns true for existing query', () {
      final client = QueryClient();
      final queryKey = 'test-key'.toQueryKey();
      client.getQuery<String>(queryKey, () async => 'data');

      expect(client.hasQuery(queryKey), isTrue);
    });

    test('hasQuery returns false for non-existent query', () {
      final client = QueryClient();

      expect(client.hasQuery('non-existent'.toQueryKey()), isFalse);
    });

    test('passes options to created query', () {
      final client = QueryClient();
      final options = QueryOptions(enabled: false);

      final query = client.getQuery<String>(
        'test-key'.toQueryKey(),
        () async => 'data',
        options: options,
      );

      expect(query.options, options);
    });

    test('handles multiple query types', () {
      final client = QueryClient();
      final stringQuery = client.getQuery<String>(
        'string-key'.toQueryKey(),
        () async => 'data',
      );
      final intQuery = client.getQuery<int>(
        'int-key'.toQueryKey(),
        () async => 42,
      );
      final listQuery = client.getQuery<List<String>>(
        'list-key'.toQueryKey(),
        () async => ['a', 'b'],
      );

      expect(stringQuery, isA<Query<String>>());
      expect(intQuery, isA<Query<int>>());
      expect(listQuery, isA<Query<List<String>>>());
      expect(client.queryCount, 3);
    });

    test('works with TypedQueryKey', () {
      final client = QueryClient();
      final typedKey = TypedQueryKey<String>('typed-key', String);
      final query = client.getQuery<String>(
        typedKey,
        () async => 'data',
      );

      expect(query, isNotNull);
      expect(query.key, 'typed-key');
      expect(query.queryKey, typedKey);
    });

    test('String extension converts to QueryKey', () {
      final key = 'test-key';
      final queryKey = key.toQueryKey();

      expect(queryKey, isA<QueryKey>());
      expect(queryKey.key, 'test-key');
    });
  });
}
