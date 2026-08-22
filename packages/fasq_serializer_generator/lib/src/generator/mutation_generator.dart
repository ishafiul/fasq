import 'dart:async';
import 'dart:convert';

import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:build/build.dart';
import 'package:fasq/src/persistence/annotations.dart';
import 'package:source_gen/source_gen.dart';

/// Generates one [DurableMutation] contract and executor factory from each
/// annotated top-level function.
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
    final executable = element as ExecutableElement;

    final parameters = executable.formalParameters;
    if (parameters.length != 1 || parameters.single.isNamed) {
      throw InvalidGenerationSourceError(
        '@FasqMutation functions must accept exactly one positional variable.',
        element: element,
      );
    }

    final returnType = executable.returnType;
    if (returnType is! InterfaceType ||
        returnType.element.name != 'Future' ||
        returnType.typeArguments.length != 1) {
      throw InvalidGenerationSourceError(
        '@FasqMutation functions must return Future<T>.',
        element: element,
      );
    }

    final key = _readMutationIdentity(annotation, element);
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
    final factoryOnly = annotation.read('factoryOnly').boolValue;
    final dependencies = annotation
        .read('dependencies')
        .listValue
        .map(
          (dependency) => _readDependency(
            dependency,
            variablesType: parameters.single.type,
            element: element,
          ),
        )
        .toList(growable: false);
    final variablesType = parameters.single.type.getDisplayString();
    final dataType = returnType.typeArguments.single.getDisplayString();
    final functionName = element.name!;
    final generatedName = '${functionName}Durable';

    final resultEncoder = encodeResult
        ? 'resultEncoder: (data) => data.toJson(),'
        : '';
    final dependenciesArgument = dependencies.isEmpty
        ? ''
        : '''
  dependencies: <FasqMutationDependency<Object?, Object?, Object?, Object?>>[
${dependencies.map(_dependencySource).join('\n')}
  ],''';

    final generatedKeyName = '${functionName}MutationKey';

    String handleFor(String executor) =>
        '''
DurableMutation<$dataType, $variablesType>.define(
  key: $generatedKeyName,
  codec: JsonMutationCodec<$variablesType>(
    encoder: (value) => value.toJson(),
    decoder: (payload) => $variablesType.fromJson(
      Map<String, Object?>.from(payload as Map),
    ),
  ),
  execute: $executor,
  authPolicy: AuthPolicy.$authPolicyName,
  $resultEncoder
  $dependenciesArgument
)
''';

    return '''
// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
const $generatedKeyName = FasqMutationKey<$dataType, $variablesType>(
  namespace: ${jsonEncode(key.namespace)},
  name: ${jsonEncode(key.name)},
  version: ${key.version},
);

${factoryOnly ? '' : 'final $generatedName = ${generatedName}Handle(execute: $functionName);'}

DurableMutation<$dataType, $variablesType> ${generatedName}Handle({
  required Future<$dataType> Function($variablesType) execute,
}) => ${handleFor('execute')};
''';
  }

  _MutationIdentity _readMutationIdentity(
    ConstantReader annotation,
    Element element,
  ) {
    final object = annotation.objectValue;
    final namespace = object.getField('namespace')?.toStringValue();
    final name = object.getField('name')?.toStringValue();
    final version = object.getField('version')?.toIntValue();
    if (namespace == null || name == null || version == null) {
      throw InvalidGenerationSourceError(
        '@FasqMutation must define namespace, name, and version.',
        element: element,
      );
    }
    return _MutationIdentity(
      namespace: namespace,
      name: name,
      version: version,
    );
  }

  _Dependency _readDependency(
    DartObject object, {
    required DartType variablesType,
    required Element element,
  }) {
    final parent = object.getField('dependsOn');
    final fromResult = object.getField('fromResult');
    final toInput = object.getField('toInput');
    if (parent == null || fromResult == null || toInput == null) {
      throw InvalidGenerationSourceError(
        '@FasqMutation dependency must contain dependsOn, fromResult, and '
        'toInput.',
        element: element,
      );
    }
    final parentSource = _readMutationSource(parent, element);
    final parentKey = parentSource.key;
    final parentType = parentSource.type;
    final source = _readField(fromResult, element);
    final target = _readField(toInput, element);
    final parentDataType = parentType.typeArguments[0];
    if (!_sameType(source.ownerType, parentDataType)) {
      throw InvalidGenerationSourceError(
        'Dependency fromResult owner ${source.ownerType.getDisplayString()} '
        'must match producer result ${parentDataType.getDisplayString()}.',
        element: element,
      );
    }
    if (!_sameType(target.ownerType, variablesType)) {
      throw InvalidGenerationSourceError(
        'Dependency toInput owner ${target.ownerType.getDisplayString()} '
        'must match current variables ${variablesType.getDisplayString()}.',
        element: element,
      );
    }
    if (!_sameType(source.valueType, target.valueType)) {
      throw InvalidGenerationSourceError(
        'Dependency fields must have the same value type; '
        '${source.valueType.getDisplayString()} cannot map to '
        '${target.valueType.getDisplayString()}.',
        element: element,
      );
    }
    if (source.valueType.getDisplayString() != 'String') {
      throw InvalidGenerationSourceError(
        'Durable dependency fields must currently use non-nullable String '
        'identifiers. Other identifier types require an explicit local '
        'reference codec.',
        element: element,
      );
    }
    _validateModelField(source, element);
    _validateModelField(target, element);
    return _Dependency(parent: parentKey, source: source, target: target);
  }

  _MutationSource _readMutationSource(DartObject object, Element element) {
    final sourceType = object.type;
    final function = object.getField('function')?.toFunctionValue();
    if (function == null || function is! TopLevelFunctionElement) {
      throw InvalidGenerationSourceError(
        'Dependency dependsOn must reference an annotated top-level '
        'mutation function with FasqMutationSource.',
        element: element,
      );
    }
    if (sourceType is! InterfaceType || sourceType.typeArguments.length != 2) {
      throw InvalidGenerationSourceError(
        'Dependency producer reference must preserve result and variable '
        'types.',
        element: element,
      );
    }

    final parameters = function.formalParameters;
    final returnType = function.returnType;
    if (parameters.length != 1 ||
        parameters.single.isNamed ||
        returnType is! InterfaceType ||
        returnType.element.name != 'Future' ||
        returnType.typeArguments.length != 1) {
      throw InvalidGenerationSourceError(
        'Dependency producer must be an annotated function returning '
        'Future<T> with one positional variable.',
        element: element,
      );
    }

    final sourceDataType = sourceType.typeArguments[0];
    final sourceVariablesType = sourceType.typeArguments[1];
    final functionDataType = returnType.typeArguments.single;
    final functionVariablesType = parameters.single.type;
    if (!_sameType(sourceDataType, functionDataType) ||
        !_sameType(sourceVariablesType, functionVariablesType)) {
      throw InvalidGenerationSourceError(
        'Dependency producer reference types '
        '<${sourceDataType.getDisplayString()}, '
        '${sourceVariablesType.getDisplayString()}> do not match '
        'function ${function.name} types '
        '<${functionDataType.getDisplayString()}, '
        '${functionVariablesType.getDisplayString()}>.',
        element: element,
      );
    }

    final mutationAnnotation = function.metadata.annotations
        .map((metadata) => metadata.computeConstantValue())
        .whereType<DartObject>()
        .firstWhere(
          (value) => value.type?.element?.name == 'FasqMutation',
          orElse: () => throw InvalidGenerationSourceError(
            'Dependency producer ${function.name} must be annotated with '
            '@FasqMutation.',
            element: element,
          ),
        );
    final identity = _readMutationIdentity(
      ConstantReader(mutationAnnotation),
      element,
    );
    return _MutationSource(
      key: _TypedKey(
        namespace: identity.namespace,
        name: identity.name,
        version: identity.version,
        type: sourceType,
      ),
      type: sourceType,
    );
  }

  _TypedField _readField(DartObject object, Element element) {
    final path = object.getField('path')?.toStringValue();
    final type = object.type;
    if (path == null ||
        path.isEmpty ||
        type is! InterfaceType ||
        type.typeArguments.length != 2) {
      throw InvalidGenerationSourceError(
        'Dependency fields must be typed FasqMutationField constants.',
        element: element,
      );
    }
    return _TypedField(
      path: path,
      ownerType: type.typeArguments[0],
      valueType: type.typeArguments[1],
    );
  }

  void _validateModelField(_TypedField field, Element element) {
    var currentType = field.ownerType;
    for (final segment in field.path.split('.')) {
      if (currentType is! InterfaceType) {
        throw InvalidGenerationSourceError(
          'Cannot read ${field.path} from '
          '${field.ownerType.getDisplayString()}.',
          element: element,
        );
      }
      final getter = currentType.element.getGetter(segment);
      if (getter == null) {
        throw InvalidGenerationSourceError(
          '${currentType.getDisplayString()} has no field named $segment.',
          element: element,
        );
      }
      currentType = getter.returnType;
    }
    if (!_sameType(currentType, field.valueType)) {
      throw InvalidGenerationSourceError(
        '${field.ownerType.getDisplayString()}.${field.path} has type '
        '${currentType.getDisplayString()}, not '
        '${field.valueType.getDisplayString()}.',
        element: element,
      );
    }
  }

  bool _sameType(DartType left, DartType right) =>
      left.getDisplayString() == right.getDisplayString();

  String _dependencySource(_Dependency dependency) {
    final parentType = dependency.parent.type! as InterfaceType;
    final parentData = parentType.typeArguments[0].getDisplayString();
    final parentVariables = parentType.typeArguments[1].getDisplayString();
    final childVariables = dependency.target.ownerType.getDisplayString();
    final valueType = dependency.source.valueType.getDisplayString();
    return '''
    FasqMutationDependency<$parentData, $parentVariables, $childVariables, $valueType>(
      dependsOn: const FasqMutationKey<$parentData, $parentVariables>(
        namespace: ${jsonEncode(dependency.parent.namespace)},
        name: ${jsonEncode(dependency.parent.name)},
        version: ${dependency.parent.version},
      ),
      fromResult: const FasqMutationField<$parentData, $valueType>(
        ${jsonEncode(dependency.source.path)},
      ),
      toInput: const FasqMutationField<$childVariables, $valueType>(
        ${jsonEncode(dependency.target.path)},
      ),
    ),''';
  }
}

class _MutationIdentity {
  const _MutationIdentity({
    required this.namespace,
    required this.name,
    required this.version,
  });

  final String namespace;
  final String name;
  final int version;
}

class _TypedKey {
  const _TypedKey({
    required this.namespace,
    required this.name,
    required this.version,
    required this.type,
  });

  final String namespace;
  final String name;
  final int version;
  final DartType? type;
}

class _MutationSource {
  const _MutationSource({required this.key, required this.type});

  final _TypedKey key;
  final InterfaceType type;
}

class _Dependency {
  const _Dependency({
    required this.parent,
    required this.source,
    required this.target,
  });

  final _TypedKey parent;
  final _TypedField source;
  final _TypedField target;
}

class _TypedField {
  const _TypedField({
    required this.path,
    required this.ownerType,
    required this.valueType,
  });

  final String path;
  final DartType ownerType;
  final DartType valueType;
}
