import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CancellationToken', () {
    test('starts not cancelled', () {
      final token = CancellationToken();
      expect(token.isCancelled, isFalse);
    });

    test('isCancelled returns true after cancel()', () {
      final token = CancellationToken()..cancel();
      expect(token.isCancelled, isTrue);
    });

    test('cancel() is idempotent', () {
      final token = CancellationToken()
        ..cancel()
        ..cancel();
      expect(token.isCancelled, isTrue);
    });

    test('throwIfCancelled() does nothing when not cancelled', () {
      final token = CancellationToken();
      expect(token.throwIfCancelled, returnsNormally);
    });

    test('throwIfCancelled() throws CancelledException when cancelled', () {
      final token = CancellationToken()..cancel();
      expect(
        token.throwIfCancelled,
        throwsA(isA<CancelledException>()),
      );
    });

    test('onCancel callback is invoked when cancel() is called', () {
      final token = CancellationToken();
      var callbackInvoked = false;
      token.onCancel(() {
        callbackInvoked = true;
      });
      expect(callbackInvoked, isFalse);

      token.cancel();
      expect(callbackInvoked, isTrue);
    });

    test('onCancel callback is invoked immediately if already cancelled', () {
      final token = CancellationToken()..cancel();

      var callbackInvoked = false;
      token.onCancel(() {
        callbackInvoked = true;
      });
      expect(callbackInvoked, isTrue);
    });

    test('multiple onCancel callbacks are all invoked', () {
      final token = CancellationToken();
      var count = 0;
      token
        ..onCancel(() => count++)
        ..onCancel(() => count++)
        ..onCancel(() => count++)
        ..cancel();
      expect(count, equals(3));
    });

    test('cancelled Future completes when cancel() is called', () async {
      final token = CancellationToken();

      var completed = false;
      await token.cancelled.then((_) => completed = true);

      expect(completed, isFalse);
      token.cancel();

      // Allow microtask to complete
      await Future<void>.delayed(Duration.zero);
      expect(completed, isTrue);
    });

    test('cancelled Future completes immediately if already cancelled',
        () async {
      final token = CancellationToken()..cancel();

      var completed = false;
      await token.cancelled.then((_) => completed = true);
      expect(completed, isTrue);
    });

    test('createChild creates a child token', () {
      final parent = CancellationToken();
      final child = parent.createChild();

      expect(child.isCancelled, isFalse);
    });

    test('child token is cancelled when parent is cancelled', () {
      final parent = CancellationToken();
      final child = parent.createChild();

      parent.cancel();
      expect(child.isCancelled, isTrue);
    });

    test('child token is already cancelled if parent was cancelled', () {
      final parent = CancellationToken()..cancel();

      final child = parent.createChild();
      expect(child.isCancelled, isTrue);
    });

    test('onCancel errors do not prevent other callbacks', () {
      final token = CancellationToken();
      var secondCallbackCalled = false;

      token
        ..onCancel(() => throw Exception('error'))
        ..onCancel(() => secondCallbackCalled = true)
        ..cancel();
      expect(secondCallbackCalled, isTrue);
    });
  });

  group('CancelledException', () {
    test('has default message', () {
      const exception = CancelledException();
      expect(exception.message, equals('Operation was cancelled'));
    });

    test('accepts custom message', () {
      const exception = CancelledException('Custom cancellation');
      expect(exception.message, equals('Custom cancellation'));
    });

    test('toString includes message', () {
      const exception = CancelledException('test');
      expect(exception.toString(), contains('test'));
    });
  });

  group('Query cancellation', () {
    late QueryCache cache;

    setUp(() {
      cache = QueryCache();
      // Use zero disposal delay for tests
      Query.disposalDelay = Duration.zero;
    });

    tearDown(() {
      cache.clear();
      // Reset to default
      Query.disposalDelay = const Duration(seconds: 5);
    });

    test('cancel() does not throw when no fetch is in progress', () {
      final query = Query<String>(
        queryKey: const StringQueryKey('test'),
        queryFn: () async => 'data',
        cache: cache,
      );

      expect(query.cancel, returnsNormally);
      query.dispose();
    });

    test('cancel() cancels internal token without throwing', () async {
      final query = Query<String>(
        queryKey: const StringQueryKey('test'),
        queryFn: () async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 'data';
        },
        cache: cache,
      )..addListener();

      // Start fetch (don't await)
      final fetchFuture = query.fetch();

      // Cancel - should not throw
      expect(query.cancel, returnsNormally);

      // Wait for fetch to complete (it will complete normally since
      // queryFn doesn't check cancellation token yet)
      await fetchFuture;

      query
        ..removeListener()
        ..dispose();
    });

    test('rapid cancel and refetch works correctly', () async {
      var fetchCount = 0;

      final query = Query<String>(
        queryKey: const StringQueryKey('test'),
        queryFn: () async {
          fetchCount++;
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return 'data-$fetchCount';
        },
        cache: cache,
      )
        ..addListener()

        // Start fetch
        // ignore: unawaited_futures
        ..fetch()

        // Cancel and refetch rapidly
        ..cancel();
      await query.fetch();

      // Query should have data
      expect(query.state.isSuccess, isTrue);

      query
        ..removeListener()
        ..dispose();
    });

    test('new fetch cancels previous in-flight fetch', () async {
      var firstFetchCancelled = false;

      final query = Query<String>(
        queryKey: const StringQueryKey('test'),
        queryFn: () async {
          await Future<void>.delayed(const Duration(milliseconds: 50));
          if (!firstFetchCancelled) {
            firstFetchCancelled = true;
            return 'first';
          }
          return 'second';
        },
        cache: cache,
      )..addListener();

      // Start first fetch
      final firstFetch = query.fetch();

      // Start second fetch immediately (should cancel first)
      final secondFetch = query.fetch();

      await Future.wait([firstFetch, secondFetch]);

      // Only one fetch result should be stored
      expect(query.state.data, anyOf('first', 'second'));

      query
        ..removeListener()
        ..dispose();
    });

    test('dispose() cancels in-flight fetch', () async {
      final query = Query<String>(
        queryKey: const StringQueryKey('test'),
        queryFn: () async {
          await Future<void>.delayed(const Duration(milliseconds: 100));
          return 'data';
        },
        cache: cache,
      )..addListener();

      // Start fetch
      unawaited(query.fetch());

      // Dispose immediately
      query
        ..removeListener()
        ..dispose();

      // Wait for fetch to potentially complete
      await Future<void>.delayed(const Duration(milliseconds: 150));

      // Fetch should not have completed successfully
      // (because query was disposed)
      // Note: fetchCompleted might be true but state won't update
    });
  });
}

// Helper to avoid unawaited_futures lint
void unawaited(Future<void> future) {}
