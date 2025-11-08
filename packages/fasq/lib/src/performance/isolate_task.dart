import 'dart:async';

/// A task wrapper for isolate execution.
///
/// Encapsulates the callback function, input data, and completion handling
/// for executing work in an isolate.
class IsolateTask<T, R> {
  /// The callback function to execute in the isolate
  final FutureOr<R> Function(T message) callback;

  /// The input data to pass to the callback
  final T message;

  /// Completer to signal task completion
  final Completer<R> completer;

  /// Timestamp when the task was created
  final DateTime createdAt;

  /// Whether this task has been cancelled
  bool _isCancelled = false;

  IsolateTask({
    required this.callback,
    required this.message,
    required this.completer,
  }) : createdAt = DateTime.now();

  /// Whether this task has been completed
  bool get isCompleted => completer.isCompleted;

  /// Whether this task has been cancelled
  bool get isCancelled => _isCancelled;

  /// Complete the task with a result
  void complete(R result) {
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  /// Complete the task with an error
  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
  }

  /// Cancel the task
  void cancel() {
    if (!completer.isCompleted) {
      _isCancelled = true;
      completer.completeError(
        IsolateTaskCancelledException('Task was cancelled'),
      );
    }
  }
}

/// Exception thrown when an isolate task is cancelled
class IsolateTaskCancelledException implements Exception {
  final String message;

  const IsolateTaskCancelledException(this.message);

  @override
  String toString() => 'IsolateTaskCancelledException: $message';
}

/// Exception thrown when isolate execution fails
class IsolateExecutionException implements Exception {
  final String message;
  final Object? originalError;

  const IsolateExecutionException(this.message, [this.originalError]);

  @override
  String toString() =>
      'IsolateExecutionException: $message${originalError != null ? ' (Original: $originalError)' : ''}';
}
