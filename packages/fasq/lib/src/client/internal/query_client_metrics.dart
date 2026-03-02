import 'dart:async';

import 'package:fasq/src/cache/cache_metrics.dart';
import 'package:fasq/src/cache/query_cache.dart';
import 'package:fasq/src/observability/performance/metrics_config.dart';
import 'package:fasq/src/observability/performance/performance_monitor.dart';
import 'package:fasq/src/query/keys/query_key.dart';
import 'package:fasq/src/query/query.dart';

/// Encapsulates performance metrics and exporter scheduling for `QueryClient`.
final class QueryClientMetrics {
  /// Creates a metrics coordinator.
  QueryClientMetrics({
    required QueryCache cache,
    required Map<String, Query<Object?>> queries,
  }) : _performanceMonitor = PerformanceMonitor(
          cache: cache,
          queries: queries,
        );

  final PerformanceMonitor _performanceMonitor;
  MetricsConfig _metricsConfig = MetricsConfig();
  Timer? _exportTimer;

  /// Returns a snapshot of global performance metrics.
  PerformanceSnapshot getMetrics({
    Duration throughputWindow = const Duration(minutes: 1),
  }) {
    return _performanceMonitor.getSnapshot(throughputWindow: throughputWindow);
  }

  /// Returns metrics for a specific query key.
  QueryMetrics? getQueryMetrics(
    QueryKey queryKey, {
    Duration throughputWindow = const Duration(minutes: 1),
  }) {
    final snapshot =
        _performanceMonitor.getSnapshot(throughputWindow: throughputWindow);
    return snapshot.queryMetrics[queryKey.key];
  }

  /// Configures metric exporters and optional periodic auto-export.
  void configureMetricsExporters(MetricsConfig config) {
    _metricsConfig = config;
    _exportTimer?.cancel();
    _exportTimer = null;

    _metricsConfig.applyConfigurationToExporters(<String, dynamic>{});

    if (_metricsConfig.enableAutoExport &&
        _metricsConfig.exporters.isNotEmpty) {
      _exportTimer = Timer.periodic(
        _metricsConfig.exportInterval,
        (timer) async {
          final snapshot = _performanceMonitor.getSnapshot();
          for (final exporter in _metricsConfig.exporters) {
            try {
              await exporter.export(snapshot);
            } on Object catch (_) {
              // Exporter-level logging is delegated to exporters.
            }
          }
        },
      );
    }
  }

  /// Triggers an immediate export to all configured exporters.
  Future<void> exportMetricsManually() async {
    final snapshot = _performanceMonitor.getSnapshot();
    for (final exporter in _metricsConfig.exporters) {
      try {
        await exporter.export(snapshot);
      } on Object catch (_) {
        // Exporter-level logging is delegated to exporters.
      }
    }
  }

  /// Disposes active auto-export resources.
  void dispose() {
    _exportTimer?.cancel();
    _exportTimer = null;
  }
}
