import 'package:fasq/src/mutation/sync_engine/kahn_dag.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Given a Kahn DAG sorter', () {
    group('When the graph is a simple dependency chain', () {
      const sorter = KahnDagSorter<String>();
      final nodes = <SyncDagNode<String>>[
        const SyncDagNode<String>(id: 'create_post', payload: 'create'),
        const SyncDagNode<String>(
          id: 'update_post',
          payload: 'update',
          dependsOnIds: <String>['create_post'],
        ),
      ];

      late SyncDagResolution<String> result;

      setUp(() {
        result = sorter.resolve(nodes);
      });

      test('Then it returns no blocked nodes', () {
        expect(result.blockedNodes, isEmpty);
      });

      test('Then it resolves create before update', () {
        expect(
          result.orderedNodes.map((node) => node.id).toList(),
          equals(<String>['create_post', 'update_post']),
        );
      });
    });

    group('When multiple independent nodes become ready', () {
      final sorter = KahnDagSorter<int>(
        readyNodeComparator: (a, b) => b.payload.compareTo(a.payload),
      );
      final nodes = <SyncDagNode<int>>[
        const SyncDagNode<int>(id: 'a', payload: 1),
        const SyncDagNode<int>(id: 'b', payload: 5),
        const SyncDagNode<int>(id: 'c', payload: 3),
      ];

      late SyncDagResolution<int> result;

      setUp(() {
        result = sorter.resolve(nodes);
      });

      test('Then it uses the ready-node comparator order', () {
        expect(result.blockedNodes, isEmpty);
        expect(
          result.orderedNodes.map((node) => node.id).toList(),
          equals(<String>['b', 'c', 'a']),
        );
      });
    });

    group('When a node depends on a missing node', () {
      const sorter = KahnDagSorter<String>();
      final nodes = <SyncDagNode<String>>[
        const SyncDagNode<String>(
          id: 'update_post',
          payload: 'update',
          dependsOnIds: <String>['create_post'],
        ),
      ];

      late SyncDagResolution<String> result;

      setUp(() {
        result = sorter.resolve(nodes);
      });

      test('Then the node is blocked as missing dependency', () {
        expect(result.orderedNodes, isEmpty);
        expect(result.blockedNodes, hasLength(1));
        expect(
          result.blockedNodes.first.reason,
          SyncDagBlockReason.missingDependency,
        );
        expect(
          result.blockedNodes.first.missingDependencyIds,
          equals(<String>['create_post']),
        );
      });
    });

    group('When the graph contains a cycle', () {
      const sorter = KahnDagSorter<String>();
      final nodes = <SyncDagNode<String>>[
        const SyncDagNode<String>(
          id: 'a',
          payload: 'A',
          dependsOnIds: <String>['b'],
        ),
        const SyncDagNode<String>(
          id: 'b',
          payload: 'B',
          dependsOnIds: <String>['a'],
        ),
      ];

      late SyncDagResolution<String> result;

      setUp(() {
        result = sorter.resolve(nodes);
      });

      test('Then all nodes are blocked as cycle', () {
        expect(result.orderedNodes, isEmpty);
        expect(result.blockedNodes, hasLength(2));
        expect(
          result.blockedNodes.every(
            (node) => node.reason == SyncDagBlockReason.cycle,
          ),
          isTrue,
        );
      });
    });

    test('When duplicate ids are provided then it throws argument error', () {
      const sorter = KahnDagSorter<String>();
      final nodes = <SyncDagNode<String>>[
        const SyncDagNode<String>(id: 'a', payload: 'A'),
        const SyncDagNode<String>(id: 'a', payload: 'B'),
      ];

      expect(() => sorter.resolve(nodes), throwsArgumentError);
    });
  });
}
