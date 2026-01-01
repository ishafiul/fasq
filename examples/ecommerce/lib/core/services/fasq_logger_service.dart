import 'package:ecommerce/core/utils/logger.dart';
import 'package:fasq/fasq.dart';
import 'package:injectable/injectable.dart';

/// FASQ-specific logger service that integrates with the app's logger.
///
/// Provides structured logging for FASQ operations including:
/// - Query lifecycle events (fetch, success, error)
/// - Cache operations (hit, miss, eviction)
/// - Performance metrics
/// - Metrics export events
@singleton
class FasqLoggerService {
  /// Logs a query fetch event.
  void logQueryFetch(String queryKey) {
    logger.d('[FASQ] Query fetch: $queryKey');
  }

  /// Logs a query success event.
  void logQuerySuccess(String queryKey, {Duration? duration}) {
    final durationStr = duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    logger.i('[FASQ] Query success: $queryKey$durationStr');
  }

  /// Logs a query error event.
  void logQueryError(String queryKey, Object error, [StackTrace? stackTrace]) {
    logger.e(
      '[FASQ] Query error: $queryKey - $error',
      stackTrace: stackTrace,
    );
  }

  /// Logs a cache hit event.
  void logCacheHit(String queryKey) {
    logger.d('[FASQ] Cache hit: $queryKey');
  }

  /// Logs a cache miss event.
  void logCacheMiss(String queryKey) {
    logger.d('[FASQ] Cache miss: $queryKey');
  }

  /// Logs a cache eviction event.
  void logCacheEviction(String queryKey) {
    logger.w('[FASQ] Cache eviction: $queryKey');
  }

  /// Logs performance metrics.
  void logPerformanceMetrics(PerformanceSnapshot snapshot) {
    final cacheReport = snapshot.cacheMetrics.getReport();
    logger.i(
      '[FASQ] Performance Metrics:\n'
      '  Cache Hit Rate: ${(cacheReport.hitRate * 100).toStringAsFixed(1)}%\n'
      '  Total Queries: ${snapshot.totalQueries}\n'
      '  Active Queries: ${snapshot.activeQueries}\n'
      '  Memory Usage: ${(snapshot.memoryUsageBytes / 1024 / 1024).toStringAsFixed(2)} MB\n'
      '  Avg Fetch Time: ${cacheReport.avgFetchTime.inMilliseconds}ms\n'
      '  P95 Fetch Time: ${cacheReport.p95FetchTime.inMilliseconds}ms',
    );
  }

  /// Logs metrics export event.
  void logMetricsExport(String exporterType, {bool success = true}) {
    if (success) {
      logger.i('[FASQ] Metrics exported via $exporterType');
    } else {
      logger.e('[FASQ] Metrics export failed via $exporterType');
    }
  }

  /// Logs query execution for throughput tracking.
  void logQueryExecution(String queryKey) {
    logger.t('[FASQ] Query execution recorded: $queryKey');
  }
}
