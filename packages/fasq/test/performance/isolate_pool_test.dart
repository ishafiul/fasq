import 'package:flutter_test/flutter_test.dart';
import 'package:fasq/src/performance/isolate_pool.dart';
import 'package:fasq/src/performance/isolate_task.dart';

void main() {
  group('IsolatePool', () {
    late IsolatePool pool;

    setUp(() {
      pool = IsolatePool(poolSize: 1);
    });

    tearDown(() async {
      await pool.dispose();
    });

    test('executes synchronous work and returns result', () async {
      final result =
          await pool.execute<List<int>, int>(_sumReducer, [1, 2, 3, 4]);
      expect(result, 10);
    });

    test('executes asynchronous work and returns result', () async {
      final result = await pool.execute<int, int>(_delayedSquare, 7);
      expect(result, 49);
    });

    test('queues tasks when all workers are busy', () async {
      final futures = [
        pool.execute<int, int>(_delayedIdentity, 1),
        pool.execute<int, int>(_delayedIdentity, 2),
        pool.execute<int, int>(_delayedIdentity, 3),
      ];

      final values = await Future.wait(futures);
      expect(values, [1, 2, 3]);
    });

    test('propagates errors from worker isolate', () async {
      await expectLater(
        () => pool.execute<int, int>(_throwingWork, 5),
        throwsA(isA<IsolateExecutionException>()),
      );
    });
  });
}

int _sumReducer(List<int> values) {
  var total = 0;
  for (final value in values) {
    total += value;
  }
  return total;
}

Future<int> _delayedSquare(int value) async {
  await Future.delayed(const Duration(milliseconds: 20));
  return value * value;
}

Future<int> _delayedIdentity(int value) async {
  await Future.delayed(const Duration(milliseconds: 10));
  return value;
}

int _throwingWork(int value) {
  throw StateError('failed on $value');
}
