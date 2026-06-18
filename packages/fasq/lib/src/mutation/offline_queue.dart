import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Processing status for a queued offline mutation node.
enum OfflineMutationStatus {
  /// Ready for processing when selected by queue ordering.
  pending,

  /// Currently being processed.
  running,

  /// Processing should be retried at a later time.
  retryScheduled,

  /// Successfully processed.
  succeeded,

  /// Reached a terminal failure and moved to dead-letter storage.
  failedTerminal,

  /// Blocked because an upstream dependency failed terminally.
  blockedByParentFailure,
}

/// Persisted representation of a queued offline mutation in v2 storage.
class OfflineMutationNode {
  /// Creates an offline mutation node.
  const OfflineMutationNode({
    required this.id,
    required this.key,
    required this.mutationType,
    required this.variables,
    required this.createdAt,
    required this.idempotencyKey,
    this.status = OfflineMutationStatus.pending,
    this.attempts = 0,
    this.lastError,
    this.priority = 0,
    this.dependsOnIds = const <String>[],
    this.maxRetries = 5,
    this.nextRunAt,
  });

  /// Deserializes a node from JSON.
  factory OfflineMutationNode.fromJson(Map<String, dynamic> json) {
    final rawStatus = json['status'];
    final status = rawStatus is String
        ? OfflineMutationStatus.values.firstWhere(
            (value) => value.name == rawStatus,
            orElse: () => OfflineMutationStatus.pending,
          )
        : OfflineMutationStatus.pending;

    final dependsOn = json['dependsOnIds'];
    final id = json['id'] as String;

    return OfflineMutationNode(
      id: id,
      key: json['key'] as String,
      mutationType: json['mutationType'] as String,
      variables: json['variables'],
      createdAt: DateTime.parse(json['createdAt'] as String),
      status: status,
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
      dependsOnIds: dependsOn is List
          ? dependsOn.whereType<String>().toList(growable: false)
          : const <String>[],
      idempotencyKey: (json['idempotencyKey'] as String?) ?? id,
      maxRetries: _safeRetryCount((json['maxRetries'] as num?)?.toInt()),
      nextRunAt: json['nextRunAt'] == null
          ? null
          : DateTime.parse(json['nextRunAt'] as String),
    );
  }

  static const Object _unset = Object();

  /// Stable queue node identifier.
  final String id;

  /// Query/mutation key associated with this node.
  final String key;

  /// Logical mutation type (for example: `createPost`, `updateUser`).
  final String mutationType;

  /// Serialized variables passed to the mutation handler.
  final dynamic variables;

  /// Creation timestamp for queue ordering.
  final DateTime createdAt;

  /// Current processing status.
  final OfflineMutationStatus status;

  /// Number of processing attempts.
  final int attempts;

  /// Last error message encountered while processing, if any.
  final String? lastError;

  /// Priority value used for ordering. Higher numbers run first.
  final int priority;

  /// Upstream dependency node IDs.
  final List<String> dependsOnIds;

  /// Idempotency key used for replay-safe writes.
  final String idempotencyKey;

  /// Maximum retry attempts before terminal failure.
  final int maxRetries;

  /// Optional next eligible replay timestamp.
  final DateTime? nextRunAt;

  /// Returns a copy with updated node metadata.
  OfflineMutationNode copyWith({
    OfflineMutationStatus? status,
    int? attempts,
    Object? lastError = _unset,
    int? priority,
    List<String>? dependsOnIds,
    String? idempotencyKey,
    int? maxRetries,
    Object? nextRunAt = _unset,
  }) {
    return OfflineMutationNode(
      id: id,
      key: key,
      mutationType: mutationType,
      variables: variables,
      createdAt: createdAt,
      status: status ?? this.status,
      attempts: attempts ?? this.attempts,
      lastError: identical(lastError, _unset)
          ? this.lastError
          : lastError as String?,
      priority: priority ?? this.priority,
      dependsOnIds: dependsOnIds ?? this.dependsOnIds,
      idempotencyKey: idempotencyKey ?? this.idempotencyKey,
      maxRetries: _safeRetryCount(maxRetries ?? this.maxRetries),
      nextRunAt: identical(nextRunAt, _unset)
          ? this.nextRunAt
          : nextRunAt as DateTime?,
    );
  }

