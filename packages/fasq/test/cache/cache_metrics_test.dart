import 'package:fasq/src/cache/cache_metrics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('throughput windows retain exact rolling counts after expiry', () {
    var now = DateTime.utc(2026, 1, 1);
    final metrics = CacheMetrics(now: () => now);

    metrics.recordQueryExecution('todos');
    metrics.recordQueryExecution('todos');
    expect(
      metrics
          .calculateThroughput(
            'todos',
            window: const Duration(seconds: 1),
          )
          ?.totalRequests,
      2,
    );

    now = now.add(const Duration(seconds: 2));
    metrics.recordQueryExecution('todos');
    expect(
      metrics
          .calculateThroughput(
            'todos',
            window: const Duration(seconds: 1),
          )
          ?.totalRequests,
      1,
    );
    expect(
      metrics
          .calculateThroughput(
            'todos',
            window: const Duration(seconds: 5),
          )
          ?.totalRequests,
      3,
    );

    now = now.add(const Duration(minutes: 16));
    expect(
      metrics.calculateThroughput(
        'todos',
        window: const Duration(minutes: 1),
      ),
      isNull,
    );
  });
}
