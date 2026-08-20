import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/projection/projection.dart';
import 'package:fasq/src/query/keys/query_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = StringQueryKey('todo:tmp-1');
  final plan = ProjectionPlan(id: 'todo.edit', queryKeys: [key]);

  ProjectionCoordinator coordinator({ProjectionState? state}) {
    final registry = ProjectionRegistry()
      ..register(
        ProjectionDefinition(
          plan: plan,
          apply: (base, patch) => {
            ...(base as Map<Object?, Object?>? ?? const {}),
            ...(patch as Map<Object?, Object?>),
          },
        ),
      );
    return ProjectionCoordinator(registry: registry, state: state);
  }

  ProjectionOverlay overlay(
    String id,
    Map<String, Object?> patch, {
    int sequence = 0,
  }) => ProjectionOverlay(
    operationId: OperationId(id),
    lineageId: LineageId('lineage-$id'),
    plan: plan,
    patches: {key.key: patch},
    references: const {'dependency': 'tmp-1'},
    temporaryIds: const {'todo': 'tmp-1'},
    sequence: sequence,
  );

  test('keeps ordered overlays above revision-aware remote base', () {
    final subject = coordinator();
    subject.setRemoteBase(key, const {'title': 'server'}, revision: 2);
    subject.enqueue(overlay('one', const {'title': 'local-one'}));
    subject.enqueue(overlay('two', const {'title': 'local-two'}));

    expect(subject.materialize(key).value, {'title': 'local-two'});
    subject.setRemoteBase(key, const {'title': 'new-server'}, revision: 3);
    expect(subject.materialize(key).value, {'title': 'local-two'});
    subject.setRemoteBase(key, const {'title': 'old-server'}, revision: 1);
    expect(subject.state.remoteBases[key.key], {'title': 'new-server'});
  });

  test('round trips state and remaps detail, references, and IDs', () {
    final subject = coordinator();
    subject.setRemoteBase(key, const {'id': 'tmp-1', 'title': 'base'});
    subject.enqueue(overlay('create', const {'id': 'tmp-1'}));

    final restored = coordinator(
      state: ProjectionState.fromJson(subject.state.toJson()),
    );
    final outcome = restored.remapId(
      temporaryId: 'tmp-1',
      serverId: 'server-1',
    );

    expect(outcome.succeeded, isTrue);
    expect(restored.state.idMappings['tmp-1'], 'server-1');
    expect(restored.state.remoteBases['todo:server-1'], {
      'id': 'server-1',
      'title': 'base',
    });
    expect(restored.state.overlays.single.plan.queryKeys, ['todo:server-1']);
    expect(restored.state.overlays.single.references['dependency'], 'server-1');
  });

  test('projection failures stay separate from mutation completion', () {
    final failing = ProjectionRegistry()
      ..register(
        ProjectionDefinition(
          plan: plan,
          apply: (_, __) => throw StateError('domain projection failed'),
          reconcile: (_, __) => throw StateError('reconcile failed'),
        ),
      );
    final subject = ProjectionCoordinator(registry: failing);
    subject.setRemoteBase(key, const {'title': 'server'});
    subject.enqueue(overlay('one', const {'title': 'local'}));

    expect(
      subject.materialize(key).failure?.messageKey,
      'projection.apply_failed',
    );
    final outcome = subject.complete(OperationId('one'), const {'ok': true});
    expect(outcome.failure?.messageKey, 'projection.reconcile_failed');
    expect(
      subject.state.overlays.single.state,
      ProjectionOverlayState.projectionError,
    );
  });

  test(
    'conflict repair uses fresh identity and preserves original evidence',
    () {
      final subject = coordinator();
      subject.enqueue(overlay('one', const {'title': 'local'}));
      subject.markConflict(
        OperationId('one'),
        remoteKey: key,
        remoteValue: const {'title': 'remote'},
      );

      final repair = subject.repair(
        conflictedOperationId: OperationId('one'),
        action: ProjectionRepairAction.replace,
        replacementOperationId: OperationId('repair-one'),
        replacementLineageId: LineageId('repair-lineage'),
        replacementPlan: plan,
        replacementPatches: const {
          'todo:tmp-1': {'title': 'replacement'},
        },
      );

      expect(repair.succeeded, isTrue);
      expect(subject.state.overlays.map((item) => item.operationId.value), [
        'one',
        'repair-one',
      ]);
      expect(
        subject.state.overlays.first.state,
        ProjectionOverlayState.resolved,
      );
    },
  );
}
