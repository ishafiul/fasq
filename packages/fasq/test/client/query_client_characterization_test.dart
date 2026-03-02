import 'package:fasq/fasq.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QueryClient characterization', () {
    setUp(() async {
      await QueryClient.resetForTesting();
    });

    tearDown(() async {
      await QueryClient.resetForTesting();
    });

    test('singleton throws on conflicting config and allows same config', () {
      const configA = CacheConfig(
        defaultStaleTime: Duration(minutes: 1),
      );
      const configB = CacheConfig(
        defaultStaleTime: Duration(minutes: 2),
      );

      final client = QueryClient(config: configA);

      expect(QueryClient(config: configA), same(client));
      expect(() => QueryClient(config: configB), throwsStateError);
    });

    test('infinite query can be retrieved and removed by key', () async {
      final client = QueryClient();
      final queryKey = 'infinite:list'.toQueryKey();

      final query = client.getInfiniteQuery<List<int>, int>(
        queryKey,
        (page) async => [page],
        options: InfiniteQueryOptions<List<int>, int>(
          getNextPageParam: (pages, last) =>
              last == null ? 1 : pages.length + 1,
        ),
      );

      expect(
        client.getInfiniteQueryByKey<List<int>, int>(queryKey),
        same(query),
      );

      client.removeInfiniteQuery(queryKey);

      expect(query.isDisposed, isTrue);
      expect(client.getInfiniteQueryByKey<List<int>, int>(queryKey), isNull);
    });

    test('invalidate variants refetch active queries', () async {
      final client = QueryClient();
      var fetchCount = 0;

      final query = client.getQuery<String>(
        'user:1'.toQueryKey(),
        queryFn: () async {
          fetchCount++;
          return 'data-$fetchCount';
        },
      )..addListener('test-owner');

      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(fetchCount, 1);

      client.invalidateQueriesWhere((key) => key.startsWith('user:'));
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(fetchCount, 2);

      client.invalidateQueriesWithPrefix('user:');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(fetchCount, 3);

      client.invalidateQueriesWherePredicate((key) => key == 'user:1');
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(fetchCount, 4);

      query.removeListener('test-owner');
    });

    test('clearSecureCache removes secure entries only', () {
      final client = QueryClient()
        ..setQueryData<String>(
          'secure-key'.toQueryKey(),
          'secret',
          isSecure: true,
          maxAge: const Duration(minutes: 5),
        )
        ..setQueryData<String>('public-key'.toQueryKey(), 'public');

      expect(client.getQueryData<String>('secure-key'.toQueryKey()), 'secret');
      expect(client.getQueryData<String>('public-key'.toQueryKey()), 'public');

      client.clearSecureCache();

      expect(client.getQueryData<String>('secure-key'.toQueryKey()), isNull);
      expect(client.getQueryData<String>('public-key'.toQueryKey()), 'public');
    });

    test('paused lifecycle state clears secure cache entries', () {
      final client = QueryClient()
        ..setQueryData<String>(
          'secure-life'.toQueryKey(),
          'secret',
          isSecure: true,
          maxAge: const Duration(minutes: 5),
        )
        ..setQueryData<String>('public-life'.toQueryKey(), 'public')
        ..didChangeAppLifecycleState(AppLifecycleState.paused);

      expect(client.getQueryData<String>('secure-life'.toQueryKey()), isNull);
      expect(client.getQueryData<String>('public-life'.toQueryKey()), 'public');
    });

    test('metrics reconfiguration cancels prior auto-export timer', () async {
      final client = QueryClient();
      final oldExporter = _CountingExporter();
      final newExporter = _CountingExporter();

      client.configureMetricsExporters(
        MetricsConfig(
          exporters: [oldExporter],
          exportInterval: const Duration(milliseconds: 80),
          enableAutoExport: true,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 20));

      client.configureMetricsExporters(
        MetricsConfig(
          exporters: [newExporter],
          exportInterval: const Duration(milliseconds: 20),
          enableAutoExport: true,
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(oldExporter.exportCount, 0);
      expect(newExporter.exportCount, greaterThanOrEqualTo(3));
    });

    test('manual metrics export isolates exporter failures', () async {
      final client = QueryClient();
      final failingExporter = _FailingExporter();
      final successExporter = _CountingExporter();

      client.configureMetricsExporters(
        MetricsConfig(
          exporters: [failingExporter, successExporter],
        ),
      );

      await client.exportMetricsManually();

      expect(failingExporter.exportAttempts, 1);
      expect(successExporter.exportCount, 1);
    });

    test('manual metrics export runs all configured exporters', () async {
      final client = QueryClient();
      final exporterA = _CountingExporter();
      final exporterB = _CountingExporter();

      client.configureMetricsExporters(
        MetricsConfig(
          exporters: [exporterA, exporterB],
        ),
      );

      await client.exportMetricsManually();

      expect(exporterA.exportCount, 1);
      expect(exporterB.exportCount, 1);
    });
  });
}

class _CountingExporter implements MetricsExporter {
  int exportCount = 0;
  int configureCount = 0;

  @override
  Future<void> export(PerformanceSnapshot snapshot) async {
    exportCount++;
  }

  @override
  void configure(Map<String, dynamic> config) {
    configureCount++;
  }
}

class _FailingExporter implements MetricsExporter {
  int exportAttempts = 0;

  @override
  Future<void> export(PerformanceSnapshot snapshot) async {
    exportAttempts++;
    throw StateError('Intentional exporter failure');
  }

  @override
  void configure(Map<String, dynamic> config) {}
}
