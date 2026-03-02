import 'package:fasq/src/cache/cache_config.dart';
import 'package:fasq/src/circuit_breaker/circuit_breaker_registry.dart';
import 'package:fasq/src/persistence/persistence_options.dart';
import 'package:fasq/src/security/security_plugin.dart';

/// Evaluates singleton reconfiguration compatibility for `QueryClient`.
abstract final class QueryClientConfigGuard {
  /// Returns true when requested config conflicts with existing snapshots.
  static bool hasConfigurationConflict({
    required CacheConfig existingConfigSnapshot,
    required PersistenceOptions? existingPersistenceSnapshot,
    required Type? existingSecurityPluginType,
    required CircuitBreakerRegistry? existingCircuitBreakerRegistry,
    CacheConfig? requestedConfig,
    PersistenceOptions? requestedPersistenceOptions,
    SecurityPlugin? requestedSecurityPlugin,
    CircuitBreakerRegistry? requestedCircuitBreakerRegistry,
  }) {
    if (requestedConfig != null &&
        _cacheConfigDiffers(existingConfigSnapshot, requestedConfig)) {
      return true;
    }

    if (requestedPersistenceOptions != null &&
        existingPersistenceSnapshot != null &&
        existingPersistenceSnapshot != requestedPersistenceOptions) {
      return true;
    }

    if (requestedSecurityPlugin != null &&
        existingSecurityPluginType != requestedSecurityPlugin.runtimeType) {
      return true;
    }

    if (requestedCircuitBreakerRegistry != null &&
        existingCircuitBreakerRegistry != requestedCircuitBreakerRegistry) {
      return true;
    }

    return false;
  }

  static bool _cacheConfigDiffers(CacheConfig a, CacheConfig b) {
    if (a.maxCacheSize != b.maxCacheSize) {
      return true;
    }
    if (a.maxEntries != b.maxEntries) {
      return true;
    }
    if (a.defaultStaleTime != b.defaultStaleTime) {
      return true;
    }
    if (a.defaultCacheTime != b.defaultCacheTime) {
      return true;
    }
    if (a.evictionPolicy != b.evictionPolicy) {
      return true;
    }
    if (a.enableMemoryPressure != b.enableMemoryPressure) {
      return true;
    }
    if (_performanceConfigDiffers(a.performance, b.performance)) {
      return true;
    }
    return false;
  }

  static bool _performanceConfigDiffers(
    GlobalPerformanceConfig a,
    GlobalPerformanceConfig b,
  ) {
    if (a.enableTracking != b.enableTracking) {
      return true;
    }
    if (a.hotCacheSize != b.hotCacheSize) {
      return true;
    }
    if (a.enableWarnings != b.enableWarnings) {
      return true;
    }
    if (a.slowQueryThresholdMs != b.slowQueryThresholdMs) {
      return true;
    }
    if (a.memoryWarningThreshold != b.memoryWarningThreshold) {
      return true;
    }
    if (a.isolatePoolSize != b.isolatePoolSize) {
      return true;
    }
    if (a.defaultIsolateThreshold != b.defaultIsolateThreshold) {
      return true;
    }
    return false;
  }
}
