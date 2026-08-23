import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:meta/meta.dart';

/// Compile-time typed identity for one durable mutation contract.
///
/// Runtime persistence uses [MutationKey]. This type adds result and variable
/// types so annotation references cannot silently point at an unrelated
/// mutation contract.
@immutable
final class FasqMutationKey<TData, TVariables> {
  /// Creates a typed mutation key.
  const FasqMutationKey({
    required this.namespace,
    required this.name,
    this.version = 1,
  }) : assert(namespace != '', 'namespace must not be empty'),
       assert(name != '', 'name must not be empty'),
       assert(version > 0, 'version must be positive');

  /// Namespace used to avoid collisions between application features.
  final String namespace;

  /// Stable logical mutation name.
  final String name;

  /// Persisted variable schema version.
  final int version;

  /// Type-erased key used by durable storage and replay registries.
  MutationKey get runtimeKey => MutationKey(
    namespace: namespace,
    name: name,
    version: version,
  );

  /// Canonical string used for diagnostics.
  String get value => '$namespace:$name:v$version';
}

/// A typed reference to another annotated mutation function.
///
/// The generator reads the referenced function's durable-mutation annotation,
/// so the producer's identity has one source of truth. The generic
/// arguments keep the dependency tied to the producer's result and input
/// types at the annotation boundary.
@immutable
final class FasqMutationSource<TData, TVariables> {
  /// References an annotated top-level mutation function.
  const FasqMutationSource(this.function);

  /// The annotated producer function.
  final Future<TData> Function(TVariables) function;
}

/// A typed field used by a durable mutation dependency.
///
/// [path] addresses the JSON produced by the owner's `toJson` method. Code
/// generation verifies that the owner has a field with the same name and
/// [TValue] type, so renames and incompatible mappings fail at build time.
@immutable
final class FasqMutationField<TOwner, TValue> {
  /// Creates a typed field descriptor.
  const FasqMutationField(this.path)
    : assert(path != '', 'path must not be empty');

  /// JSON path selecting the field value.
  final String path;
}

/// Declares a producer mutation result to current mutation input mapping in a
/// durable-mutation annotation.
///
/// This declaration references the producer function directly. The generator
/// reads that function's annotation and emits the runtime
/// [FasqMutationDependency] with the producer's generated key.
@immutable
final class FasqMutationDependencyDeclaration<
  TParentData,
  TParentVariables,
  TVariables,
  TValue
> {
  /// Creates a typed annotation dependency declaration.
  const FasqMutationDependencyDeclaration({
    required this.dependsOn,
    required this.fromResult,
    required this.toInput,
  });

  /// Typed producer mutation function.
  final FasqMutationSource<TParentData, TParentVariables> dependsOn;

  /// Producer response field containing the canonical remote value.
  final FasqMutationField<TParentData, TValue> fromResult;

  /// Current mutation input field receiving the canonical remote value.
  final FasqMutationField<TVariables, TValue> toInput;
}

/// Maps a producer mutation result into this mutation's input at runtime.
///
/// Fasq generates the temporary local reference internally. A value in
/// [toInput] is treated as a dependency only when it matches a retained local
/// reference produced by [dependsOn]. Real remote values pass through as-is.
/// Generated durable dependencies currently require non-nullable `String`
/// fields so the opaque local reference can inhabit the command model safely.
@immutable
final class FasqMutationDependency<
  TParentData,
  TParentVariables,
  TVariables,
  TValue
> {
  /// Creates a typed dependency mapping.
  const FasqMutationDependency({
    required this.dependsOn,
    required this.fromResult,
    required this.toInput,
  });

  /// Typed producer mutation contract.
  final FasqMutationKey<TParentData, TParentVariables> dependsOn;

  /// Producer response field containing the canonical remote value.
  final FasqMutationField<TParentData, TValue> fromResult;

  /// Current mutation input field receiving the canonical remote value.
  final FasqMutationField<TVariables, TValue> toInput;
}
