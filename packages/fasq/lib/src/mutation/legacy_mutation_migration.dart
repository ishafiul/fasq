import 'package:fasq/src/mutation/durable_mutation_queue.dart';
import 'package:fasq/src/mutation/offline_queue.dart';
import 'package:fasq/src/mutation/sync_engine/codecs/mutation_codec.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';

/// Runtime registration used to translate one legacy mutation type.
abstract interface class LegacyMutationRegistration {
  /// Legacy type stored in [OfflineMutationNode.mutationType].
  String get mutationType;

  /// Stable key used by the durable mutation registry.
  MutationKey get key;

  /// Registers the existing immediate executor with [queue].
  void register(DurableMutationQueue queue);

  /// Validates a legacy node without writing to the durable queue.
  void validate(OfflineMutationNode node);

  /// Translates and enqueues [node] into [queue].
  Future<DurableEnqueueAcknowledgement> enqueue(
    DurableMutationQueue queue,
    OfflineMutationNode node,
  );
}

/// Typed legacy registration backed by the same executor used online.
class TypedLegacyMutationRegistration<TData, TVariables>
    implements LegacyMutationRegistration {
  /// Creates a typed legacy-to-durable registration.
  const TypedLegacyMutationRegistration({
    required this.mutationType,
    required this.key,
    required this.codec,
    required this.mutationFn,
    this.authPolicy = AuthPolicy.none,
    this.authScope,
    this.authScopeResolver,
    this.maxAge = const Duration(days: 3650),
    this.resultEncoder,
  });

  @override
  final String mutationType;

  @override
  final MutationKey key;

  /// Codec for the legacy node variables.
  final MutationCodec<TVariables> codec;

  /// Existing online mutation executor.
  final Future<TData> Function(TVariables variables) mutationFn;

  /// Authentication policy applied to imported operations.
  final AuthPolicy authPolicy;

  /// Non-secret identity used when imported work requires auth.
  final AuthScope? authScope;

  /// Resolves auth scope for each imported legacy node.
  final AuthScope? Function(OfflineMutationNode node)? authScopeResolver;

  /// Maximum age retained for imported work; override for app-specific policy.
  final Duration maxAge;

  /// Optional JSON-safe result encoder for replay history.
  final Object? Function(TData data)? resultEncoder;

  @override
  void register(DurableMutationQueue queue) {
    queue.register<TData, TVariables>(
      key: key,
      codec: codec,
      mutationFn: mutationFn,
      authPolicy: authPolicy,
      resultEncoder: resultEncoder,
    );
  }

  @override
  void validate(OfflineMutationNode node) {
    try {
      codec.decode(node.variables);
      _resolveAuthScope(node);
      if (maxAge <= Duration.zero) {
        throw const InvalidMutationPayloadException(
          'Legacy mutation retention policy is invalid',
        );
      }
      OperationId(node.id);
      IdempotencyKey(node.idempotencyKey);
      LineageId('legacy:${node.id}');
      for (final parentId in node.dependsOnIds) {
        OperationId(parentId);
      }
    } on LegacyMutationMigrationException {
      rethrow;
    } on Object catch (_, stackTrace) {
      Error.throwWithStackTrace(
        LegacyMutationMigrationException(
          node.id,
          'Legacy mutation payload or identity is invalid',
        ),
        stackTrace,
      );
    }
  }

  @override
  Future<DurableEnqueueAcknowledgement> enqueue(
    DurableMutationQueue queue,
    OfflineMutationNode node,
  ) async {
    validate(node);
    final variables = codec.decode(node.variables);
    final state = switch (node.status) {
      OfflineMutationStatus.pending => MutationOperationState.pending,
      OfflineMutationStatus.retryScheduled =>
        MutationOperationState.retryScheduled,
      _ => throw LegacyMutationMigrationException(
        node.id,
        'Only pending or retryScheduled nodes can be migrated safely',
      ),
    };
    final resolvedAuthScope = _resolveAuthScope(node);

    return queue.enqueue<TVariables>(
      key: key,
      variables: variables,
      operationId: OperationId(node.id),
      idempotencyKey: IdempotencyKey(node.idempotencyKey),
      lineageId: LineageId('legacy:${node.id}'),
      authScope: resolvedAuthScope,
      createdAt: node.createdAt,
      priority: node.priority,
      dependencies: node.dependsOnIds
          .map(
            (id) => MutationDependency(parentOperationId: OperationId(id)),
          )
          .toList(growable: false),
      state: state,
      attemptCount: node.attempts,
      maxAttempts: node.maxRetries,
      maxAge: maxAge,
      nextRunAt: node.nextRunAt,
    );
  }

  AuthScope? _resolveAuthScope(OfflineMutationNode node) {
    final resolved = authScopeResolver?.call(node) ?? authScope;
    if ((authPolicy == AuthPolicy.required) != (resolved != null)) {
      throw LegacyMutationMigrationException(
        node.id,
        'Required auth scope is not available for legacy work',
      );
    }
    return resolved;
  }
}

/// Imports active legacy queue nodes into a durable queue.
class LegacyMutationQueueMigrator {
  /// Creates a migrator from legacy mutation types to stable registrations.
  const LegacyMutationQueueMigrator({required this.registrations});

  /// Registration keyed by [OfflineMutationNode.mutationType].
  final Map<String, LegacyMutationRegistration> registrations;

