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
  const AutoRegisterSerializers();
}

