/// Manages parent-child relationships between queries.
///
/// Enables cascading cancellation when a parent query is disposed,
/// automatically cancelling in-flight fetch operations of dependent queries.
///
/// Example:
/// ```dart
/// final manager = QueryDependencyManager();
/// manager.registerDependency('user:123:posts', 'user:123');
/// manager.registerDependency('user:123:followers', 'user:123');
///
/// // When 'user:123' is disposed:
/// manager.notifyParentDisposed('user:123', (childKey) {
///   print('Cancelling: $childKey');
/// });
/// // Output: Cancelling: user:123:posts
/// //         Cancelling: user:123:followers
/// ```
class QueryDependencyManager {
  /// Map of parent key → set of child keys
  final Map<String, Set<String>> _parentToChildren = {};

  /// Map of child key → parent key (for reverse lookup)
  final Map<String, String> _childToParent = {};

  /// Registers a dependency relationship between a child and parent query.
  ///
  /// When the parent query is disposed, the child will be notified for
  /// cancellation. A child can only have one parent.
  ///
  /// Throws [ArgumentError] if a circular dependency would be created.
  void registerDependency(String childKey, String parentKey) {
    if (childKey == parentKey) {
      throw ArgumentError('Query cannot depend on itself: $childKey');
    }

    // Check for circular dependency
    if (_wouldCreateCycle(childKey, parentKey)) {
      throw ArgumentError(
        'Circular dependency detected: $parentKey -> $childKey would create '
        'a cycle',
      );
    }

    // Remove any existing parent relationship
    final existingParent = _childToParent[childKey];
    if (existingParent != null) {
      _parentToChildren[existingParent]?.remove(childKey);
    }

    // Register the new relationship
    _childToParent[childKey] = parentKey;
    _parentToChildren.putIfAbsent(parentKey, () => {}).add(childKey);
  }

  /// Unregisters a query from all dependency relationships.
  ///
  /// Removes the query as both a parent and a child.
  void unregister(String key) {
    // Remove as child
    final parent = _childToParent.remove(key);
    if (parent != null) {
      _parentToChildren[parent]?.remove(key);
      if (_parentToChildren[parent]?.isEmpty ?? false) {
        _parentToChildren.remove(parent);
      }
    }

    // Remove as parent (orphan all children)
    final children = _parentToChildren.remove(key);
    if (children != null) {
      for (final child in children) {
        _childToParent.remove(child);
      }
    }
  }

  /// Returns all direct child keys for a given parent.
  Set<String> getChildren(String parentKey) {
    return Set.unmodifiable(_parentToChildren[parentKey] ?? {});
  }

  /// Returns all descendant keys (children, grandchildren, etc.) for a parent.
  Set<String> getAllDescendants(String parentKey) {
    final descendants = <String>{};
    final toVisit = <String>[parentKey];

    while (toVisit.isNotEmpty) {
      final current = toVisit.removeLast();
      final children = _parentToChildren[current];
      if (children != null) {
        for (final child in children) {
          if (descendants.add(child)) {
            toVisit.add(child);
          }
        }
      }
    }

    return descendants;
  }

  /// Returns the parent key for a given child, or null if no parent.
  String? getParent(String childKey) {
    return _childToParent[childKey];
  }

  /// Notifies all direct child queries when a parent is disposed.
  ///
  /// The [onChild] callback is invoked for each direct child key.
  void notifyParentDisposed(String parentKey, void Function(String) onChild) {
    final children = _parentToChildren[parentKey];
    if (children == null) return;

    // Create a copy to avoid modification during iteration
    for (final childKey in children.toList()) {
      onChild(childKey);
    }
  }

  /// Notifies all descendant queries (deep) when a parent is disposed.
  ///
  /// The [onDescendant] callback is invoked for each descendant key.
  void notifyAllDescendantsDisposed(
    String parentKey,
    void Function(String) onDescendant,
  ) {
    final descendants = getAllDescendants(parentKey);
    for (final key in descendants) {
      onDescendant(key);
    }
  }

  /// Checks whether a query has any registered dependents.
  bool hasChildren(String parentKey) {
    return _parentToChildren[parentKey]?.isNotEmpty ?? false;
  }

  /// Checks whether a query has a parent dependency.
  bool hasParent(String childKey) {
    return _childToParent.containsKey(childKey);
  }

  /// Returns the total number of registered relationships.
  int get relationshipCount => _childToParent.length;

  /// Clears all registered relationships.
  void clear() {
    _parentToChildren.clear();
    _childToParent.clear();
  }

  /// Checks if adding childKey -> parentKey would create a cycle.
  bool _wouldCreateCycle(String childKey, String parentKey) {
    // If child is an ancestor of parent, adding this edge creates a cycle
    String? current = parentKey;
    while (current != null) {
      if (current == childKey) {
        return true;
      }
      current = _childToParent[current];
    }
    return false;
  }
}
