// Why a DAG here?
//
// Offline mutation chains frequently have hard ordering constraints:
// `create_post -> update_post -> publish_post`.
//
// This module provides a reusable, service-agnostic Kahn topological sorter
// that can be used by sync services to decide which queued requests are ready
// to execute and which are blocked (missing dependency or cycle).

/// A node in a directed acyclic graph for sync execution.
class SyncDagNode<TPayload> {
  /// Creates a sync DAG node.
  const SyncDagNode({
    required this.id,
    required this.payload,
    this.dependsOnIds = const <String>[],
  });

  /// Stable unique node identifier.
  final String id;

  /// Arbitrary payload associated with this node (request data, etc.).
  final TPayload payload;

  /// IDs that must run before this node can run.
  final List<String> dependsOnIds;
}

/// Why a node was not schedulable in the current graph.
enum SyncDagBlockReason {
  /// The node references dependencies that are absent from the current graph.
  missingDependency,

  /// The node is part of a cycle (or downstream of an unresolved cycle).
  cycle,

  /// The node directly depends on itself.
  selfDependency,
}

/// A node that could not be ordered, with reason details.
class BlockedSyncDagNode<TPayload> {
  /// Creates a blocked-node result.
  const BlockedSyncDagNode({
    required this.node,
    required this.reason,
    this.missingDependencyIds = const <String>[],
  });

  /// The original graph node.
  final SyncDagNode<TPayload> node;

  /// Why this node is blocked.
  final SyncDagBlockReason reason;

  /// Missing dependency IDs (when [reason] is missingDependency).
  final List<String> missingDependencyIds;
}

/// Topological ordering output for sync orchestration.
class SyncDagResolution<TPayload> {
  /// Creates a resolution result.
  const SyncDagResolution({
    required this.orderedNodes,
    required this.blockedNodes,
  });

  /// Nodes in executable topological order.
  final List<SyncDagNode<TPayload>> orderedNodes;

  /// Nodes that could not be scheduled.
  final List<BlockedSyncDagNode<TPayload>> blockedNodes;

  /// True when any node is blocked by missing dependency or cycle.
  bool get hasBlockedNodes => blockedNodes.isNotEmpty;
}

/// Kahn-based topological sorter for sync DAGs.
///
/// Duplicate IDs are rejected. Self-dependencies are reported as blocked.
class KahnDagSorter<TPayload> {
  /// Creates a DAG sorter.
  ///
  /// [readyNodeComparator] can be used to deterministically choose among
  /// multiple ready nodes (for example priority/time ordering).
  const KahnDagSorter({
    this.readyNodeComparator,
  });

  /// Optional comparator used when more than one node has in-degree 0.
  final Comparator<SyncDagNode<TPayload>>? readyNodeComparator;

  /// Produces topological execution order and blocked-node diagnostics.
  SyncDagResolution<TPayload> resolve(Iterable<SyncDagNode<TPayload>> nodes) {
    final nodeById = <String, SyncDagNode<TPayload>>{};
    for (final node in nodes) {
      if (nodeById.containsKey(node.id)) {
        throw ArgumentError('Duplicate DAG node id: ${node.id}');
      }
      nodeById[node.id] = node;
    }

    final inDegree = <String, int>{for (final id in nodeById.keys) id: 0};
    final outgoing = <String, Set<String>>{};
    final blockedByMissing = <String, List<String>>{};
    final selfBlocked = <String>{};

    for (final node in nodeById.values) {
      for (final dependencyId in node.dependsOnIds) {
        if (dependencyId == node.id) {
          selfBlocked.add(node.id);
          continue;
        }

        final dependencyExists = nodeById.containsKey(dependencyId);
        if (!dependencyExists) {
          blockedByMissing
              .putIfAbsent(node.id, () => <String>[])
              .add(dependencyId);
          continue;
        }

        inDegree[node.id] = (inDegree[node.id] ?? 0) + 1;
        outgoing.putIfAbsent(dependencyId, () => <String>{}).add(node.id);
      }
    }

    final blockedIds = <String>{
      ...selfBlocked,
      ...blockedByMissing.keys,
    };

    final ready = <SyncDagNode<TPayload>>[
      for (final node in nodeById.values)
        if (!blockedIds.contains(node.id) && (inDegree[node.id] ?? 0) == 0)
          node,
    ];
    _sortReady(ready);

    final ordered = <SyncDagNode<TPayload>>[];
    final visited = <String>{};

    while (ready.isNotEmpty) {
      final current = ready.removeAt(0);
      if (!visited.add(current.id)) continue;
      ordered.add(current);

      for (final childId in outgoing[current.id] ?? const <String>{}) {
        if (blockedIds.contains(childId)) continue;
        final next = (inDegree[childId] ?? 0) - 1;
        inDegree[childId] = next;
        if (next == 0) {
          final child = nodeById[childId];
          if (child != null && !visited.contains(child.id)) {
            ready.add(child);
          }
        }
      }
      _sortReady(ready);
    }

    final blocked = <BlockedSyncDagNode<TPayload>>[];
    for (final node in nodeById.values) {
      if (selfBlocked.contains(node.id)) {
        blocked.add(
          BlockedSyncDagNode<TPayload>(
            node: node,
            reason: SyncDagBlockReason.selfDependency,
          ),
        );
        continue;
      }

      final missing = blockedByMissing[node.id];
      if (missing != null && missing.isNotEmpty) {
        blocked.add(
          BlockedSyncDagNode<TPayload>(
            node: node,
            reason: SyncDagBlockReason.missingDependency,
            missingDependencyIds: List<String>.from(missing),
          ),
        );
        continue;
      }

      final isUnvisited = !visited.contains(node.id);
      if (isUnvisited) {
        blocked.add(
          BlockedSyncDagNode<TPayload>(
            node: node,
            reason: SyncDagBlockReason.cycle,
          ),
        );
      }
    }

    return SyncDagResolution<TPayload>(
      orderedNodes: ordered,
      blockedNodes: blocked,
    );
  }

  void _sortReady(List<SyncDagNode<TPayload>> ready) {
    final comparator = readyNodeComparator;
    if (comparator != null) {
      ready.sort(comparator);
    }
  }
}
