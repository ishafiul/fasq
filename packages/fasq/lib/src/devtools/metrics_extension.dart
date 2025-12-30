import 'dart:async';

import 'package:flutter/material.dart';

import '../cache/cache_metrics.dart';
import 'metrics_stream.dart';

/// Flutter widget for displaying FASQ performance metrics.
///
/// This widget can be used standalone or integrated with Flutter DevTools
/// to visualize real-time performance metrics from FASQ queries.
///
/// Example:
/// ```dart
/// final monitor = PerformanceMonitor(cache: cache, queries: queries);
/// final metricsStream = MetricsStream(monitor);
///
/// MaterialApp(
///   home: FasqMetricsExtension(metricsStream: metricsStream),
/// );
/// ```
class FasqMetricsExtension extends StatefulWidget {
  /// Optional stream of performance metrics for real-time updates.
  ///
  /// If provided, the widget will listen to this stream and update the UI
  /// whenever new snapshots are emitted.
  final MetricsStream? metricsStream;

  /// Optional initial snapshot to display before stream updates arrive.
  ///
  /// Useful for showing initial state or when using the widget without
  /// a metrics stream.
  final PerformanceSnapshot? initialSnapshot;

  /// Creates a new [FasqMetricsExtension] widget.
  ///
  /// [metricsStream] Optional stream for real-time metric updates.
  /// [initialSnapshot] Optional initial snapshot to display.
  const FasqMetricsExtension({
    super.key,
    this.metricsStream,
    this.initialSnapshot,
  });

  @override
  State<FasqMetricsExtension> createState() => _FasqMetricsExtensionState();
}

class _FasqMetricsExtensionState extends State<FasqMetricsExtension> {
  PerformanceSnapshot? _currentSnapshot;
  StreamSubscription<PerformanceSnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    _currentSnapshot = widget.initialSnapshot;

    if (widget.metricsStream != null) {
      _subscription = widget.metricsStream!.stream.listen((snapshot) {
        if (mounted) {
          setState(() {
            _currentSnapshot = snapshot;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentSnapshot == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('FASQ Performance Metrics'),
        ),
        body: const Center(
          child: Text('Waiting for FASQ metrics...'),
        ),
      );
    }

    final snapshot = _currentSnapshot!;
    final cacheReport = snapshot.cacheMetrics.getReport();

    return Scaffold(
      appBar: AppBar(
        title: const Text('FASQ Performance Metrics'),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('Cache Metrics'),
              _buildMetricCard(
                'Cache Hit Rate',
                '${(cacheReport.hitRate * 100).toStringAsFixed(2)}%',
              ),
              _buildMetricCard(
                'Cache Hits',
                '${snapshot.cacheMetrics.hits}',
              ),
              _buildMetricCard(
                'Cache Misses',
                '${snapshot.cacheMetrics.misses}',
              ),
              _buildMetricCard(
                'Cache Evictions',
                '${snapshot.cacheMetrics.evictions}',
              ),
              _buildMetricCard(
                'Total Requests',
                '${snapshot.cacheMetrics.totalRequests}',
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Memory Usage'),
              _buildMetricCard(
                'Current Memory',
                '${(snapshot.memoryUsageBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
              ),
              _buildMetricCard(
                'Peak Memory',
                '${(cacheReport.peakMemoryBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Query Statistics'),
              _buildMetricCard(
                'Total Queries',
                '${snapshot.totalQueries}',
              ),
              _buildMetricCard(
                'Active Queries',
                '${snapshot.activeQueries}',
              ),
              const SizedBox(height: 20),
              _buildSectionTitle('Performance Timing'),
              _buildMetricCard(
                'Avg Fetch Time',
                '${cacheReport.avgFetchTime.inMilliseconds}ms',
              ),
              _buildMetricCard(
                'P95 Fetch Time',
                '${cacheReport.p95FetchTime.inMilliseconds}ms',
              ),
              _buildMetricCard(
                'Avg Lookup Time',
                '${cacheReport.avgLookupTime.inMicroseconds}μs',
              ),
              if (snapshot.queryMetrics.isNotEmpty) ...[
                const SizedBox(height: 20),
                _buildSectionTitle('Query Metrics'),
                ...snapshot.queryMetrics.entries.map((entry) {
                  final queryKey = entry.key;
                  final metrics = entry.value;
                  return _buildQueryMetricsCard(queryKey, metrics);
                }),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a section title widget with consistent styling.
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0, top: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }

  /// Builds a metric card displaying a label-value pair.
  ///
  /// [label] The metric name or description.
  /// [value] The metric value to display.
  Widget _buildMetricCard(String label, String value) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds an expandable card displaying detailed metrics for a specific query.
  ///
  /// [queryKey] The unique identifier for the query.
  /// [metrics] The performance metrics for this query.
  Widget _buildQueryMetricsCard(String queryKey, QueryMetrics metrics) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: ExpansionTile(
        title: Text(
          'Query: $queryKey',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w500,
              ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetricRow('Fetch Count', '${metrics.fetchCount}'),
                _buildMetricRow(
                  'Reference Count',
                  '${metrics.referenceCount}',
                ),
                if (metrics.averageFetchTime != null)
                  _buildMetricRow(
                    'Avg Fetch Time',
                    '${metrics.averageFetchTime!.inMilliseconds}ms',
                  ),
                if (metrics.maxFetchTime != null)
                  _buildMetricRow(
                    'Max Fetch Time',
                    '${metrics.maxFetchTime!.inMilliseconds}ms',
                  ),
                if (metrics.lastFetchDuration != null)
                  _buildMetricRow(
                    'Last Fetch Duration',
                    '${metrics.lastFetchDuration!.inMilliseconds}ms',
                  ),
                if (metrics.throughputMetrics != null) ...[
                  const SizedBox(height: 8),
                  _buildSectionTitle('Throughput'),
                  _buildMetricRow(
                    'Requests Per Minute',
                    metrics.throughputMetrics!.requestsPerMinute
                        .toStringAsFixed(2),
                  ),
                  _buildMetricRow(
                    'Requests Per Second',
                    metrics.throughputMetrics!.requestsPerSecond
                        .toStringAsFixed(2),
                  ),
                  _buildMetricRow(
                    'Total Requests (Window)',
                    '${metrics.throughputMetrics!.totalRequests}',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a row displaying a label-value pair within a query metrics card.
  ///
  /// [label] The metric name or description.
  /// [value] The metric value to display.
  Widget _buildMetricRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}