  /// Serializes this node into a JSON map.
  Map<String, dynamic> toJson() => {
    'id': id,
    'key': key,
    'mutationType': mutationType,
    'variables': variables,
    'createdAt': createdAt.toIso8601String(),
    'status': status.name,
    'attempts': attempts,
    'lastError': lastError,
    'priority': priority,
    'dependsOnIds': dependsOnIds,
    'idempotencyKey': idempotencyKey,
    'maxRetries': maxRetries,
    'nextRunAt': nextRunAt?.toIso8601String(),
  };

  static int _safeRetryCount(int? value) {
    if (value == null || value < 1) return 1;
    return value;
  }
}

/// Persisted dead-letter entry for terminally failed offline mutations.
class OfflineDeadLetterEntry {
  /// Creates a dead-letter record.
  const OfflineDeadLetterEntry({
    required this.id,
    required this.node,
    required this.reason,
    required this.failedAt,
    this.errorMessage,
  });

  /// Deserializes an entry from JSON.
  factory OfflineDeadLetterEntry.fromJson(Map<String, dynamic> json) {
    return OfflineDeadLetterEntry(
      id: json['id'] as String,
      node: OfflineMutationNode.fromJson(json['node'] as Map<String, dynamic>),
      reason: json['reason'] as String,
      failedAt: DateTime.parse(json['failedAt'] as String),
      errorMessage: json['errorMessage'] as String?,
    );
  }

  /// Dead-letter entry ID.
  final String id;

  /// Original queue node.
  final OfflineMutationNode node;

  /// Classification of terminal failure.
  final String reason;

  /// Timestamp when entry was moved to dead-letter storage.
  final DateTime failedAt;

  /// Optional terminal failure message.
  final String? errorMessage;

  /// Serializes this entry into JSON.
  Map<String, dynamic> toJson() => {
    'id': id,
    'node': node.toJson(),
    'reason': reason,
    'failedAt': failedAt.toIso8601String(),
    'errorMessage': errorMessage,
  };
}

class _LegacyOfflineMutationEntry {
  const _LegacyOfflineMutationEntry({
    required this.id,
    required this.key,
    required this.mutationType,
    required this.variables,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
    this.priority = 0,
  });

