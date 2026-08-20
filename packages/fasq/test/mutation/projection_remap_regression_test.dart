import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reports old and new keys for base and overlay remaps', () {
    final temporaryKey = StringQueryKey('todo:tmp-3');
    final plan = ProjectionPlan(
      id: 'todo.remap',
      queryKeys: [temporaryKey],
    );
    final registry = ProjectionRegistry()
      ..register(ProjectionDefinition(plan: plan, apply: (_, patch) => patch));
    final coordinator = ProjectionCoordinator(registry: registry);

    coordinator.setRemoteBase(temporaryKey, const {'id': 'tmp-3'});
    coordinator.enqueue(
      ProjectionOverlay(
        operationId: OperationId('create'),
        lineageId: LineageId('lineage-create'),
        plan: plan,
        patches: const {
          'todo:tmp-3': {'id': 'tmp-3'},
        },
      ),
    );

    final outcome = coordinator.remapId(
      temporaryId: 'tmp-3',
      serverId: 'server-3',
    );

    expect(outcome.changedKeys, ['todo:tmp-3', 'todo:server-3']);
  });

  test('remaps exact identifiers without rewriting unrelated text', () {
    final remapped = remapProjectionReferences(
      const {
        'id': 'tmp-3',
        'description': 'copy tmp-3 later',
        'nested': ['tmp-3', 'tmp-30'],
        'copy tmp-3 later': 'tmp-3',
      },
      temporaryId: 'tmp-3',
      serverId: 'server-3',
    );

    expect(remapped, {
      'id': 'server-3',
      'description': 'copy tmp-3 later',
      'nested': ['server-3', 'tmp-30'],
      'copy tmp-3 later': 'server-3',
    });
  });

  test('only remaps query-key segments in projection descriptors', () {
    final descriptor = MutationProjectionDescriptor(
      id: 'todo.remap:v1 tmp-3',
      queryKeys: const ['todo:tmp-3', 'todo:copy tmp-3 later'],
    );

    final remapped = descriptor.mapKeys('tmp-3', 'server-3');

    expect(remapped.id, 'todo.remap:v1 tmp-3');
    expect(remapped.queryKeys, ['todo:server-3', 'todo:copy tmp-3 later']);
  });
}
