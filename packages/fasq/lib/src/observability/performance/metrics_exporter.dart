import 'package:fasq/src/cache/cache_metrics.dart';

/// Contract for exporting performance snapshots to external sinks.
abstract class MetricsExporter {
  /// Exports a single [snapshot] to the configured destination.
  Future<void> export(PerformanceSnapshot snapshot);

  /// Applies exporter-specific [config] values.
  void configure(Map<String, dynamic> config);
}
