import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';

/// Validates a value against durable JSON value grammar.
void validateJsonValue(Object? value, [String path = 'value']) {
  if (value == null || value is String || value is bool) return;
  if (value is num) {
    if (value is double && !value.isFinite) {
      throw InvalidMutationPayloadException('$path must be finite');
    }
    return;
  }
  if (value is List<Object?>) {
    for (var index = 0; index < value.length; index++) {
      validateJsonValue(value[index], '$path[$index]');
    }
    return;
  }
  if (value is Map<Object?, Object?>) {
    for (final entry in value.entries) {
      if (entry.key is! String) {
        throw InvalidMutationPayloadException('$path has a non-string key');
      }
      validateJsonValue(entry.value, '$path.${entry.key}');
    }
    return;
  }
  throw InvalidMutationPayloadException(
    '$path contains unsupported type ${value.runtimeType}',
  );
}
