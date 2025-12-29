import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FasqLogger Integration Tests', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await QueryClient.resetForTesting();
    });

    tearDown(() async {
      await QueryClient.resetForTesting();
    });

    test('FasqLogger can be instantiated and added to QueryClient', () {
      final logger = FasqLogger(
        enabled: true,
        showData: false,
        truncateLength: 100,
      );

      final client = QueryClient();
      client.addObserver(logger);

      expect(logger.enabled, isTrue);
      expect(logger.showData, isFalse);
      expect(logger.truncateLength, 100);
    });

    test('FasqLogger logs query loading events', () async {
      await expectLater(
        () async {
          final logger = FasqLogger(enabled: true);
          final client = QueryClient();
          client.addObserver(logger);

          final query = client.getQuery<String>(
            'test-query'.toQueryKey(),
            queryFn: () async {
              await Future.delayed(const Duration(milliseconds: 10));
              return 'test data';
            },
          );

          await query.fetch();
        },
        prints(contains('⏳ [Fetch]')),
      );
    });

    test('FasqLogger logs query success events with duration', () async {
      await expectLater(
        () async {
          final logger = FasqLogger(enabled: true);
          final client = QueryClient();
          client.addObserver(logger);

          final query = client.getQuery<String>(
            'success-query'.toQueryKey(),
            queryFn: () async {
              await Future.delayed(const Duration(milliseconds: 50));
              return 'success data';
            },
          );

          await query.fetch();
        },
        prints(allOf(
          contains('✅ [Success]'),
          contains('success-query'),
          contains('ms)'),
        )),
      );
    });

    test('FasqLogger logs query error events', () async {
      await expectLater(
        () async {
          final logger = FasqLogger(enabled: true);
          final client = QueryClient();
          client.addObserver(logger);

          final query = client.getQuery<String>(
            'error-query'.toQueryKey(),
            queryFn: () async {
              throw Exception('Test error');
            },
          );

          try {
            await query.fetch();
          } catch (_) {}
        },
        prints(allOf(
          contains('❌ [Error]'),
          contains('error-query'),
        )),
      );
    });

    test('FasqLogger respects showData=false setting', () async {
      await expectLater(
        () async {
          final logger = FasqLogger(
            enabled: true,
            showData: false,
          );
          final client = QueryClient();
          client.addObserver(logger);

          final query = client.getQuery<String>(
            'data-query'.toQueryKey(),
            queryFn: () async => 'sensitive data',
          );

          await query.fetch();
        },
        prints(isNot(contains('sensitive data'))),
      );
    });

    test('FasqLogger respects showData=true and truncateLength', () async {
      final longData = 'a' * 20;
      await expectLater(
        () async {
          final logger = FasqLogger(
            enabled: true,
            showData: true,
            truncateLength: 5,
          );
          final client = QueryClient();
          client.addObserver(logger);

          final query = client.getQuery<String>(
            'truncate-query'.toQueryKey(),
            queryFn: () async => longData,
          );

          await query.fetch();
        },
        prints(allOf(
          contains('aaaaa...'),
          isNot(contains(longData)),
        )),
      );
    });

    test('FasqLogger does not log when enabled=false', () async {
      await expectLater(
        () async {
          final logger = FasqLogger(enabled: false);
          final client = QueryClient();
          client.addObserver(logger);

          final query = client.getQuery<String>(
            'disabled-query'.toQueryKey(),
            queryFn: () async => 'data',
          );

          await query.fetch();
        },
        prints(isNot(anyOf(
          contains('⏳ [Fetch]'),
          contains('✅ [Success]'),
        ))),
      );
    });

    test('FasqLogger logs mutation loading events', () async {
      await expectLater(
        () async {
          final logger = FasqLogger(enabled: true);
          final client = QueryClient();
          client.addObserver(logger);

          final mutation = Mutation<String, String>(
            mutationFn: (String variables) async {
              await Future.delayed(const Duration(milliseconds: 10));
              return 'mutation result';
            },
          );

          await mutation.mutate('test variables');
        },
        prints(contains('🚀 [Mutation]')),
      );
    });

    test('FasqLogger logs mutation success events', () async {
      await expectLater(
        () async {
          final logger = FasqLogger(enabled: true);
          final client = QueryClient();
          client.addObserver(logger);

          final mutation = Mutation<String, String>(
            mutationFn: (String variables) async {
              await Future.delayed(const Duration(milliseconds: 50));
              return 'mutation result';
            },
          );

          await mutation.mutate('test');
        },
        prints(allOf(
          contains('✅ [Mutation Success]'),
          contains('ms)'),
        )),
      );
    });

    test('FasqLogger logs mutation error events', () async {
      await expectLater(
        () async {
          final logger = FasqLogger(enabled: true);
          final client = QueryClient();
          client.addObserver(logger);

          final mutation = Mutation<String, String>(
            mutationFn: (String variables) async {
              throw Exception('Mutation error');
            },
          );

          try {
            await mutation.mutate('test');
          } catch (_) {}
        },
        prints(contains('❌ [Mutation Error]')),
      );
    });
  });
}
