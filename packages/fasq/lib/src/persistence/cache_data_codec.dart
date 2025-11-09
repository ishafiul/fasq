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
    final updated = Map<String, CacheDataSerializer<dynamic>>.from(serializers);
    updated[serializer.typeKey] = serializer;
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
