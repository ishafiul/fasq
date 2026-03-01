import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Persisted representation of a queued offline mutation.
class OfflineMutationEntry {
  // Higher number = higher priority

  /// Creates an offline queue entry.
  const OfflineMutationEntry({
    required this.id,
    required this.key,
    required this.mutationType,
    required this.variables,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
    this.priority = 0,
  });

  /// Deserializes an entry from a JSON map.
  factory OfflineMutationEntry.fromJson(Map<String, dynamic> json) {
    return OfflineMutationEntry(
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

  /// Unique queue entry identifier.
  final String id;

  /// Query/mutation key associated with this entry.
  final String key;

  /// Logical mutation type (for example: `createPost`, `updateUser`).
  final String
      mutationType; // e.g., 'createPost', 'updateUser', 'deleteComment'

  /// Serialized variables passed to the mutation handler.
  final dynamic variables;

  /// Creation timestamp for queue ordering.
  final DateTime createdAt;

  /// Number of processing attempts.
  final int attempts;

  /// Last error message encountered while processing, if any.
  final String? lastError;

  /// Priority value used for ordering. Higher numbers run first.
  final int priority;

  /// Returns a copy with updated retry/error metadata.
  OfflineMutationEntry copyWith({
    int? attempts,
    String? lastError,
  }) {
    return OfflineMutationEntry(
      id: id,
      key: key,
      mutationType: mutationType,
      variables: variables,
      createdAt: createdAt,
      attempts: attempts ?? this.attempts,
      lastError: lastError,
      priority: priority,
    );
  }

  /// Serializes this entry into a JSON map.
  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'mutationType': mutationType,
        'variables': variables,
        'createdAt': createdAt.toIso8601String(),
        'attempts': attempts,
        'lastError': lastError,
        'priority': priority,
      };
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

/// Manages persistence and processing of offline mutation queue entries.
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
    _controller = StreamController<List<OfflineMutationEntry>>.broadcast();
    _uuidGenerator = const Uuid();
    _initialLoad = _loadFromDisk();
  }

  static OfflineQueueManager? _singleton;
  bool _disposed = false;
  bool _isProcessing = false;

  static const String _storageFileName = 'fasq_offline_queue.json';
  static String? _cachedStoragePath;

  final List<OfflineMutationEntry> _entries = [];
  late final StreamController<List<OfflineMutationEntry>> _controller;
  late final Uuid _uuidGenerator;
  Future<void>? _initialLoad;
  File? _storageFile;
  Future<void>? _saveOperation;

  /// Broadcast stream of queue snapshots.
  Stream<List<OfflineMutationEntry>> get stream => _controller.stream;

  /// Immutable view of current queued entries.
  List<OfflineMutationEntry> get entries => List.unmodifiable(_entries);

  /// Current queue length.
  int get length => _entries.length;

  void _emit() {
    if (!_controller.isClosed) _controller.add(entries);
  }

  /// Adds a mutation entry to the offline queue.
  ///
  /// Entries are persisted to disk after enqueue.
  Future<void> enqueue(
    String key,
    String mutationType,
    dynamic variables, {
    int priority = 0,
  }) async {
    await _ensureInitialized();
    final id = _uuidGenerator.v4();
    _entries.add(
      OfflineMutationEntry(
        id: id,
        key: key,
        mutationType: mutationType,
        variables: variables,
        createdAt: DateTime.now(),
        priority: priority,
      ),
    );
    await save();
    _emit();
  }

  /// Removes an entry by [id] and persists the queue.
  Future<void> remove(String id) async {
    await _ensureInitialized();
    _entries.removeWhere((e) => e.id == id);
    await save();
    _emit();
  }

  /// Clears all queued entries and persists the queue.
  Future<void> clear() async {
    await _ensureInitialized();
    _entries.clear();
    await save();
    _emit();
  }

  /// Persists current queue entries to disk.
  Future<void> save() async {
    await _ensureInitialized();
    if (_saveOperation != null) {
      await _saveOperation;
      return;
    }

    _saveOperation = _writeEntries().catchError((
      Object error,
      StackTrace stackTrace,
    ) {
      developer.log(
        'Failed to persist offline queue entries',
        name: 'FASQ.OfflineQueue',
        error: error,
        stackTrace: stackTrace,
      );
    }).whenComplete(() {
      _saveOperation = null;
    });

    await _saveOperation;
  }

  /// Reloads queue entries from disk.
  Future<void> load() async {
    _initialLoad = _loadFromDisk();
    await _initialLoad;
  }

