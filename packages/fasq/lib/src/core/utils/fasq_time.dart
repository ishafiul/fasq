import 'package:meta/meta.dart';

/// A utility class for providing the current time.
///
/// This allows mocking the current time in tests without depending on
/// external clock packages.
class FasqTime {
  static DateTime Function() _nowProvider = DateTime.now;

  /// Returns the current time.
  static DateTime get now => _nowProvider();

  /// Sets a custom provider for the current time.
  @visibleForTesting
  static void setNowProvider(DateTime Function() provider) {
    _nowProvider = provider;
  }

  /// Resets the time provider to use [DateTime.now].
  @visibleForTesting
  static void reset() {
    _nowProvider = DateTime.now;
  }
}
