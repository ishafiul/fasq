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
      _notifyListeners();
    });
  }

  void _notifyListeners() {
    // On iOS/Android, didHaveMemoryPressure usually means "low memory".
    // We treat this as a potentially critical situation.
    // However, for now, we can perhaps default critical to false or true based on policy.
    // The PRD suggests Adaptive Eviction.
    // Let's pass 'critical: true' because if the OS warns us, we should be aggressive.
    for (final listener in List.from(_listeners)) {
      // Copy to avoid concurrent mod
      listener(true);
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
