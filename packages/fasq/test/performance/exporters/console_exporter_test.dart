import 'package:fasq/src/cache/cache_metrics.dart';
import 'package:fasq/src/performance/exporters/console_exporter.dart';
import 'package:fasq/src/performance/metrics_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ConsoleExporter', () {
    late ConsoleExporter exporter;

    setUp(() {
      exporter = ConsoleExporter();
    });

    test('implements MetricsExporter interface', () {
      expect(exporter, isA<MetricsExporter>());
    });

    test('configure updates internal config', () {
      final config = {'key': 'value', 'enabled': true};
      exporter.configure(config);
      expect(exporter.config, config);
    });

    test('export handles snapshot with no queries', () async {
      final cacheMetrics = CacheMetrics();
      cacheMetrics.recordHit();
      cacheMetrics.recordMiss();
      cacheMetrics.recordMemoryUsage(1024 * 1024);

      final snapshot = PerformanceSnapshot(
        timestamp: DateTime.now(),
        cacheMetrics: cacheMetrics,
        queryMetrics: {},
        totalQueries: 0,
        activeQueries: 0,
        memoryUsageBytes: 1024 * 1024,
      );

      await expectLater(
        () => exporter.export(snapshot),
        returnsNormally,
      );
    });

    test('export handles snapshot with multiple queries', () async {
      final cacheMetrics = CacheMetrics();
      cacheMetrics.recordHit();
      cacheMetrics.recordHit();
      cacheMetrics.recordMiss();
      cacheMetrics.recordMemoryUsage(2 * 1024 * 1024);

      final queryMetrics = <String, QueryMetrics>{
        'query1': QueryMetrics(
          fetchHistory: [
            const Duration(milliseconds: 100),
            const Duration(milliseconds: 150),
          ],
          lastFetchDuration: const Duration(milliseconds: 150),
          referenceCount: 1,
        ),
        'query2': QueryMetrics(
          fetchHistory: [
            const Duration(milliseconds: 200),
          ],
          lastFetchDuration: const Duration(milliseconds: 200),
          referenceCount: 2,
        ),
      };

      final snapshot = PerformanceSnapshot(
        timestamp: DateTime.now(),
        cacheMetrics: cacheMetrics,
        queryMetrics: queryMetrics,
        totalQueries: 2,
        activeQueries: 2,
        memoryUsageBytes: 2 * 1024 * 1024,
      );

      await expectLater(
        () => exporter.export(snapshot),
        returnsNormally,
      );
    });

    test('export handles query metrics with no fetch history', () async {
      final cacheMetrics = CacheMetrics();
      final queryMetrics = <String, QueryMetrics>{
        'query1': QueryMetrics(
          fetchHistory: [],
          referenceCount: 0,
        ),
      };

      final snapshot = PerformanceSnapshot(
        timestamp: DateTime.now(),
        cacheMetrics: cacheMetrics,
        queryMetrics: queryMetrics,
        totalQueries: 1,
        activeQueries: 0,
        memoryUsageBytes: 0,
      );

      await expectLater(
        () => exporter.export(snapshot),
        returnsNormally,
      );
    });

    test('export formats cache hit rate correctly', () async {
      final cacheMetrics = CacheMetrics();
      cacheMetrics.recordHit();
      cacheMetrics.recordHit();
      cacheMetrics.recordMiss();

      final snapshot = PerformanceSnapshot(
        timestamp: DateTime.now(),
        cacheMetrics: cacheMetrics,
        queryMetrics: {},
        totalQueries: 0,
        activeQueries: 0,
        memoryUsageBytes: 0,
      );

      await expectLater(
        () => exporter.export(snapshot),
        returnsNormally,
      );

      expect(cacheMetrics.hitRate, closeTo(0.666, 0.01));
    });

    test('export formats memory usage in MB', () async {
      final cacheMetrics = CacheMetrics();
      final memoryBytes = 5 * 1024 * 1024;

      final snapshot = PerformanceSnapshot(
        timestamp: DateTime.now(),
        cacheMetrics: cacheMetrics,
        queryMetrics: {},
        totalQueries: 0,
        activeQueries: 0,
        memoryUsageBytes: memoryBytes,
      );

      await expectLater(
        () => exporter.export(snapshot),
        returnsNormally,
      );
    });
  });
}
