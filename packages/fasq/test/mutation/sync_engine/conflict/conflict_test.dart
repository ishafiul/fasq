import 'package:fasq/src/mutation/sync_engine/conflict/conflict.dart';
import 'package:fasq/src/mutation/sync_engine/execution/execution_context.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final key = MutationKey(namespace: 'notes', name: 'update');
  final scope = AuthScope(
    principalId: 'user-1',
    tenantId: 'tenant-1',
    authRealm: 'primary',
  );
  final operation = MutationOperation(
    operationId: OperationId('op-1'),
    mutationKey: key,
    variables: const <String, Object?>{'title': 'local'},
    createdAt: DateTime.utc(2026, 8, 21),
    idempotencyKey: IdempotencyKey('idem-1'),
    lineageId: LineageId('lineage-1'),
    authPolicy: AuthPolicy.required,
    authScope: scope,
    state: MutationOperationState.failedTerminal,
  );

  test('classifies normalized conflict without transport knowledge', () {
    final classification = classifyConflictFailure(
      const MutationAdapterFailure(
        category: MutationFailureCategory.conflict,
        messageKey: 'sync.conflict.precondition',
        disposition: MutationFailureDisposition.terminal,
      ),
    );

    expect(classification?.kind, ConflictKind.unknown);
    expect(
      classifyConflictFailure(
        const MutationAdapterFailure(
          category: MutationFailureCategory.business,
          messageKey: 'sync.business.rejected',
          disposition: MutationFailureDisposition.terminal,
        ),
      ),
      isNull,
    );
  });

  test('requires explicit preconditions and round trips safe evidence', () {
    final expected = ConflictPrecondition('revision-4');
    expect(
      () => ConflictPolicy.required.validate(null),
      throwsA(isA<MissingConflictPreconditionException>()),
    );
    expect(
      () => ConflictPolicy.none.validate(expected),
      throwsA(isA<UnexpectedConflictPreconditionException>()),
    );

    final evidence = ConflictEvidence(
      operation: operation,
      classification: ConflictClassification(
        kind: ConflictKind.staleWrite,
        messageKey: 'sync.conflict.stale',
      ),
      occurredAt: DateTime.utc(2026, 8, 21, 1),
      expectedPrecondition: expected,
      observedPrecondition: ConflictPrecondition('revision-5'),
      latestServerSnapshot: const <String, Object?>{'title': 'remote'},
      projectionImpact: const <String, Object?>{'queryKey': 'note:1'},
    );
    final restored = ConflictEvidence.fromJson(evidence.toJson());

    expect(restored.operationId, operation.operationId);
    expect(restored.authScope, scope);
    expect(restored.classification.kind, ConflictKind.staleWrite);
    expect(restored.latestServerSnapshot, <String, Object?>{'title': 'remote'});
    expect(
      () => (restored.latestServerSnapshot! as Map<String, Object?>)['title'] =
          'changed',
      throwsUnsupportedError,
    );
  });

  test('discard and replacement use fresh identities and scope checks', () {
    final repair = ConflictRepair(
      evidence: ConflictEvidence(
        operation: operation,
        classification: ConflictClassification(
          kind: ConflictKind.staleWrite,
          messageKey: 'sync.conflict.stale',
        ),
        occurredAt: DateTime.utc(2026, 8, 21),
      ),
      identities: _TestIdentities(),
      now: () => DateTime.utc(2026, 8, 21, 2),
    );

    final discarded = repair.discard(currentAuthScope: scope);
    final replacement = repair.replace(
      variables: const <String, Object?>{'title': 'resolved'},
      precondition: ConflictPrecondition('revision-6'),
      currentAuthScope: scope,
    );

    expect(discarded.operationId.value, 'repair-op-1');
    expect(replacement.operation.operationId.value, 'repair-op-2');
    expect(replacement.operation.idempotencyKey.value, 'repair-idem-2');
    expect(replacement.operation.lineageId, operation.lineageId);
    expect(replacement.operation.state, MutationOperationState.pending);
    expect(
      () => repair.discard(
        currentAuthScope: AuthScope(
          principalId: 'other',
          tenantId: 'tenant-1',
          authRealm: 'primary',
        ),
      ),
      throwsA(isA<ConflictAuthScopeMismatchException>()),
    );
  });

  test('public-scope repair does not attach an unrelated auth scope', () {
    final publicOperation = MutationOperation(
      operationId: OperationId('public-op'),
      mutationKey: key,
      variables: const <String, Object?>{},
      createdAt: DateTime.utc(2026, 8, 21),
      idempotencyKey: IdempotencyKey('public-idem'),
      lineageId: LineageId('public-lineage'),
      authPolicy: AuthPolicy.none,
      state: MutationOperationState.failedTerminal,
    );
    final replacement =
        ConflictRepair(
          evidence: ConflictEvidence(
            operation: publicOperation,
            classification: ConflictClassification(
              kind: ConflictKind.staleWrite,
              messageKey: 'sync.conflict.stale',
            ),
            occurredAt: DateTime.utc(2026, 8, 21),
          ),
          identities: _TestIdentities(),
        ).replace(
          variables: const <String, Object?>{},
          precondition: ConflictPrecondition('revision-2'),
          currentAuthScope: scope,
        );

    expect(replacement.operation.authPolicy, AuthPolicy.none);
    expect(replacement.operation.authScope, isNull);
  });

  test('domain resolver can discard, replace, or remain unresolved', () {
    final repair = ConflictRepair(
      evidence: ConflictEvidence(
        operation: operation,
        classification: ConflictClassification(
          kind: ConflictKind.duplicateCreate,
          messageKey: 'sync.conflict.duplicate',
        ),
        occurredAt: DateTime.utc(2026, 8, 21),
      ),
      identities: _TestIdentities(),
    );

    expect(
      repair.resolve(
        resolver: (_) => const DiscardConflictPlan(),
        currentAuthScope: scope,
      ),
      isA<ConflictDiscarded>(),
    );
    expect(
      repair.resolve(
        resolver: (_) => ReplacementConflictPlan(
          variables: const <String, Object?>{'title': 'domain'},
          precondition: ConflictPrecondition('revision-7'),
        ),
        currentAuthScope: scope,
      ),
      isA<ConflictReplaced>(),
    );
    expect(
      repair.resolve(
        resolver: (_) => const UnresolvedConflictPlan(),
        currentAuthScope: scope,
      ),
      isA<ConflictUnresolved>(),
    );
  });
}

class _TestIdentities implements RepairIdentityFactory {
  var _count = 0;

  @override
  OperationId newOperationId() => OperationId('repair-op-${++_count}');

  @override
  IdempotencyKey newIdempotencyKey() => IdempotencyKey('repair-idem-$_count');
}
