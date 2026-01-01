import 'package:ecommerce/core/services/fasq_logger_service.dart';
import 'package:ecommerce/core/services/query_client_service.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/foundation.dart';
import 'package:injectable/injectable.dart';

/// Service for managing metrics exporters and performance monitoring.
///
/// Configures and manages metrics export to various destinations:
/// - Console (development)
/// - JSON (logging/analysis)
/// - OpenTelemetry (production observability)
@singleton
class MetricsExporterService {
  final QueryClientService _queryClientService;
  final FasqLoggerService _logger;

  MetricsExporterService(
    this._queryClientService,
    this._logger,
  );

  /// Initializes metrics exporters based on the current environment.
  ///
  /// In debug mode: Console + JSON exporters
  /// In release mode: JSON + OpenTelemetry exporters (if endpoint configured)
  void initializeMetricsExporters({
    String? openTelemetryEndpoint,
    Map<String, String>? openTelemetryHeaders,
    bool enableAutoExport = true,
    Duration exportInterval = const Duration(minutes: 1),
  }) {
    final client = _queryClientService.client;
    final exporters = <MetricsExporter>[];

    // Always include console exporter in debug mode
    if (kDebugMode) {
      exporters.add(ConsoleExporter());
    }

    // JSON exporter with configuration for logging
    final jsonExporter = JsonExporter();
    if (kDebugMode) {
      // In debug mode, configure JSON exporter to log
      jsonExporter.configure({
        'log': true, // Custom config flag for logging
      });
    }
    exporters.add(jsonExporter);

    // OpenTelemetry exporter (if endpoint provided)
    if (openTelemetryEndpoint != null && openTelemetryEndpoint.isNotEmpty) {
      final exporter = OpenTelemetryExporter(
        endpoint: openTelemetryEndpoint,
      );
      // Configure headers if provided
      if (openTelemetryHeaders != null && openTelemetryHeaders.isNotEmpty) {
        exporter.configure(openTelemetryHeaders);
      }
      exporters.add(exporter);
    }

    // Configure exporters
    client.configureMetricsExporters(
      MetricsConfig(
        exporters: exporters,
        enableAutoExport: enableAutoExport,
        exportInterval: exportInterval,
      ),
    );

    _logger.logMetricsExport('Configuration', success: true);
  }

  /// Manually exports current metrics.
  Future<void> exportMetricsManually() async {
    try {
      await _queryClientService.client.exportMetricsManually();
      _logger.logMetricsExport('Manual Export', success: true);
    } catch (e, stackTrace) {
      _logger.logMetricsExport('Manual Export', success: false);
      _logger.logQueryError('metrics-export', e, stackTrace);
    }
  }

  /// Gets current performance snapshot.
  PerformanceSnapshot getMetrics({Duration throughputWindow = const Duration(minutes: 1)}) {
    return _queryClientService.client.getMetrics(
      throughputWindow: throughputWindow,
    );
  }

  /// Gets metrics for a specific query.
  QueryMetrics? getQueryMetrics(String queryKey, {Duration throughputWindow = const Duration(minutes: 1)}) {
    return _queryClientService.client.getQueryMetrics(
      queryKey.toQueryKey(),
      throughputWindow: throughputWindow,
    );
  }
}
