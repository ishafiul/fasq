import 'dart:async';

/// An async lock for ensuring mutual exclusion in async operations.
///
/// Prevents race conditions when multiple async operations access
/// the same resource concurrently.
class AsyncLock {
  final _queue = <Completer<void>>[];
  bool _locked = false;

  /// Acquires the lock, waiting if necessary.
  ///
  /// Returns a Future that completes when the lock is acquired.
  /// Times out after 30 seconds to prevent deadlocks.
  Future<void> acquire() async {
    final completer = Completer<void>();

    if (!_locked) {
      _locked = true;
      completer.complete();
      return completer.future;
    }

    _queue.add(completer);

    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _queue.remove(completer);
        throw TimeoutException('Lock acquisition timed out after 30 seconds');
      },
    );
  }

  /// Releases the lock, allowing the next waiter to proceed.
  void release() {
    if (_queue.isNotEmpty) {
      final next = _queue.removeAt(0);
      next.complete();
    } else {
      _locked = false;
    }
  }

  /// Executes a function with the lock held.
  ///
  /// Automatically acquires the lock, executes the function, and releases
  /// the lock, even if the function throws an error.
  Future<T> synchronized<T>(Future<T> Function() fn) async {
    await acquire();
    try {
      return await fn();
    } finally {
      release();
    }
  }

  /// Whether the lock is currently held.
  bool get isLocked => _locked;

  /// Number of operations waiting for the lock.
  int get queueLength => _queue.length;
}

