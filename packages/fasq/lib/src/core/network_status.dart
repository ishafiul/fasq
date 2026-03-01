import 'dart:async';

/// In-memory network connectivity state notifier.
///
/// Exposes a singleton stream of online/offline changes used by queueing and
/// mutation logic.
class NetworkStatus {
  /// Returns the shared [NetworkStatus] singleton instance.
  factory NetworkStatus() => _instance;

  NetworkStatus._internal();

  static final NetworkStatus _instance = NetworkStatus._internal();

  /// Accessor for the shared singleton instance.
  static NetworkStatus get instance => _instance;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;

  /// Broadcast stream of connectivity changes.
  Stream<bool> get stream => _controller.stream;

  /// Whether the current network state is online.
  bool get isOnline => _isOnline;

  /// Updates network state and notifies listeners when it changes.
  void setOnline({required bool online}) {
    if (_isOnline == online) return;
    _isOnline = online;
    _controller.add(_isOnline);
  }

  /// Closes the connectivity stream controller.
  void dispose() {
    unawaited(_controller.close());
  }
}
