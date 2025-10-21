import '../query_options.dart';

/// Validates inputs to prevent injection attacks and malformed data.
///
/// Ensures all inputs conform to expected formats and ranges,
/// throwing clear error messages for invalid inputs.
class InputValidator {
  static final RegExp _validKeyPattern = RegExp(r'^[a-zA-Z0-9:_-]+$');

  /// Validates a query key.
  ///
  /// Query keys must contain only alphanumeric characters, colons, hyphens, and underscores.
  /// Throws [ArgumentError] if the key is invalid.
  static void validateQueryKey(String key) {
    if (key.isEmpty) {
      throw ArgumentError('Query key cannot be empty');
    }

    if (key.length > 255) {
      throw ArgumentError(
          'Query key cannot exceed 255 characters. Got: ${key.length}');
    }

    if (!_validKeyPattern.hasMatch(key)) {
      throw ArgumentError(
        'Query key must contain only alphanumeric, colon, hyphen, underscore. Got: \'$key\'',
      );
    }
  }

  /// Validates cache data.
  ///
  /// Ensures data is serializable and doesn't contain functions or closures.
  /// Throws [ArgumentError] if the data is invalid.
  static void validateCacheData<T>(T data) {
    if (data == null) {
      throw ArgumentError('Cache data cannot be null');
    }

    // Check for functions or closures
    if (data is Function) {
      throw ArgumentError('Cache data cannot be a function or closure');
    }

    // Check for complex objects that might contain functions
    if (data is Map) {
      _validateMap(data);
    } else if (data is List) {
      _validateList(data);
    }

    // Additional validation could be added here for specific types
  }

  /// Validates query options.
  ///
  /// Ensures all durations are non-negative and other options are valid.
  /// Throws [ArgumentError] if any option is invalid.
  static void validateOptions(QueryOptions options) {
    validateDuration(options.staleTime, 'staleTime');
    validateDuration(options.cacheTime, 'cacheTime');
    validateDuration(options.maxAge, 'maxAge');

    // Validate secure options
    if (options.isSecure && options.maxAge == null) {
      throw ArgumentError(
        'Secure queries must specify maxAge for TTL enforcement',
      );
    }

    if (options.isSecure &&
        options.maxAge != null &&
        options.maxAge!.isNegative) {
      throw ArgumentError(
        'maxAge for secure queries must be non-negative. Got: ${options.maxAge}',
      );
    }
  }

  /// Validates a duration.
  ///
  /// Ensures the duration is non-negative if provided.
  /// Throws [ArgumentError] if the duration is invalid.
  static void validateDuration(Duration? duration, String name) {
    if (duration != null && duration.isNegative) {
      throw ArgumentError('$name must be non-negative. Got: $duration');
    }
  }

  /// Validates a map for functions or closures.
  static void _validateMap(Map map) {
    for (final entry in map.entries) {
      if (entry.key is Function) {
        throw ArgumentError('Map keys cannot be functions or closures');
      }
      if (entry.value is Function) {
        throw ArgumentError('Map values cannot be functions or closures');
      }
      if (entry.value is Map) {
        _validateMap(entry.value as Map);
      }
      if (entry.value is List) {
        _validateList(entry.value as List);
      }
    }
  }

  /// Validates a list for functions or closures.
  static void _validateList(List list) {
    for (final item in list) {
      if (item is Function) {
        throw ArgumentError('List items cannot be functions or closures');
      }
      if (item is Map) {
        _validateMap(item);
      }
      if (item is List) {
        _validateList(item);
      }
    }
  }

  /// Validates that a string is not empty and within length limits.
  static void validateString(String? value, String name,
      {int maxLength = 1000}) {
    if (value == null) return;

    if (value.isEmpty) {
      throw ArgumentError('$name cannot be empty');
    }

    if (value.length > maxLength) {
      throw ArgumentError(
          '$name cannot exceed $maxLength characters. Got: ${value.length}');
    }
  }

  /// Validates that a number is within expected range.
  static void validateNumber(num? value, String name, {num? min, num? max}) {
    if (value == null) return;

    if (min != null && value < min) {
      throw ArgumentError('$name must be >= $min. Got: $value');
    }

    if (max != null && value > max) {
      throw ArgumentError('$name must be <= $max. Got: $value');
    }
  }

  /// Validates that a boolean value is not null when required.
  static void validateBoolean(bool? value, String name,
      {bool required = false}) {
    if (required && value == null) {
      throw ArgumentError('$name is required but was null');
    }
  }
}
