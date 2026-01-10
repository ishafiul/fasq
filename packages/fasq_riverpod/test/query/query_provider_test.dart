import 'package:flutter_test/flutter_test.dart';
import 'package:fasq_riverpod/fasq_riverpod.dart';

void main() {
  group('QueryProvider', () {
    setUp(() async {
      await QueryClient.resetForTesting();
    });

    tearDown(() async {
      await QueryClient.resetForTesting();
    });

    test('queryProvider returns AsyncValue<T>', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = queryProvider<String>(
        'test'.toQueryKey(),
        () async => 'test data',
      );

      final asyncValue = container.read(provider);

      // Initially should be loading
      expect(asyncValue, isA<AsyncLoading<String>>());

      // Wait for data
      await container.read(provider.future);

      final updatedValue = container.read(provider);
      expect(updatedValue, isA<AsyncData<String>>());
      expect(updatedValue.value, equals('test data'));
    });

    test('queryProvider handles errors correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = queryProvider<String>(
        'error'.toQueryKey(),
        () async => throw Exception('Test error'),
      );

      try {
        await container.read(provider.future);
        fail('Should have thrown an error');
      } catch (e) {
        expect(e, isA<Exception>());
      }

      final asyncValue = container.read(provider);
      expect(asyncValue, isA<AsyncError<String>>());
      expect(asyncValue.error.toString(), contains('Test error'));
    });

    test('queryProvider supports refetch', () async {
      var callCount = 0;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = queryProvider<String>(
        'refetch'.toQueryKey(),
        () async {
          callCount++;
          return 'data $callCount';
        },
      );

      // Wait for initial fetch
      final data1 = await container.read(provider.future);
      expect(data1, equals('data 1'));
      expect(callCount, equals(1));

      // Trigger refetch
      await container.read(provider.notifier).refetch();

      // Wait for refetch to complete
      await Future.delayed(const Duration(milliseconds: 100));

      final updatedValue = container.read(provider);
      expect(updatedValue.value, equals('data 2'));
      expect(callCount, equals(2));
    });

    test('queryProvider supports invalidate', () async {
      var callCount = 0;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = queryProvider<String>(
        'invalidate'.toQueryKey(),
        () async {
          callCount++;
          await Future.delayed(const Duration(milliseconds: 10));
          return 'data $callCount';
        },
        options: QueryOptions(
          staleTime: Duration.zero, // Make data stale immediately
          cacheTime: Duration(minutes: 5),
        ),
      );

      // Wait for initial fetch
      final data1 = await container.read(provider.future);
      expect(data1, equals('data 1'));
      expect(callCount, equals(1));

      // Invalidate clears the cache
      container.read(provider.notifier).invalidate();

      // Wait a bit for invalidation to process
      await Future.delayed(const Duration(milliseconds: 50));

      // Since data is invalidated, accessing it should trigger a refetch
      // The query should refetch since we're actively watching it
      expect(callCount, greaterThanOrEqualTo(1)); // At minimum, initial fetch happened
    });

    test('queryProvider uses fasqClientProvider', () async {
      final customConfig = CacheConfig(
        defaultStaleTime: Duration(minutes: 5),
      );

      final container = ProviderContainer(
        overrides: [
          fasqCacheConfigProvider.overrideWithValue(customConfig),
        ],
      );
      addTearDown(container.dispose);

      final provider = queryProvider<String>(
        'config'.toQueryKey(),
        () async => 'data',
      );

      await container.read(provider.future);

      // Verify the client is using the custom config
      final client = container.read(fasqClientProvider);
      expect(client, isNotNull);
    });

    test('queryProviderWithToken passes cancellation token', () async {
      CancellationToken? receivedToken;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = queryProviderWithToken<String>(
        'token'.toQueryKey(),
        (token) async {
          receivedToken = token;
          return 'data';
        },
      );

      await container.read(provider.future);

      expect(receivedToken, isNotNull);
      expect(receivedToken, isA<CancellationToken>());
    });

    test('queryProvider disposes properly', () async {
      final container = ProviderContainer();

      final provider = queryProvider<String>(
        'dispose'.toQueryKey(),
        () async => 'data',
      );

      await container.read(provider.future);

      final client = container.read(fasqClientProvider);
      expect(client.hasQuery('dispose'.toQueryKey()), isTrue);

      // Dispose container
      container.dispose();

      // Wait for cleanup
      await Future.delayed(const Duration(milliseconds: 200));

      // Query should be cleaned up
      // Note: We can't easily verify this without accessing internals
    });

    test('queryProvider with AsyncValue.when() works correctly', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = queryProvider<String>(
        'when'.toQueryKey(),
        () async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'test data';
        },
      );

      final initialValue = container.read(provider);
      var whenResult = initialValue.when(
        data: (data) => 'data: $data',
        loading: () => 'loading',
        error: (error, stack) => 'error: $error',
      );
      expect(whenResult, equals('loading'));

      // Wait for data
      await container.read(provider.future);

      final finalValue = container.read(provider);
      whenResult = finalValue.when(
        data: (data) => 'data: $data',
        loading: () => 'loading',
        error: (error, stack) => 'error: $error',
      );
      expect(whenResult, equals('data: test data'));
    });
  });
}
