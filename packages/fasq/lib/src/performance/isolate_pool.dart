import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

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
  Future<R> execute<T, R>(IsolateTask<T, R> task) async {
    if (_isDisposed) {
      task.completeError(IsolateExecutionException('Worker is disposed'));
      return task.completer.future;
    }

    if (_currentTask != null) {
      _taskQueue.add(task);
      return task.completer.future;
    }

    _currentTask = task;
    _sendPort!.send(task);

    return task.completer.future.then((result) {
      _currentTask = null;
      _processNextTask();
      return result;
    }).catchError((error) {
      _currentTask = null;
      _processNextTask();
      throw error;
    });
  }

  /// Process the next task in the queue
  void _processNextTask() {
    if (_taskQueue.isNotEmpty && _currentTask == null) {
      final nextTask = _taskQueue.removeAt(0);
      execute(nextTask);
    }
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

  receivePort.listen((message) {
    if (message == null) {
      // Shutdown signal
      receivePort.close();
      return;
    }

    if (message is IsolateTask<dynamic, dynamic>) {
      try {
        final result = message.callback(message.message);

        // Handle both sync and async results
        if (result is Future) {
          result.then((value) {
            message.complete(value);
          }).catchError((error, stackTrace) {
            message.completeError(error, stackTrace);
          });
        } else {
          message.complete(result);
        }
      } catch (error, stackTrace) {
        message.completeError(error, stackTrace);
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

  /// Create an isolate pool with the specified number of workers
  IsolatePool({this.poolSize = 2}) {
    assert(poolSize > 0, 'Pool size must be greater than 0');
    _initializeWorkers();
  }

  /// Initialize all worker isolates
  Future<void> _initializeWorkers() async {
    for (int i = 0; i < poolSize; i++) {
      final worker = _IsolateWorker();
      try {
        await worker.initialize();
        _workers.add(worker);
      } catch (e) {
        // If worker initialization fails, continue with remaining workers
        // but log the error for debugging
        // In production, you might want to throw or handle this differently
        continue;
      }
    }

    // Ensure we have at least one worker
    if (_workers.isEmpty) {
      throw IsolateExecutionException(
          'Failed to initialize any worker isolates');
    }
  }

  /// Execute a callback function in an isolate
  ///
  /// The callback function must be a top-level function or static method
  /// that can be serialized and sent to an isolate.
  Future<R> execute<T, R>(R Function(T message) callback, T message) async {
    if (_isDisposed) {
      throw IsolateExecutionException('Isolate pool is disposed');
    }

    if (_workers.isEmpty) {
      throw IsolateExecutionException('No worker isolates available');
    }

    final task = IsolateTask<T, R>(
      callback: callback,
      message: message,
      completer: Completer<R>(),
    );

    // Find the least busy worker
    _IsolateWorker? selectedWorker;
    int minQueueSize = double.infinity.toInt();

    for (final worker in _workers) {
      if (!worker.isBusy) {
        selectedWorker = worker;
        break;
      }

      // Count queued tasks (approximate)
      if (worker._taskQueue.length < minQueueSize) {
        minQueueSize = worker._taskQueue.length;
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
    int threshold = 100 * 1024, // 100KB default
  }) async {
    // Estimate message size (rough approximation)
    final messageSize = _estimateSize(message);

    if (messageSize > threshold) {
      return execute(callback, message);
    } else {
      // Execute on main thread for small messages
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
      return message.toString().length * 2;
    } else if (message is List) {
      return message.toString().length * 2;
    } else {
      // Fallback: serialize to string and estimate
      return message.toString().length * 2;
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
