typedef CacheDataEncoder<T> = Object? Function(T value);
typedef CacheDataDecoder<T> = T Function(Object? value);

class CacheDataSerializer<T> {
  CacheDataSerializer({
    required this.encode,
    required this.decode,
    String? typeKey,
    bool Function(Object? value)? canHandle,
  })  : type = T,
        typeKey = typeKey ?? T.toString(),
        _canHandle = canHandle;

  final Type type;
  final String typeKey;
  final CacheDataEncoder<T> encode;
  final CacheDataDecoder<T> decode;
  final bool Function(Object? value)? _canHandle;

  bool matches(Object? value) {
    if (_canHandle != null) {
      return _canHandle!(value);
    }
    return value is T;
  }
}

class CacheDataCodecResult {
  const CacheDataCodecResult({
    required this.typeKey,
    required this.payload,
  });

  final String typeKey;
  final Object? payload;
}

class CacheDataCodecRegistry {
  const CacheDataCodecRegistry({
    this.serializers = const {},
    this.primitiveTypeKey = '_primitive',
  });

  final Map<String, CacheDataSerializer<dynamic>> serializers;
  final String primitiveTypeKey;

  CacheDataCodecRegistry registerSerializer<T>(
    CacheDataSerializer<T> serializer,
  ) {
    CacheDataSerializer<dynamic> dynamicSerializer;
    // Check if T is exactly dynamic (or Object?), otherwise we need adapter
    // Dart generic classes are covariant, so 'is CacheDataSerializer<dynamic>' is true
    // even if it's not safe to use as such.
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

    final updated = Map<String, CacheDataSerializer<dynamic>>.from(serializers);
    updated[serializer.typeKey] = dynamicSerializer;
    return CacheDataCodecRegistry(
      serializers: updated,
      primitiveTypeKey: primitiveTypeKey,
    );
  }

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
            'Serializer for ${serializer.typeKey} must return JSON safe payload',
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

extension JsonSerializableRegistry on CacheDataCodecRegistry {
  /// Registers a serializer for a type with fromJson factory.
  ///
  /// Automatically uses toJson() for encoding and fromJson() for decoding.
  CacheDataCodecRegistry registerJsonSerializable<T>({
    required T Function(Map<String, Object?> json) fromJson,
    String? typeKey,
  }) {
    return registerSerializer<T>(
      CacheDataSerializer<T>(
        encode: (value) {
          return (value as dynamic).toJson() as Map<String, Object?>;
        },
        decode: (value) {
          if (value is! Map<String, Object?>) {
            throw ArgumentError(
              'Expected Map<String, Object?> for ${typeKey ?? T.toString()}',
            );
          }
          return fromJson(value);
        },
        typeKey: typeKey ?? T.toString(),
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
    final listTypeKey = typeKey ?? 'List<${T.toString()}>';
    return registerSerializer<List<T>>(
      CacheDataSerializer<List<T>>(
        encode: (value) {
          return value.map((item) {
            final dynamic obj = item;
            return obj.toJson() as Map<String, Object?>;
          }).toList();
        },
        decode: (value) {
          if (value is! List) {
            return <T>[];
          }
          return (value)
              .map((json) => fromJson(json as Map<String, Object?>))
              .toList();
        },
        typeKey: listTypeKey,
        canHandle: (value) => value is List<T>,
      ),
    );
  }
}
