import 'package:fasq/src/mutation/durable_mutation_queue.dart';
import 'package:fasq/src/mutation/sync_engine/mutation_contracts.dart';

/// Runtime registration contract for one durable mutation.
///
/// Implementations are registered before the durable outbox opens so replay
/// can resolve the same executor used by immediate mutations.
abstract interface class DurableMutationDefinitionBase {
  /// Registers this definition with [queue].
  void register(DurableMutationQueue queue);
}

/// Low-level durable mutation registration contract.
///
/// Use the higher-level `DurableMutation` handle for new application code.
/// This type remains public for advanced queue composition and compatibility
/// with earlier setup APIs.
class DurableMutationDefinition<TData, TVariables>
    implements DurableMutationDefinitionBase {
  /// Creates a low-level durable mutation definition.
  const DurableMutationDefinition({
    required this.key,
    required this.codec,
    required this.execute,
    this.authPolicy = AuthPolicy.none,
    this.resultEncoder,
  });

  /// Stable logical mutation identity.
  final MutationKey key;

  /// JSON-safe variables codec.
  final MutationCodec<TVariables> codec;

  /// Immediate and replay executor.
  final Future<TData> Function(TVariables variables) execute;

  /// Auth requirement for queued work.
  final AuthPolicy authPolicy;

  /// Optional JSON-safe result projection for dependent operations.
  final Object? Function(TData data)? resultEncoder;

  @override
  void register(DurableMutationQueue queue) {
    queue.register<TData, TVariables>(
      key: key,
      codec: codec,
      mutationFn: execute,
      authPolicy: authPolicy,
      resultEncoder: resultEncoder,
    );
  }
}
