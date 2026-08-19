import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mutation with Offline Queue', () {
    late Mutation<String, String> mutation;
    late DurableMutationQueue durableQueue;

    setUp(() {
      durableQueue = DurableMutationQueue(store: _MemoryOutboxStore());
      mutation = Mutation<String, String>(
        mutationFn: (data) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return 'Processed: $data';
        },
        options: MutationOptions(
          queueWhenOffline: true,
          durableQueue: DurableMutationQueueOptions(
            queue: durableQueue,
            mutationKey: _mutationKey,
            codec: _stringCodec,
          ),
        ),
      );
    });

    tearDown(() {
      mutation.dispose();
      NetworkStatus.instance.setOnline(online: true);
      unawaited(durableQueue.close());
    });

    test('should execute immediately when online', () async {
      NetworkStatus.instance.setOnline(online: true);

      final states = <MutationState<String>>[];
      final subscription = mutation.stream.listen(states.add);

      await mutation.mutate('test data');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states.length, greaterThanOrEqualTo(2));
      expect(states.first.isLoading, isTrue);
      expect(states.last.isSuccess, isTrue);
      expect(states.last.data, equals('Processed: test data'));

      await subscription.cancel();
    });

    test('should queue when offline', () async {
      NetworkStatus.instance.setOnline(online: false);

      final states = <MutationState<String>>[];
      final subscription = mutation.stream.listen(states.add);

      await mutation.mutate('test data');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states.length, equals(1));
      expect(states.first.isQueued, isTrue);
      expect(durableQueue.snapshot.active, hasLength(1));

      await subscription.cancel();
    });

    test('should not queue when queueWhenOffline is false', () async {
      final mutationNoQueue = Mutation<String, String>(
        mutationFn: (data) async {
          return 'Processed: $data';
        },
        options: const MutationOptions(),
      );

      NetworkStatus.instance.setOnline(online: false);

      final states = <MutationState<String>>[];
      final subscription = mutationNoQueue.stream.listen(states.add);

      await mutationNoQueue.mutate('test data');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states.length, greaterThanOrEqualTo(2));
      expect(states.first.isLoading, isTrue);
      expect(states.last.isSuccess, isTrue);

      await subscription.cancel();
      mutationNoQueue.dispose();
    });

    test('should call onQueued callback when queued', () async {
      String? queuedData;
      final callbackQueue = DurableMutationQueue(
        store: _MemoryOutboxStore(),
      );
      final mutationWithCallback = Mutation<String, String>(
        mutationFn: (data) async {
          return 'Processed: $data';
        },
        options: MutationOptions(
          queueWhenOffline: true,
          durableQueue: DurableMutationQueueOptions(
            queue: callbackQueue,
            mutationKey: _mutationKey,
            codec: _stringCodec,
          ),
          onQueued: (data) {
            queuedData = data;
          },
        ),
      );

      NetworkStatus.instance.setOnline(online: false);

      await mutationWithCallback.mutate('test data');

      expect(queuedData, equals('test data'));

      mutationWithCallback.dispose();
      await callbackQueue.close();
    });

    test(
      'replays queued work through the registered mutation function',
      () async {
        var calls = 0;
        final replayQueue = DurableMutationQueue(store: _MemoryOutboxStore());
        final replayMutation = Mutation<String, String>(
          mutationFn: (data) async {
            calls++;
            return 'Replayed: $data';
          },
          options: MutationOptions(
            queueWhenOffline: true,
            durableQueue: DurableMutationQueueOptions(
              queue: replayQueue,
              mutationKey: MutationKey(namespace: 'tests', name: 'replay'),
              codec: _stringCodec,
            ),
          ),
        );

        NetworkStatus.instance.setOnline(online: false);
        await replayMutation.mutate('after restart');
        NetworkStatus.instance.setOnline(online: true);
        final report = await replayQueue.replay();

        expect(calls, 1);
        expect(report.executedOperationIds, hasLength(1));
        expect(replayQueue.snapshot.active, isEmpty);
        expect(
          replayQueue.snapshot.history.single.state,
          MutationOperationState.succeeded,
        );

        replayMutation.dispose();
        await replayQueue.close();
      },
    );

    test('should handle errors when online', () async {
      final errorQueue = DurableMutationQueue(store: _MemoryOutboxStore());
      final errorMutation = Mutation<String, String>(
        mutationFn: (data) async {
          throw Exception('Test error');
        },
        options: MutationOptions(
          queueWhenOffline: true,
          durableQueue: DurableMutationQueueOptions(
            queue: errorQueue,
            mutationKey: _mutationKey,
            codec: _stringCodec,
          ),
        ),
      );

      NetworkStatus.instance.setOnline(online: true);

      final states = <MutationState<String>>[];
      final subscription = errorMutation.stream.listen(states.add);

      await errorMutation.mutate('test data');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(states.length, greaterThanOrEqualTo(2));
      expect(states.first.isLoading, isTrue);
      expect(states.last.isError, isTrue);
      expect(states.last.error.toString(), contains('Test error'));

      await subscription.cancel();
      errorMutation.dispose();
      await errorQueue.close();
    });

    test('should reset state correctly', () async {
      NetworkStatus.instance.setOnline(online: true);

      await mutation.mutate('test data');
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(mutation.state.isSuccess, isTrue);

      mutation.reset();

      expect(mutation.state.isIdle, isTrue);
    });
  });
}

final _mutationKey = MutationKey(namespace: 'tests', name: 'text');

final _stringCodec = JsonMutationCodec<String>(
  encoder: (value) => value,
  decoder: (payload) {
    if (payload is! String) {
      throw const InvalidMutationPayloadException('Expected a string');
    }
    return payload;
  },
);

class _MemoryOutboxStore implements DurableOutboxStore {
  OutboxSnapshot _snapshot = OutboxSnapshot();
  int _generation = 0;
  bool _isOpen = false;

  @override
  Future<OutboxSnapshot> open() async {
    _isOpen = true;
    return _snapshot;
  }

  @override
  OutboxSnapshot get snapshot => _snapshot;

  @override
  int get generation => _generation;

  @override
  Future<OutboxSnapshot> transact(
    DurableOutboxTransaction transaction, {
    int? expectedGeneration,
  }) async {
    if (!_isOpen) throw StateError('store is closed');
    if (expectedGeneration != null && expectedGeneration != _generation) {
      throw const OutboxGenerationConflictException();
    }
    _snapshot = transaction(_snapshot);
    _generation++;
    return _snapshot;
  }

  @override
  Future<void> close() async {
    _isOpen = false;
  }
}
