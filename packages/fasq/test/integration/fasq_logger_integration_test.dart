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
      final logger = FasqLogger();

      QueryClient().addObserver(logger);

      expect(logger.enabled, isTrue);
      expect(logger.showData, isFalse);
      expect(logger.truncateLength, 100);
    });

    test('FasqLogger logs query loading events', () async {
      await expectLater(
        () async {
          final logger = FasqLogger();
          final client = QueryClient()..addObserver(logger);

          final query = client.getQuery<String>(
            'test-query'.toQueryKey(),
            queryFn: () async {
              await Future<void>.delayed(const Duration(milliseconds: 10));
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
          final logger = FasqLogger();
          final client = QueryClient()..addObserver(logger);

          final query = client.getQuery<String>(
            'success-query'.toQueryKey(),
            queryFn: () async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return 'success data';
            },
          );

          await query.fetch();
        },
        prints(
          allOf(
            contains('✅ [Success]'),
            contains('success-query'),
            contains('ms)'),
          ),
        ),
      );
    });

    test('FasqLogger logs query error events', () async {
      await expectLater(
        () async {
          final logger = FasqLogger();
          final client = QueryClient()..addObserver(logger);

          final query = client.getQuery<String>(
            'error-query'.toQueryKey(),
            queryFn: () async {
              throw Exception('Test error');
            },
          );

          try {
            await query.fetch();
          } on Object catch (_) {}
        },
        prints(
          allOf(
            contains('❌ [Error]'),
            contains('error-query'),
          ),
        ),
      );
    });

    test('FasqLogger respects showData=false setting', () async {
      await expectLater(
        () async {
          final logger = FasqLogger();
          final client = QueryClient()..addObserver(logger);

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
            showData: true,
            truncateLength: 5,
          );
          final client = QueryClient()..addObserver(logger);

          final query = client.getQuery<String>(
            'truncate-query'.toQueryKey(),
            queryFn: () async => longData,
          );

          await query.fetch();
        },
        prints(
          allOf(
            contains('aaaaa...'),
            isNot(contains(longData)),
          ),
        ),
      );
    });

    test('FasqLogger does not log when enabled=false', () async {
      await expectLater(
        () async {
          final logger = FasqLogger(enabled: false);
          final client = QueryClient()..addObserver(logger);

          final query = client.getQuery<String>(
            'disabled-query'.toQueryKey(),
            queryFn: () async => 'data',
          );

          await query.fetch();
        },
        prints(
          isNot(
            anyOf(
              contains('⏳ [Fetch]'),
              contains('✅ [Success]'),
            ),
          ),
        ),
      );
    });

    test('FasqLogger logs mutation loading events', () async {
      await expectLater(
        () async {
          final logger = FasqLogger();
          QueryClient().addObserver(logger);

          final mutation = Mutation<String, String>(
            mutationFn: (variables) async {
              await Future<void>.delayed(const Duration(milliseconds: 10));
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
          final logger = FasqLogger();
          QueryClient().addObserver(logger);

          final mutation = Mutation<String, String>(
            mutationFn: (variables) async {
              await Future<void>.delayed(const Duration(milliseconds: 50));
              return 'mutation result';
            },
          );

          await mutation.mutate('test');
        },
        prints(
          allOf(
            contains('✅ [Mutation Success]'),
            contains('ms)'),
          ),
        ),
      );
    });

    test('FasqLogger logs mutation error events', () async {
      await expectLater(
        () async {
          final logger = FasqLogger();
          QueryClient().addObserver(logger);

          final mutation = Mutation<String, String>(
            mutationFn: (variables) async {
              throw Exception('Mutation error');
            },
          );

          try {
            await mutation.mutate('test');
          } on Object catch (_) {}
        },
        prints(contains('❌ [Mutation Error]')),
      );
    });
  });
}
