/// Exception thrown when an isolate callback captures context invalidly.
///
/// This usually happens when passing a closure or instance method that captures
/// `this` or other non-static context, which cannot be sent to another isolate.
class IsolateCallbackCaptureException implements Exception {
  final String message;
  final Object? originalError;

  const IsolateCallbackCaptureException(this.message, [this.originalError]);

  @override
  String toString() =>
      'IsolateCallbackCaptureException: $message${originalError != null ? ' (Original: $originalError)' : ''}';
}
