import '../core/query.dart';
import '../core/query_client.dart';

/// Utility class for detecting memory leaks in FASQ queries.
///
/// The [LeakDetector] provides methods to check for queries that have been
/// created but not properly disposed, which can lead to memory leaks in
/// applications.
///
/// This class is intended for use in tests to ensure that queries are properly
/// cleaned up after use.
///
/// Example:
/// ```dart
/// test('no leaked queries', () async {
///   final client = QueryClient();
///   final detector = LeakDetector();
///   final query = client.getQuery<String>('test', () async => 'data');
///   query.addListener();
///
///   // Track the query for GC
///   detector.trackForGc(query, debugLabel: 'test-query');
///
///   // ... test code ...
///
///   query.removeListener();
///   query.dispose();
///
///   // Wait for GC and verify no leaks
///   await detector.verifyAllTrackedObjectsGc();
///   detector.expectNoLeakedQueries(client);
/// });
/// ```
class LeakDetector {
  /// Internal map to track expected disposals.
  ///
  /// This will be used in future tasks to track queries that should be
  /// disposed but haven't been yet.
  final Map<String, QueryDebugInfo> _expectedDisposals = {};

  /// Finalizer used to detect when tracked objects are garbage collected.
  ///
  /// The callback receives the label that was attached to the object when
  /// it was tracked. We use this to mark the object as GC'd.
  late final Finalizer<String> _finalizer;

  /// Map of tracked objects to their debug labels and identity hashes.
  ///
  /// Keys are the debug labels, values are the identity hash of the tracked object.
  /// Objects are removed from this map when they are GC'd.
  final Map<String, int> _trackedObjects = {};

  /// Set of labels for objects that have been confirmed as garbage collected.
  ///
  /// When the Finalizer callback is invoked, the object's label is
  /// added to this set.
  final Set<String> _gcConfirmed = {};

  /// Creates a new [LeakDetector] instance.
  LeakDetector() {
    _finalizer = Finalizer<String>((label) {
      // This callback is invoked when the tracked object is GC'd
      _gcConfirmed.add(label);
    });
  }

  /// Checks for leaked queries in the given [QueryClient].
  ///
  /// Returns a list of leaked query debug information if any leaks are found.
  /// Returns an empty list if no leaks are detected.
  ///
  /// This method will be implemented in a later task.
  List<QueryDebugInfo> checkForLeaks(QueryClient client) {
    // TODO: Implement leak detection logic
    // Clear expected disposals as they will be populated in future tasks
    _expectedDisposals.clear();
    return [];
  }

  /// Tracks an object to verify it is garbage collected after disposal.
  ///
  /// The object will be monitored using a [Finalizer]. When the object is
  /// garbage collected, it will be recorded in [_gcConfirmed].
  ///
  /// [object] - The object to track for garbage collection.
  /// [debugLabel] - Optional label to identify the object in error messages.
  ///
  /// Example:
  /// ```dart
  /// final query = client.getQuery<String>('test', () async => 'data');
  /// detector.trackForGc(query, debugLabel: 'test-query');
  /// ```
  void trackForGc(Object object, {String? debugLabel}) {
    final identityHash = identityHashCode(object);
    final label = debugLabel ?? 'object-${identityHash.toRadixString(16)}';

    _trackedObjects[label] = identityHash;

    // Attach the finalizer to the object
    // The finalizer will be invoked when the object is GC'd
    _finalizer.attach(object, label);
  }

  /// Verifies that all tracked objects have been garbage collected.
  ///
  /// This method waits for a short duration to allow the garbage collector
  /// to run, then checks if all tracked objects have been GC'd.
  ///
  /// [timeout] - Maximum time to wait for GC. Defaults to 1 second.
  ///
  /// Returns `true` if all tracked objects have been GC'd, `false` otherwise.
  ///
  /// Example:
  /// ```dart
  /// final query = client.getQuery<String>('test', () async => 'data');
  /// detector.trackForGc(query);
  /// query.dispose();
  ///
  /// // Make query unreachable
  /// query = null;
  ///
  /// // Wait for GC
  /// final allGc = await detector.verifyAllTrackedObjectsGc();
  /// expect(allGc, isTrue);
  /// ```
  Future<bool> verifyAllTrackedObjectsGc({
    Duration timeout = const Duration(seconds: 1),
  }) async {
    final startTime = DateTime.now();

    // Wait a bit to allow GC to run
    await Future.delayed(const Duration(milliseconds: 100));

    // Check periodically if all objects have been GC'd
    while (DateTime.now().difference(startTime) < timeout) {
      // Check if all tracked objects have been GC'd
      if (_trackedObjects.keys.every((label) => _gcConfirmed.contains(label))) {
        return true;
      }

      // Wait a bit more for GC
      await Future.delayed(const Duration(milliseconds: 50));
    }

    // Final check
    return _trackedObjects.keys.every((label) => _gcConfirmed.contains(label));
  }

