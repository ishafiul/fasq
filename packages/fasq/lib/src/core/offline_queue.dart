import 'dart:async';

class OfflineMutationEntry {
  final String id;
  final String key;
  final String
      mutationType; // e.g., 'createPost', 'updateUser', 'deleteComment'
  final dynamic variables;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;
  final int priority; // Higher number = higher priority

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

  static OfflineMutationEntry fromJson(Map<String, dynamic> json) {
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
}

// Registry for different mutation types
class MutationTypeRegistry {
  static final Map<String, MutationHandler> _handlers = {};

  static void register<TData, TVariables>(
    String mutationType,
    Future<TData> Function(TVariables variables) handler,
  ) {
    _handlers[mutationType] = MutationHandler<TData, TVariables>(
      mutationType: mutationType,
      handler: handler,
    );
  }

  static MutationHandler? getHandler(String mutationType) {
    return _handlers[mutationType];
  }

  static List<String> get registeredTypes => _handlers.keys.toList();
}

class MutationHandler<TData, TVariables> {
  final String mutationType;
  final Future<TData> Function(TVariables variables) handler;

  const MutationHandler({
    required this.mutationType,
    required this.handler,
  });

  Future<TData> execute(TVariables variables) {
    return handler(variables);
  }
}

class OfflineQueueManager {
  static final OfflineQueueManager _instance = OfflineQueueManager._internal();
  factory OfflineQueueManager() => _instance;
  OfflineQueueManager._internal();

  static OfflineQueueManager get instance => _instance;

  final List<OfflineMutationEntry> _entries = [];
  final StreamController<List<OfflineMutationEntry>> _controller =
      StreamController<List<OfflineMutationEntry>>.broadcast();

  Stream<List<OfflineMutationEntry>> get stream => _controller.stream;
  List<OfflineMutationEntry> get entries => List.unmodifiable(_entries);
  int get length => _entries.length;

  void _emit() {
    if (!_controller.isClosed) _controller.add(entries);
  }

  Future<void> enqueue(String key, String mutationType, dynamic variables,
      {int priority = 0}) async {
    final id =
        '${DateTime.now().millisecondsSinceEpoch}-${_entries.length + 1}';
    _entries.add(OfflineMutationEntry(
      id: id,
      key: key,
      mutationType: mutationType,
      variables: variables,
      createdAt: DateTime.now(),
      priority: priority,
    ));
    await save();
    _emit();
  }

  Future<void> remove(String id) async {
    _entries.removeWhere((e) => e.id == id);
    await save();
    _emit();
  }

  Future<void> clear() async {
    _entries.clear();
    await save();
    _emit();
  }

  Future<void> save() async {
    // In this minimal implementation, we just keep in-memory and simulate persistence.
    // Consider integrating with platform storage in production.
  }

  Future<void> load() async {
    // No-op for now.
  }

  Future<void> processQueue() async {
    if (_entries.isEmpty) return;

    // Sort by priority (higher first), then by creation time
    final sortedEntries = List<OfflineMutationEntry>.from(_entries)
      ..sort((a, b) {
        final priorityCompare = b.priority.compareTo(a.priority);
        if (priorityCompare != 0) return priorityCompare;
        return a.createdAt.compareTo(b.createdAt);
      });

    for (final entry in sortedEntries) {
      final handler = MutationTypeRegistry.getHandler(entry.mutationType);

      if (handler == null) {
        // Remove unknown mutation types
        await remove(entry.id);
        continue;
      }

      try {
        await handler.execute(entry.variables);
        await remove(entry.id);
      } catch (error) {
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

        // Stop processing if max attempts reached
        if (updatedEntry.attempts >= 5) {
          break;
        }
      }
    }
  }

  // Process specific mutation type only
  Future<void> processQueueByType(String mutationType) async {
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
      } catch (error) {
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

  // Get entries by mutation type
  List<OfflineMutationEntry> getEntriesByType(String mutationType) {
    return _entries.where((e) => e.mutationType == mutationType).toList();
  }

  // Get queue statistics
  Map<String, int> getQueueStats() {
    final stats = <String, int>{};
    for (final entry in _entries) {
      stats[entry.mutationType] = (stats[entry.mutationType] ?? 0) + 1;
    }
    return stats;
  }
}
