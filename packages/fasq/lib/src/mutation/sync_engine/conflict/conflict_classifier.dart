import 'package:fasq/src/mutation/sync_engine/conflict/conflict_models.dart';
import 'package:fasq/src/mutation/sync_engine/execution/execution_context.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';

/// Converts only an explicit normalized conflict failure into conflict data.
/// Transport adapters own HTTP/status/error interpretation before this seam.
ConflictClassification? classifyConflictFailure(
  MutationAdapterFailure failure,
) {
  if (failure.category != MutationFailureCategory.conflict) return null;
  return ConflictClassification(
    kind: failure.conflictKind,
    messageKey: failure.messageKey,
  );
}
