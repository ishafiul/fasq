/// Cancellation support for async query operations.
///
/// This module provides cooperative cancellation for queries, allowing
/// in-flight fetch operations to be cancelled when queries are disposed
/// or manually cancelled.
library;

import 'dart:async';

/// Exception thrown when a query operation is cancelled.
///
/// This exception is caught silently by the query system and does not
/// propagate to error handlers or update query state to error.
///
/// Example:
/// ```dart
/// queryFn: (token) async {
///   token.throwIfCancelled();
///   final result = await fetchData();
///   token.throwIfCancelled();
///   return result;
/// }
/// ```
class CancelledException implements Exception {
  /// A message describing why the operation was cancelled.
  final String message;

  /// Creates a [CancelledException] with the given [message].
  const CancelledException([this.message = 'Operation was cancelled']);

  @override
  String toString() => 'CancelledException: $message';
}

/// A token that signals when a query operation should be cancelled.
///
/// [CancellationToken] provides cooperative cancellation, meaning the query
/// function must check the token and respond appropriately. It does not
/// forcibly terminate running code.
///
/// ## Usage
///
/// ```dart
/// QueryBuilder<User>(
///   queryKey: 'user:123',
///   queryFn: (token) async {
///     // Check before expensive operations
///     token.throwIfCancelled();
///
///     // Integrate with HTTP libraries
///     final cancelToken = CancelToken();
///     token.onCancel(() => cancelToken.cancel());
///
///     return dio.get('/user/123', cancelToken: cancelToken);
///   },
///   builder: (context, state) => /* ... */,
/// )
/// ```
///
/// ## Dio Integration
///
/// ```dart
/// queryFn: (token) async {
///   final dioCancelToken = CancelToken();
///   token.onCancel(() => dioCancelToken.cancel());
///
///   try {
///     final response = await dio.get('/api', cancelToken: dioCancelToken);
///     return response.data;
///   } on DioException catch (e) {
///     if (e.type == DioExceptionType.cancel) {
///       throw const CancelledException();
///     }
///     rethrow;
///   }
/// }
/// ```
class CancellationToken {
  bool _isCancelled = false;
  final List<void Function()> _listeners = [];
  Completer<void>? _completer;

  /// Whether cancellation has been requested.
  ///
  /// Once true, this value never changes back to false.
  bool get isCancelled => _isCancelled;

  /// Throws [CancelledException] if cancellation has been requested.
  ///
  /// Call this at strategic points in your query function to check
  /// for cancellation before continuing with expensive operations.
  ///
  /// Example:
  /// ```dart
  /// queryFn: (token) async {
  ///   final data = await fetchData();
  ///   token.throwIfCancelled(); // Check before processing
  ///   return processData(data);
  /// }
  /// ```
  void throwIfCancelled() {
    if (_isCancelled) {
      throw const CancelledException();
    }
  }

  /// Registers a callback to be called when cancellation is requested.
  ///
  /// If the token is already cancelled, the callback is invoked immediately.
  /// Callbacks are invoked synchronously when [cancel] is called.
  ///
  /// Use this to integrate with HTTP libraries that support cancellation:
  /// ```dart
  /// final dioCancelToken = CancelToken();
  /// token.onCancel(() => dioCancelToken.cancel());
  /// ```
  void onCancel(void Function() callback) {
    if (_isCancelled) {
      callback();
    } else {
      _listeners.add(callback);
    }
  }

  /// Returns a Future that completes when cancellation is requested.
  ///
  /// Useful for race conditions or waiting for cancellation:
  /// ```dart
  /// await Future.any([
  ///   actualWork(),
  ///   token.cancelled.then((_) => throw CancelledException()),
  /// ]);
  /// ```
  Future<void> get cancelled {
    if (_isCancelled) {
      return Future.value();
    }
    _completer ??= Completer<void>();
    return _completer!.future;
  }

  /// Cancels the token and notifies all registered listeners.
  ///
  /// This method is idempotent - calling it multiple times has no effect
  /// after the first call.
  ///
  /// Listeners are invoked synchronously in the order they were registered.
  void cancel() {
    if (_isCancelled) return;

    _isCancelled = true;

    // Complete the future first
    _completer?.complete();

    // Then notify all listeners
    for (final listener in _listeners) {
      try {
        listener();
      } catch (_) {
        // Ignore errors from listeners to ensure all are called
      }
    }
    _listeners.clear();
  }

  /// Creates a child token that is cancelled when this token is cancelled.
  ///
  /// Useful for creating scoped cancellation within a larger operation.
  CancellationToken createChild() {
    final child = CancellationToken();
    if (_isCancelled) {
      child.cancel();
    } else {
      onCancel(child.cancel);
    }
    return child;
  }
}
