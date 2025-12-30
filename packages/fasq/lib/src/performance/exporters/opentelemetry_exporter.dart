import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import '../../cache/cache_metrics.dart';
import '../metrics_exporter.dart';

class OpenTelemetryExporter implements MetricsExporter {
  final String? endpoint;
  final Map<String, String> resourceAttributes;
  Map<String, dynamic> _config = {};

  OpenTelemetryExporter({
    this.endpoint,
    this.resourceAttributes = const {},
  });

  Map<String, dynamic> get config => _config;

  @override
  Future<void> export(PerformanceSnapshot snapshot) async {
    final otlpPayload = _buildOtlpPayload(snapshot);
    final jsonString = jsonEncode(otlpPayload);

    if (endpoint != null) {
      await _sendOtlp(jsonString, endpoint!);
    }
  }

  Map<String, dynamic> _buildOtlpPayload(PerformanceSnapshot snapshot) {
    final cacheReport = snapshot.cacheMetrics.getReport();
    final now = DateTime.now().toUtc();
    final timestampNanos = now.millisecondsSinceEpoch * 1000000;

    final resourceMetrics = <Map<String, dynamic>>[];

    final scopeMetrics = <Map<String, dynamic>>[
      {
        'scope': {
          'name': 'fasq',
          'version': '0.4.0',
        },
        'metrics': _buildMetrics(snapshot, cacheReport, timestampNanos),
      }
    ];

    resourceMetrics.add({
      'resource': {
        'attributes': [
          {
            'key': 'service.name',
            'value': {'stringValue': 'fasq'}
          },
          ...resourceAttributes.entries.map((e) => {
                'key': e.key,
                'value': {'stringValue': e.value}
              }),
        ],
      },
      'scopeMetrics': scopeMetrics,
    });

    return {
      'resourceMetrics': resourceMetrics,
    };
  }

  List<Map<String, dynamic>> _buildMetrics(
    PerformanceSnapshot snapshot,
    PerformanceReport cacheReport,
    int timestampNanos,
  ) {
    final metrics = <Map<String, dynamic>>[];

    metrics.add(_createGaugeMetric(
      'fasq.cache.hit_rate',
      'Cache hit rate (0.0 to 1.0)',
      cacheReport.hitRate,
      timestampNanos,
    ));

    metrics.add(_createGaugeMetric(
      'fasq.cache.hits',
      'Total number of cache hits',
      snapshot.cacheMetrics.hits.toDouble(),
      timestampNanos,
    ));

    metrics.add(_createGaugeMetric(
      'fasq.cache.misses',
      'Total number of cache misses',
      snapshot.cacheMetrics.misses.toDouble(),
      timestampNanos,
    ));

    metrics.add(_createGaugeMetric(
      'fasq.cache.evictions',
      'Total number of cache evictions',
      snapshot.cacheMetrics.evictions.toDouble(),
      timestampNanos,
    ));

    metrics.add(_createGaugeMetric(
      'fasq.memory.usage_bytes',
      'Total memory usage in bytes',
      snapshot.memoryUsageBytes.toDouble(),
      timestampNanos,
    ));

    metrics.add(_createGaugeMetric(
      'fasq.memory.peak_bytes',
      'Peak memory usage in bytes',
      cacheReport.peakMemoryBytes.toDouble(),
      timestampNanos,
    ));

    metrics.add(_createGaugeMetric(
      'fasq.queries.total',
      'Total number of queries',
      snapshot.totalQueries.toDouble(),
      timestampNanos,
    ));

    metrics.add(_createGaugeMetric(
      'fasq.queries.active',
      'Number of active queries',
      snapshot.activeQueries.toDouble(),
      timestampNanos,
    ));

    metrics.add(_createGaugeMetric(
      'fasq.cache.fetch_time.avg_ms',
      'Average fetch time in milliseconds',
      cacheReport.avgFetchTime.inMilliseconds.toDouble(),
      timestampNanos,
    ));

    metrics.add(_createGaugeMetric(
      'fasq.cache.fetch_time.p95_ms',
      '95th percentile fetch time in milliseconds',
      cacheReport.p95FetchTime.inMilliseconds.toDouble(),
      timestampNanos,
    ));

    snapshot.queryMetrics.forEach((queryKey, queryMetrics) {
      if (queryMetrics.averageFetchTime != null) {
        metrics.add(_createGaugeMetric(
          'fasq.query.fetch_time.avg_ms',
          'Average fetch time for query in milliseconds',
          queryMetrics.averageFetchTime!.inMilliseconds.toDouble(),
          timestampNanos,
          attributes: {'query': queryKey},
        ));
      }

      if (queryMetrics.maxFetchTime != null) {
        metrics.add(_createGaugeMetric(
          'fasq.query.fetch_time.max_ms',
          'Maximum fetch time for query in milliseconds',
          queryMetrics.maxFetchTime!.inMilliseconds.toDouble(),
          timestampNanos,
          attributes: {'query': queryKey},
        ));
      }

      metrics.add(_createSumMetric(
        'fasq.query.fetch.count',
        'Total number of fetches for query',
        queryMetrics.fetchCount.toDouble(),
        timestampNanos,
        attributes: {'query': queryKey},
      ));

      metrics.add(_createGaugeMetric(
        'fasq.query.reference_count',
        'Reference count for query',
        queryMetrics.referenceCount.toDouble(),
        timestampNanos,
        attributes: {'query': queryKey},
      ));
    });

    return metrics;
  }

  Map<String, dynamic> _createGaugeMetric(
    String name,
    String description,
    double value,
    int timestampNanos, {
    Map<String, String> attributes = const {},
  }) {
    return {
      'name': name,
      'description': description,
      'unit': '',
      'gauge': {
        'dataPoints': [
          {
            'attributes': attributes.entries
                .map((e) => {
                      'key': e.key,
                      'value': {'stringValue': e.value}
                    })
                .toList(),
            'asInt': null,
            'asDouble': value,
            'timeUnixNano': timestampNanos.toString(),
          }
        ],
      },
    };
  }

  Map<String, dynamic> _createSumMetric(
    String name,
    String description,
    double value,
    int timestampNanos, {
    Map<String, String> attributes = const {},
  }) {
    return {
      'name': name,
      'description': description,
      'unit': '',
      'sum': {
        'aggregationTemporality': 'AGGREGATION_TEMPORALITY_CUMULATIVE',
        'isMonotonic': true,
        'dataPoints': [
          {
            'attributes': attributes.entries
                .map((e) => {
                      'key': e.key,
                      'value': {'stringValue': e.value}
                    })
                .toList(),
            'asInt': null,
            'asDouble': value,
            'timeUnixNano': timestampNanos.toString(),
          }
        ],
      },
    };
  }

  Future<void> _sendOtlp(String jsonPayload, String endpoint) async {
    try {
      final uri = Uri.parse(endpoint);
      final client = HttpClient();

      try {
        final request = await client.postUrl(uri);
        request.headers.set('Content-Type', 'application/json');
        request.headers.set('Content-Encoding', 'gzip');
        request.write(jsonPayload);
        final response = await request.close();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          log('OpenTelemetry metrics exported successfully to $endpoint');
        } else {
          log('OpenTelemetry export failed with status ${response.statusCode}');
        }
      } finally {
        client.close();
      }
    } catch (e, stackTrace) {
      log('Error exporting to OpenTelemetry: $e',
          error: e, stackTrace: stackTrace);
    }
  }

  @override
  void configure(Map<String, dynamic> config) {
    _config = config;
    if (config['endpoint'] != null) {
      // Endpoint can be updated via config
    }
  }
}
