import 'dart:async';
import 'dart:io';

import 'package:fasq/src/mutation/sync_engine/codecs/mutation_codec.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/replay/replay_coordinator.dart';
import 'package:fasq/src/mutation/sync_engine/store/file_durable_outbox.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';
import 'package:fasq/src/security/outbox_encryption.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('fasq-replay-test-');
  });

  tearDown(() async {
    if (directory.existsSync()) await directory.delete(recursive: true);
  });

  test(
    'replays dependencies in order and persists parent bindings first',
    () async {
      final store = _newStore(directory);
      final registrations = MutationRegistrationRegistry();
      final parentKey = MutationKey(namespace: 'test', name: 'createTodo');
      final childKey = MutationKey(namespace: 'test', name: 'updateTodo');
      final independentKey = MutationKey(
        namespace: 'test',
        name: 'refreshTodos',
      );
      final executed = <String>[];
      Object? variablesAtExecution;

      registrations
        ..register<Map<String, Object?>, Map<String, Object?>>(
          key: parentKey,
          codec: _mapCodec,
          mutationFn: (_) async {
            executed.add('parent');
            return <String, Object?>{'id': 'todo-1'};
          },
        )
        ..register<Map<String, Object?>, Map<String, Object?>>(
          key: childKey,
          codec: _mapCodec,
          mutationFn: (variables) async {
            executed.add('child');
            variablesAtExecution = store.snapshot.active
                .singleWhere(
                  (operation) =>
                      operation.operationId.value == 'child-operation',
                )
                .variables;
            expect(variables['todoId'], 'todo-1');
            return <String, Object?>{'updated': true};
          },
        )
        ..register<Map<String, Object?>, Map<String, Object?>>(
          key: independentKey,
          codec: _mapCodec,
          mutationFn: (_) async {
            executed.add('independent');
            return <String, Object?>{'refreshed': true};
          },
        );

      await store.open();
      await store.transact(
        (current) => current.copyWith(
          active: [
            _operation(
              'parent-operation',
              key: parentKey,
              priority: 2,
            ),
            _operation(
              'child-operation',
              key: childKey,
              priority: 1,
              variables: {'todoId': 'placeholder'},
              dependencies: [
                MutationDependency(
                  parentOperationId: OperationId('parent-operation'),
                  parentResultPath: 'id',
                  childVariablePath: 'todoId',
                ),
              ],
            ),
            _operation(
              'independent-operation',
              key: independentKey,
            ),
          ],
        ),
      );

      final coordinator = DurableReplayCoordinator(
        store: store,
        registrations: registrations,
      );
      await coordinator.open();
      final report = await coordinator.replay();

      expect(executed, ['parent', 'child', 'independent']);
      expect(report.executedOperationIds.map((id) => id.value), [
        'parent-operation',
        'child-operation',
        'independent-operation',
      ]);
      expect(variablesAtExecution, {'todoId': 'todo-1'});
      expect(store.snapshot.active, isEmpty);
      expect(
        store.snapshot.history.map((entry) => entry.operationId.value),
        containsAll(<String>[
          'parent-operation',
          'child-operation',
          'independent-operation',
        ]),
      );
      await coordinator.close();
    },
  );

  test(
    'blocks descendants after terminal parent failure but runs independent '
    'work',
    () async {
      final store = _newStore(directory);
      final registrations = MutationRegistrationRegistry();
      final parentKey = MutationKey(namespace: 'test', name: 'failingParent');
      final childKey = MutationKey(namespace: 'test', name: 'dependentChild');
      final independentKey = MutationKey(
        namespace: 'test',
        name: 'independent',
      );
      var childInvocations = 0;
      var independentInvocations = 0;

      registrations
        ..register<Map<String, Object?>, Map<String, Object?>>(
          key: parentKey,
          codec: _mapCodec,
          mutationFn: (_) async => throw StateError('expected failure'),
        )
        ..register<Map<String, Object?>, Map<String, Object?>>(
          key: childKey,
          codec: _mapCodec,
          mutationFn: (_) async {
            childInvocations++;
            return <String, Object?>{};
          },
        )
        ..register<Map<String, Object?>, Map<String, Object?>>(
          key: independentKey,
          codec: _mapCodec,
          mutationFn: (_) async {
            independentInvocations++;
            return <String, Object?>{};
          },
        );

      await store.open();
      await store.transact(
        (current) => current.copyWith(
          active: [
            _operation('parent', key: parentKey, priority: 2),
            _operation(
              'child',
              key: childKey,
              dependencies: [
                MutationDependency(parentOperationId: OperationId('parent')),
              ],
            ),
            _operation('independent', key: independentKey, priority: 1),
          ],
        ),
      );

      final coordinator = DurableReplayCoordinator(
        store: store,
        registrations: registrations,
      );
      await coordinator.open();
      final report = await coordinator.replay();

      expect(childInvocations, 0);
      expect(independentInvocations, 1);
      expect(report.failedOperationIds.map((id) => id.value), ['parent']);
      expect(
        store.snapshot.deadLetters.single.operation.operationId.value,
        'parent',
      );
      expect(
        store.snapshot.deadLetters.single.operation.state,
        MutationOperationState.unknownOutcome,
      );
      expect(
        store.snapshot.active
            .singleWhere((operation) => operation.operationId.value == 'child')
            .state,
        MutationOperationState.blocked,
      );
      expect(
        report.blockedOperations
            .singleWhere(
              (diagnostic) => diagnostic.operationId.value == 'child',
            )
            .reason,
        ReplayBlockReason.parentFailure,
      );
      await coordinator.close();
    },
  );

  test('persists missing, cycle, and registration diagnostics', () async {
    final store = _newStore(directory);
    final registrations = MutationRegistrationRegistry();
    final key = MutationKey(namespace: 'test', name: 'registered');
    registrations.register<Map<String, Object?>, Map<String, Object?>>(
      key: key,
      codec: _mapCodec,
      mutationFn: (_) async => <String, Object?>{},
    );

    await store.open();
    await store.transact(
      (current) => current.copyWith(
        active: [
          _operation(
            'missing',
            key: key,
            dependencies: [
              MutationDependency(parentOperationId: OperationId('absent')),
            ],
          ),
          _operation(
            'cycle-a',
            key: key,
            dependencies: [
              MutationDependency(parentOperationId: OperationId('cycle-b')),
            ],
          ),
          _operation(
            'cycle-b',
            key: key,
            dependencies: [
              MutationDependency(parentOperationId: OperationId('cycle-a')),
            ],
          ),
          _operation(
            'unregistered',
            key: MutationKey(namespace: 'test', name: 'missing'),
          ),
        ],
      ),
    );

    final coordinator = DurableReplayCoordinator(
      store: store,
      registrations: registrations,
    );
    await coordinator.open();
    final report = await coordinator.replay();
    final diagnostics = {
      for (final diagnostic in report.blockedOperations)
        diagnostic.operationId.value: diagnostic.reason,
    };

    expect(diagnostics['missing'], ReplayBlockReason.missingDependency);
    expect(diagnostics['cycle-a'], ReplayBlockReason.cycle);
    expect(diagnostics['cycle-b'], ReplayBlockReason.cycle);
    expect(
      diagnostics['unregistered'],
      ReplayBlockReason.missingRegistration,
    );
    expect(store.snapshot.metadata['replayDiagnostics'], isNotEmpty);
    expect(
      store.snapshot.active.every(
        (operation) => operation.state == MutationOperationState.blocked,
      ),
      isTrue,
    );
    await coordinator.close();
  });

  test('recovers leftover running work as unknown outcome', () async {
    final store = _newStore(directory);
    final registrations = MutationRegistrationRegistry();
    final key = MutationKey(namespace: 'test', name: 'running');
    var invocations = 0;
    registrations.register<Map<String, Object?>, Map<String, Object?>>(
      key: key,
      codec: _mapCodec,
      mutationFn: (_) async {
        invocations++;
        return <String, Object?>{};
      },
    );

    await store.open();
    await store.transact(
      (current) => current.copyWith(
        active: [
          _operation(
            'running',
            key: key,
            state: MutationOperationState.running,
          ),
        ],
      ),
    );
    await store.close();

    final recoveredStore = _newStore(directory);
    final coordinator = DurableReplayCoordinator(
      store: recoveredStore,
      registrations: registrations,
    );
    await coordinator.open();
    final report = await coordinator.replay();

    expect(report.recoveredUnknownOutcomeIds.map((id) => id.value), [
      'running',
    ]);
    expect(invocations, 0);
    expect(recoveredStore.snapshot.active, isEmpty);
    expect(
      recoveredStore.snapshot.deadLetters.single.operation.state,
      MutationOperationState.unknownOutcome,
    );
    await coordinator.close();
  });

  test(
    'blocks duplicate operation IDs and one-sided bindings',
    () async {
      final store = _newStore(directory);
      final registrations = MutationRegistrationRegistry();
      final key = MutationKey(namespace: 'test', name: 'registered');
      registrations.register<Map<String, Object?>, Map<String, Object?>>(
        key: key,
        codec: _mapCodec,
        mutationFn: (_) async => <String, Object?>{},
      );

      await store.open();
      await store.transact(
        (current) => current.copyWith(
          active: [
            _operation('duplicate', key: key),
            _operation('duplicate', key: key),
            _operation(
              'invalid-binding',
              key: key,
              dependencies: [
                MutationDependency(
                  parentOperationId: OperationId('parent'),
                  parentResultPath: 'id',
                ),
              ],
            ),
          ],
        ),
      );

      final coordinator = DurableReplayCoordinator(
        store: store,
        registrations: registrations,
      );
      await coordinator.open();
      final report = await coordinator.replay();
      final reasons = {
        for (final diagnostic in report.blockedOperations)
          diagnostic.operationId.value: diagnostic.reason,
      };

      expect(reasons['duplicate'], ReplayBlockReason.duplicateOperation);
      expect(reasons['invalid-binding'], ReplayBlockReason.invalidBinding);
      await coordinator.close();
    },
  );

  test('blocks active operation IDs already in terminal ledgers', () async {
    final store = _newStore(directory);
    final registrations = MutationRegistrationRegistry();
    final key = MutationKey(namespace: 'test', name: 'registered');
    var invocations = 0;
    registrations.register<Map<String, Object?>, Map<String, Object?>>(
      key: key,
      codec: _mapCodec,
      mutationFn: (_) async {
        invocations++;
        return <String, Object?>{};
      },
    );

    final operationId = OperationId('terminal-operation');
    final terminalOperation = _operation(
      operationId.value,
      key: key,
      state: MutationOperationState.failedTerminal,
    );
    await store.open();
    await store.transact(
      (current) => current.copyWith(
        active: [_operation(operationId.value, key: key)],
        history: [
          OutboxHistoryEntry.validated(
            operationId: operationId,
            state: MutationOperationState.failedTerminal,
            completedAt: DateTime.utc(2026),
          ),
        ],
        deadLetters: [
          OutboxDeadLetter(
            operation: terminalOperation,
            category: MutationFailureCategory.business,
            messageKey: 'sync.replay.failure.business',
            retryable: false,
            repairable: true,
            failedAt: DateTime.utc(2026),
          ),
        ],
      ),
    );

    final coordinator = DurableReplayCoordinator(
      store: store,
      registrations: registrations,
    );
    await coordinator.open();
    final report = await coordinator.replay();

    expect(invocations, 0);
    expect(
      report.blockedOperations.single.reason,
      ReplayBlockReason.duplicateOperation,
    );
    expect(store.snapshot.active.single.state, MutationOperationState.blocked);
    await coordinator.close();
  });

  test(
    'does not satisfy a child from history when active ID is duplicated',
    () async {
      final store = _newStore(directory);
      final registrations = MutationRegistrationRegistry();
      final key = MutationKey(namespace: 'test', name: 'registered');
      var invocations = 0;
      registrations.register<Map<String, Object?>, Map<String, Object?>>(
        key: key,
        codec: _mapCodec,
        mutationFn: (_) async {
          invocations++;
          return <String, Object?>{};
        },
      );

      final operationId = OperationId('duplicate-parent');
      await store.open();
      await store.transact(
        (current) => current.copyWith(
          active: [
            _operation(operationId.value, key: key),
            _operation(
              'dependent',
              key: key,
              dependencies: [
                MutationDependency(parentOperationId: operationId),
              ],
            ),
          ],
          history: [
            OutboxHistoryEntry.validated(
              operationId: operationId,
              state: MutationOperationState.succeeded,
              completedAt: DateTime.utc(2026),
            ),
          ],
        ),
      );

      final coordinator = DurableReplayCoordinator(
        store: store,
        registrations: registrations,
      );
      await coordinator.open();
      final report = await coordinator.replay();

      expect(invocations, 0);
      expect(
        report.blockedOperations
            .singleWhere(
              (diagnostic) => diagnostic.operationId.value == 'dependent',
            )
            .reason,
        ReplayBlockReason.duplicateOperation,
      );
      await coordinator.close();
    },
  );

  test('preserves all missing and related dependency IDs', () async {
    final store = _newStore(directory);
    final registrations = MutationRegistrationRegistry();
    final key = MutationKey(namespace: 'test', name: 'registered');
    registrations.register<Map<String, Object?>, Map<String, Object?>>(
      key: key,
      codec: _mapCodec,
      mutationFn: (_) async => <String, Object?>{},
    );

    await store.open();
    await store.transact(
      (current) => current.copyWith(
        active: [
          _operation(
            'blocked',
            key: key,
            dependencies: [
              MutationDependency(
                parentOperationId: OperationId('missing-a'),
              ),
              MutationDependency(
                parentOperationId: OperationId('missing-b'),
              ),
              MutationDependency(
                parentOperationId: OperationId('invalid-a'),
                parentResultPath: 'id',
              ),
              MutationDependency(
                parentOperationId: OperationId('invalid-b'),
                parentResultPath: 'id',
              ),
            ],
          ),
        ],
      ),
    );

    final coordinator = DurableReplayCoordinator(
      store: store,
      registrations: registrations,
    );
    await coordinator.open();
    final report = await coordinator.replay();
    final diagnostic = report.blockedOperations.single;

    expect(diagnostic.reason, ReplayBlockReason.invalidBinding);
    expect(diagnostic.missingDependencyIds, ['missing-a', 'missing-b']);
    expect(diagnostic.relatedOperationIds, [
      OperationId('invalid-a'),
      OperationId('invalid-b'),
    ]);
    await coordinator.close();
  });

  test(
    'prevents duplicate execution through two coordinators sharing a store',
    () async {
      final store = _newStore(directory);
      final registrations = MutationRegistrationRegistry();
      final key = MutationKey(namespace: 'test', name: 'slow');
      final started = Completer<void>();
      final release = Completer<void>();
      var invocations = 0;
      registrations.register<Map<String, Object?>, Map<String, Object?>>(
        key: key,
        codec: _mapCodec,
        mutationFn: (_) async {
          invocations++;
          started.complete();
          await release.future;
          return <String, Object?>{};
        },
      );

      await store.open();
      await store.transact(
        (current) => current.copyWith(active: [_operation('slow', key: key)]),
      );
      final first = DurableReplayCoordinator(
        store: store,
        registrations: registrations,
      );
      final second = DurableReplayCoordinator(
        store: store,
        registrations: registrations,
      );
      await first.open();
      await second.open();

      final firstReplay = first.replay();
      await started.future;
      final secondReplay = second.replay();
      release.complete();
      await Future.wait([firstReplay, secondReplay]);

      expect(invocations, 1);
      await first.close();
      await second.close();
    },
  );

  test('leaves running work when completion generation conflicts', () async {
    final store = _newStore(directory);
    final registrations = MutationRegistrationRegistry();
    final key = MutationKey(namespace: 'test', name: 'conflicting');
    registrations.register<Map<String, Object?>, Map<String, Object?>>(
      key: key,
      codec: _mapCodec,
      mutationFn: (_) async {
        await store.transact(
          (current) => current.copyWith(
            metadata: {'externalWrite': true},
          ),
        );
        return <String, Object?>{'ok': true};
      },
    );

    await store.open();
    await store.transact(
      (current) =>
          current.copyWith(active: [_operation('conflicting', key: key)]),
    );
    final coordinator = DurableReplayCoordinator(
      store: store,
      registrations: registrations,
    );
    await coordinator.open();

    await expectLater(
      coordinator.replay(),
      throwsA(isA<OutboxGenerationConflictException>()),
    );
    expect(store.snapshot.active.single.state, MutationOperationState.running);
    expect(store.snapshot.history, isEmpty);
    expect(store.snapshot.deadLetters, isEmpty);
    await coordinator.close();
  });

  test('does not open a second coordinator for another store owner', () async {
    final firstStore = _newStore(directory);
    final secondStore = _newStore(directory);
    final registrations = MutationRegistrationRegistry();
    final first = DurableReplayCoordinator(
      store: firstStore,
      registrations: registrations,
    );
    final second = DurableReplayCoordinator(
      store: secondStore,
      registrations: registrations,
    );

    await first.open();
    await expectLater(
      second.open(),
      throwsA(isA<OutboxOwnershipException>()),
    );
    await first.close();
  });

  test('replay result collections cannot be mutated by callers', () {
    final operationId = OperationId('immutable');
    final diagnostic = ReplayDiagnostic(
      operationId: operationId,
      reason: ReplayBlockReason.missingDependency,
      messageKey: 'sync.replay.missing_dependency',
      missingDependencyIds: ['missing'],
    );
    final report = ReplayRunResult(
      executedOperationIds: [operationId],
      failedOperationIds: const [],
      recoveredUnknownOutcomeIds: const [],
      blockedOperations: [diagnostic],
    );

    expect(
      () => report.executedOperationIds.add(OperationId('another')),
      throwsUnsupportedError,
    );
    expect(
      () => report.blockedOperations.add(diagnostic),
      throwsUnsupportedError,
    );
    expect(
      () => diagnostic.missingDependencyIds.add('another'),
      throwsUnsupportedError,
    );
  });
}

