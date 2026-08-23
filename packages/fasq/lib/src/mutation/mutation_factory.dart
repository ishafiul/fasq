import 'package:fasq/src/client/query_client.dart';
import 'package:fasq/src/mutation/durable_mutation_catalog.dart';
import 'package:fasq/src/mutation/durable_mutation_queue.dart';
import 'package:fasq/src/mutation/mutation.dart';
import 'package:fasq/src/mutation/mutation_contract.dart';
import 'package:fasq/src/mutation/mutation_options.dart';

/// Creates mutations from either ordinary functions or bootstrapped durable
/// mutation keys.
final class MutationFactory {
  const MutationFactory._();

  /// Creates a mutation from a registered durable [key].
  static Mutation<TData, TVariables> fromKey<TData, TVariables>({
    required FasqMutationKey<TData, TVariables> key,
    required DurableMutationCatalog catalog,
    required DurableMutationQueue queue,
    QueryClient? client,
    MutationOptions<TData, TVariables>? options,
  }) {
    final definition = catalog.resolve(key);
    final effectiveOptions = definition.bind(queue, base: options);
    return Mutation<TData, TVariables>(
      mutationFn: definition.execute,
      options: effectiveOptions,
      client: client,
    );
  }

  /// Creates an ordinary non-durable mutation.
  static Mutation<TData, TVariables> fromFunction<TData, TVariables>({
    required Future<TData> Function(TVariables variables) mutationFn,
    QueryClient? client,
    MutationOptions<TData, TVariables>? options,
  }) {
    return Mutation<TData, TVariables>(
      mutationFn: mutationFn,
      options: options,
      client: client,
    );
  }
}
