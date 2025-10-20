import 'dart:async';

class NetworkStatus {
  static final NetworkStatus _instance = NetworkStatus._internal();
  factory NetworkStatus() => _instance;
  NetworkStatus._internal();

  static NetworkStatus get instance => _instance;

  final StreamController<bool> _controller = StreamController<bool>.broadcast();
  bool _isOnline = true;

  Stream<bool> get stream => _controller.stream;
  bool get isOnline => _isOnline;

  void setOnline(bool online) {
    if (_isOnline == online) return;
    _isOnline = online;
    _controller.add(_isOnline);
  }

  void dispose() {
    _controller.close();
  }
}