  /// Migrates active legacy nodes after durable enqueue acknowledgement.
  ///
  /// Source nodes are removed only after their durable operation commits. The
  /// destination remains open for the caller to replay or continue enqueueing.
  Future<LegacyMutationMigrationReport> migrate({
    required OfflineQueueManager source,
    required DurableMutationQueue destination,
    bool removeSourceAfterCommit = true,
  }) async {
    await source.load();
    final nodes = List<OfflineMutationNode>.from(source.entries);
    final missing = nodes
        .where((node) => !registrations.containsKey(node.mutationType))
        .map((node) => node.mutationType)
        .toSet();
    if (missing.isNotEmpty) {
      throw LegacyMutationMigrationException(
        missing.first,
        'No stable migration registration exists for legacy mutation type',
      );
    }

    await destination.open();
    final sourceIds = nodes.map((node) => node.id).toSet();
    if (sourceIds.length != nodes.length) {
      throw LegacyMutationMigrationException(
        'unknown',
        'Legacy queue contains duplicate operation identities',
      );
    }
    for (final node in nodes) {
      if (node.status != OfflineMutationStatus.pending &&
          node.status != OfflineMutationStatus.retryScheduled) {
        throw LegacyMutationMigrationException(
          node.id,
          'Legacy status ${node.status.name} has ambiguous execution outcome',
        );
      }
      for (final parentId in node.dependsOnIds) {
        final parentOperationId = _parseOperationId(node.id, parentId);
        if (!sourceIds.contains(parentId) &&
            !destination.hasRetainedOperation(parentOperationId)) {
          throw LegacyMutationMigrationException(
            node.id,
            'Dependency $parentId is not present in legacy or durable storage',
          );
        }
      }
    }

    for (final node in nodes) {
      final operationId = _parseOperationId(node.id, node.id);
      final idempotencyKey = _parseIdempotencyKey(node.id, node.idempotencyKey);
      if (destination.hasRetainedOperation(operationId)) continue;
      if (destination.hasRetainedIdempotencyKey(idempotencyKey)) {
        throw LegacyMutationMigrationException(
          node.id,
          'Legacy idempotency identity is already retained durably',
        );
      }
      registrations[node.mutationType]!.validate(node);
    }

    for (final node in nodes) {
      final registration = registrations[node.mutationType]!;
      if (!destination.hasRegistration(registration.key)) {
        registration.register(destination);
      }
    }

    final migrated = <OperationId>[];
    final alreadyPresent = <OperationId>[];
    for (final node in nodes) {
      final registration = registrations[node.mutationType]!;
      final operationId = _parseOperationId(node.id, node.id);
      if (destination.hasRetainedOperation(operationId)) {
        alreadyPresent.add(operationId);
        if (removeSourceAfterCommit) await source.remove(node.id);
        continue;
      }
      try {
        final acknowledgement = await registration.enqueue(destination, node);
        migrated.add(acknowledgement.operationId);
      } on LegacyMutationMigrationException {
        rethrow;
      } on Object catch (_, stackTrace) {
        Error.throwWithStackTrace(
          LegacyMutationMigrationException(
            node.id,
            'Legacy mutation could not be durably imported',
          ),
          stackTrace,
        );
      }
      if (removeSourceAfterCommit) await source.remove(node.id);
    }
    return LegacyMutationMigrationReport(
      migratedOperationIds: migrated,
      alreadyPresentOperationIds: alreadyPresent,
      untouchedDeadLetterCount: source.deadLetters.length,
    );
  }

  OperationId _parseOperationId(String nodeId, String value) {
    try {
      return OperationId(value);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        LegacyMutationMigrationException(
          nodeId,
          'Legacy operation identity is invalid',
        ),
        stackTrace,
      );
    }
  }

  IdempotencyKey _parseIdempotencyKey(String nodeId, String value) {
    try {
      return IdempotencyKey(value);
    } on Object catch (error, stackTrace) {
      Error.throwWithStackTrace(
        LegacyMutationMigrationException(
          nodeId,
          'Legacy idempotency identity is invalid',
        ),
        stackTrace,
      );
    }
  }
}

/// Result of one legacy queue migration request.
class LegacyMutationMigrationReport {
  /// Creates a migration report.
  LegacyMutationMigrationReport({
    required List<OperationId> migratedOperationIds,
    required this.untouchedDeadLetterCount,
    List<OperationId> alreadyPresentOperationIds = const <OperationId>[],
  }) : migratedOperationIds = List.unmodifiable(migratedOperationIds),
       alreadyPresentOperationIds = List.unmodifiable(
         alreadyPresentOperationIds,
       );

  /// Durable operation IDs committed by the migration.
  final List<OperationId> migratedOperationIds;

  /// IDs already retained after a prior durable commit.
  final List<OperationId> alreadyPresentOperationIds;

  /// Legacy dead letters intentionally left in their original manager.
  final int untouchedDeadLetterCount;

  /// Number of legacy nodes committed to the durable queue.
  int get migratedCount => migratedOperationIds.length;
}

/// Safe error identifying a legacy node that could not be migrated.
class LegacyMutationMigrationException extends MutationContractException {
  /// Creates a migration failure for [legacyNodeId].
  LegacyMutationMigrationException(String legacyNodeId, String reason)
    : super(
        'Legacy mutation node $legacyNodeId could not be migrated: $reason',
      );
}
