import 'metrics_exporter.dart';

/// Configuration for managing multiple metrics exporters and export settings.
///
/// This class serves as the central point for managing a list of [MetricsExporter]
/// instances and defining settings for metrics export, such as export interval
/// and auto-export functionality.
class MetricsConfig {
  /// List of configured metrics exporters.
  ///
  /// Each exporter will receive performance snapshots when metrics are exported.
  /// List of configured metrics exporters.
  ///
  /// Each exporter will receive performance snapshots when metrics are exported.
  final List<MetricsExporter> exporters;

  /// How often to automatically export metrics.
  ///
  /// Defaults to 1 minute. Only used when [enableAutoExport] is true.
  final Duration exportInterval;

  /// Whether to enable periodic automatic export of metrics.
  ///
  /// When enabled, metrics will be exported at the interval specified by
  /// [exportInterval]. Defaults to false.
  final bool enableAutoExport;

  /// Creates a new [MetricsConfig] instance.
  ///
  /// [exporters] defaults to an empty list.
  /// [exportInterval] defaults to 1 minute.
  /// [enableAutoExport] defaults to false.
  MetricsConfig({
    List<MetricsExporter> exporters = const [],
    this.exportInterval = const Duration(minutes: 1),
    this.enableAutoExport = false,
  }) : exporters = List.unmodifiable(exporters);

  /// Applies configuration to all managed exporters.
  ///
  /// Iterates through the [exporters] list and calls [MetricsExporter.configure]
  /// on each exporter with the provided [config] map.
  ///
  /// This allows bulk configuration of all exporters with shared settings,
  /// such as endpoint URLs or authentication tokens.
  ///
  /// Example:
  /// ```dart
  /// final config = MetricsConfig(exporters: [consoleExporter, jsonExporter]);
  /// config.applyConfigurationToExporters({
  ///   'endpoint': 'https://api.example.com/metrics',
  ///   'apiKey': 'secret-key',
  /// });
  /// ```
  void applyConfigurationToExporters(Map<String, dynamic> config) {
    for (final exporter in exporters) {
      exporter.configure(config);
    }
  }
}
