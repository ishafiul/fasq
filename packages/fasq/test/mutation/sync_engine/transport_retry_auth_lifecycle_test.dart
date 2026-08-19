import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Mutation execution contracts', () {
    test('fails closed for unclassified adapter errors', () {
      const classifier = DefaultMutationFailureClassifier();

      final failure = classifier.classify(StateError('private details'));

      expect(failure.category, MutationFailureCategory.unknown);
      expect(failure.disposition, MutationFailureDisposition.unknownOutcome);
      expect(failure.outcomeKnowledge, MutationOutcomeKnowledge.unknown);
      expect(failure.messageKey, 'sync.replay.unknown_outcome');
    });

    test('keeps explicit adapter classification transport neutral', () async {
      const adapter = DirectMutationExecutionAdapter(
        classifier: _FixedFailureClassifier(
          MutationAdapterFailure(
            category: MutationFailureCategory.connectivity,
            messageKey: 'sync.network.unavailable',
            disposition: MutationFailureDisposition.retry,
            retryAfter: Duration(seconds: 10),
            idempotencySafe: true,
          ),
        ),
      );
      final context = MutationExecutionContext(
        operationId: OperationId('operation'),
        idempotencyKey: IdempotencyKey('idempotency'),
        authPolicy: AuthPolicy.none,
        authScope: null,
        attempt: 1,
        cancellationToken: ReplayCancellationToken(),
      );

      final result = await adapter.execute(
        context,
        () async => throw StateError('not persisted'),
      );

      expect(result, isA<MutationExecutionFailure>());
      expect(
        (result as MutationExecutionFailure).failure.category,
        MutationFailureCategory.connectivity,
      );
    });

    test('requires exact auth scope before authenticated execution', () {
      const gate = AuthScopeGate();
      final expected = AuthScope(
        principalId: 'user-1',
        tenantId: 'tenant-1',
        authRealm: 'primary',
      );
      final operation = _operation(expected);

      expect(
        gate.evaluate(operation, AuthSessionSnapshot.ready(expected)),
        AuthExecutionDecision.allowed,
      );
      expect(
        gate.evaluate(
          operation,
          AuthSessionSnapshot.ready(
            AuthScope(
              principalId: 'user-2',
              tenantId: 'tenant-1',
              authRealm: 'primary',
            ),
          ),
        ),
        AuthExecutionDecision.quarantined,
      );
      expect(
        gate.evaluate(
          operation,
          const AuthSessionSnapshot(
            status: AuthSessionStatus.reauthenticationRequired,
          ),
        ),
        AuthExecutionDecision.blocked,
      );
    });
  });

  group('Retry policy', () {
    test('uses full jitter and preserves valid minimum wait hint', () {
      final operation = _operation(
        null,
        createdAt: DateTime.utc(2026),
        attemptCount: 1,
      );
      final now = DateTime.utc(2026, 1, 1, 0, 0, 1);
      const policy = RetryPolicy(baseDelay: Duration(seconds: 10));

      final plan = policy.plan(
        operation: operation,
        failure: const MutationAdapterFailure(
          category: MutationFailureCategory.rateLimit,
          messageKey: 'sync.rate_limit',
          disposition: MutationFailureDisposition.retry,
          retryAfter: Duration(seconds: 30),
          rateLimitBucket: 'api.example.com',
          idempotencySafe: true,
        ),
        now: now,
        randomUnit: () => 0,
      );

      expect(plan.action, RetryPlanAction.retry);
      expect(plan.nextRunAt, now.add(const Duration(seconds: 30)));
    });

    test('does not retry after max attempts or unknown outcome', () {
      final exhausted = _operation(null, attemptCount: 5);
      const failure = MutationAdapterFailure(
        category: MutationFailureCategory.connectivity,
        messageKey: 'sync.network.unavailable',
        disposition: MutationFailureDisposition.retry,
        idempotencySafe: true,
      );
      const policy = RetryPolicy();

      expect(
        policy
            .plan(
              operation: exhausted,
              failure: failure,
              now: DateTime.utc(2026),
              randomUnit: () => 0,
            )
            .messageKey,
        'sync.replay.max_attempts',
      );
      expect(
        policy
            .plan(
              operation: _operation(null),
              failure: const MutationAdapterFailure(
                category: MutationFailureCategory.timeout,
                messageKey: 'sync.timeout',
                disposition: MutationFailureDisposition.retry,
                outcomeKnowledge: MutationOutcomeKnowledge.unknown,
              ),
              now: DateTime.utc(2026),
              randomUnit: () => 0,
            )
            .action,
        RetryPlanAction.unknownOutcome,
      );
    });

    test('persists retry metadata in operation contract', () {
      final operation = _operation(
        null,
        attemptCount: 2,
        maxAttempts: 7,
        nextRunAt: DateTime.utc(2026, 1, 1, 1),
        rateLimitBucket: 'tenant-1',
        lastAttemptAt: DateTime.utc(2026),
      );

      final restored = MutationOperation.fromJson(operation.toJson());

      expect(restored.attemptCount, 2);
      expect(restored.maxAttempts, 7);
      expect(restored.nextRunAt, operation.nextRunAt);
      expect(restored.rateLimitBucket, 'tenant-1');
      expect(restored.lastAttemptAt, operation.lastAttemptAt);
    });
  });

  group('Lifecycle bridge', () {
    test('coalesces concurrent lifecycle requests into one replay', () async {
      final readiness = ReplayReadinessBarrier(
        initial: const ReplayReadiness(
          storeReady: true,
          registrationsReady: true,
          encryptionReady: true,
          connectivityReady: true,
          authReady: true,
        ),
      );
      final replayStarted = Completer<void>();
      final replayRelease = Completer<ReplayRunResult>();
      var replayCalls = 0;
      final controller = ReplayLifecycleController(
        readiness: readiness,
        replay: () async {
          replayCalls++;
          replayStarted.complete();
          return replayRelease.future;
        },
      );

      final first = controller.onStartup();
      await replayStarted.future;
      final second = controller.onForeground();
      expect(identical(first, second), isTrue);
      replayRelease.complete(_emptyReplayResult());
      await Future.wait([first, second]);
      expect(replayCalls, 1);
      await controller.dispose();
      await readiness.dispose();
    });

    test('background adapter cannot bypass readiness', () async {
      final readiness = ReplayReadinessBarrier();
      final adapter = _RecordingBackgroundAdapter();
      final controller = ReplayLifecycleController(
        readiness: readiness,
        replay: _emptyReplay,
        backgroundAdapter: adapter,
      );

      await controller.request(ReplayLifecycleTrigger.background);
      expect(adapter.requests, 0);
      readiness.update(
        storeReady: true,
        registrationsReady: true,
        encryptionReady: true,
        connectivityReady: true,
        authReady: true,
      );
      await controller.request(ReplayLifecycleTrigger.background);
      expect(adapter.requests, 1);
      await controller.dispose();
      await readiness.dispose();
    });
  });

  group('Replay coordinator integration', () {
    test(
      'persists safe retry state without blocking unrelated replay',
      () async {
        final store = _MemoryOutbox();
        final key = MutationKey(namespace: 'test', name: 'retry');
        final registrations = MutationRegistrationRegistry()
          ..register<Map<String, Object?>, Map<String, Object?>>(
            key: key,
            codec: _mapCodec,
            mutationFn: (_) async {
              throw const MutationAdapterException(
                MutationAdapterFailure(
                  category: MutationFailureCategory.connectivity,
                  messageKey: 'sync.network.unavailable',
                  disposition: MutationFailureDisposition.retry,
                  retryAfter: Duration(seconds: 10),
                  idempotencySafe: true,
                ),
              );
            },
          );
        await store.transact(
          (current) => current.copyWith(
            active: [
              _operation(null, mutationKey: key),
            ],
          ),
        );
        final coordinator = DurableReplayCoordinator(
          store: store,
          registrations: registrations,
          now: () => DateTime.utc(2026, 1, 1, 0, 0, 1),
          retryPolicy: const RetryPolicy(
            baseDelay: Duration(seconds: 10),
            randomUnit: _zeroRandom,
          ),
        );

        await coordinator.open();
        final report = await coordinator.replay();

        expect(report.scheduledRetryOperationIds, [OperationId('operation')]);
        expect(
          store.snapshot.active.single.state,
          MutationOperationState.retryScheduled,
        );
        expect(store.snapshot.active.single.attemptCount, 1);
        expect(
          store.snapshot.active.single.nextRunAt,
          DateTime.utc(2026, 1, 1, 0, 0, 11),
        );
        await coordinator.close();
      },
    );

    test('blocks authenticated work until exact scope becomes ready', () async {
      final scope = AuthScope(
        principalId: 'user-1',
        tenantId: 'tenant-1',
        authRealm: 'primary',
      );
      final store = _MemoryOutbox();
      final key = MutationKey(namespace: 'test', name: 'authenticated');
      var invocations = 0;
      final registrations = MutationRegistrationRegistry()
        ..register<Map<String, Object?>, Map<String, Object?>>(
          key: key,
          codec: _mapCodec,
          authPolicy: AuthPolicy.required,
          mutationFn: (_) async {
            invocations++;
            return <String, Object?>{'ok': true};
          },
        );
      await store.transact(
        (current) => current.copyWith(
          active: [_operation(scope, mutationKey: key)],
        ),
      );
      final auth = InMemoryAuthSessionProvider(
        initial: const AuthSessionSnapshot(
          status: AuthSessionStatus.reauthenticationRequired,
        ),
      );
      final coordinator = DurableReplayCoordinator(
        store: store,
        registrations: registrations,
        authSessionProvider: auth,
      );

      await coordinator.open();
      await coordinator.replay();
      expect(invocations, 0);
      expect(
        store.snapshot.active.single.state,
        MutationOperationState.authBlocked,
      );

      auth.update(AuthSessionSnapshot.ready(scope));
      await coordinator.replay();
      expect(invocations, 1);
      expect(store.snapshot.active, isEmpty);
      await coordinator.close();
      await auth.dispose();
    });
  });
}

