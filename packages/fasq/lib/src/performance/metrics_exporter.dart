import '../cache/cache_metrics.dart';

abstract class MetricsExporter {
  Future<void> export(PerformanceSnapshot snapshot);
  void configure(Map<String, dynamic> config);
}
