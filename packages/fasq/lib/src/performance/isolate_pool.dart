import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'isolate_exceptions.dart';
import 'isolate_task.dart';

/// A worker isolate that can execute tasks.
///
/// Each worker maintains its own isolate and can process tasks sequentially.
class _IsolateWorker {
  Isolate? _isolate;
  SendPort? _sendPort;
  ReceivePort? _receivePort;
  bool _isDisposed = false;

  /// Whether this worker is currently processing a task
  bool get isBusy => _currentTask != null;

  /// The current task being processed
  IsolateTask<dynamic, dynamic>? _currentTask;
  StreamSubscription<dynamic>? _currentSubscription;

  /// Queue of pending tasks for this worker
  final List<IsolateTask<dynamic, dynamic>> _taskQueue = [];

  /// Initialize the worker isolate
  Future<void> initialize() async {
    if (_isDisposed) return;

    _receivePort = ReceivePort();
    _isolate = await Isolate.spawn(_isolateEntryPoint, _receivePort!.sendPort);

    // Wait for the isolate to send back its send port
    _sendPort = await _receivePort!.first as SendPort;
  }

  /// Execute a task in this worker
  Future<R> execute<T, R>(IsolateTask<T, R> task,
      {Duration timeout = const Duration(seconds: 30)}) async {
    if (_isDisposed) {
      task.completeError(IsolateExecutionException('Worker is disposed'));
      return task.completer.future;
    }

    if (_currentTask != null) {
      _taskQueue.add(task);
    } else {
      _runTask(task);
    }

    try {
      return await task.completer.future.timeout(
        timeout,
        onTimeout: () {
          task.cancel();
          throw IsolateExecutionException(
              'Task execution timed out after ${timeout.inSeconds}s');
        },
      );
    } catch (e) {
      if (!task.isCancelled) {
        task.completeError(e);
      }
      rethrow;
    }
  }

  /// Process the next task in the queue
  void _processNextTask() {
    if (_taskQueue.isNotEmpty && _currentTask == null) {
      final nextTask = _taskQueue.removeAt(0);
      _runTask(nextTask);
    }
  }

  void _runTask(IsolateTask<dynamic, dynamic> task) {
    if (_sendPort == null) {
      task.completeError(IsolateExecutionException('Isolate not ready'));
      _processNextTask();
      return;
    }

    _currentTask = task;
    final responsePort = ReceivePort();
    _currentSubscription = responsePort.listen((message) {
      _handleResponse(task, message);
      _cleanupCurrentTask();
      responsePort.close();
    });

    final taskData = [
      task.callback,
      task.message,
      responsePort.sendPort,
    ];

    try {
      _sendPort!.send(taskData);
    } catch (error, stackTrace) {
      _currentSubscription?.cancel();
      responsePort.close();
      _currentSubscription = null;
      _currentTask = null;

      // Check if error is likely due to closure capture
      final isCaptureError = error.toString().contains('Invalid argument') ||
          error.toString().contains('closure');

      final exception = isCaptureError
          ? IsolateCallbackCaptureException(
              'Failed to send task to isolate. Ensure callback is a static or top-level function.',
              error,
            )
          : IsolateExecutionException(
              'Failed to send task to isolate',
              error,
            );

      task.completeError(exception, stackTrace);
      _processNextTask();
    }
  }

  void _handleResponse(
    IsolateTask<dynamic, dynamic> task,
    dynamic message,
  ) {
    if (task.isCancelled) {
      return;
    }

    if (message is List) {
      final status = message[0] as String;
      if (status == 'success') {
        task.complete(message[1]);
        return;
      } else if (status == 'error') {
        final error = message[1] as Object;
        final stack = message[2] != null
            ? StackTrace.fromString(message[2] as String)
            : null;
        task.completeError(
          IsolateExecutionException('Task execution failed', error),
          stack,
        );
        return;
      }
    }

    task.completeError(
      IsolateExecutionException('Received unknown response from isolate'),
    );
  }

  void _cleanupCurrentTask() {
    _currentSubscription?.cancel();
    _currentSubscription = null;
    _currentTask = null;
    _processNextTask();
  }

  /// Dispose the worker and its isolate
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    // Cancel all pending tasks
    for (final task in _taskQueue) {
      task.cancel();
    }
    _taskQueue.clear();

    // Cancel current task
    _currentSubscription?.cancel();
    _currentSubscription = null;
    _currentTask?.cancel();
    _currentTask = null;

    // Close the isolate
    _sendPort?.send(null); // Signal shutdown
    _receivePort?.close();
    _isolate?.kill();

    _isolate = null;
    _sendPort = null;
    _receivePort = null;
  }
}

/// Entry point for worker isolates
void _isolateEntryPoint(SendPort sendPort) {
  final receivePort = ReceivePort();
  sendPort.send(receivePort.sendPort);

  receivePort.listen((dynamic message) async {
    if (message == null) {
      // Shutdown signal
      receivePort.close();
      return;
    }

    if (message is List && message.length == 3) {
      final Function callback = message[0] as Function;
      final dynamic argument = message[1];
      final SendPort replyPort = message[2] as SendPort;

      try {
        final dynamic result = await Function.apply(callback, [argument]);
        replyPort.send(['success', result]);
      } catch (error, stackTrace) {
        replyPort.send(['error', error, stackTrace.toString()]);
      }
    }
  });
}

