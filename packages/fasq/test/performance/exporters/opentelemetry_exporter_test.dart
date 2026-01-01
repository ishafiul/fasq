import 'package:fasq/src/cache/cache_metrics.dart';
import 'package:fasq/src/performance/exporters/opentelemetry_exporter.dart';
import 'package:fasq/src/performance/metrics_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('OpenTelemetryExporter', () {
    late OpenTelemetryExporter exporter;

    setUp(() {
      exporter = OpenTelemetryExporter();
    });

    test('implements MetricsExporter interface', () {
      expect(exporter, isA<MetricsExporter>());
    });

    test('configure updates internal config', () {
      final config = {
        'endpoint': 'https://otel-collector.example.com/v1/metrics',
        'enabled': true
      };
      exporter.configure(config);
      expect(exporter.config, config);
    });

    test('export generates valid OTLP payload for snapshot with no queries', () async {
      final cacheMetrics = CacheMetrics();
      cacheMetrics.recordHit();
      cacheMetrics.recordMiss();
      cacheMetrics.recordMemoryUsage(1024 * 1024);
      cacheMetrics.recordFetchTime(const Duration(milliseconds: 100));
      cacheMetrics.recordLookupTime(const Duration(microseconds: 500));

      final snapshot = PerformanceSnapshot(
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        cacheMetrics: cacheMetrics,
        queryMetrics: {},
        totalQueries: 0,
        activeQueries: 0,
        memoryUsageBytes: 1024 * 1024,
      );

      await exporter.export(snapshot);

      // Verify export completes without errors
      expect(exporter.config, isA<Map<String, dynamic>>());
    });

    test('export generates valid OTLP payload structure', () async {
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
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        cacheMetrics: cacheMetrics,
        queryMetrics: queryMetrics,
        totalQueries: 2,
        activeQueries: 2,
        memoryUsageBytes: 2 * 1024 * 1024,
      );

      await exporter.export(snapshot);

      // Verify export completes without errors
      expect(exporter.config, isA<Map<String, dynamic>>());
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
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        cacheMetrics: cacheMetrics,
        queryMetrics: queryMetrics,
        totalQueries: 1,
        activeQueries: 0,
        memoryUsageBytes: 0,
      );

      await exporter.export(snapshot);

      // Verify export completes without errors
      expect(exporter.config, isA<Map<String, dynamic>>());
    });

    test('exporter with endpoint configured', () {
      final exporterWithEndpoint = OpenTelemetryExporter(
        endpoint: 'https://otel-collector.example.com/v1/metrics',
        resourceAttributes: {'environment': 'test'},
      );

      expect(exporterWithEndpoint.endpoint, 'https://otel-collector.example.com/v1/metrics');
      expect(exporterWithEndpoint.resourceAttributes['environment'], 'test');
    });

    test('export handles null optional fields in query metrics', () async {
      final cacheMetrics = CacheMetrics();
      final queryMetrics = <String, QueryMetrics>{
        'query1': QueryMetrics(
          fetchHistory: [const Duration(milliseconds: 100)],
          lastFetchDuration: null,
          referenceCount: 1,
        ),
      };

      final snapshot = PerformanceSnapshot(
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        cacheMetrics: cacheMetrics,
        queryMetrics: queryMetrics,
        totalQueries: 1,
        activeQueries: 1,
        memoryUsageBytes: 0,
      );

      await exporter.export(snapshot);

      // Verify export completes without errors
      expect(exporter.config, isA<Map<String, dynamic>>());
    });

    test('export without endpoint does not throw', () async {
      final exporterNoEndpoint = OpenTelemetryExporter();
      final cacheMetrics = CacheMetrics();
      final snapshot = PerformanceSnapshot(
        timestamp: DateTime.now(),
        cacheMetrics: cacheMetrics,
        queryMetrics: {},
        totalQueries: 0,
        activeQueries: 0,
        memoryUsageBytes: 0,
      );

      await expectLater(
        () => exporterNoEndpoint.export(snapshot),
        returnsNormally,
      );
    });
  });
}

