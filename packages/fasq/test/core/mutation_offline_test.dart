import 'package:flutter_test/flutter_test.dart';
import 'package:fasq/fasq.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Mutation with Offline Queue', () {
    late Mutation<String, String> mutation;

    setUp(() {
      mutation = Mutation<String, String>(
        mutationFn: (String data) async {
          await Future.delayed(Duration(milliseconds: 10));
          return 'Processed: $data';
        },
        options: MutationOptions(
          queueWhenOffline: true,
        ),
      );
    });

    tearDown(() {
      mutation.dispose();
      NetworkStatus.instance.setOnline(true);
      OfflineQueueManager.instance.clear();
    });

    test('should execute immediately when online', () async {
      NetworkStatus.instance.setOnline(true);

      final states = <MutationState<String>>[];
      final subscription = mutation.stream.listen(states.add);

      await mutation.mutate('test data');
      await Future.delayed(Duration(milliseconds: 50));

      expect(states.length, greaterThanOrEqualTo(2));
      expect(states.first.isLoading, isTrue);
      expect(states.last.isSuccess, isTrue);
      expect(states.last.data, equals('Processed: test data'));

      subscription.cancel();
    });

    test('should queue when offline', () async {
      NetworkStatus.instance.setOnline(false);

      final states = <MutationState<String>>[];
      final subscription = mutation.stream.listen(states.add);

      await mutation.mutate('test data');
      await Future.delayed(Duration(milliseconds: 50));

      expect(states.length, equals(1));
      expect(states.first.isQueued, isTrue);
      expect(OfflineQueueManager.instance.length, equals(1));

      subscription.cancel();
    });

    test('should not queue when queueWhenOffline is false', () async {
      final mutationNoQueue = Mutation<String, String>(
        mutationFn: (String data) async {
          return 'Processed: $data';
        },
        options: MutationOptions(
          queueWhenOffline: false,
        ),
      );

      NetworkStatus.instance.setOnline(false);

      final states = <MutationState<String>>[];
      final subscription = mutationNoQueue.stream.listen(states.add);

      await mutationNoQueue.mutate('test data');
      await Future.delayed(Duration(milliseconds: 50));

      expect(states.length, greaterThanOrEqualTo(2));
      expect(states.first.isLoading, isTrue);
      expect(states.last.isSuccess, isTrue);
      expect(OfflineQueueManager.instance.length, equals(0));

      subscription.cancel();
      mutationNoQueue.dispose();
    });

    test('should call onQueued callback when queued', () async {
      String? queuedData;
      final mutationWithCallback = Mutation<String, String>(
        mutationFn: (String data) async {
          return 'Processed: $data';
        },
        options: MutationOptions(
          queueWhenOffline: true,
          onQueued: (String data) {
            queuedData = data;
          },
        ),
      );

      NetworkStatus.instance.setOnline(false);

      await mutationWithCallback.mutate('test data');

      expect(queuedData, equals('test data'));

      mutationWithCallback.dispose();
    });

    test('should handle errors when online', () async {
      final errorMutation = Mutation<String, String>(
        mutationFn: (String data) async {
          throw Exception('Test error');
        },
        options: MutationOptions(
          queueWhenOffline: true,
        ),
      );

      NetworkStatus.instance.setOnline(true);

      final states = <MutationState<String>>[];
      final subscription = errorMutation.stream.listen(states.add);

      await errorMutation.mutate('test data');
      await Future.delayed(Duration(milliseconds: 50));

      expect(states.length, greaterThanOrEqualTo(2));
      expect(states.first.isLoading, isTrue);
      expect(states.last.isError, isTrue);
      expect(states.last.error.toString(), contains('Test error'));

      subscription.cancel();
      errorMutation.dispose();
    });

    test('should reset state correctly', () async {
      NetworkStatus.instance.setOnline(true);

      await mutation.mutate('test data');
      await Future.delayed(Duration(milliseconds: 50));

      expect(mutation.state.isSuccess, isTrue);

      mutation.reset();

      expect(mutation.state.isIdle, isTrue);
    });
  });
}