/// A pool of isolates for executing heavy computation tasks.
///
/// Provides a general-purpose isolate pool that can handle any heavy computation
/// with automatic work distribution, lifecycle management, and error handling.
class IsolatePool {
  final int poolSize;
  final List<_IsolateWorker> _workers = [];
  int _currentWorkerIndex = 0;
  bool _isDisposed = false;
  Future<void>? _initialization;

  /// Create an isolate pool with the specified number of workers
  IsolatePool({this.poolSize = 2}) {
    assert(poolSize > 0, 'Pool size must be greater than 0');
  }

  /// Initialize all worker isolates lazily
  Future<void> _initializeWorkers() async {
    if (_initialization != null) return _initialization;

    _initialization = Future.wait(
      List.generate(poolSize, (_) async {
        final worker = _IsolateWorker();
        try {
          await worker.initialize();
          _workers.add(worker);
        } catch (e) {
          // Worker initialization failed
        }
      }),
    );

    await _initialization;
  }

  /// Execute a callback function in an isolate
  ///
  /// The callback function must be a top-level function or static method
  /// that can be serialized and sent to an isolate.
  Future<R> execute<T, R>(
      FutureOr<R> Function(T message) callback, T message) async {
    if (_isDisposed) {
      throw IsolateExecutionException('Isolate pool is disposed');
    }

    await _initializeWorkers();

    if (_workers.isEmpty) {
      throw const IsolateExecutionException('No worker isolates available');
    }

    final task = IsolateTask<T, R>(
      callback: callback,
      message: message,
      completer: Completer<R>(),
    );

    // Find the least busy worker
    _IsolateWorker? selectedWorker;
    int? minQueueSize;

    for (final worker in _workers) {
      if (!worker.isBusy) {
        selectedWorker = worker;
        break;
      }

      // Count queued tasks (approximate)
      final queueSize = worker._taskQueue.length;
      if (minQueueSize == null || queueSize < minQueueSize) {
        minQueueSize = queueSize;
        selectedWorker = worker;
      }
    }

    if (selectedWorker == null) {
      // Fallback to round-robin
      selectedWorker = _workers[_currentWorkerIndex];
      _currentWorkerIndex = (_currentWorkerIndex + 1) % _workers.length;
    }

    try {
      return await selectedWorker.execute(task);
    } catch (e) {
      throw IsolateExecutionException('Task execution failed', e);
    }
  }

  /// Execute a callback function in an isolate with automatic threshold detection
  ///
  /// If the message size exceeds the threshold, it will be executed in an isolate.
  /// Otherwise, it will be executed on the main thread.
  Future<R> executeIfNeeded<T, R>(
    R Function(T message) callback,
    T message, {
    int threshold = 30 * 1024, // 30KB default
  }) async {
    // Estimate message size (rough approximation)
    final messageSize = _estimateSize(message);

    if (messageSize > 0 && messageSize > threshold) {
      return execute(callback, message);
    } else {
      // Execute on main thread for small messages or unknown sizes
      return callback(message);
    }
  }

  /// Estimate the size of a message in bytes
  int _estimateSize<T>(T message) {
    if (message == null) return 0;

    if (message is String) {
      return message.length * 2; // UTF-16 encoding
    } else if (message is List<int>) {
      return message.length;
    } else if (message is Uint8List) {
      return message.length;
    } else if (message is Map) {
      // Rough estimate for maps without full serialization
      return message.length * 16;
    } else if (message is List) {
      // Rough estimate for lists
      return message.length * 8;
    } else {
      // Default to 0 to avoid expensive serialization
      return 0;
    }
  }

  /// Get the current status of the isolate pool
  IsolatePoolStatus get status {
    final busyWorkers = _workers.where((w) => w.isBusy).length;
    final totalQueuedTasks =
        _workers.fold<int>(0, (sum, w) => sum + w._taskQueue.length);

    return IsolatePoolStatus(
      totalWorkers: poolSize,
      busyWorkers: busyWorkers,
      idleWorkers: poolSize - busyWorkers,
      totalQueuedTasks: totalQueuedTasks,
      isDisposed: _isDisposed,
    );
  }

  /// Dispose the isolate pool and all workers
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    // Dispose all workers
    final disposeFutures = _workers.map((worker) => worker.dispose());
    await Future.wait(disposeFutures);

    _workers.clear();
  }
}

/// Status information about an isolate pool
class IsolatePoolStatus {
  final int totalWorkers;
  final int busyWorkers;
  final int idleWorkers;
  final int totalQueuedTasks;
  final bool isDisposed;

  const IsolatePoolStatus({
    required this.totalWorkers,
    required this.busyWorkers,
    required this.idleWorkers,
    required this.totalQueuedTasks,
    required this.isDisposed,
  });

  /// Whether the pool is healthy and operational
  bool get isHealthy => !isDisposed && totalWorkers > 0;

  /// The utilization percentage of the pool
  double get utilizationPercentage =>
      totalWorkers > 0 ? (busyWorkers / totalWorkers) * 100 : 0.0;

  @override
  String toString() {
    return 'IsolatePoolStatus('
        'workers: $busyWorkers/$totalWorkers busy, '
        'queued: $totalQueuedTasks, '
        'utilization: ${utilizationPercentage.toStringAsFixed(1)}%)';
  }
}
