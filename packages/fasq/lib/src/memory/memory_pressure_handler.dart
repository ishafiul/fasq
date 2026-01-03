import 'dart:async';

import 'package:flutter/widgets.dart';

/// Handles system memory pressure warnings.
///
/// Listens to [WidgetsBindingObserver.didHaveMemoryPressure] and notifies
/// registered listeners to release memory.
class MemoryPressureHandler extends WidgetsBindingObserver {
  static final MemoryPressureHandler _instance =
      MemoryPressureHandler._internal();

  /// Returns the singleton instance of [MemoryPressureHandler].
  factory MemoryPressureHandler() => _instance;

  MemoryPressureHandler._internal() {
    WidgetsBinding.instance.addObserver(this);
  }

  final List<void Function(bool critical)> _listeners = [];
  Timer? _debounceTimer;

  /// Registers a callback to be invoked when memory pressure is detected.
  ///
  /// The callback receives a [critical] flag, which may be true if the system
  /// indicates a critical low-memory state (though Flutter's API is generic,
  /// we assume all warnings are important).
  void addListener(void Function(bool critical) listener) {
    _listeners.add(listener);
  }

  /// Removes a previously registered callback.
  void removeListener(void Function(bool critical) listener) {
    _listeners.remove(listener);
  }

  @override
  void didHaveMemoryPressure() {
    // Debounce rapid signals to prevent thrashing
    if (_debounceTimer?.isActive ?? false) return;

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      // On iOS/Android, didHaveMemoryPressure usually means "low memory".
      // We treat this as a potentially critical situation.
      // The PRD suggests Adaptive Eviction with different levels, but since
      // Flutter's API doesn't distinguish levels, we default to critical.
      _notifyListeners(critical: true);
    });
  }

  /// Simulates a memory pressure event for testing purposes.
  ///
  /// This method allows developers to manually trigger memory pressure
  /// events to test cache trimming behavior without waiting for system signals.
  ///
  /// [critical] - If true (default), triggers critical memory pressure
  /// which removes all inactive entries. If false, triggers low/warning
  /// pressure which removes only stale inactive entries.
  ///
  /// Example:
  /// ```dart
  /// final handler = MemoryPressureHandler();
  /// handler.simulateMemoryPressure(critical: false); // Low pressure
  /// handler.simulateMemoryPressure(critical: true);  // Critical pressure
  /// ```
  void simulateMemoryPressure({bool critical = true}) {
    // Debounce rapid signals to prevent thrashing
    if (_debounceTimer?.isActive ?? false) return;

    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _notifyListeners(critical: critical);
    });
  }

  void _notifyListeners({required bool critical}) {
    for (final listener in List.from(_listeners)) {
      // Copy to avoid concurrent mod
      listener(critical);
    }
  }

  /// Manually dispose the handler (mostly for testing).
  ///
  /// In a real app, this singleton likely lives forever.
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounceTimer?.cancel();
    _listeners.clear();
  }
}