  factory _LegacyOfflineMutationEntry.fromJson(Map<String, dynamic> json) {
    return _LegacyOfflineMutationEntry(
      id: json['id'] as String,
      key: json['key'] as String,
      mutationType: json['mutationType'] as String,
      variables: json['variables'],
      createdAt: DateTime.parse(json['createdAt'] as String),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      lastError: json['lastError'] as String?,
      priority: (json['priority'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String key;
  final String mutationType;
  final dynamic variables;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  final int priority;

  OfflineMutationNode toNode() {
    return OfflineMutationNode(
      id: id,
      key: key,
      mutationType: mutationType,
      variables: variables,
      createdAt: createdAt,
      attempts: attempts,
      lastError: lastError,
      priority: priority,
      idempotencyKey: id,
    );
  }
}

/// Global registry that maps mutation type names to execution handlers.
class MutationTypeRegistry {
  static final Map<String, MutationHandler<Object?, Object?>> _handlers = {};

  /// Registers a handler for [mutationType].
  ///
  /// When queued entries with the same type are processed, [handler] is used
  /// to execute the mutation with its persisted variables.
  static void register<TData, TVariables>(
    String mutationType,
    Future<TData> Function(TVariables variables) handler,
  ) {
    _handlers[mutationType] = MutationHandler<Object?, Object?>(
      mutationType: mutationType,
      handler: (variables) => handler(variables as TVariables),
    );
  }

  /// Returns the registered handler for [mutationType], if any.
  static MutationHandler<Object?, Object?>? getHandler(String mutationType) {
    return _handlers[mutationType];
  }

  /// Returns all currently registered mutation type names.
  static List<String> get registeredTypes => _handlers.keys.toList();

  /// Clears all registered handlers.
  @visibleForTesting
  static void clearForTesting() {
    _handlers.clear();
  }
}

/// Executes a registered mutation type with typed variables.
class MutationHandler<TData, TVariables> {
  /// Creates a mutation handler for [mutationType].
  const MutationHandler({
    required this.mutationType,
    required this.handler,
  });

  /// Logical mutation type identifier.
  final String mutationType;

  /// Function used to execute the mutation.
  final Future<TData> Function(TVariables variables) handler;

  /// Executes the mutation handler with [variables].
  Future<TData> execute(TVariables variables) {
    return handler(variables);
  }
}

/// Manages persistence and processing of offline mutation queue nodes.
///
/// The manager stores queued mutations on disk, emits updates via [stream],
/// and replays entries when connectivity is restored.
class OfflineQueueManager {
  /// Returns the shared queue manager instance.
  factory OfflineQueueManager() {
    if ((_singleton?._disposed ?? false) || _singleton == null) {
      _singleton = OfflineQueueManager._internal();
    }
    return _singleton!;
  }

  /// Returns the shared queue manager instance.
  factory OfflineQueueManager.instance() => OfflineQueueManager();

  OfflineQueueManager._internal() {
    _controller = StreamController<List<OfflineMutationNode>>.broadcast();
    _uuidGenerator = const Uuid();
    _initialLoad = _loadFromDisk();
  }

  static OfflineQueueManager? _singleton;
  bool _disposed = false;
  bool _isProcessing = false;

  static const int _queueSchemaVersion = 2;
  static const int _deadLetterSchemaVersion = 1;
  static const String _queueStorageFileName = 'fasq_offline_queue.json';
  static const String _deadLetterStorageFileName =
      'fasq_offline_dead_letter.json';

  static String? _cachedQueueStoragePath;
  static String? _cachedDeadLetterStoragePath;

  final List<OfflineMutationNode> _entries = [];
  final List<OfflineDeadLetterEntry> _deadLetterEntries = [];
  late final StreamController<List<OfflineMutationNode>> _controller;
  late final Uuid _uuidGenerator;
  Future<void>? _initialLoad;
  File? _queueStorageFile;
  File? _deadLetterStorageFile;
  Future<void>? _saveOperation;
  Future<void>? _deadLetterSaveOperation;

  /// Broadcast stream of queue snapshots.
  Stream<List<OfflineMutationNode>> get stream => _controller.stream;

  /// Immutable view of current queued nodes.
  List<OfflineMutationNode> get entries => List.unmodifiable(_entries);

  /// Immutable view of current dead-letter entries.
  List<OfflineDeadLetterEntry> get deadLetters =>
      List.unmodifiable(_deadLetterEntries);

  /// Current active queue length.
  int get length => _entries.length;

  /// Current dead-letter queue length.
  int get deadLetterLength => _deadLetterEntries.length;

  void _emit() {
    if (!_controller.isClosed) _controller.add(entries);
  }

  /// Adds a mutation node to the offline queue.
  ///
  /// Nodes are persisted to disk after enqueue.
  Future<void> enqueue(
    String key,
    String mutationType,
    dynamic variables, {
    int priority = 0,
    List<String> dependsOnIds = const <String>[],
    String? idempotencyKey,
    int maxRetries = 5,
  }) async {
    await _ensureInitialized();
    final id = _uuidGenerator.v4();
    _entries.add(
      OfflineMutationNode(
        id: id,
        key: key,
        mutationType: mutationType,
        variables: variables,
        createdAt: DateTime.now(),
        priority: priority,
        dependsOnIds: List<String>.from(dependsOnIds),
        idempotencyKey: idempotencyKey ?? id,
        maxRetries: OfflineMutationNode._safeRetryCount(maxRetries),
      ),
    );
    await save();
    _emit();
  }

  /// Removes a node by [id] and persists the queue.
  Future<void> remove(String id) async {
    await _ensureInitialized();
    _entries.removeWhere((node) => node.id == id);
    await save();
    _emit();
  }

  /// Clears all active queue nodes and persists the queue.
  Future<void> clear() async {
    await _ensureInitialized();
    _entries.clear();
    await save();
    _emit();
  }

  /// Persists current queue nodes to disk.
  Future<void> save() async {
    await _ensureInitialized();
    if (_saveOperation != null) {
      await _saveOperation;
      return;
    }

    _saveOperation = _writeQueueEnvelope()
        .catchError((Object error, StackTrace stackTrace) {
          developer.log(
            'Failed to persist offline queue nodes',
            name: 'FASQ.OfflineQueue',
            error: error,
            stackTrace: stackTrace,
          );
        })
        .whenComplete(() {
          _saveOperation = null;
        });

    await _saveOperation;
  }

  /// Reloads queue and dead-letter data from disk.
  Future<void> load() async {
    _initialLoad = _loadFromDisk();
    await _initialLoad;
  }

  /// Processes all queued nodes in priority and creation order.
  Future<void> processQueue() async {
    await _ensureInitialized();
    if (_entries.isEmpty) return;

    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final sortedEntries = List<OfflineMutationNode>.from(_entries)
        ..sort((a, b) {
          final priorityCompare = b.priority.compareTo(a.priority);
          if (priorityCompare != 0) return priorityCompare;
          return a.createdAt.compareTo(b.createdAt);
        });

      for (final node in sortedEntries) {
        await _processNode(node);
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Processes queued nodes for a specific [mutationType] only.
  Future<void> processQueueByType(String mutationType) async {
    await _ensureInitialized();
    final entriesOfType = _entries
        .where((node) => node.mutationType == mutationType)
        .toList();

    for (final node in entriesOfType) {
      await _processNode(node);
    }
  }

  Future<void> _processNode(OfflineMutationNode snapshotNode) async {
    final currentIndex = _entries.indexWhere(
      (node) => node.id == snapshotNode.id,
    );
    if (currentIndex == -1) return;

    final currentNode = _entries[currentIndex];
    final handler = MutationTypeRegistry.getHandler(currentNode.mutationType);

    if (handler == null) {
      await _moveToDeadLetter(
        currentNode,
        reason: 'missing_handler',
        errorMessage: 'No handler registered for ${currentNode.mutationType}',
      );
      return;
    }

    _entries[currentIndex] = currentNode.copyWith(
      status: OfflineMutationStatus.running,
      lastError: null,
      nextRunAt: null,
    );
    await save();
    _emit();

    try {
      await handler.execute(currentNode.variables);
      await remove(currentNode.id);
    } on Object catch (error) {
      final latestIndex = _entries.indexWhere(
        (node) => node.id == currentNode.id,
      );
      if (latestIndex == -1) return;

      final latestNode = _entries[latestIndex];
      final updatedAttempts = latestNode.attempts + 1;
      final isTerminal = updatedAttempts >= latestNode.maxRetries;

      final updatedNode = latestNode.copyWith(
        attempts: updatedAttempts,
        lastError: error.toString(),
        status: isTerminal
            ? OfflineMutationStatus.failedTerminal
            : OfflineMutationStatus.pending,
      );

      _entries[latestIndex] = updatedNode;
      await save();
      _emit();

      if (isTerminal) {
        await _moveToDeadLetter(
          updatedNode,
          reason: 'max_retries_exceeded',
          errorMessage: error.toString(),
        );
      }
    }
  }

  Future<void> _moveToDeadLetter(
    OfflineMutationNode node, {
    required String reason,
    String? errorMessage,
  }) async {
    final deadLetterNode = node.copyWith(
      status: OfflineMutationStatus.failedTerminal,
      lastError: errorMessage ?? node.lastError,
    );

    _deadLetterEntries.add(
      OfflineDeadLetterEntry(
        id: _uuidGenerator.v4(),
        node: deadLetterNode,
        reason: reason,
        failedAt: DateTime.now(),
        errorMessage: errorMessage ?? node.lastError,
      ),
    );

    _entries.removeWhere((entry) => entry.id == node.id);

    await _saveDeadLetters();
    await save();
    _emit();
  }

  /// Returns queued nodes filtered by [mutationType].
  List<OfflineMutationNode> getEntriesByType(String mutationType) {
    // We assume load() has been awaited before calling this synchronous getter.
    return _entries.where((node) => node.mutationType == mutationType).toList();
  }

  /// Returns counts per mutation type currently in the active queue.
  Map<String, int> getQueueStats() {
    // We assume load() has been awaited before calling this synchronous getter.
    final stats = <String, int>{};
    for (final node in _entries) {
      stats[node.mutationType] = (stats[node.mutationType] ?? 0) + 1;
    }
    return stats;
  }

  Future<void> _ensureInitialized() {
    return _initialLoad ??= _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    try {
      final queueFile = await _resolveQueueStorageFile();
      final deadLetterFile = await _resolveDeadLetterStorageFile();
      _queueStorageFile = queueFile;
      _deadLetterStorageFile = deadLetterFile;

      var migratedLegacy = false;
      var resetQueueToEmpty = false;
      final loadedNodes = <OfflineMutationNode>[];

      if (!queueFile.existsSync()) {
        resetQueueToEmpty = true;
      } else {
        final contents = await queueFile.readAsString();
        final trimmed = contents.trim();

        if (trimmed.isEmpty) {
          resetQueueToEmpty = true;
        } else {
          try {
            final decoded = jsonDecode(trimmed);

            if (decoded is List) {
              loadedNodes.addAll(
                decoded
                    .whereType<Map<String, dynamic>>()
                    .map(_LegacyOfflineMutationEntry.fromJson)
                    .map((entry) => entry.toNode()),
              );
              migratedLegacy = true;
            } else if (decoded is Map<String, dynamic>) {
              final schemaVersion = decoded['schemaVersion'];
              final rawNodes = decoded['nodes'];

              if (schemaVersion == _queueSchemaVersion && rawNodes is List) {
                loadedNodes.addAll(
                  rawNodes.whereType<Map<String, dynamic>>().map(
                    OfflineMutationNode.fromJson,
                  ),
                );
              } else {
                developer.log(
                  'Unsupported offline queue schema. '
                  'Resetting to empty v2 queue.',
                  name: 'FASQ.OfflineQueue',
                  error:
                      'schemaVersion=$schemaVersion '
                      'hasNodes=${rawNodes is List}',
                );
                resetQueueToEmpty = true;
              }
            } else {
              developer.log(
                'Malformed offline queue payload. Resetting to empty v2 queue.',
                name: 'FASQ.OfflineQueue',
              );
              resetQueueToEmpty = true;
            }
          } on Object catch (error, stackTrace) {
            developer.log(
              'Failed to decode offline queue payload. '
              'Resetting to empty v2 queue.',
              name: 'FASQ.OfflineQueue',
              error: error,
              stackTrace: stackTrace,
            );
            resetQueueToEmpty = true;
          }
        }
      }

      _entries
        ..clear()
        ..addAll(
          resetQueueToEmpty ? const <OfflineMutationNode>[] : loadedNodes,
        );

      if (migratedLegacy || resetQueueToEmpty) {
        await _writeQueueEnvelope();
      }

      var resetDeadLettersToEmpty = false;
      final loadedDeadLetters = <OfflineDeadLetterEntry>[];

      if (!deadLetterFile.existsSync()) {
        resetDeadLettersToEmpty = true;
      } else {
        final contents = await deadLetterFile.readAsString();
        final trimmed = contents.trim();

        if (trimmed.isEmpty) {
          resetDeadLettersToEmpty = true;
        } else {
          try {
            final decoded = jsonDecode(trimmed);
            if (decoded is Map<String, dynamic>) {
              final schemaVersion = decoded['schemaVersion'];
              final rawEntries = decoded['entries'];

              if (schemaVersion == _deadLetterSchemaVersion &&
                  rawEntries is List) {
                loadedDeadLetters.addAll(
                  rawEntries.whereType<Map<String, dynamic>>().map(
                    OfflineDeadLetterEntry.fromJson,
                  ),
                );
              } else {
                developer.log(
                  'Unsupported dead-letter schema. '
                  'Resetting dead-letter storage.',
                  name: 'FASQ.OfflineQueue',
                  error:
                      'schemaVersion=$schemaVersion '
                      'hasEntries=${rawEntries is List}',
                );
                resetDeadLettersToEmpty = true;
              }
            } else {
              developer.log(
                'Malformed dead-letter payload. Resetting dead-letter storage.',
                name: 'FASQ.OfflineQueue',
              );
              resetDeadLettersToEmpty = true;
            }
          } on Object catch (error, stackTrace) {
            developer.log(
              'Failed to decode dead-letter payload. '
              'Resetting dead-letter storage.',
              name: 'FASQ.OfflineQueue',
              error: error,
              stackTrace: stackTrace,
            );
            resetDeadLettersToEmpty = true;
          }
        }
      }

      _deadLetterEntries
        ..clear()
        ..addAll(
          resetDeadLettersToEmpty
              ? const <OfflineDeadLetterEntry>[]
              : loadedDeadLetters,
        );

      if (resetDeadLettersToEmpty) {
        await _writeDeadLetterEnvelope();
      }

      _emit();
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to load offline queue entries',
        name: 'FASQ.OfflineQueue',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<File> _resolveQueueStorageFile() {
    return _resolveStorageFile(
      cachedPath: _cachedQueueStoragePath,
      fileName: _queueStorageFileName,
      onPathResolved: (value) {
        _cachedQueueStoragePath = value;
      },
    );
  }

  Future<File> _resolveDeadLetterStorageFile() {
    return _resolveStorageFile(
      cachedPath: _cachedDeadLetterStoragePath,
      fileName: _deadLetterStorageFileName,
      onPathResolved: (value) {
        _cachedDeadLetterStoragePath = value;
      },
    );
  }

  Future<File> _resolveStorageFile({
    required String? cachedPath,
    required String fileName,
    required void Function(String path) onPathResolved,
  }) async {
    if (cachedPath != null) {
      final file = File(cachedPath);
      await file.parent.create(recursive: true);
      return file;
    }

    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, fileName));
      onPathResolved(file.path);
      return file;
    } on MissingPluginException {
      final fallbackDir = Directory(
        p.join(Directory.systemTemp.path, 'fasq_offline_queue'),
      );
      await fallbackDir.create(recursive: true);
      final file = File(p.join(fallbackDir.path, fileName));
      onPathResolved(file.path);
      return file;
    }
  }

  Future<void> _writeQueueEnvelope() async {
    final file = _queueStorageFile ?? await _resolveQueueStorageFile();
    _queueStorageFile = file;

    final payload = <String, dynamic>{
      'schemaVersion': _queueSchemaVersion,
      'nodes': _entries.map((entry) => entry.toJson()).toList(),
    };

    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  Future<void> _saveDeadLetters() async {
    if (_deadLetterSaveOperation != null) {
      await _deadLetterSaveOperation;
      return;
    }

    _deadLetterSaveOperation = _writeDeadLetterEnvelope()
        .catchError((Object error, StackTrace stackTrace) {
          developer.log(
            'Failed to persist offline dead-letter entries',
            name: 'FASQ.OfflineQueue',
            error: error,
            stackTrace: stackTrace,
          );
        })
        .whenComplete(() {
          _deadLetterSaveOperation = null;
        });

    await _deadLetterSaveOperation;
  }

  Future<void> _writeDeadLetterEnvelope() async {
    final file =
        _deadLetterStorageFile ?? await _resolveDeadLetterStorageFile();
    _deadLetterStorageFile = file;

    final payload = <String, dynamic>{
      'schemaVersion': _deadLetterSchemaVersion,
      'entries': _deadLetterEntries.map((entry) => entry.toJson()).toList(),
    };

    await file.writeAsString(jsonEncode(payload), flush: true);
  }

  /// Disposes this manager and releases stream resources.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _controller.close();
    _entries.clear();
    _deadLetterEntries.clear();
    _queueStorageFile = null;
    _deadLetterStorageFile = null;
    _initialLoad = null;
  }

  @visibleForTesting
  /// Clears queue and dead-letter state for tests and resets persisted storage.
  Future<void> resetForTesting({bool deleteStorage = true}) async {
    await _ensureInitialized();
    _entries.clear();
    _deadLetterEntries.clear();

    if (deleteStorage) {
      try {
        await _writeQueueEnvelope();
        await _writeDeadLetterEnvelope();
      } on Object catch (error, stackTrace) {
        developer.log(
          'Failed to reset offline queue storage',
          name: 'FASQ.OfflineQueue',
          error: error,
          stackTrace: stackTrace,
        );
      }
    }

    _emit();
  }

  /// Resets singleton/static queue state for tests.
  static Future<void> resetForTestingStatic() async {
    if (_singleton != null) {
      await _singleton!.dispose();
    }
    _singleton = null;
    _cachedQueueStoragePath = null;
    _cachedDeadLetterStoragePath = null;
    MutationTypeRegistry.clearForTesting();
  }

  @visibleForTesting
  /// Clears only in-memory active queue nodes for tests.
  void clearInMemoryOnly() {
    _entries.clear();
    _emit();
  }

  @visibleForTesting
  /// Resolves the queue storage file path for tests.
  Future<File> resolveQueueStorageFileForTesting() {
    return _resolveQueueStorageFile();
  }

  @visibleForTesting
  /// Resolves the dead-letter storage file path for tests.
  Future<File> resolveDeadLetterStorageFileForTesting() {
    return _resolveDeadLetterStorageFile();
  }
}