MutationOperation _operation(
  AuthScope? scope, {
  DateTime? createdAt,
  int attemptCount = 0,
  int maxAttempts = 5,
  DateTime? nextRunAt,
  String? rateLimitBucket,
  DateTime? lastAttemptAt,
  MutationKey? mutationKey,
}) {
  return MutationOperation(
    operationId: OperationId('operation'),
    mutationKey:
        mutationKey ?? MutationKey(namespace: 'test', name: 'operation'),
    variables: const <String, Object?>{},
    createdAt: createdAt ?? DateTime.utc(2026),
    idempotencyKey: IdempotencyKey('idempotency'),
    lineageId: LineageId('lineage'),
    authPolicy: scope == null ? AuthPolicy.none : AuthPolicy.required,
    authScope: scope,
    state: MutationOperationState.pending,
    attemptCount: attemptCount,
    maxAttempts: maxAttempts,
    nextRunAt: nextRunAt,
    rateLimitBucket: rateLimitBucket,
    lastAttemptAt: lastAttemptAt,
  );
}

const _mapCodec = JsonMutationCodec<Map<String, Object?>>(
  encoder: _encodeMap,
  decoder: _decodeMap,
);

Map<String, Object?> _encodeMap(Map<String, Object?> value) => value;

Map<String, Object?> _decodeMap(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const InvalidMutationPayloadException('Expected map');
  }
  return <String, Object?>{
    for (final entry in value.entries)
      if (entry.key is String) entry.key! as String: entry.value,
  };
}

