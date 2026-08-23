import 'package:fasq/src/mutation/sync_engine/conflict/conflict_models.dart';
import 'package:fasq/src/mutation/sync_engine/conflict/conflict_policy.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';
import 'package:uuid/uuid.dart';

/// Supplies fresh identities for every explicit repair attempt.
abstract interface class RepairIdentityFactory {
  OperationId newOperationId();
  IdempotencyKey newIdempotencyKey();
}

/// Production identity source; tests can inject a deterministic source.
class UuidRepairIdentityFactory implements RepairIdentityFactory {
  UuidRepairIdentityFactory({Uuid? uuid}) : _uuid = uuid ?? const Uuid();

  final Uuid _uuid;

  @override
  OperationId newOperationId() => OperationId(_uuid.v4());

  @override
  IdempotencyKey newIdempotencyKey() => IdempotencyKey(_uuid.v4());
}

/// Fresh queued work produced by explicit replacement/domain resolution.
class ConflictRepairOperation {
  const ConflictRepairOperation({
    required this.originalOperationId,
    required this.operation,
    required this.precondition,
  });

  final OperationId originalOperationId;
  final MutationOperation operation;
  final ConflictPrecondition precondition;

  Map<String, Object?> toJson() => {
    'originalOperationId': originalOperationId.value,
    'operation': operation.toJson(),
    'precondition': precondition.toJson(),
  };
}

/// Fresh audit identity for an explicit discard action.
class ConflictDiscardAction {
  const ConflictDiscardAction({
    required this.originalOperationId,
    required this.operationId,
    required this.idempotencyKey,
  });

  final OperationId originalOperationId;
  final OperationId operationId;
  final IdempotencyKey idempotencyKey;

  Map<String, Object?> toJson() => {
    'originalOperationId': originalOperationId.value,
    'operationId': operationId.value,
    'idempotencyKey': idempotencyKey.value,
    'action': 'discard',
  };
}

sealed class ConflictRepairPlan {
  const ConflictRepairPlan();
}

final class DiscardConflictPlan extends ConflictRepairPlan {
  const DiscardConflictPlan();
}

final class ReplacementConflictPlan extends ConflictRepairPlan {
  const ReplacementConflictPlan({
    required this.variables,
    required this.precondition,
    this.mutationKey,
  });

  final Object? variables;
  final ConflictPrecondition precondition;
  final MutationKey? mutationKey;
}

final class UnresolvedConflictPlan extends ConflictRepairPlan {
  const UnresolvedConflictPlan();
}

/// Inputs supplied to an explicit domain resolver.
class ConflictResolutionContext {
  const ConflictResolutionContext(this.evidence);

  final ConflictEvidence evidence;
  Object? get originalIntent => evidence.operation.variables;
  Object? get latestServerSnapshot => evidence.latestServerSnapshot;
}

typedef ConflictDomainResolver =
    ConflictRepairPlan Function(
      ConflictResolutionContext context,
    );

sealed class ConflictRepairResult {
  const ConflictRepairResult();
}

final class ConflictDiscarded extends ConflictRepairResult {
  const ConflictDiscarded(this.action);
  final ConflictDiscardAction action;
}

final class ConflictReplaced extends ConflictRepairResult {
  const ConflictReplaced(this.repair);
  final ConflictRepairOperation repair;
}

final class ConflictUnresolved extends ConflictRepairResult {
  const ConflictUnresolved();
}

/// Creates only explicit repairs; never retries unchanged or merges generically.
class ConflictRepair {
  ConflictRepair({
    required this.evidence,
    RepairIdentityFactory? identities,
    DateTime Function()? now,
  }) : _identities = identities ?? UuidRepairIdentityFactory(),
       _now = now ?? DateTime.now;

  final ConflictEvidence evidence;
  final RepairIdentityFactory _identities;
  final DateTime Function() _now;

  ConflictDiscardAction discard({AuthScope? currentAuthScope}) {
    _checkScope(currentAuthScope);
    return ConflictDiscardAction(
      originalOperationId: evidence.operationId,
      operationId: _identities.newOperationId(),
      idempotencyKey: _identities.newIdempotencyKey(),
    );
  }

  ConflictRepairOperation replace({
    required Object? variables,
    required ConflictPrecondition precondition,
    MutationKey? mutationKey,
    AuthScope? currentAuthScope,
  }) {
    _checkScope(currentAuthScope);
    return ConflictRepairOperation(
      originalOperationId: evidence.operationId,
      operation: _newOperation(
        variables: variables,
        mutationKey: mutationKey ?? evidence.mutationKey,
        conflictPrecondition: precondition,
        authScope: evidence.operation.authPolicy == AuthPolicy.required
            ? currentAuthScope
            : null,
      ),
      precondition: precondition,
    );
  }

  ConflictRepairResult resolve({
    required ConflictDomainResolver resolver,
    AuthScope? currentAuthScope,
  }) {
    _checkScope(currentAuthScope);
    return switch (resolver(ConflictResolutionContext(evidence))) {
      DiscardConflictPlan() => ConflictDiscarded(
        discard(currentAuthScope: currentAuthScope),
      ),
      ReplacementConflictPlan(
        :final variables,
        :final precondition,
        :final mutationKey,
      ) =>
        ConflictReplaced(
          replace(
            variables: variables,
            precondition: precondition,
            mutationKey: mutationKey,
            currentAuthScope: currentAuthScope,
          ),
        ),
      UnresolvedConflictPlan() => const ConflictUnresolved(),
    };
  }

  MutationOperation _newOperation({
    required Object? variables,
    required MutationKey mutationKey,
    required ConflictPrecondition conflictPrecondition,
    required AuthScope? authScope,
  }) {
    return MutationOperation(
      operationId: _identities.newOperationId(),
      mutationKey: mutationKey,
      variables: variables,
      createdAt: _now().toUtc(),
      idempotencyKey: _identities.newIdempotencyKey(),
      lineageId: evidence.operation.lineageId,
      authPolicy: evidence.operation.authPolicy,
      conflictPolicy: ConflictPolicy.required,
      conflictPrecondition: conflictPrecondition,
      authScope: authScope,
      state: MutationOperationState.pending,
      priority: evidence.operation.priority,
      maxAttempts: evidence.operation.maxAttempts,
      maxAge: evidence.operation.maxAge,
      dependencies: evidence.operation.dependencies,
      projections: evidence.operation.projections,
    );
  }

  void _checkScope(AuthScope? currentAuthScope) {
    if (evidence.operation.authPolicy == AuthPolicy.required &&
        currentAuthScope != evidence.authScope) {
      throw const ConflictAuthScopeMismatchException();
    }
  }
}
