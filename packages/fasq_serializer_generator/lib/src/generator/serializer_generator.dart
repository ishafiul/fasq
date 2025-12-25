import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:fasq/src/persistence/annotations.dart';
import 'package:source_gen/source_gen.dart';

import '../utils/code_builder.dart';
import '../utils/type_extractor.dart';

/// Generator for automatically registering serializers from TypedQueryKey declarations.
class SerializerGenerator
    extends GeneratorForAnnotation<AutoRegisterSerializers> {
  const SerializerGenerator();

  @override
  FutureOr<String> generateForAnnotatedElement(
    // ignore: deprecated_member_use
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) async {
    // ignore: deprecated_member_use
    if (element is! InterfaceElement) {
      print('FASQ Generator: skipping non-interface element ${element.name}');
      throw InvalidGenerationSourceError(
        '@AutoRegisterSerializers can only be applied to classes.',
        element: element,
      );
    }
    print('FASQ Generator: processing ${element.name}');
    // ignore: deprecated_member_use
    final library = element.library;

    final types = TypeExtractor.extractTypedQueryKeys(library);

    if (types.isEmpty) {
      return '';
    }

    return CodeBuilder.buildRegistrationCode(types);
  }
}
