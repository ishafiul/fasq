import 'dart:convert';

import 'package:fasq/src/cache/cache_metrics.dart';
import 'package:fasq/src/performance/exporters/json_exporter.dart';
import 'package:fasq/src/performance/metrics_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('JsonExporter', () {
    late JsonExporter exporter;

    setUp(() {
      exporter = JsonExporter();
    });

    test('implements MetricsExporter interface', () {
      expect(exporter, isA<MetricsExporter>());
    });

    test('configure updates internal config', () {
      final config = {
        'endpoint': 'https://example.com/metrics',
        'enabled': true
      };
      exporter.configure(config);
      expect(exporter.config, config);
    });

    test('export generates valid JSON for snapshot with no queries', () async {
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

      // Verify snapshot can be serialized
      final jsonMap = snapshot.toJson();
      final jsonString = jsonEncode(jsonMap);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['timestamp'], isA<String>());
      expect(decoded['totalQueries'], 0);
      expect(decoded['activeQueries'], 0);
      expect(decoded['memoryUsageBytes'], 1024 * 1024);
      expect(decoded['cacheMetrics'], isA<Map>());
      expect(decoded['queryMetrics'], isA<Map>());
    });

    test('export generates valid JSON for snapshot with multiple queries',
        () async {
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
            const Duration(milliseconds: 180),
            const Duration(milliseconds: 220),
          ],
          lastFetchDuration: const Duration(milliseconds: 220),
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

      final jsonMap = snapshot.toJson();
      final jsonString = jsonEncode(jsonMap);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['totalQueries'], 2);
      expect(decoded['activeQueries'], 2);
      expect(decoded['queryMetrics'], isA<Map>());

      final queryMetricsMap = decoded['queryMetrics'] as Map<String, dynamic>;
      expect(queryMetricsMap.length, 2);
      expect(queryMetricsMap.containsKey('query1'), isTrue);
      expect(queryMetricsMap.containsKey('query2'), isTrue);

      final query1Data = queryMetricsMap['query1'] as Map<String, dynamic>;
      expect(query1Data['fetchCount'], 2);
      expect(query1Data['referenceCount'], 1);
      expect(query1Data['averageFetchTimeMs'], isA<int>());
      expect(query1Data['fetchHistory'], isA<List>());
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

      final jsonMap = snapshot.toJson();
      final jsonString = jsonEncode(jsonMap);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      final queryMetricsMap = decoded['queryMetrics'] as Map<String, dynamic>;
      final query1Data = queryMetricsMap['query1'] as Map<String, dynamic>;

      expect(query1Data['fetchCount'], 0);
      expect(query1Data['referenceCount'], 0);
      expect(query1Data['fetchHistory'], isA<List>());
      expect((query1Data['fetchHistory'] as List).isEmpty, isTrue);
    });

    test('export includes all cache metrics', () async {
      final cacheMetrics = CacheMetrics();
      cacheMetrics.recordHit();
      cacheMetrics.recordHit();
      cacheMetrics.recordMiss();
      cacheMetrics.recordEviction();
      cacheMetrics.recordMemoryUsage(5 * 1024 * 1024);
      cacheMetrics.recordFetchTime(const Duration(milliseconds: 100));
      cacheMetrics.recordFetchTime(const Duration(milliseconds: 150));
      cacheMetrics.recordLookupTime(const Duration(microseconds: 500));

      final snapshot = PerformanceSnapshot(
        timestamp: DateTime(2024, 1, 1, 12, 0, 0),
        cacheMetrics: cacheMetrics,
        queryMetrics: {},
        totalQueries: 0,
        activeQueries: 0,
        memoryUsageBytes: 5 * 1024 * 1024,
      );

      final jsonMap = snapshot.toJson();
      final cacheMetricsData = jsonMap['cacheMetrics'] as Map<String, dynamic>;

      expect(cacheMetricsData['hitRate'], isA<double>());
      expect(cacheMetricsData['hits'], 2);
      expect(cacheMetricsData['misses'], 1);
      expect(cacheMetricsData['totalRequests'], 3);
      expect(cacheMetricsData['evictions'], 1);
      expect(cacheMetricsData['avgFetchTimeMs'], isA<int>());
      expect(cacheMetricsData['p95FetchTimeMs'], isA<int>());
      expect(cacheMetricsData['avgLookupTimeMicros'], isA<int>());
      expect(cacheMetricsData['peakMemoryBytes'], isA<int>());
      expect(cacheMetricsData['currentMemoryBytes'], isA<int>());
    });

    test('export formats timestamp as ISO 8601 string', () async {
      final cacheMetrics = CacheMetrics();
      final timestamp = DateTime(2024, 1, 1, 12, 30, 45, 123, 456);

      final snapshot = PerformanceSnapshot(
        timestamp: timestamp,
        cacheMetrics: cacheMetrics,
        queryMetrics: {},
        totalQueries: 0,
        activeQueries: 0,
        memoryUsageBytes: 0,
      );

      final jsonMap = snapshot.toJson();
      final jsonString = jsonEncode(jsonMap);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      expect(decoded['timestamp'], timestamp.toIso8601String());
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

      final jsonMap = snapshot.toJson();
      final jsonString = jsonEncode(jsonMap);
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;

      final queryMetricsMap = decoded['queryMetrics'] as Map<String, dynamic>;
      final query1Data = queryMetricsMap['query1'] as Map<String, dynamic>;

      expect(query1Data['averageFetchTimeMs'], isA<int>());
      expect(query1Data.containsKey('lastFetchDurationMs'), isTrue);
    });
  });
}
