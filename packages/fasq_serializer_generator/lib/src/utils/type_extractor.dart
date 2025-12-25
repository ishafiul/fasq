import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';

import '../models/type_info.dart';

/// Extracts type information from TypedQueryKey declarations using Element API.
class TypeExtractor {
  /// Extracts all unique types from TypedQueryKey declarations in the library.
  static Set<TypeInfo> extractTypedQueryKeys(LibraryElement library) {
    final types = <TypeInfo>{};

    Iterable<dynamic> elements = [];

    try {
      // ignore: avoid_dynamic_calls
      print('FASQ Generator: Trying namespace.definedNames');
      elements = (library.exportNamespace as dynamic).definedNames.values;
    } catch (e) {
      print('FASQ Generator: definedNames failed: $e');
      try {
        // ignore: avoid_dynamic_calls
        print('FASQ Generator: Trying namespace.definedNames2');
        elements = (library.exportNamespace as dynamic).definedNames2.values;
      } catch (e2) {
        print('FASQ Generator: definedNames2 failed: $e2');
        // Fallback to units/fragments
        try {
          print('FASQ Generator: Falling back to units/fragments');
          // ignore: avoid_dynamic_calls
          final units = (library as dynamic).units as List<dynamic>;
          final extracted = <dynamic>[];
          for (final u in units) {
            // ignore: avoid_dynamic_calls
            for (final v in (u as dynamic).topLevelVariables) {
              // ignore: avoid_dynamic_calls
              extracted.add((v as dynamic).element ?? v);
            }
            // ignore: avoid_dynamic_calls
            for (final c in (u as dynamic).classes) {
              // ignore: avoid_dynamic_calls
              extracted.add((c as dynamic).element ?? c);
            }
          }
          elements = extracted;
        } catch (e3) {
          print('FASQ Generator: Fragment fallback failed: $e3');
        }
      }
    }

    for (final element in elements) {
      if (element is PropertyInducingElement) {
        _extractFromVariable(element, types);
      } else if (element is InterfaceElement) {
        // Check classes/mixins - iterate children to find accessors
        try {
          // ignore: deprecated_member_use
          for (final child in element.children) {
            _processChild(child, types);
          }
        } catch (e) {
          print('FASQ Generator: Failed to iterate children: $e');
          // Try fields/accessors directly if children fails
          try {
            // ignore: avoid_dynamic_calls
            for (final f in (element as dynamic).fields) {
              if ((f as dynamic).isStatic == true)
                _extractFromVariable(f, types);
            }
            // ignore: avoid_dynamic_calls
            for (final a in (element as dynamic).accessors) {
              if (_isStaticGetter(a)) _extractFromAccessor(a, types);
            }
          } catch (_) {}
        }
      }
    }

    return types;
  }

  static void _extractFromVariable(
      PropertyInducingElement element, Set<TypeInfo> types) {
    _analyzeType(element.type, types);
  }

  static void _extractFromAccessor(
      PropertyAccessorElement element, Set<TypeInfo> types) {
    _analyzeType(element.returnType, types);
  }

  static void _analyzeType(DartType type, Set<TypeInfo> types) {
    if (type is InterfaceType) {
      // Check if it's TypedQueryKey<T>
      if (type.element.name == 'TypedQueryKey') {
        final typeArgs = type.typeArguments;
        if (typeArgs.isNotEmpty) {
          _extractTypeInfo(typeArgs.first, types);
        }
      }
    }
  }

  static void _extractTypeInfo(DartType type, Set<TypeInfo> types) {
    if (type is InterfaceType) {
      if (type.isDartCoreList) {
        final elementType = type.typeArguments.first;
        _addTypeInfo(elementType, types, isList: true);
      } else {
        _addTypeInfo(type, types, isList: false);
      }
    }
  }

  static void _addTypeInfo(DartType type, Set<TypeInfo> types,
      {required bool isList}) {
    if (_isPrimitive(type)) return;

    final element = type.element;
    if (element is InterfaceElement) {
      final library = element.library;
      // ignore: deprecated_member_use
      final uri = library.identifier; // Trying identifier as URI

      types.add(TypeInfo(
        typeName: isList ? 'List<${element.name ?? ''}>' : (element.name ?? ''),
        importPath: uri,
        isList: isList,
        elementTypeName: element.name ?? '',
      ));
    }
  }

  static bool _isPrimitive(DartType type) {
    return type.isDartCoreString ||
        type.isDartCoreInt ||
        type.isDartCoreDouble ||
        type.isDartCoreBool ||
        type.isDartCoreNum ||
        type.isDartCoreObject ||
        type is DynamicType ||
        type is VoidType;
  }

  static void _processChild(dynamic child, Set<TypeInfo> types) {
    bool isStatic = false;
    try {
      isStatic = (child as dynamic).isStatic as bool? ?? false;
    } catch (_) {}

    if (child is FieldElement && isStatic) {
      _extractFromVariable(child, types);
    } else if (child is PropertyAccessorElement) {
      if (isStatic && _isStaticGetter(child)) {
        _extractFromAccessor(child, types);
      }
    } else if (child is MethodElement && isStatic) {
      _extractFromMethod(child, types);
    }
  }

  static void _extractFromMethod(MethodElement element, Set<TypeInfo> types) {
    _analyzeType(element.returnType, types);
  }

  static bool _isStaticGetter(dynamic accessor) {
    try {
      final isStatic = (accessor as dynamic).isStatic as bool? ?? false;
      if (!isStatic) return false;
      // ignore: avoid_dynamic_calls
      return (accessor as dynamic).isGetter as bool? ?? false;
    } catch (_) {
      return false;
    }
  }
}
