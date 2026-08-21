import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:meta/meta_meta.dart';

/// Annotation to mark a class for automatic serializer registration.
///
/// When applied to a class containing TypedQueryKey declarations,
/// the build_runner generator will automatically scan for all types
/// used in TypedQueryKey and generate serializer registration code.
///
/// Example:
/// ```dart
/// @AutoRegisterSerializers()
/// class QueryKeys {
///   static TypedQueryKey<List<Product>> get products =>
///       const TypedQueryKey<List<Product>>('products', List<Product>);
/// }
/// ```
class AutoRegisterSerializers {
  /// Creates an [AutoRegisterSerializers] annotation instance.
  const AutoRegisterSerializers();
}

/// Marks a one-argument function as a durable mutation contract.
///
/// The function remains the single source of truth for both immediate and
/// replay execution. The build-runner generator only supplies the stable
/// identity and JSON codec needed by the durable queue.
@Target({TargetKind.function})
class FasqMutation {
  /// Creates a durable mutation annotation.
  const FasqMutation({
    required this.key,
    this.version = 1,
    this.offline = true,
    this.authPolicy = AuthPolicy.none,
    this.encodeResult = false,
  });

  /// Dot-separated logical identity, for example `cart.add-item`.
  final String key;

  /// Schema version for persisted variables.
  final int version;

  /// Whether the generated contract participates in offline queueing.
  final bool offline;

  /// Authentication policy captured by queued operations.
  final AuthPolicy authPolicy;

  /// Whether generated replay history should encode the result with
  /// `data.toJson()`.
  final bool encodeResult;
}
