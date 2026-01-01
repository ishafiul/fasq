import 'dart:developer';

import '../../cache/cache_metrics.dart';
import '../metrics_exporter.dart';

class ConsoleExporter implements MetricsExporter {
  Map<String, dynamic> _config = {};

  Map<String, dynamic> get config => _config;

  @override
  Future<void> export(PerformanceSnapshot snapshot) async {
    log('FASQ Performance Metrics Snapshot:');
    log('  Timestamp: ${snapshot.timestamp.toIso8601String()}');
    log('  Total Queries: ${snapshot.totalQueries}');
    log('  Active Queries: ${snapshot.activeQueries}');
    log('  Cache Hit Rate: ${(snapshot.cacheMetrics.hitRate * 100).toStringAsFixed(2)}%');
    log('  Memory Usage: ${(snapshot.memoryUsageBytes / (1024 * 1024)).toStringAsFixed(2)} MB');
    log('  Cache Requests: ${snapshot.cacheMetrics.totalRequests}');
    log('  Cache Hits: ${snapshot.cacheMetrics.hits}');
    log('  Cache Misses: ${snapshot.cacheMetrics.misses}');

    if (snapshot.queryMetrics.isNotEmpty) {
      log('  Query Metrics:');
      snapshot.queryMetrics.forEach((key, metrics) {
        log('    Query: $key');
        final avgTime = metrics.averageFetchTime;
        if (avgTime != null) {
          log('      Avg Fetch Time: ${avgTime.inMilliseconds}ms');
        } else {
          log('      Avg Fetch Time: N/A');
        }
        final maxTime = metrics.maxFetchTime;
        if (maxTime != null) {
          log('      Max Fetch Time: ${maxTime.inMilliseconds}ms');
        } else {
          log('      Max Fetch Time: N/A');
        }
        log('      Fetch Count: ${metrics.fetchCount}');
        log('      Reference Count: ${metrics.referenceCount}');
      });
    } else {
      log('  Query Metrics: None');
    }
  }

  @override
  void configure(Map<String, dynamic> config) {
    _config = config;
  }
}
