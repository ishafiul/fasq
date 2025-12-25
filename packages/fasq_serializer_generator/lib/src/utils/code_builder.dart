import '../models/type_info.dart';

/// Builds the generated code for serializer registrations.
class CodeBuilder {
  static String buildRegistrationCode(Set<TypeInfo> types) {
    final buffer = StringBuffer();

    buffer.writeln('// coverage:ignore-file');
    buffer.writeln('// GENERATED CODE - DO NOT MODIFY BY HAND');
    buffer.writeln('// ignore_for_file: type=lint');
    buffer.writeln();

    // Imports must be in the main library file.
    buffer.writeln();
    buffer.writeln(
        '/// Automatically generated serializer registrations for QueryKeys types.');
    buffer.writeln('CacheDataCodecRegistry registerQueryKeySerializers(');
    buffer.writeln('  CacheDataCodecRegistry registry,');
    buffer.writeln(') {');

    final listTypes = types.where((t) => t.isList).toList();
    final singleTypes = types.where((t) => !t.isList).toList();

    if (listTypes.isNotEmpty) {
      buffer.writeln('  // Register List<T> types');
      for (final type in listTypes) {
        buffer.writeln(
          "  registry = registry.registerJsonSerializableList<${type.elementTypeName}>(",
        );
        buffer.writeln(
          "    fromJson: ${type.elementTypeName}.fromJson,",
        );
        buffer.writeln('  );');
        buffer.writeln();
      }
    }

    if (singleTypes.isNotEmpty) {
      if (listTypes.isNotEmpty) {
        buffer.writeln('  // Register single types');
      }
      for (final type in singleTypes) {
        buffer.writeln(
          "  registry = registry.registerJsonSerializable<${type.typeName}>(",
        );
        buffer.writeln(
          "    fromJson: ${type.typeName}.fromJson,",
        );
        buffer.writeln('  );');
        buffer.writeln();
      }
    }

    buffer.writeln('  return registry;');
    buffer.writeln('}');

    return buffer.toString();
  }
}
