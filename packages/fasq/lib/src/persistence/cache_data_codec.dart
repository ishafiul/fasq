import 'dart:convert';

/// Encodes a typed cache value into a JSON-safe object.
typedef CacheDataEncoder<T> = Object? Function(T value);

/// Decodes a JSON-safe object back into a typed cache value.
typedef CacheDataDecoder<T> = T Function(Object? value);

/// Serializer definition for a single cache data type.
class CacheDataSerializer<T> {
  /// Creates a serializer with encode/decode handlers.
  CacheDataSerializer({
    required this.encode,
    required this.decode,
    String? typeKey,
    bool Function(Object? value)? canHandle,
  })  : type = T,
        typeKey = typeKey ?? T.toString(),
        _canHandle = canHandle;

  /// Runtime type handled by this serializer.
  final Type type;

  /// Stable type identifier used during persistence.
  final String typeKey;

  /// Function that serializes typed values.
  final CacheDataEncoder<T> encode;

  /// Function that deserializes stored payloads.
  final CacheDataDecoder<T> decode;
  final bool Function(Object? value)? _canHandle;

  /// Returns whether this serializer can handle [value].
  bool matches(Object? value) {
    if (_canHandle != null) {
      return _canHandle!(value);
    }
    return value is T;
  }
}

/// Serialized value plus type information.
class CacheDataCodecResult {
  /// Creates a codec result with [typeKey] and [payload].
  const CacheDataCodecResult({
    required this.typeKey,
    required this.payload,
  });

  /// Type identifier for deserialization.
  final String typeKey;

  /// Serialized JSON-safe payload.
  final Object? payload;
}

/// Registry of serializers used by cache persistence.
class CacheDataCodecRegistry {
  /// Creates a registry with optional [serializers] and primitive type key.
  const CacheDataCodecRegistry({
    this.serializers = const {},
    this.primitiveTypeKey = '_primitive',
  });

  /// Registered serializers by type key.
  final Map<String, CacheDataSerializer<dynamic>> serializers;

  /// Type key used for primitive JSON values.
  final String primitiveTypeKey;

  /// Returns a new registry with [serializer] added.
  CacheDataCodecRegistry registerSerializer<T>(
    CacheDataSerializer<T> serializer,
  ) {
    CacheDataSerializer<dynamic> dynamicSerializer;
    // Check if T is exactly dynamic (or Object?), otherwise we need adapter
    // Dart generic classes are covariant, so
    // `is CacheDataSerializer<dynamic>` can be true even when unsafe.
    if (T == dynamic || T == Object) {
      // Safe to cast if T is dynamic/Object
      dynamicSerializer = serializer as CacheDataSerializer<dynamic>;
    } else {
      dynamicSerializer = CacheDataSerializer<dynamic>(
        // Use adapter to cast value correctly for strict serializers
        encode: (value) => serializer.encode(value as T),
        decode: (value) => serializer.decode(value),
        typeKey: serializer.typeKey,
        canHandle: serializer.matches,
      );
    }

    final updated =
        Map<String, CacheDataSerializer<dynamic>>.from(serializers);
    updated[serializer.typeKey] = dynamicSerializer;
    return CacheDataCodecRegistry(
      serializers: updated,
      primitiveTypeKey: primitiveTypeKey,
    );
  }

  /// Serializes [value] using the first matching serializer.
  ///
  /// Returns `null` when no serializer matches the value.
  CacheDataCodecResult? serialize(Object? value) {
    if (_isJsonPrimitive(value)) {
      return CacheDataCodecResult(
        typeKey: primitiveTypeKey,
        payload: value,
      );
    }

    for (final serializer in serializers.values) {
      if (serializer.matches(value)) {
        final payload = serializer.encode(value);
        if (!_isJsonPrimitive(payload) && !_isJsonContainer(payload)) {
          throw ArgumentError(
            'Serializer for ${serializer.typeKey} '
            'must return JSON safe payload',
          );
        }
        return CacheDataCodecResult(
          typeKey: serializer.typeKey,
          payload: payload,
        );
      }
    }

    return null;
  }

  /// Deserializes [payload] using [typeKey].
  Object? deserialize(String? typeKey, Object? payload) {
    if (typeKey == null || typeKey == primitiveTypeKey) {
      return payload;
    }

    final serializer = serializers[typeKey];
    if (serializer == null) {
      throw ArgumentError('No serializer registered for $typeKey');
    }
    return serializer.decode(payload);
  }

  bool _isJsonPrimitive(Object? value) =>
      value == null ||
      value is num ||
      value is bool ||
      value is String ||
      value is double;

  bool _isJsonContainer(Object? value) {
    if (value is List) {
      return value.every(_isJsonSafeElement);
    }
    if (value is Map) {
      return value.entries.every(
        (entry) => entry.key is String && _isJsonSafeElement(entry.value),
      );
    }
    return false;
  }

  bool _isJsonSafeElement(Object? value) {
    if (_isJsonPrimitive(value)) {
      return true;
    }
    if (value is List || value is Map) {
      return _isJsonContainer(value);
    }
    return false;
  }
}

/// Helper registration APIs for JSON-serializable models.
extension JsonSerializableRegistry on CacheDataCodecRegistry {
  /// Registers a serializer for a type with fromJson factory.
  ///
  /// Automatically uses toJson() for encoding and fromJson() for decoding.
  CacheDataCodecRegistry registerJsonSerializable<T>({
    required T Function(Map<String, Object?> json) fromJson,
    String? typeKey,
  }) {
    final resolvedTypeKey = typeKey ?? T.toString();
    return registerSerializer<T>(
      CacheDataSerializer<T>(
        encode: (value) {
          return _encodeJsonMap(value, resolvedTypeKey);
        },
        decode: (value) {
          if (value is! Map<String, Object?>) {
            throw ArgumentError(
              'Expected Map<String, Object?> for $resolvedTypeKey',
            );
          }
          return fromJson(value);
        },
        typeKey: resolvedTypeKey,
        canHandle: (value) => value is T,
      ),
    );
  }

  /// Registers a serializer for `List<T>` where `T` has `fromJson` factory.
  ///
  /// Automatically handles encoding/decoding of lists of JSON-serializable objects.
  CacheDataCodecRegistry registerJsonSerializableList<T>({
    required T Function(Map<String, Object?> json) fromJson,
    String? typeKey,
  }) {
    final listTypeKey = typeKey ?? 'List<$T>';
    return registerSerializer<List<T>>(
      CacheDataSerializer<List<T>>(
        encode: (value) {
          return value.map((item) {
            return _encodeJsonMap(item, listTypeKey);
          }).toList();
        },
        decode: (value) {
          if (value is! List) {
            return <T>[];
          }
          return value
              .map((json) => fromJson(json as Map<String, Object?>))
              .toList();
        },
        typeKey: listTypeKey,
        canHandle: (value) => value is List<T>,
      ),
    );
  }
}

Map<String, Object?> _encodeJsonMap(Object? value, String typeKey) {
  final encoded = jsonDecode(jsonEncode(value));
  if (encoded is! Map) {
    throw ArgumentError('Expected JSON object for $typeKey');
  }
  return Map<String, Object?>.from(encoded);
}
