import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:fasq/src/persistence/annotations.dart';
import 'package:source_gen/source_gen.dart';

/// Generates one [DurableMutation] handle from each annotated top-level
/// function.
class MutationGenerator extends GeneratorForAnnotation<FasqMutation> {
  const MutationGenerator();

  @override
  FutureOr<String> generateForAnnotatedElement(
    // ignore: deprecated_member_use
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    // ignore: deprecated_member_use
    if (element is! TopLevelFunctionElement) {
      throw InvalidGenerationSourceError(
        '@FasqMutation can only be applied to top-level functions.',
        element: element,
      );
    }

    final parameters = element.formalParameters;
    if (parameters.length != 1 || parameters.single.isNamed) {
      throw InvalidGenerationSourceError(
        '@FasqMutation functions must accept exactly one positional variable.',
        element: element,
      );
    }

    final returnType = element.returnType;
    if (returnType is! InterfaceType ||
        returnType.element.name != 'Future' ||
        returnType.typeArguments.length != 1) {
      throw InvalidGenerationSourceError(
        '@FasqMutation functions must return Future<T>.',
        element: element,
      );
    }

    final key = annotation.read('key').stringValue;
    final version = annotation.read('version').intValue;
    final offline = annotation.read('offline').boolValue;
    if (!offline) {
      throw InvalidGenerationSourceError(
        '@FasqMutation is only for durable offline mutations. '
        'Use a normal mutationFn for online-only work.',
        element: element,
      );
    }

    final authPolicyName = annotation
        .read('authPolicy')
        .revive()
        .accessor
        .split('.')
        .last;
    final encodeResult = annotation.read('encodeResult').boolValue;
    final variablesType = parameters.single.type.getDisplayString();
    final dataType = returnType.typeArguments.single.getDisplayString();
    final functionName = element.name;
    final generatedName = '${functionName}Durable';

    final resultEncoder = encodeResult
        ? 'resultEncoder: (data) => data.toJson(),'
        : '';

    return '''
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
final $generatedName = DurableMutation<$dataType, $variablesType>.define(
  key: ${jsonEncode(key)},
  version: $version,
  codec: JsonMutationCodec<$variablesType>(
    encoder: (value) => value.toJson(),
    decoder: (payload) => $variablesType.fromJson(
      Map<String, Object?>.from(payload as Map),
    ),
  ),
  execute: $functionName,
  authPolicy: AuthPolicy.$authPolicyName,
  $resultEncoder
);
''';
  }
}
