import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_models.dart';
import 'package:fasq/src/mutation/sync_engine/store/outbox_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isolates nested operation and history data from caller mutation', () {
    final variables = <String, Object?>{
      'nested': <String, Object?>{
        'items': <Object?>['before'],
      },
    };
    final projection = <String, Object?>{
      'nested': <String, Object?>{
        'items': <Object?>['before'],
      },
    };
    final operation = _operation(variables: variables);
    final history = OutboxHistoryEntry(
      operationId: operation.operationId,
      state: MutationOperationState.succeeded,
      completedAt: DateTime.utc(2026),
      resultProjection: projection,
    );
    final snapshot = OutboxSnapshot(
      active: [operation],
      history: [history],
    );

    (variables['nested']! as Map<String, Object?>)['items'] = ['after'];
    (projection['nested']! as Map<String, Object?>)['items'] = ['after'];

    expect(
      ((snapshot.active.single.variables! as Map<Object?, Object?>)['nested']!
          as Map<Object?, Object?>)['items'],
      ['before'],
    );
    expect(
      ((snapshot.history.single.resultProjection!
              as Map<Object?, Object?>)['nested']!
          as Map<Object?, Object?>)['items'],
      ['before'],
    );
  });

  test('exposes unmodifiable nested snapshot collections', () {
    final snapshot = OutboxSnapshot(
      active: [
        _operation(
          variables: <String, Object?>{
            'nested': <String, Object?>{
              'items': <Object?>['value'],
            },
          },
          dependencies: [
            MutationDependency(parentOperationId: OperationId('parent')),
          ],
          projections: [
            MutationProjectionDescriptor(
              id: 'projection',
              queryKeys: const ['key'],
            ),
          ],
        ),
      ],
      metadata: <String, Object?>{
        'nested': <String, Object?>{
          'items': <Object?>['value'],
        },
      },
    );

    expect(snapshot.active.clear, throwsUnsupportedError);
    expect(
      () => (snapshot.metadata['nested']! as Map<String, Object?>)['items'] = [
        'changed',
      ],
      throwsUnsupportedError,
    );
    expect(
      () =>
          (snapshot.active.single.variables!
                  as Map<String, Object?>)['nested'] =
              <String, Object?>{},
      throwsUnsupportedError,
    );
    expect(
      () => snapshot.active.single.dependencies.clear(),
      throwsUnsupportedError,
    );
    expect(
      () => snapshot.active.single.projections.single.queryKeys.clear(),
      throwsUnsupportedError,
    );
  });

  test(
    'rejects invalid history projections and metadata at model boundary',
    () {
      expect(
        () => OutboxHistoryEntry.validated(
          operationId: OperationId('operation'),
          state: MutationOperationState.succeeded,
          completedAt: DateTime.utc(2026),
          resultProjection: DateTime.utc(2026),
        ),
        throwsA(isA<InvalidMutationPayloadException>()),
      );
      expect(
        () => OutboxSnapshot(
          metadata: <String, Object?>{
            'invalid': DateTime.utc(2026),
          },
        ),
        throwsA(isA<InvalidMutationPayloadException>()),
      );
    },
  );

  test('surfaces invalid persisted projection and metadata as corruption', () {
    final base = <String, Object?>{
      'active': <Object?>[],
      'deadLetters': <Object?>[],
      'history': <Object?>[],
      'metadata': <String, Object?>{},
    };

    expect(
      () => OutboxSnapshot.fromJson({
        ...base,
        'history': [
          {
            'operationId': 'operation',
            'state': MutationOperationState.succeeded.name,
            'completedAt': DateTime.utc(2026).toIso8601String(),
            'resultProjection': DateTime.utc(2026),
          },
        ],
      }),
      throwsA(isA<OutboxCorruptException>()),
    );
    expect(
      () => OutboxSnapshot.fromJson({
        ...base,
        'metadata': <String, Object?>{'invalid': DateTime.utc(2026)},
      }),
      throwsA(isA<OutboxCorruptException>()),
    );
  });

  test('rejects representative credential-like field names', () {
    const fieldNames = <String>[
      'apiKey',
      'Authorization-Header',
      'cookie_header',
      'PRIVATE-KEY',
      'sessionToken',
      'x_auth_token',
    ];
    const policy = OutboxSecurityPolicy();

    for (final fieldName in fieldNames) {
      expect(
        () => policy.validate(<String, Object?>{fieldName: 'value'}),
        throwsA(isA<OutboxCredentialRejectedException>()),
        reason: fieldName,
      );
    }
  });
}

MutationOperation _operation({
  Object? variables = const <String, Object?>{'title': 'todo'},
  List<MutationDependency> dependencies = const <MutationDependency>[],
  List<MutationProjectionDescriptor> projections =
      const <MutationProjectionDescriptor>[],
}) {
  return MutationOperation(
    operationId: OperationId('operation'),
    mutationKey: MutationKey(namespace: 'test', name: 'operation'),
    variables: variables,
    createdAt: DateTime.utc(2026),
    idempotencyKey: IdempotencyKey('idempotency'),
    lineageId: LineageId('lineage'),
    authPolicy: AuthPolicy.none,
    state: MutationOperationState.pending,
    dependencies: dependencies,
    projections: projections,
  );
}
