import '../cache/cache_metrics.dart';
import '../cache/query_cache.dart';
import '../core/query.dart';

/// Centralized performance monitoring service.
///
/// Provides comprehensive performance tracking and reporting capabilities
/// for the entire query system.
class PerformanceMonitor {
  final QueryCache cache;
  final Map<String, Query> queries;

  bool _isRecording = false;
  DateTime? _recordingStartTime;
  final Map<String, dynamic> _recordingData = {};

  /// Create a performance monitor
  PerformanceMonitor({
    required this.cache,
    required this.queries,
  });

  /// Get global performance snapshot
  PerformanceSnapshot getSnapshot(
      {Duration throughputWindow = const Duration(minutes: 1)}) {
    final queryMetrics = <String, QueryMetrics>{};

    // Collect metrics from all queries
    for (final entry in queries.entries) {
      final query = entry.value;
      final baseMetrics = query.metrics;

      // Calculate throughput metrics for this query
      final throughputMetrics = cache.metrics.calculateThroughput(
        entry.key,
        window: throughputWindow,
      );

      // Create QueryMetrics with throughput data
      final metricsWithThroughput = QueryMetrics(
        fetchHistory: baseMetrics.fetchHistory,
        lastFetchDuration: baseMetrics.lastFetchDuration,
        referenceCount: baseMetrics.referenceCount,
        throughputMetrics: throughputMetrics,
      );

      queryMetrics[entry.key] = metricsWithThroughput;
    }

    return PerformanceSnapshot(
      timestamp: DateTime.now(),
      cacheMetrics: cache.metrics,
      queryMetrics: queryMetrics,
      totalQueries: queries.length,
      activeQueries: queries.values.where((q) => q.referenceCount > 0).length,
      memoryUsageBytes: cache.metrics.currentMemoryBytes,
    );
  }

  /// Start recording performance metrics
  void startRecording() {
    if (_isRecording) return;

    _isRecording = true;
    _recordingStartTime = DateTime.now();
    _recordingData.clear();

    // Record initial state
    _recordingData['startTime'] = _recordingStartTime;
    _recordingData['initialSnapshot'] = getSnapshot().toJson();
  }

  /// Stop recording and get comprehensive report
  PerformanceReport stopRecording() {
    if (!_isRecording) {
      throw StateError('Recording is not active');
    }

    _isRecording = false;
    final endTime = DateTime.now();
    final duration = endTime.difference(_recordingStartTime!);

    // Record final state
    _recordingData['endTime'] = endTime;
    _recordingData['duration'] = duration.inMilliseconds;
    _recordingData['finalSnapshot'] = getSnapshot().toJson();

    // Generate report
    final report = _generateRecordingReport();

    return report;
  }

  /// Generate a comprehensive report from recording data
  PerformanceReport _generateRecordingReport() {
    final finalSnapshot =
        _recordingData['finalSnapshot'] as Map<String, dynamic>;
    final finalCacheMetrics =
        finalSnapshot['cacheMetrics'] as Map<String, dynamic>;

    // Use final metrics as base
    return PerformanceReport(
      hitRate: finalCacheMetrics['hitRate'] as double,
      avgFetchTime:
          Duration(milliseconds: finalCacheMetrics['avgFetchTimeMs'] as int),
      p95FetchTime:
          Duration(milliseconds: finalCacheMetrics['p95FetchTimeMs'] as int),
      avgLookupTime: Duration(
          microseconds: finalCacheMetrics['avgLookupTimeMicros'] as int),
      peakMemoryBytes: finalCacheMetrics['peakMemoryBytes'] as int,
      currentMemoryBytes: finalCacheMetrics['currentMemoryBytes'] as int,
      activeSubscriptions: finalCacheMetrics['activeSubscriptions'] as int,
      totalQueries: finalCacheMetrics['totalQueries'] as int,
      totalFetches: finalCacheMetrics['totalFetches'] as int,
      totalLookups: finalCacheMetrics['totalLookups'] as int,
    );
  }

  /// Export metrics for external monitoring systems
  Map<String, dynamic> exportMetrics() {
    final snapshot = getSnapshot();
    final data = snapshot.toJson();

    // Add recording data if available
    if (_recordingData.isNotEmpty) {
      data['recording'] = Map.from(_recordingData);
    }

    // Add system information
    data['system'] = {
      'timestamp': DateTime.now().toIso8601String(),
      'isRecording': _isRecording,
      'recordingDuration': _isRecording && _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : null,
    };

    return data;
  }

  /// Get performance summary for quick overview
  PerformanceSummary getSummary() {
    final snapshot = getSnapshot();
    final report = snapshot.report;

    return PerformanceSummary(
      hitRate: report.hitRate,
      averageFetchTime: report.avgFetchTime,
      memoryUsage: report.currentMemoryBytes,
      activeQueries: snapshot.activeQueries,
      totalQueries: snapshot.totalQueries,
      isHealthy: _isHealthy(report),
    );
  }

  /// Determine if the system is performing well
  bool _isHealthy(PerformanceReport report) {
    // Define health criteria
    const minHitRate = 0.7; // 70% hit rate
    const maxFetchTimeMs = 2000; // 2 seconds max fetch time
    const maxMemoryMB = 50; // 50MB max memory

    return report.hitRate >= minHitRate &&
        report.avgFetchTime.inMilliseconds <= maxFetchTimeMs &&
        report.currentMemoryBytes <= maxMemoryMB * 1024 * 1024;
  }

  /// Whether recording is currently active
  bool get isRecording => _isRecording;

  /// Get recording duration if active
  Duration? get recordingDuration {
    if (!_isRecording || _recordingStartTime == null) return null;
    return DateTime.now().difference(_recordingStartTime!);
  }
}

/// Quick performance summary for monitoring dashboards
class PerformanceSummary {
  final double hitRate;
  final Duration averageFetchTime;
  final int memoryUsage;
  final int activeQueries;
  final int totalQueries;
  final bool isHealthy;

  const PerformanceSummary({
    required this.hitRate,
    required this.averageFetchTime,
    required this.memoryUsage,
    required this.activeQueries,
    required this.totalQueries,
    required this.isHealthy,
  });

  /// Memory usage in MB
  double get memoryUsageMB => memoryUsage / (1024 * 1024);

  /// Hit rate as percentage
  double get hitRatePercentage => hitRate * 100;

  /// Query utilization (active vs total)
  double get queryUtilization =>
      totalQueries > 0 ? activeQueries / totalQueries : 0.0;

  @override
  String toString() {
    return 'PerformanceSummary('
        'hitRate: ${hitRatePercentage.toStringAsFixed(1)}%, '
        'avgFetch: ${averageFetchTime.inMilliseconds}ms, '
        'memory: ${memoryUsageMB.toStringAsFixed(1)}MB, '
        'queries: $activeQueries/$totalQueries, '
        'healthy: $isHealthy)';
  }
}
