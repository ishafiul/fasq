// These interfaces are deliberate substitution boundaries for app adapters.
// ignore_for_file: one_member_abstracts

import 'package:fasq/src/mutation/sync_engine/conflict/conflict_models.dart';
import 'package:fasq/src/mutation/sync_engine/conflict/conflict_policy.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';

/// Whether an adapter knows if its failed operation changed remote state.
enum MutationOutcomeKnowledge {
  /// The adapter knows the operation did not produce an ambiguous effect.
  known,

  /// The adapter cannot prove whether the operation produced an effect.
  unknown,
}

/// Whether an execution adapter invoked its executor before cancellation.
enum MutationExecutionPhase {
  /// Cancellation happened before executor invocation.
  notStarted,

  /// Executor invocation began before cancellation was observed.
  started,
}

/// Scheduler action requested by a normalized adapter failure.
enum MutationFailureDisposition {
  /// Retry after the scheduler applies retry and rate-limit policy.
  retry,

  /// Keep the operation active but wait for an external readiness change.
  pause,

  /// Move the operation to terminal failure storage.
  terminal,

  /// Preserve an ambiguous result as a repairable unknown outcome.
  unknownOutcome,
}

/// Safe, transport-neutral failure returned by an execution adapter.
class MutationAdapterFailure {
  /// Creates a normalized adapter failure.
  const MutationAdapterFailure({
    required this.category,
    required this.messageKey,
    required this.disposition,
    this.outcomeKnowledge = MutationOutcomeKnowledge.known,
    this.retryAfter,
    this.rateLimitBucket,
    this.idempotencySafe = false,
    this.executionPhase = MutationExecutionPhase.notStarted,
    this.repairable = true,
    this.conflictKind = ConflictKind.unknown,
    this.observedPrecondition,
    this.latestServerSnapshot,
    this.projectionImpact,
  });

  /// Creates a conservative failure for an unclassified exception.
  const MutationAdapterFailure.unknown()
    : category = MutationFailureCategory.unknown,
      messageKey = 'sync.replay.unknown_outcome',
      disposition = MutationFailureDisposition.unknownOutcome,
      outcomeKnowledge = MutationOutcomeKnowledge.unknown,
      retryAfter = null,
      rateLimitBucket = null,
      idempotencySafe = false,
      executionPhase = MutationExecutionPhase.notStarted,
      repairable = true,
      conflictKind = ConflictKind.unknown,
      observedPrecondition = null,
      latestServerSnapshot = null,
      projectionImpact = null;

  /// Normalized failure category.
  final MutationFailureCategory category;

  /// Safe stable message key for public presentation.
  final String messageKey;

  /// Scheduler action requested by the adapter.
  final MutationFailureDisposition disposition;

  /// Whether the side-effect outcome is known.
  final MutationOutcomeKnowledge outcomeKnowledge;

  /// Minimum delay requested by the adapter.
  final Duration? retryAfter;

  /// Stable fairness bucket, such as a host, resource, or tenant.
  final String? rateLimitBucket;

  /// Whether replay with the same idempotency key is safe after ambiguity.
  final bool idempotencySafe;

  /// Whether executor invocation began before this failure was observed.
  final MutationExecutionPhase executionPhase;

  /// Whether explicit repair is allowed.
  final bool repairable;

  /// Normalized conflict kind supplied by an adapter when applicable.
  final ConflictKind conflictKind;

  /// Version token observed by the adapter, when available.
  final ConflictPrecondition? observedPrecondition;

  /// Optional bounded server snapshot supplied by the adapter.
  final Object? latestServerSnapshot;

  /// Optional safe metadata describing affected projections.
  final Object? projectionImpact;
}

/// Exception adapter implementations can throw to provide normalized failure.
class MutationAdapterException implements Exception {
  /// Creates an exception carrying a normalized failure.
  const MutationAdapterException(this.failure);

  /// Normalized failure supplied by the adapter.
  final MutationAdapterFailure failure;

  @override
  String toString() => 'MutationAdapterException: ${failure.messageKey}';
}

/// Cooperative cancellation token owned by one replay attempt.
class ReplayCancellationToken {
  bool _isCancelled = false;

  /// Whether cancellation was requested.
  bool get isCancelled => _isCancelled;

  /// Requests cancellation. Calling repeatedly is safe.
  void cancel() => _isCancelled = true;

  /// Throws a typed cancellation error when cancellation was requested.
  void throwIfCancelled() {
    if (_isCancelled) throw const ReplayCancelledException();
  }
}

/// Safe cancellation failure for work that did not start or was interrupted.
class ReplayCancelledException implements Exception {
  /// Creates a cancellation exception.
  const ReplayCancelledException();

  @override
  String toString() => 'ReplayCancelledException';
}