  /// Processes all queued entries in priority and creation order.
  Future<void> processQueue() async {
    await _ensureInitialized();
    if (_entries.isEmpty) return;

    if (_isProcessing) return;
    _isProcessing = true;

    try {
      final sortedEntries = List<OfflineMutationEntry>.from(_entries)
        ..sort((a, b) {
          final priorityCompare = b.priority.compareTo(a.priority);
          if (priorityCompare != 0) return priorityCompare;
          return a.createdAt.compareTo(b.createdAt);
        });

      for (final entry in sortedEntries) {
        final handler = MutationTypeRegistry.getHandler(entry.mutationType);

        if (handler == null) {
          await remove(entry.id);
          continue;
        }

        try {
          await handler.execute(entry.variables);
          await remove(entry.id);
        } on Object catch (error) {
          final updatedEntry = entry.copyWith(
            attempts: entry.attempts + 1,
            lastError: error.toString(),
          );

          final index = _entries.indexWhere((e) => e.id == entry.id);
          if (index != -1) {
            _entries[index] = updatedEntry;
            await save();
            _emit();
          }

          if (updatedEntry.attempts >= 5) {
            await remove(entry.id);
            continue;
          }
        }
      }
    } finally {
      _isProcessing = false;
    }
  }

  /// Processes queued entries for a specific [mutationType] only.
  Future<void> processQueueByType(String mutationType) async {
    await _ensureInitialized();
    final entriesOfType =
        _entries.where((e) => e.mutationType == mutationType).toList();

    for (final entry in entriesOfType) {
      final handler = MutationTypeRegistry.getHandler(entry.mutationType);

      if (handler == null) {
        await remove(entry.id);
        continue;
      }

      try {
        await handler.execute(entry.variables);
        await remove(entry.id);
      } on Object catch (error) {
        final updatedEntry = entry.copyWith(
          attempts: entry.attempts + 1,
          lastError: error.toString(),
        );

        final index = _entries.indexWhere((e) => e.id == entry.id);
        if (index != -1) {
          _entries[index] = updatedEntry;
          await save();
          _emit();
        }
      }
    }
  }

  /// Returns queued entries filtered by [mutationType].
  List<OfflineMutationEntry> getEntriesByType(String mutationType) {
    // We assume load() has been awaited before calling this synchronous getter.
    return _entries.where((e) => e.mutationType == mutationType).toList();
  }

  /// Returns counts per mutation type currently in the queue.
  Map<String, int> getQueueStats() {
    // We assume load() has been awaited before calling this synchronous getter.
    final stats = <String, int>{};
    for (final entry in _entries) {
      stats[entry.mutationType] = (stats[entry.mutationType] ?? 0) + 1;
    }
    return stats;
  }

  Future<void> _ensureInitialized() {
    return _initialLoad ??= _loadFromDisk();
  }

  Future<void> _loadFromDisk() async {
    try {
      final file = await _resolveStorageFile();
      _storageFile = file;

      if (!file.existsSync()) {
        await file.writeAsString('[]', flush: true);
        _entries.clear();
        _emit();
        return;
      }

      final contents = await file.readAsString();
      if (contents.isEmpty) {
        _entries.clear();
        _emit();
        return;
      }

      final decoded = jsonDecode(contents);
      if (decoded is List) {
        _entries
          ..clear()
          ..addAll(
            decoded
                .whereType<Map<String, dynamic>>()
                .map(OfflineMutationEntry.fromJson),
          );
        _emit();
      }
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to load offline queue entries',
        name: 'FASQ.OfflineQueue',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  Future<File> _resolveStorageFile() async {
    if (_cachedStoragePath != null) {
      final file = File(_cachedStoragePath!);
      await file.parent.create(recursive: true);
      return file;
    }

    try {
      final dir = await getApplicationSupportDirectory();
      await dir.create(recursive: true);
      final file = File(p.join(dir.path, _storageFileName));
      _cachedStoragePath = file.path;
      return file;
    } on MissingPluginException {
      final fallbackDir =
          Directory(p.join(Directory.systemTemp.path, 'fasq_offline_queue'));
      await fallbackDir.create(recursive: true);
      final file = File(p.join(fallbackDir.path, _storageFileName));
      _cachedStoragePath = file.path;
      return file;
    }
  }

  Future<void> _writeEntries() async {
    try {
      final file = _storageFile ?? await _resolveStorageFile();
      _storageFile = file;
      final payload = _entries.map((entry) => entry.toJson()).toList();
      final jsonString = jsonEncode(payload);
      await file.writeAsString(jsonString, flush: true);
    } on Object catch (error, stackTrace) {
      developer.log(
        'Failed to write offline queue entries',
        name: 'FASQ.OfflineQueue',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Disposes this manager and releases stream resources.
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;

    await _controller.close();
    _entries.clear();
    _storageFile = null;
    _initialLoad = null;
  }

  @visibleForTesting

  /// Clears queue state for tests and optionally resets persisted storage.
  Future<void> resetForTesting({bool deleteStorage = true}) async {
    await _ensureInitialized();
    _entries.clear();
    if (deleteStorage && _storageFile != null) {
      try {
        await _storageFile!.writeAsString('[]', flush: true);
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
    _cachedStoragePath = null;
  }

  @visibleForTesting

  /// Clears only in-memory queue entries for tests.
  void clearInMemoryOnly() {
    _entries.clear();
    _emit();
  }
}