const _mapCodec = JsonMutationCodec<Map<String, Object?>>(
  encoder: _encodeMap,
  decoder: _decodeMap,
);

Map<String, Object?> _encodeMap(Map<String, Object?> value) => value;

Map<String, Object?> _decodeMap(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const FormatException('Expected a JSON object');
  }
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key! as String: entry.value,
  };
}

FileDurableOutbox _newStore(Directory directory) {
  return FileDurableOutbox(
    directoryPath: directory.path,
    encryption: const _FakeOutboxEncryption(),
  );
}

MutationOperation _operation(
  String id, {
  required MutationKey key,
  Object? variables = const <String, Object?>{},
  List<MutationDependency> dependencies = const <MutationDependency>[],
  MutationOperationState state = MutationOperationState.pending,
  int priority = 0,
  Duration maxAge = const Duration(days: 3650),
}) {
  return MutationOperation(
    operationId: OperationId(id),
    mutationKey: key,
    variables: variables,
    createdAt: DateTime.utc(2026),
    idempotencyKey: IdempotencyKey('idempotency-$id'),
    lineageId: LineageId('lineage-$id'),
    authPolicy: AuthPolicy.none,
    state: state,
    priority: priority,
    maxAge: maxAge,
    dependencies: dependencies,
  );
}

class _FakeOutboxEncryption implements OutboxEncryption {
  const _FakeOutboxEncryption();

  @override
  Future<void> prepare({required bool allowCreateKey}) async {}

  @override
  Future<List<int>> encrypt(List<int> plaintext) async =>
      plaintext.map((byte) => byte ^ 0xAA).toList(growable: false);

  @override
  Future<List<int>> decrypt(List<int> ciphertext) async =>
      ciphertext.map((byte) => byte ^ 0xAA).toList(growable: false);
}
