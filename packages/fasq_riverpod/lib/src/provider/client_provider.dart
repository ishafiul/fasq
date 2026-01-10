import 'package:fasq/fasq.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides the [CacheConfig] for the QueryClient.
///
/// Override this provider to customize caching behavior:
/// ```dart
/// ProviderScope(
///   overrides: [
///     fasqCacheConfigProvider.overrideWithValue(
///       CacheConfig(
///         defaultStaleTime: Duration(minutes: 5),
///         defaultCacheTime: Duration(minutes: 10),
///       ),
///     ),
///   ],
///   child: MyApp(),
/// )
/// ```
final fasqCacheConfigProvider = Provider<CacheConfig>((ref) {
  return const CacheConfig();
});

/// Provides the [PersistenceOptions] for the QueryClient.
///
/// Override this provider to enable cache persistence:
/// ```dart
/// ProviderScope(
///   overrides: [
///     fasqPersistenceOptionsProvider.overrideWithValue(
///       PersistenceOptions(
///         directory: await getApplicationDocumentsDirectory(),
///         // ... other options
///       ),
///     ),
///   ],
///   child: MyApp(),
/// )
/// ```
final fasqPersistenceOptionsProvider = Provider<PersistenceOptions?>((ref) {
  return null;
});

/// Provides an optional [SecurityPlugin] for the QueryClient.
///
/// Override this provider to add security features:
/// ```dart
/// ProviderScope(
///   overrides: [
///     fasqSecurityPluginProvider.overrideWithValue(
///       MySecurityPlugin(),
///     ),
///   ],
///   child: MyApp(),
/// )
/// ```
final fasqSecurityPluginProvider = Provider<SecurityPlugin?>((ref) {
  return null;
});

/// Provides a [CircuitBreakerRegistry] for the QueryClient.
///
/// Override this provider to customize circuit breaker behavior:
/// ```dart
/// ProviderScope(
///   overrides: [
///     fasqCircuitBreakerRegistryProvider.overrideWithValue(
///       CircuitBreakerRegistry(),
///     ),
///   ],
///   child: MyApp(),
/// )
/// ```
final fasqCircuitBreakerRegistryProvider =
    Provider<CircuitBreakerRegistry?>((ref) {
  return null;
});

/// Provides a list of [QueryClientObserver]s for the QueryClient.
///
/// Override this provider to add observers:
/// ```dart
/// ProviderScope(
///   overrides: [
///     fasqObserversProvider.overrideWithValue([
///       FasqLogger(),
///       MyCustomObserver(),
///     ]),
///   ],
///   child: MyApp(),
/// )
/// ```
final fasqObserversProvider = Provider<List<QueryClientObserver>>((ref) {
  return [];
});

/// Provides the default [FasqLogger] for the QueryClient.
///
/// Use this provider to add the default logger to your observers:
/// ```dart
/// ProviderScope(
///   overrides: [
///     fasqObserversProvider.overrideWith((ref) => [
///       ref.watch(fasqLoggerProvider),
///     ]),
///   ],
///   child: MyApp(),
/// )
/// ```
final fasqLoggerProvider = Provider<FasqLogger>((ref) {
  return FasqLogger();
});

/// Provides a list of [FasqErrorReporter]s for the QueryClient.
///
/// Override this provider to add error reporting:
/// ```dart
/// ProviderScope(
///   overrides: [
///     fasqErrorReportersProvider.overrideWithValue([
///       SentryErrorReporter(),
///       FirebaseErrorReporter(),
///     ]),
///   ],
///   child: MyApp(),
/// )
/// ```
final fasqErrorReportersProvider = Provider<List<FasqErrorReporter>>((ref) {
  return [];
});

/// Provides the [MetricsConfig] for the QueryClient.
///
/// Override this provider to configure metrics exporters:
/// ```dart
/// ProviderScope(
///   overrides: [
///     fasqMetricsConfigProvider.overrideWithValue(
///       MetricsConfig(
///         exporters: [ConsoleExporter()],
///         enableAutoExport: true,
///       ),
///     ),
///   ],
///   child: MyApp(),
/// )
/// ```
final fasqMetricsConfigProvider = Provider<MetricsConfig>((ref) {
  return MetricsConfig();
});

/// Provides the [QueryClient] instance configured with all the providers.
///
/// This provider automatically consumes all configuration providers and
/// creates a QueryClient with the specified configuration. The QueryClient
/// is automatically disposed when the provider is disposed.
///
/// Example usage:
/// ```dart
/// final client = ref.read(fasqClientProvider);
/// ```
///
/// To customize the configuration, override the individual config providers:
/// ```dart
/// ProviderScope(
///   overrides: [
///     fasqCacheConfigProvider.overrideWithValue(
///       CacheConfig(defaultStaleTime: Duration(minutes: 5)),
///     ),
///   ],
///   child: MyApp(),
/// )
/// ```
final fasqClientProvider = Provider<QueryClient>((ref) {
  final cacheConfig = ref.watch(fasqCacheConfigProvider);
  final persistenceOptions = ref.watch(fasqPersistenceOptionsProvider);
  final securityPlugin = ref.watch(fasqSecurityPluginProvider);
  final circuitBreakerRegistry = ref.watch(fasqCircuitBreakerRegistryProvider);
  final observers = ref.watch(fasqObserversProvider);
  final errorReporters = ref.watch(fasqErrorReportersProvider);
  final metricsConfig = ref.watch(fasqMetricsConfigProvider);

  final client = QueryClient(
    config: cacheConfig,
    persistenceOptions: persistenceOptions,
    securityPlugin: securityPlugin,
    circuitBreakerRegistry: circuitBreakerRegistry,
  );

  // Add observers and error reporters
  for (final observer in observers) {
    client.addObserver(observer);
  }
  for (final reporter in errorReporters) {
    client.addErrorReporter(reporter);
  }

  // Initialize metrics exporters
  client.configureMetricsExporters(metricsConfig);

  // Dispose the client when the provider is disposed
  ref.onDispose(() async {
    await client.dispose();
  });

  return client;
});

/// Provides a real-time stream of performance metrics.
///
/// This provider periodically emits [PerformanceSnapshot] objects
/// which can be used for performance monitoring and visualization (e.g., in DevTools).
///
/// Example:
/// ```dart
/// final metrics = ref.watch(fasqMetricsProvider);
/// ```
final fasqMetricsProvider = StreamProvider<PerformanceSnapshot>((ref) {
  final client = ref.watch(fasqClientProvider);
  return Stream.periodic(
    const Duration(seconds: 5),
    (_) => client.getMetrics(),
  );
});
