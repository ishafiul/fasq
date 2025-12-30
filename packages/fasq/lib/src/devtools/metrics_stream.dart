import 'dart:async';

import '../cache/cache_metrics.dart';
import '../performance/performance_monitor.dart';

/// Streams performance metrics for DevTools integration.
///
/// Provides a broadcast stream of [PerformanceSnapshot] objects that can be
/// consumed by Flutter DevTools or other monitoring tools for real-time
/// performance visualization.
///
/// The stream emits snapshots periodically (default: every 5 seconds) when
/// there are active listeners, optimizing resource usage by only generating
/// snapshots when needed.
///
/// Example:
/// ```dart
/// final monitor = PerformanceMonitor(cache: cache, queries: queries);
/// final metricsStream = MetricsStream(monitor);
///
/// metricsStream.stream.listen((snapshot) {
///   print('Cache hit rate: ${snapshot.cacheMetrics.hitRate}');
/// });
///
/// // Clean up when done
/// metricsStream.dispose();
/// ```
class MetricsStream {
  final PerformanceMonitor _performanceMonitor;
  final StreamController<PerformanceSnapshot> _controller;
  Timer? _timer;

  /// Creates a new [MetricsStream] instance.
  ///
  /// [performanceMonitor] The performance monitor to retrieve snapshots from.
  /// [updateInterval] How often to emit new snapshots. Defaults to 5 seconds.
  MetricsStream(
    this._performanceMonitor, {
    Duration updateInterval = const Duration(seconds: 5),
  }) : _controller = StreamController<PerformanceSnapshot>.broadcast() {
    _timer = Timer.periodic(updateInterval, (timer) {
      if (_controller.hasListener) {
        _controller.sink.add(_performanceMonitor.getSnapshot());
      }
    });
  }

  /// The broadcast stream of performance snapshots.
  ///
  /// Emits [PerformanceSnapshot] objects periodically when there are
  /// active listeners.
  Stream<PerformanceSnapshot> get stream => _controller.stream;

  /// Disposes the stream and cancels the periodic timer.
  ///
  /// Call this method when the stream is no longer needed to prevent
  /// resource leaks.
  void dispose() {
    _timer?.cancel();
    _timer = null;
    _controller.close();
  }
}
