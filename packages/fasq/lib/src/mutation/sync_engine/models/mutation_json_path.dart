import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';

/// Result of reading one JSON object path.
class MutationJsonPathLookup {
  /// Creates a path lookup result.
  const MutationJsonPathLookup({required this.found, required this.value});

  /// Whether every path segment existed.
  final bool found;

  /// Value found at the path.
  final Object? value;
}

/// Reads one dot-separated path from a JSON object.
MutationJsonPathLookup readMutationJsonPath(Object? root, String path) {
  var current = root;
  for (final segment in mutationJsonPathSegments(path)) {
    if (current is! Map<Object?, Object?> || !current.containsKey(segment)) {
      return const MutationJsonPathLookup(found: false, value: null);
    }
    current = current[segment];
  }
  return MutationJsonPathLookup(found: true, value: current);
}

/// Returns a copied JSON object with [value] written at [path].
Object? writeMutationJsonPath(Object? root, String path, Object? value) {
  final segments = mutationJsonPathSegments(path);
  if (root is! Map<Object?, Object?>) {
    throw const InvalidMutationPayloadException(
      'Mutation variables must be a JSON object for identity binding',
    );
  }
  final result = _copyJsonMap(root);
  var current = result;
  for (var index = 0; index < segments.length; index++) {
    final segment = segments[index];
    if (index == segments.length - 1) {
      current[segment] = value;
      break;
    }
    final existing = current[segment];
    if (existing == null) {
      final next = <String, Object?>{};
      current[segment] = next;
      current = next;
    } else if (existing is Map<Object?, Object?>) {
      final next = _copyJsonMap(existing);
      current[segment] = next;
      current = next;
    } else {
      throw const InvalidMutationPayloadException(
        'Mutation path crosses a non-object value',
      );
    }
  }
  return result;
}

/// Whether [path] contains only non-empty dot-separated segments.
bool isValidMutationJsonPath(String path) {
  return path.split('.').every((segment) => segment.trim().isNotEmpty);
}

/// Parses and validates one dot-separated JSON path.
List<String> mutationJsonPathSegments(String path) {
  final segments = path.split('.');
  if (segments.any((segment) => segment.trim().isEmpty)) {
    throw const InvalidMutationPayloadException(
      'JSON path contains an empty segment',
    );
  }
  return segments.map((segment) => segment.trim()).toList(growable: false);
}

Map<String, Object?> _copyJsonMap(Map<Object?, Object?> value) {
  final result = <String, Object?>{};
  for (final entry in value.entries) {
    final key = entry.key;
    if (key is! String) {
      throw const InvalidMutationPayloadException(
        'JSON object keys must be strings',
      );
    }
    result[key] = _copyJsonValue(entry.value);
  }
  return result;
}

Object? _copyJsonValue(Object? value) {
  if (value is Map<Object?, Object?>) return _copyJsonMap(value);
  if (value is List<Object?>) {
    return value.map(_copyJsonValue).toList(growable: false);
  }
  return value;
}
