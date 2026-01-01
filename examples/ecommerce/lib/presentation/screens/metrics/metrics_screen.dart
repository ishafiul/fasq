import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/services/metrics_exporter_service.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

/// Screen for displaying FASQ performance metrics.
///
/// Shows real-time performance data including:
/// - Cache metrics (hit rate, hits, misses)
/// - Memory usage
/// - Query statistics
/// - Performance timing
/// - Per-query details
@RoutePage()
class MetricsScreen extends StatefulWidget {
  const MetricsScreen({super.key});

  @override
  State<MetricsScreen> createState() => _MetricsScreenState();
}

class _MetricsScreenState extends State<MetricsScreen> {
  late final MetricsExporterService _metricsService;
  PerformanceSnapshot? _snapshot;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    _metricsService = locator<MetricsExporterService>();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isRefreshing = true);
    try {
      final snapshot = _metricsService.getMetrics();
      setState(() {
        _snapshot = snapshot;
        _isRefreshing = false;
      });
    } catch (e) {
      setState(() => _isRefreshing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading metrics: $e')),
        );
      }
    }
  }

  Future<void> _exportMetrics() async {
    await _metricsService.exportMetricsManually();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Metrics exported successfully')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FASQ Performance Metrics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRefreshing ? null : _loadMetrics,
            tooltip: 'Refresh metrics',
          ),
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: _exportMetrics,
            tooltip: 'Export metrics',
          ),
        ],
      ),
      body: _isRefreshing
          ? const Center(child: CircularProgressIndicator())
          : _snapshot == null
              ? const Center(child: Text('No metrics available'))
              : _buildMetricsContent(_snapshot!),
    );
  }

  Widget _buildMetricsContent(PerformanceSnapshot snapshot) {
    final cacheReport = snapshot.cacheMetrics.getReport();

    return RefreshIndicator(
      onRefresh: _loadMetrics,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Cache Metrics'),
            _buildMetricCard(
              'Cache Hit Rate',
              '${(cacheReport.hitRate * 100).toStringAsFixed(2)}%',
              icon: Icons.trending_up,
            ),
            _buildMetricCard(
              'Cache Hits',
              '${snapshot.cacheMetrics.hits}',
              icon: Icons.check_circle,
            ),
            _buildMetricCard(
              'Cache Misses',
              '${snapshot.cacheMetrics.misses}',
              icon: Icons.cancel,
            ),
            _buildMetricCard(
              'Cache Evictions',
              '${snapshot.cacheMetrics.evictions}',
              icon: Icons.delete_outline,
            ),
            _buildMetricCard(
              'Total Requests',
              '${snapshot.cacheMetrics.totalRequests}',
              icon: Icons.request_quote,
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Memory Usage'),
            _buildMetricCard(
              'Current Memory',
              '${(snapshot.memoryUsageBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
              icon: Icons.memory,
            ),
            _buildMetricCard(
              'Peak Memory',
              '${(cacheReport.peakMemoryBytes / (1024 * 1024)).toStringAsFixed(2)} MB',
              icon: Icons.arrow_upward,
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Query Statistics'),
            _buildMetricCard(
              'Total Queries',
              '${snapshot.totalQueries}',
              icon: Icons.list,
            ),
            _buildMetricCard(
              'Active Queries',
              '${snapshot.activeQueries}',
              icon: Icons.play_circle,
            ),
            const SizedBox(height: 20),
            _buildSectionTitle('Performance Timing'),
            _buildMetricCard(
              'Avg Fetch Time',
              '${cacheReport.avgFetchTime.inMilliseconds}ms',
              icon: Icons.timer,
            ),
            _buildMetricCard(
              'P95 Fetch Time',
              '${cacheReport.p95FetchTime.inMilliseconds}ms',
              icon: Icons.timer_outlined,
            ),
            _buildMetricCard(
              'Avg Lookup Time',
              '${cacheReport.avgLookupTime.inMicroseconds}μs',
              icon: Icons.search,
            ),
            if (snapshot.queryMetrics.isNotEmpty) ...[
              const SizedBox(height: 20),
              _buildSectionTitle('Query Metrics'),
              ...snapshot.queryMetrics.entries.map((entry) {
                return _buildQueryMetricsCard(entry.key, entry.value);
              }),
            ],
          ],
        ),
      ),
    );
  }

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

  Widget _buildMetricCard(String label, String value, {IconData? icon}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
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
                _buildMetricRow('Reference Count', '${metrics.referenceCount}'),
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
                  Text(
                    'Throughput',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 4),
                  _buildMetricRow(
                    'Requests Per Minute',
                    metrics.throughputMetrics!.requestsPerMinute.toStringAsFixed(2),
                  ),
                  _buildMetricRow(
                    'Requests Per Second',
                    metrics.throughputMetrics!.requestsPerSecond.toStringAsFixed(2),
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
