import 'package:fasq/src/query/dependency/query_dependency_manager.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('QueryDependencyManager', () {
    late QueryDependencyManager manager;

    setUp(() {
      manager = QueryDependencyManager();
    });

    test('registers dependency correctly', () {
      manager.registerDependency('child', 'parent');

      expect(manager.getParent('child'), 'parent');
      expect(manager.getChildren('parent'), contains('child'));
    });

    test('prevents self-dependency', () {
      expect(
        () => manager.registerDependency('a', 'a'),
        throwsArgumentError,
      );
    });

    test('prevents direct circular dependency', () {
      manager.registerDependency('b', 'a');
      expect(
        () => manager.registerDependency('a', 'b'),
        throwsArgumentError,
      );
    });

    test('prevents transitive circular dependency', () {
      manager
        ..registerDependency('b', 'a')
        ..registerDependency('c', 'b');

      // a -> b -> c. Trying to make a depend on c (c -> a) calls cycle
      expect(
        () => manager.registerDependency('a', 'c'),
        throwsArgumentError,
      );
    });

    test('handles re-parenting (moving child to new parent)', () {
      manager.registerDependency('child', 'parent1');
      expect(manager.getChildren('parent1'), contains('child'));

      manager.registerDependency('child', 'parent2');
      expect(manager.getChildren('parent1'), isEmpty);
      expect(manager.getChildren('parent2'), contains('child'));
      expect(manager.getParent('child'), 'parent2');
    });

    test('unregister removes query as both parent and child', () {
      // setup: parent -> middle -> child
      manager
        ..registerDependency('middle', 'parent')
        ..registerDependency('child', 'middle')
        ..unregister('middle');

      // 'middle' should be gone
      expect(manager.getParent('middle'), isNull);
      expect(manager.getChildren('middle'), isEmpty);

      // 'parent' should no longer have 'middle' as child
      expect(manager.getChildren('parent'), isEmpty);

      // 'child' should be orphaned (no parent)
      expect(manager.getParent('child'), isNull);
    });

    test('getAllDescendants returns all deep children', () {
      manager
        ..registerDependency('b', 'a') // a -> b
        ..registerDependency('c', 'a') // a -> c
        ..registerDependency('d', 'b') // b -> d
        ..registerDependency('e', 'd'); // d -> e

      final descendants = manager.getAllDescendants('a');
      expect(descendants, hasLength(4));
      expect(descendants, containsAll(['b', 'c', 'd', 'e']));
    });

    test('notifyParentDisposed calls callback for direct children', () {
      manager
        ..registerDependency('child1', 'parent')
        ..registerDependency('child2', 'parent')
        ..registerDependency('grandchild', 'child1');

      final cancelled = <String>[];
      manager.notifyParentDisposed('parent', cancelled.add);

      expect(cancelled, hasLength(2));
      expect(cancelled, containsAll(['child1', 'child2']));
      expect(cancelled, isNot(contains('grandchild')));
    });

    test('can check for children and parents', () {
      manager.registerDependency('child', 'parent');

      expect(manager.hasChildren('parent'), isTrue);
      expect(manager.hasChildren('child'), isFalse);

      expect(manager.hasParent('child'), isTrue);
      expect(manager.hasParent('parent'), isFalse);
    });
  });
}
