import 'package:fasq/src/mutation/mutation_contract.dart';
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
    required this.namespace,
    required this.name,
    this.version = 1,
    this.offline = true,
    this.authPolicy = AuthPolicy.none,
    this.encodeResult = false,
    this.factoryOnly = false,
    this.dependencies =
        const <
          FasqMutationDependencyDeclaration<Object?, Object?, Object?, Object?>
        >[],
  }) : assert(namespace != '', 'namespace must not be empty'),
       assert(name != '', 'name must not be empty'),
       assert(version > 0, 'version must be positive');

  /// Namespace used to avoid collisions between application features.
  final String namespace;

  /// Stable logical mutation name.
  final String name;

  /// Persisted variable schema version.
  final int version;

  /// Whether the generated contract participates in offline queueing.
  final bool offline;

  /// Authentication policy captured by queued operations.
  final AuthPolicy authPolicy;

  /// Whether generated replay history should encode the result with
  /// `data.toJson()`.
  final bool encodeResult;

  /// Whether generation should omit the default global handle.
  ///
  /// Use this when the annotated function is a contract declaration and an
  /// adapter will provide an instance-scoped executor through the generated
  /// `...DurableHandle` factory.
  final bool factoryOnly;

  /// Typed producer-result to current-input mappings.
  final List<
    FasqMutationDependencyDeclaration<Object?, Object?, Object?, Object?>
  >
  dependencies;
}
