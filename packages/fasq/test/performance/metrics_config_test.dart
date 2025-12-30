import 'package:fasq/src/cache/cache_metrics.dart';
import 'package:fasq/src/performance/metrics_config.dart';
import 'package:fasq/src/performance/metrics_exporter.dart';
import 'package:flutter_test/flutter_test.dart';

class MockMetricsExporter implements MetricsExporter {
  Map<String, dynamic>? lastConfig;
  int configureCallCount = 0;
  int exportCallCount = 0;

  @override
  Future<void> export(PerformanceSnapshot snapshot) async {
    exportCallCount++;
  }

  @override
  void configure(Map<String, dynamic> config) {
    configureCallCount++;
    lastConfig = Map<String, dynamic>.from(config);
  }
}

void main() {
  group('MetricsConfig', () {
    test('initializes with default values', () {
      final config = MetricsConfig();

      expect(config.exporters, isEmpty);
      expect(config.exportInterval, const Duration(minutes: 1));
      expect(config.enableAutoExport, isFalse);
    });

    test('initializes with custom values', () {
      final exporter1 = MockMetricsExporter();
      final exporter2 = MockMetricsExporter();
      final exporters = [exporter1, exporter2];
      final interval = const Duration(minutes: 5);

      final config = MetricsConfig(
        exporters: exporters,
        exportInterval: interval,
        enableAutoExport: true,
      );

      expect(config.exporters, equals(exporters));
      expect(config.exportInterval, interval);
      expect(config.enableAutoExport, isTrue);
    });

    test('initializes with empty exporters list', () {
      final config = MetricsConfig(exporters: []);

      expect(config.exporters, isEmpty);
    });

    test('initializes with single exporter', () {
      final exporter = MockMetricsExporter();
      final config = MetricsConfig(exporters: [exporter]);

      expect(config.exporters.length, 1);
      expect(config.exporters.first, equals(exporter));
    });

    test('applyConfigurationToExporters calls configure on all exporters', () {
      final exporter1 = MockMetricsExporter();
      final exporter2 = MockMetricsExporter();
      final exporter3 = MockMetricsExporter();

      final config = MetricsConfig(
        exporters: [exporter1, exporter2, exporter3],
      );

      final testConfig = {
        'endpoint': 'https://api.example.com/metrics',
        'apiKey': 'secret-key',
        'enabled': true,
      };

      config.applyConfigurationToExporters(testConfig);

      expect(exporter1.configureCallCount, 1);
      expect(exporter2.configureCallCount, 1);
      expect(exporter3.configureCallCount, 1);

      expect(exporter1.lastConfig, equals(testConfig));
      expect(exporter2.lastConfig, equals(testConfig));
      expect(exporter3.lastConfig, equals(testConfig));
    });

    test('applyConfigurationToExporters handles empty exporters list', () {
      final config = MetricsConfig(exporters: []);

      expect(
        () => config.applyConfigurationToExporters({'key': 'value'}),
        returnsNormally,
      );
    });

    test('applyConfigurationToExporters passes config correctly', () {
      final exporter = MockMetricsExporter();
      final config = MetricsConfig(exporters: [exporter]);

      final testConfig = {
        'endpoint': 'https://otel-collector.example.com/v1/metrics',
        'headers': {'Authorization': 'Bearer token'},
        'timeout': 5000,
      };

      config.applyConfigurationToExporters(testConfig);

      expect(exporter.lastConfig, equals(testConfig));
      expect(exporter.lastConfig!['endpoint'],
          equals('https://otel-collector.example.com/v1/metrics'));
      expect(exporter.lastConfig!['headers'],
          equals({'Authorization': 'Bearer token'}));
    });

    test('applyConfigurationToExporters can be called multiple times', () {
      final exporter = MockMetricsExporter();
      final config = MetricsConfig(exporters: [exporter]);

      config.applyConfigurationToExporters({'key1': 'value1'});
      config.applyConfigurationToExporters({'key2': 'value2'});
      config.applyConfigurationToExporters({'key3': 'value3'});

      expect(exporter.configureCallCount, 3);
      expect(exporter.lastConfig, equals({'key3': 'value3'}));
    });

    test('exporters list is immutable', () {
      final exporter1 = MockMetricsExporter();
      final exporter2 = MockMetricsExporter();
      final config = MetricsConfig(exporters: [exporter1, exporter2]);

      expect(() => config.exporters.add(MockMetricsExporter()),
          throwsUnsupportedError);
    });

    test('const constructor works with const values', () {
      final config = MetricsConfig(
        exporters: [],
        exportInterval: const Duration(minutes: 2),
        enableAutoExport: true,
      );

      expect(config.exporters, isEmpty);
      expect(config.exportInterval, const Duration(minutes: 2));
      expect(config.enableAutoExport, isTrue);
    });
  });
}
