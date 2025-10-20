import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueryClient', () {
    tearDown(() {
      QueryClient.resetForTesting();
    });

    test('is a singleton', () {
      final client1 = QueryClient();
      final client2 = QueryClient();

      expect(client1, same(client2));
    });

    test('creates new query if key does not exist', () {
      final client = QueryClient();
      final query = client.getQuery<String>(
        'test-key',
        () async => 'data',
      );

      expect(query, isNotNull);
      expect(query.key, 'test-key');
      expect(client.queryCount, 1);
    });

    test('returns existing query for same key', () {
      final client = QueryClient();
      final query1 = client.getQuery<String>(
        'test-key',
        () async => 'data',
      );
      final query2 = client.getQuery<String>(
        'test-key',
        () async => 'other data',
      );

      expect(query1, same(query2));
      expect(client.queryCount, 1);
    });

    test('creates different queries for different keys', () {
      final client = QueryClient();
      final query1 = client.getQuery<String>(
        'key1',
        () async => 'data1',
      );
      final query2 = client.getQuery<String>(
        'key2',
        () async => 'data2',
      );

      expect(query1, isNot(same(query2)));
      expect(client.queryCount, 2);
    });

    test('getQueryByKey returns existing query', () {
      final client = QueryClient();
      client.getQuery<String>(
        'test-key',
        () async => 'data',
      );

      final query = client.getQueryByKey<String>('test-key');

      expect(query, isNotNull);
      expect(query!.key, 'test-key');
    });

    test('getQueryByKey returns null for non-existent key', () {
      final client = QueryClient();
      final query = client.getQueryByKey<String>('non-existent');

      expect(query, isNull);
    });

    test('removeQuery disposes and removes query', () {
      final client = QueryClient();
      final query = client.getQuery<String>(
        'test-key',
        () async => 'data',
      );

      expect(client.queryCount, 1);
      expect(query.isDisposed, isFalse);

      client.removeQuery('test-key');

      expect(client.queryCount, 0);
      expect(query.isDisposed, isTrue);
    });

    test('removeQuery with non-existent key does not throw', () {
      final client = QueryClient();

      expect(() => client.removeQuery('non-existent'), returnsNormally);
    });

    test('clear disposes all queries', () {
      final client = QueryClient();
      final query1 = client.getQuery<String>(
        'key1',
        () async => 'data1',
      );
      final query2 = client.getQuery<String>(
        'key2',
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
      client.getQuery<String>('test-key', () async => 'data');

      expect(client.hasQuery('test-key'), isTrue);
    });

    test('hasQuery returns false for non-existent query', () {
      final client = QueryClient();

      expect(client.hasQuery('non-existent'), isFalse);
    });

    test('passes options to created query', () {
      final client = QueryClient();
      final options = const QueryOptions(enabled: false);

      final query = client.getQuery<String>(
        'test-key',
        () async => 'data',
        options: options,
      );

      expect(query.options, options);
    });

    test('handles multiple query types', () {
      final client = QueryClient();
      final stringQuery = client.getQuery<String>(
        'string-key',
        () async => 'data',
      );
      final intQuery = client.getQuery<int>(
        'int-key',
        () async => 42,
      );
      final listQuery = client.getQuery<List<String>>(
        'list-key',
        () async => ['a', 'b'],
      );

      expect(stringQuery, isA<Query<String>>());
      expect(intQuery, isA<Query<int>>());
      expect(listQuery, isA<Query<List<String>>>());
      expect(client.queryCount, 3);
    });
  });
}
