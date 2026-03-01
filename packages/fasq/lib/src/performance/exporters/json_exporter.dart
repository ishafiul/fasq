import 'dart:convert';

import 'package:fasq/src/cache/cache_metrics.dart';
import 'package:fasq/src/performance/metrics_exporter.dart';

/// Exports performance snapshots as JSON payloads.
class JsonExporter implements MetricsExporter {
  Map<String, dynamic> _config = {};

  /// Current exporter configuration.
  Map<String, dynamic> get config => _config;

  @override
  Future<void> export(PerformanceSnapshot snapshot) async {
    final cacheReport = snapshot.cacheMetrics.getReport();

    final exportData = <String, dynamic>{
      'timestamp': snapshot.timestamp.toIso8601String(),
      'totalQueries': snapshot.totalQueries,
      'activeQueries': snapshot.activeQueries,
      'memoryUsageBytes': snapshot.memoryUsageBytes,
      'cacheMetrics': {
        'hitRate': cacheReport.hitRate,
        'hits': snapshot.cacheMetrics.hits,
        'misses': snapshot.cacheMetrics.misses,
        'totalRequests': snapshot.cacheMetrics.totalRequests,
        'evictions': snapshot.cacheMetrics.evictions,
        'avgFetchTimeMs': cacheReport.avgFetchTime.inMilliseconds,
        'p95FetchTimeMs': cacheReport.p95FetchTime.inMilliseconds,
        'avgLookupTimeMicros': cacheReport.avgLookupTime.inMicroseconds,
        'peakMemoryBytes': cacheReport.peakMemoryBytes,
        'currentMemoryBytes': cacheReport.currentMemoryBytes,
        'activeSubscriptions': cacheReport.activeSubscriptions,
        'totalFetches': cacheReport.totalFetches,
        'totalLookups': cacheReport.totalLookups,
      },
      'queryMetrics': snapshot.queryMetrics.map((key, metrics) {
        final queryData = <String, dynamic>{
          'fetchCount': metrics.fetchCount,
          'referenceCount': metrics.referenceCount,
        };

        if (metrics.averageFetchTime != null) {
          queryData['avgFetchTimeMs'] =
              metrics.averageFetchTime!.inMilliseconds;
        }

        if (metrics.maxFetchTime != null) {
          queryData['maxFetchTimeMs'] = metrics.maxFetchTime!.inMilliseconds;
        }

        if (metrics.lastFetchDuration != null) {
          queryData['lastFetchDurationMs'] =
              metrics.lastFetchDuration!.inMilliseconds;
        }

        queryData['fetchHistory'] =
            metrics.fetchHistory.map((d) => d.inMilliseconds).toList();

        return MapEntry(key, queryData);
      }),
    };

    final jsonString = jsonEncode(exportData);
    await _sendJson(jsonString, _config);
  }

  Future<void> _sendJson(String jsonString, Map<String, dynamic> config) async {
    final endpoint = config['endpoint'] as String?;

    if (endpoint != null) {
      // Future: Implement HTTP POST logic here
      // Example:
      // final response = await http.post(
      //   Uri.parse(endpoint),
      //   headers: {'Content-Type': 'application/json'},
      //   body: jsonString,
      // );
      // if (response.statusCode != 200) {
      //   throw Exception('Failed to send metrics: ${response.statusCode}');
      // }
    }
  }

  @override
  void configure(Map<String, dynamic> config) {
    _config = config;
  }
}
