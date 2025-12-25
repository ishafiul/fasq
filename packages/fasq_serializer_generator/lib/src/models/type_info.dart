/// Information about a type extracted from TypedQueryKey declarations.
class TypeInfo {
  const TypeInfo({
    required this.typeName,
    required this.importPath,
    required this.isList,
    this.elementTypeName,
  });

  /// The full type name (e.g., "ProductResponse" or "List<PromotionalContentResponse>")
  final String typeName;

  /// The import path for this type
  final String importPath;

  /// Whether this is a List type
  final bool isList;

  /// If isList is true, the element type name (e.g., "PromotionalContentResponse")
  final String? elementTypeName;

  /// The actual type to register (element type for lists, typeName for singles)
  String get registrationType => isList ? elementTypeName! : typeName;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TypeInfo &&
          runtimeType == other.runtimeType &&
          typeName == other.typeName &&
          importPath == other.importPath &&
          isList == other.isList &&
          elementTypeName == other.elementTypeName;

  @override
  int get hashCode =>
      Object.hash(typeName, importPath, isList, elementTypeName);
}
