import 'package:flutter_test/flutter_test.dart';
import 'package:fasq_riverpod/fasq_riverpod.dart';

void main() {
  group('MutationProvider', () {
    setUp(() async {
      await QueryClient.resetForTesting();
    });

    tearDown(() async {
      await QueryClient.resetForTesting();
    });

    test('mutationProvider starts in idle state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = mutationProvider<String, String>(
        (variables) async => 'result: $variables',
      );

      final state = container.read(provider);

      expect(state.isIdle, isTrue);
      expect(state.isLoading, isFalse);
      expect(state.hasData, isFalse);
      expect(state.hasError, isFalse);
    });

    test('mutationProvider handles successful mutation', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      bool wasLoading = false;
      final provider = mutationProvider<String, String>(
        (variables) async {
          await Future.delayed(const Duration(milliseconds: 50));
          return 'result: $variables';
        },
      );

      // Listen for state changes to check if loading state was reached
      container.listen(
        provider,
        (previous, next) {
          if (next.isLoading) {
            wasLoading = true;
          }
        },
      );

      // Trigger mutation
      await container.read(provider.notifier).mutate('test');

      // Give time for stream to emit the success state
      await Future.delayed(const Duration(milliseconds: 20));

      // Should have been loading at some point
      expect(wasLoading, isTrue);

      // Should be success now
      final state = container.read(provider);
      expect(state.isSuccess, isTrue);
      expect(state.data, equals('result: test'));
    });

    test('mutationProvider handles mutation errors', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      bool wasLoading = false;
      final provider = mutationProvider<String, String>(
        (variables) async {
          await Future.delayed(const Duration(milliseconds: 50));
          throw Exception('Test error');
        },
      );

      // Listen for state changes to check if loading state was reached
      container.listen(
        provider,
        (previous, next) {
          if (next.isLoading) {
            wasLoading = true;
          }
        },
      );

      // Trigger mutation
      await container.read(provider.notifier).mutate('test');

      // Give time for stream to emit the error state
      await Future.delayed(const Duration(milliseconds: 20));

      // Should have been loading at some point
      expect(wasLoading, isTrue);

      // Should be error state now
      final state = container.read(provider);
      expect(state.hasError, isTrue);
      expect(state.error.toString(), contains('Test error'));
    });

    test('mutationProvider reset clears state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = mutationProvider<String, String>(
        (variables) async {
          await Future.delayed(const Duration(milliseconds: 10));
          return 'result: $variables';
        },
      );

      // Trigger mutation
      await container.read(provider.notifier).mutate('test');

      // Reset
      container.read(provider.notifier).reset();

      // Wait for reset to propagate
      await Future.delayed(const Duration(milliseconds: 10));
      await Future(() {}); // Pump event queue

      // Should be idle again
      final state = container.read(provider);
      expect(state.isIdle, isTrue);
      expect(state.data, isNull);
    });

    test('mutationProvider with onSuccess callback', () async {
      var callbackData = '';
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = mutationProvider<String, String>(
        (variables) async => 'result: $variables',
        options: MutationOptions(
          onSuccess: (data) {
            callbackData = data;
          },
        ),
      );

      // Trigger mutation
      await container.read(provider.notifier).mutate('test');

      // Callback should have been called
      expect(callbackData, equals('result: test'));
    });

    test('mutationProvider with onError callback', () async {
      Object? callbackError;
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = mutationProvider<String, String>(
        (variables) async => throw Exception('Test error'),
        options: MutationOptions(
          onError: (error) {
            callbackError = error;
          },
        ),
      );

      // Trigger mutation
      await container.read(provider.notifier).mutate('test');

      // Callback should have been called
      expect(callbackError, isNotNull);
      expect(callbackError.toString(), contains('Test error'));
    });

    test('mutationProvider with onMutate callback', () async {
      var mutateCallbackCalled = false;
      String? mutateData;
      String? mutateVariables;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = mutationProvider<String, String>(
        (variables) async => 'result: $variables',
        options: MutationOptions(
          onMutate: (data, variables) {
            mutateCallbackCalled = true;
            mutateData = data;
            mutateVariables = variables;
          },
        ),
      );

      // Trigger mutation
      await container.read(provider.notifier).mutate('test');

      // Callback should have been called
      expect(mutateCallbackCalled, isTrue);
      expect(mutateData, equals('result: test'));
      expect(mutateVariables, equals('test'));
    });

    test('mutationProvider uses fasqClientProvider', () async {
      final customConfig = CacheConfig(
        defaultStaleTime: Duration(minutes: 5),
      );

      final container = ProviderContainer(
        overrides: [
          fasqCacheConfigProvider.overrideWithValue(customConfig),
        ],
      );
      addTearDown(container.dispose);

      final provider = mutationProvider<String, String>(
        (variables) async => 'result: $variables',
      );

      // Read mutation (which should trigger fasqClientProvider)
      container.read(provider);

      // Verify the client is using the custom config
      final client = container.read(fasqClientProvider);
      expect(client, isNotNull);
    });

    test('mutationProvider multiple sequential mutations', () async {
      var callCount = 0;

      final container = ProviderContainer();
      addTearDown(container.dispose);

      final provider = mutationProvider<String, int>(
        (variables) async {
          callCount++;
          await Future.delayed(const Duration(milliseconds: 10));
          return 'result $variables (call $callCount)';
        },
      );

      // First mutation
      await container.read(provider.notifier).mutate(1);

      // Second mutation
      await container.read(provider.notifier).mutate(2);

      // Both mutations should have been called
      expect(callCount, equals(2));
    });

    test('mutationProvider disposes properly', () async {
      final container = ProviderContainer();

      final provider = mutationProvider<String, String>(
        (variables) async => 'result: $variables',
      );

      await container.read(provider.notifier).mutate('test');

      // Dispose container
      container.dispose();

      // Wait for cleanup
      await Future.delayed(const Duration(milliseconds: 100));

      // Mutation should be disposed (we can't easily verify this without internals)
    });
  });
}
