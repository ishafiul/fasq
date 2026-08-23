import 'package:fasq/src/client/query_client.dart';
import 'package:fasq/src/mutation/durable_mutation_catalog.dart';
import 'package:fasq/src/mutation/durable_mutation_queue.dart';

/// Runtime resources exposed by the core Fasq provider.
///
/// Implementations decide how query persistence, durable mutation storage,
/// authentication, encryption, and replay are configured. The application
/// remains responsible for initializing and closing the runtime.
abstract interface class FasqRuntime {
  /// Query client used by the runtime.
  QueryClient get queryClient;

  /// Durable mutation queue, when offline mutation support is enabled.
  DurableMutationQueue? get mutationQueue;

  /// Typed durable mutation definitions registered during bootstrap.
  DurableMutationCatalog get mutations;

  /// Closes resources owned by this runtime.
  Future<void> close();
}
