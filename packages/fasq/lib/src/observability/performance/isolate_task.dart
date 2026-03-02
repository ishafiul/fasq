import 'dart:async';

/// A task wrapper for isolate execution.
///
/// Encapsulates the callback function, input data, and completion handling
/// for executing work in an isolate.
class IsolateTask<T, R> {
  /// Creates an isolate task.
  IsolateTask({
    required this.callback,
    required this.message,
    required this.completer,
  }) : createdAt = DateTime.now();

  /// Callback function to execute in the isolate.
  final FutureOr<R> Function(T message) callback;

  /// Input data to pass to [callback].
  final T message;

  /// Completer used to signal task completion.
  final Completer<R> completer;

  /// Timestamp when the task was created.
  final DateTime createdAt;

  bool _isCancelled = false;

  /// Whether this task has been completed.
  bool get isCompleted => completer.isCompleted;

  /// Whether this task has been cancelled.
  bool get isCancelled => _isCancelled;

  /// Completes the task with [result].
  void complete(R result) {
    if (!completer.isCompleted) {
      completer.complete(result);
    }
  }

  /// Completes the task with [error] and optional [stackTrace].
  void completeError(Object error, [StackTrace? stackTrace]) {
    if (!completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
  }

  /// Cancels the task if it has not already completed.
  void cancel() {
    if (!completer.isCompleted) {
      _isCancelled = true;
      completer.completeError(
        const IsolateTaskCancelledException('Task was cancelled'),
      );
    }
  }
}

/// Exception thrown when an isolate task is cancelled.
class IsolateTaskCancelledException implements Exception {
  /// Creates a cancellation exception with [message].
  const IsolateTaskCancelledException(this.message);

  /// Human-readable cancellation reason.
  final String message;

  @override
  String toString() => 'IsolateTaskCancelledException: $message';
}

/// Exception thrown when isolate execution fails.
class IsolateExecutionException implements Exception {
  /// Creates an execution exception with [message]
  /// and optional [originalError].
  const IsolateExecutionException(this.message, [this.originalError]);

  /// Human-readable failure message.
  final String message;

  /// Original underlying error when available.
  final Object? originalError;

  @override
  String toString() {
    return 'IsolateExecutionException: $message'
        '${originalError != null ? ' (Original: $originalError)' : ''}';
  }
}