  /// Returns a list of labels for objects that are still tracked but not yet garbage collected.
  ///
  /// This is useful for debugging which objects are preventing GC.
  List<String> getLeakedObjects() {
    return _trackedObjects.keys
        .where((label) => !_gcConfirmed.contains(label))
        .toList();
  }

  /// Clears all tracking information.
  ///
  /// This should be called between tests to ensure clean state.
  void clearTracking() {
    _trackedObjects.clear();
    _gcConfirmed.clear();
  }

  /// Asserts that no queries are leaked in the given [QueryClient].
  ///
  /// Checks all active queries in the [QueryClient] and throws an [Exception]
  /// if any queries are found that are not in the [allowedLeakKeys] set.
  ///
  /// [client] - The QueryClient to check for leaked queries.
  /// [allowedLeakKeys] - Optional set of query keys that are allowed to remain
  /// active. Useful for queries that are intentionally kept alive across tests.
  ///
  /// Throws an [Exception] with detailed information about leaked queries,
  /// including:
  /// - The query key
  /// - The creation stack trace (where the query was created)
  /// - The reference holders (what objects are keeping the query alive)
  ///
  /// Example:
  /// ```dart
  /// test('no leaked queries', () {
  ///   final client = QueryClient();
  ///   final query = client.getQuery<String>('test', () async => 'data');
  ///   query.addListener();
  ///
  ///   // ... test code ...
  ///
  ///   query.removeListener();
  ///   final detector = LeakDetector();
  ///   detector.expectNoLeakedQueries(client);
  /// });
  /// ```
  ///
  /// Example with allowed leaks:
  /// ```dart
  /// test('with allowed leaks', () {
  ///   final client = QueryClient();
  ///   final persistentQuery = client.getQuery<String>('persistent', () async => 'data');
  ///
  ///   final detector = LeakDetector();
  ///   detector.expectNoLeakedQueries(
  ///     client,
  ///     allowedLeakKeys: {'persistent'},
  ///   );
  /// });
  /// ```
  void expectNoLeakedQueries(
    QueryClient client, {
    Set<String>? allowedLeakKeys,
  }) {
    final allowedKeys = allowedLeakKeys ?? <String>{};
    final activeQueries = client.activeQueryDebugInfoMap;

    if (activeQueries.isEmpty) {
      return;
    }

    final leakedQueries = activeQueries.entries
        .where((entry) => !allowedKeys.contains(entry.key))
        .toList();

    if (leakedQueries.isEmpty) {
      return;
    }

    // Build detailed error message
    final buffer = StringBuffer();
    buffer.writeln('Found ${leakedQueries.length} leaked query(ies):');
    buffer.writeln();

    for (final entry in leakedQueries) {
      final queryKey = entry.key;
      final debugInfo = entry.value;

      buffer.writeln('Query: $queryKey');
      buffer.writeln('─' * 50);

      if (debugInfo.creationStack != null) {
        buffer.writeln('Created at:');
        buffer.writeln(debugInfo.creationStack.toString());
        buffer.writeln();
      } else {
        buffer.writeln('Created at: (stack trace not available)');
        buffer.writeln();
      }

      if (debugInfo.referenceHolders.isNotEmpty) {
        buffer.writeln(
            'Held by ${debugInfo.referenceHolders.length} reference holder(s):');
        for (final holderEntry in debugInfo.referenceHolders.entries) {
          buffer.writeln('  - ${holderEntry.key}');
          buffer.writeln('    Stack trace:');
          final stackLines = holderEntry.value.toString().split('\n');
          for (final line in stackLines.take(5)) {
            buffer.writeln('    $line');
          }
          if (stackLines.length > 5) {
            buffer.writeln('    ... (${stackLines.length - 5} more lines)');
          }
          buffer.writeln();
        }
      } else {
        buffer.writeln('Held by: (no active reference holders)');
        buffer.writeln();
      }

      buffer.writeln();
    }

    throw Exception(buffer.toString());
  }
}