class _FixedFailureClassifier implements MutationFailureClassifier {
  const _FixedFailureClassifier(this.failure);

  final MutationAdapterFailure failure;

  @override
  MutationAdapterFailure classify(Object error) => failure;
}

class _RecordingBackgroundAdapter implements BackgroundReplayAdapter {
  int requests = 0;

  @override
  Future<void> requestWakeUp(BackgroundReplayRequest request) async {
    requests++;
  }
}

Future<ReplayRunResult> _emptyReplay() async => _emptyReplayResult();

ReplayRunResult _emptyReplayResult() {
  return ReplayRunResult(
    executedOperationIds: const [],
    failedOperationIds: const [],
    recoveredUnknownOutcomeIds: const [],
    blockedOperations: const [],
  );
}

class _MemoryOutbox implements DurableOutboxStore {
  OutboxSnapshot _snapshot = OutboxSnapshot();
  int _generation = 0;

  @override
  Future<OutboxSnapshot> open() async => _snapshot;

  @override
  OutboxSnapshot get snapshot => _snapshot;

  @override
  int get generation => _generation;

  @override
  Future<OutboxSnapshot> transact(
    DurableOutboxTransaction transaction, {
    int? expectedGeneration,
  }) async {
    if (expectedGeneration != null && expectedGeneration != _generation) {
      throw StateError('stale generation');
    }
    _snapshot = transaction(_snapshot);
    _generation++;
    return _snapshot;
  }

  @override
  Future<void> close() async {}
}

double _zeroRandom() => 0;
