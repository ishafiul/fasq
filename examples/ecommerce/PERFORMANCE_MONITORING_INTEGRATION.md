# Performance Monitoring & Metrics Export Integration

This document describes the integration of FASQ's Performance Monitoring & Metrics Export System into the ecommerce example app.

## Overview

The ecommerce example now includes:
- **FASQ Logger System**: Structured logging for all FASQ operations
- **Performance Monitoring**: Real-time metrics tracking and visualization
- **Metrics Exporters**: Console, JSON, and OpenTelemetry export support
- **Metrics Screen**: UI for viewing performance data

## Files Added

### Services

1. **`lib/core/services/fasq_logger_service.dart`**
   - Structured logging service for FASQ operations
   - Logs query lifecycle events (fetch, success, error)
   - Logs cache operations (hit, miss, eviction)
   - Logs performance metrics and export events

2. **`lib/core/services/metrics_exporter_service.dart`**
   - Manages metrics exporters configuration
   - Handles auto-export and manual export
   - Provides methods to get performance snapshots
   - Environment-aware configuration (debug vs release)

3. **`lib/core/services/fasq_query_observer.dart`**
   - QueryClientObserver implementation
   - Integrates FASQ events with the logger system
   - Automatically logs query lifecycle events

### UI

4. **`lib/presentation/screens/metrics/metrics_screen.dart`**
   - Full-screen metrics visualization
   - Displays cache metrics, memory usage, query statistics
   - Per-query detailed metrics with throughput data
   - Refresh and export functionality

## Files Modified

### Core Services

1. **`lib/core/services/query_client_service.dart`**
   - Added performance tracking configuration
   - Enabled metrics collection in CacheConfig

2. **`lib/bootstrap.dart`**
   - Initializes metrics exporters on app startup
   - Registers FASQ query observer
   - Configures auto-export (debug mode only)

3. **`lib/core/router/app_router.dart`**
   - Added `/metrics` route for MetricsScreen

4. **`lib/presentation/screens/profile/profile_screen.dart`**
   - Added navigation link to metrics screen

### Package Exports

5. **`packages/fasq/lib/fasq.dart`**
   - Added exports for metrics exporters
   - Added exports for metrics config and throughput metrics

## Configuration

### Metrics Exporters

The app is configured to use different exporters based on the environment:

**Debug Mode:**
- `ConsoleExporter`: Human-readable console output
- `JsonExporter`: JSON serialization for logging

**Release Mode (if configured):**
- `JsonExporter`: JSON logging
- `OpenTelemetryExporter`: Production observability (if endpoint provided)

### Auto-Export

Auto-export is enabled in debug mode only, exporting metrics every minute. In release mode, you can manually trigger exports or configure auto-export if needed.

## Usage

### Accessing Metrics Screen

1. Navigate to Profile screen
2. Tap on "Performance Metrics" card
3. View real-time performance data

### Programmatic Access

```dart
// Get metrics service
final metricsService = locator<MetricsExporterService>();

// Get global snapshot
final snapshot = metricsService.getMetrics();

// Get query-specific metrics
final queryMetrics = metricsService.getQueryMetrics('products');

// Manual export
await metricsService.exportMetricsManually();
```

### Logging

FASQ operations are automatically logged via `FasqLoggerService`:

```dart
// Logs are automatically generated for:
// - Query fetches
// - Query successes/errors
// - Cache hits/misses
// - Performance metrics
// - Export events
```

## Next Steps

1. **Run build_runner** to generate the MetricsRoute:
   ```bash
   cd examples/ecommerce
   flutter pub run build_runner build --delete-conflicting-outputs
   ```

2. **Configure OpenTelemetry** (optional):
   - Uncomment and set `openTelemetryEndpoint` in `bootstrap.dart`
   - Add authentication headers if needed

3. **Customize Exporters**:
   - Modify `MetricsExporterService.initializeMetricsExporters()` to add custom exporters
   - Adjust export interval based on your needs

## Features

✅ **Automatic Logging**: All FASQ operations are logged  
✅ **Performance Monitoring**: Real-time metrics tracking  
✅ **Metrics Export**: Console, JSON, and OpenTelemetry support  
✅ **UI Visualization**: Complete metrics screen  
✅ **Environment-Aware**: Different configs for debug/release  
✅ **Zero Configuration**: Works out of the box  

## Testing

To test the integration:

1. Run the app in debug mode
2. Navigate through different screens (home, products, categories)
3. Check console for FASQ logs
4. Navigate to Profile → Performance Metrics
5. View the metrics screen with real-time data
6. Use refresh button to update metrics
7. Use export button to manually trigger export

## Notes

- Metrics collection is enabled by default
- Auto-export runs every minute in debug mode
- All exporters handle errors gracefully
- Metrics screen shows data from the last snapshot
- Throughput metrics use a 1-minute rolling window by default

