import 'package:fasq/src/mutation/durable_mutation_definition.dart';
import 'package:fasq/src/mutation/mutation_contract.dart';
import 'package:fasq/src/mutation/sync_engine/mutation_contracts.dart';

/// One durable mutation handle shared by immediate execution and replay.
///
/// Use [DurableMutation.define] when code generation is not a fit. The handle
/// owns the mutation identity and codec, so widgets do not need to know about
/// queue registration or outbox configuration.
class DurableMutation<TData, TVariables>
    extends DurableMutationDefinition<TData, TVariables> {
  /// Defines a durable mutation using a readable dot-separated key.
  factory DurableMutation.define({
    required FasqMutationKey<TData, TVariables> key,
    required MutationCodec<TVariables> codec,
    required Future<TData> Function(TVariables variables) execute,
    AuthPolicy authPolicy = AuthPolicy.none,
    Object? Function(TData data)? resultEncoder,
    List<FasqMutationDependency<Object?, Object?, Object?, Object?>>
        dependencies =
        const <FasqMutationDependency<Object?, Object?, Object?, Object?>>[],
  }) {
    return DurableMutation._(
      contractKey: key,
      codec: codec,
      execute: execute,
      authPolicy: authPolicy,
      resultEncoder: resultEncoder,
      dependencies: dependencies,
    );
  }

  const DurableMutation._({
    required super.contractKey,
    required super.codec,
    required super.execute,
    super.authPolicy,
    super.resultEncoder,
    super.dependencies,
  });
}