/// Context passed to transport-independent execution adapters.
class MutationExecutionContext {
  /// Creates an execution context for one invocation.
  const MutationExecutionContext({
    required this.operationId,
    required this.idempotencyKey,
    required this.authPolicy,
    required this.authScope,
    this.conflictPolicy = ConflictPolicy.none,
    this.conflictPrecondition,
    required this.attempt,
    required this.cancellationToken,
  });

  /// Operation occurrence being executed.
  final OperationId operationId;

  /// Stable key that must be reused by automatic retries.
  final IdempotencyKey idempotencyKey;

  /// Authentication policy captured at enqueue time.
  final AuthPolicy authPolicy;

  /// Exact non-secret scope for authenticated work.
  final AuthScope? authScope;

  /// Conflict policy captured at enqueue time.
  final ConflictPolicy conflictPolicy;

  /// Opaque compare-and-set token captured at enqueue time.
  final ConflictPrecondition? conflictPrecondition;

  /// One-based invocation count for this operation.
  final int attempt;

  /// Cooperative cancellation token for this invocation.
  final ReplayCancellationToken cancellationToken;
}

/// Result returned by an execution adapter.
sealed class MutationExecutionResult {
  const MutationExecutionResult();
}

/// Successful adapter result.
final class MutationExecutionSuccess extends MutationExecutionResult {
  /// Creates a successful result.
  const MutationExecutionSuccess(this.value);

  /// JSON-safe operation result.
  final Object? value;
}

/// Failed adapter result.
final class MutationExecutionFailure extends MutationExecutionResult {
  /// Creates a failed result.
  const MutationExecutionFailure(this.failure);

  /// Normalized failure metadata.
  final MutationAdapterFailure failure;
}

/// Boundary for transport, auth, and arbitrary async execution policies.
abstract interface class MutationExecutionAdapter {
  /// Executes [executor] with context and returns a normalized result.
  Future<MutationExecutionResult> execute(
    MutationExecutionContext context,
    Future<Object?> Function() executor,
  );
}

/// Classifies arbitrary adapter exceptions without inspecting transport fields.
abstract interface class MutationFailureClassifier {
  /// Converts an exception into safe normalized metadata.
  MutationAdapterFailure classify(Object error);
}

/// Default adapter that fails closed for unclassified exceptions.
class DirectMutationExecutionAdapter implements MutationExecutionAdapter {
  /// Creates a direct adapter with an injectable classifier.
  const DirectMutationExecutionAdapter({
    this.classifier = const DefaultMutationFailureClassifier(),
  });

  /// Failure classifier used at the execution boundary.
  final MutationFailureClassifier classifier;

  @override
  Future<MutationExecutionResult> execute(
    MutationExecutionContext context,
    Future<Object?> Function() executor,
  ) async {
    var executionPhase = MutationExecutionPhase.notStarted;
    try {
      context.cancellationToken.throwIfCancelled();
      executionPhase = MutationExecutionPhase.started;
      final value = await executor();
      context.cancellationToken.throwIfCancelled();
      return MutationExecutionSuccess(value);
    } on Object catch (error) {
      final failure = classifier.classify(error);
      if (executionPhase == MutationExecutionPhase.started &&
          failure.category == MutationFailureCategory.cancellation &&
          !failure.idempotencySafe) {
        return MutationExecutionFailure(
          MutationAdapterFailure(
            category: failure.category,
            messageKey: 'sync.replay.unknown_outcome',
            disposition: MutationFailureDisposition.unknownOutcome,
            outcomeKnowledge: MutationOutcomeKnowledge.unknown,
            retryAfter: failure.retryAfter,
            rateLimitBucket: failure.rateLimitBucket,
            executionPhase: MutationExecutionPhase.started,
            repairable: failure.repairable,
            conflictKind: failure.conflictKind,
            observedPrecondition: failure.observedPrecondition,
            latestServerSnapshot: failure.latestServerSnapshot,
            projectionImpact: failure.projectionImpact,
          ),
        );
      }
      return MutationExecutionFailure(failure);
    }
  }
}

/// Conservative default exception classifier.
class DefaultMutationFailureClassifier implements MutationFailureClassifier {
  /// Creates the default classifier.
  const DefaultMutationFailureClassifier();

  @override
  MutationAdapterFailure classify(Object error) {
    if (error is MutationAdapterException) return error.failure;
    if (error is ReplayCancelledException) {
      return const MutationAdapterFailure(
        category: MutationFailureCategory.cancellation,
        messageKey: 'sync.replay.cancelled',
        disposition: MutationFailureDisposition.pause,
      );
    }
    if (error is InvalidMutationPayloadException) {
      return const MutationAdapterFailure(
        category: MutationFailureCategory.payload,
        messageKey: 'sync.replay.failure.payload',
        disposition: MutationFailureDisposition.terminal,
      );
    }
    if (error is UnknownMutationKeyException) {
      return const MutationAdapterFailure(
        category: MutationFailureCategory.executor,
        messageKey: 'sync.replay.failure.executor',
        disposition: MutationFailureDisposition.terminal,
      );
    }
    return const MutationAdapterFailure.unknown();
  }
}
