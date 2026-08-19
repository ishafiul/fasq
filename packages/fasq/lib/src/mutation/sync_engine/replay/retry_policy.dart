import 'dart:math';

import 'package:fasq/src/mutation/sync_engine/execution/execution_context.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';

/// Final action selected by [RetryPolicy].
enum RetryPlanAction {
  /// Keep active work and persist its next eligible time.
  retry,

  /// Keep active work paused until an external readiness event.
  pause,

  /// Move work to terminal dead-letter storage.
  terminal,

  /// Move ambiguous work to repairable unknown-outcome storage.
  unknownOutcome,
}

/// Deterministic retry decision for one failed invocation.
class RetryPlan {
  /// Creates a retry plan.
  const RetryPlan({
    required this.action,
    required this.messageKey,
    this.nextRunAt,
  });

  /// Selected scheduler action.
  final RetryPlanAction action;

  /// Safe reason for the selected action.
  final String messageKey;

  /// Absolute next eligible time for [RetryPlanAction.retry].
  final DateTime? nextRunAt;
}

/// Exponential full-jitter retry policy with durable age and attempt limits.
class RetryPolicy {
  /// Creates a retry policy.
  const RetryPolicy({
    this.baseDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(minutes: 5),
    this.randomUnit = _randomUnit,
  });

  /// Initial exponential delay before jitter.
  final Duration baseDelay;

  /// Maximum exponential delay before adapter minimum-wait hints.
  final Duration maxDelay;

  /// Injected source of a unit interval for deterministic scheduling tests.
  final double Function() randomUnit;

  /// Plans the next state after [failure].
  RetryPlan plan({
    required MutationOperation operation,
    required MutationAdapterFailure failure,
    required DateTime now,
    double Function()? randomUnit,
  }) {
    if (failure.disposition == MutationFailureDisposition.unknownOutcome ||
        (failure.outcomeKnowledge == MutationOutcomeKnowledge.unknown &&
            !failure.idempotencySafe)) {
      return const RetryPlan(
        action: RetryPlanAction.unknownOutcome,
        messageKey: 'sync.replay.unknown_outcome',
      );
    }
    switch (failure.disposition) {
      case MutationFailureDisposition.pause:
        return RetryPlan(
          action: RetryPlanAction.pause,
          messageKey: failure.messageKey,
        );
      case MutationFailureDisposition.terminal:
        return RetryPlan(
          action: RetryPlanAction.terminal,
          messageKey: failure.messageKey,
        );
      case MutationFailureDisposition.unknownOutcome:
        return const RetryPlan(
          action: RetryPlanAction.unknownOutcome,
          messageKey: 'sync.replay.unknown_outcome',
        );
      case MutationFailureDisposition.retry:
        break;
    }

    if (operation.attemptCount >= operation.maxAttempts) {
      return const RetryPlan(
        action: RetryPlanAction.terminal,
        messageKey: 'sync.replay.max_attempts',
      );
    }
    final expiry = operation.createdAt.add(operation.maxAge);
    if (!now.isBefore(expiry)) {
      return const RetryPlan(
        action: RetryPlanAction.terminal,
        messageKey: 'sync.replay.max_age',
      );
    }

    final exponent = min(operation.attemptCount - 1, 30);
    final exponentialMicros = baseDelay.inMicroseconds * pow(2, exponent);
    final cappedMicros = min(
      exponentialMicros.round(),
      maxDelay.inMicroseconds,
    );
    final unit = (randomUnit ?? this.randomUnit)().clamp(0.0, 1.0);
    final jitter = Duration(microseconds: (cappedMicros * unit).round());
    final hint = failure.retryAfter;
    final minimumWait = hint == null || hint < jitter ? jitter : hint;
    final nextRunAt = now.add(minimumWait);
    return RetryPlan(
      action: RetryPlanAction.retry,
      messageKey: failure.messageKey,
      nextRunAt: nextRunAt.isAfter(expiry) ? expiry : nextRunAt,
    );
  }
}

double _randomUnit() => Random().nextDouble();
