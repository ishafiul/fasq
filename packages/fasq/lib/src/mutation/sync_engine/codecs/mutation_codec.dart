import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_json.dart';

/// Encodes and decodes one typed mutation variable model.
abstract interface class MutationCodec<TVariables> {
  /// Encodes variables into JSON-safe data.
  Object? encode(TVariables variables);

  /// Decodes JSON-safe data into typed variables.
  TVariables decode(Object? payload);
}

/// Codec backed by explicit JSON encode/decode functions.
class JsonMutationCodec<TVariables> implements MutationCodec<TVariables> {
  /// Creates a JSON mutation codec.
  const JsonMutationCodec({required this.encoder, required this.decoder});

  /// Typed encoder supplied by the application.
  final Object? Function(TVariables variables) encoder;

  /// Typed decoder supplied by the application.
  final TVariables Function(Object? payload) decoder;

  @override
  Object? encode(TVariables variables) {
    final payload = encoder(variables);
    validateJsonValue(payload);
    return payload;
  }

  @override
  TVariables decode(Object? payload) {
    validateJsonValue(payload);
    try {
      return decoder(payload);
    } on MutationContractException {
      rethrow;
    } on Object {
      throw const InvalidMutationPayloadException(
        'Mutation payload could not be decoded',
      );
    }
  }
}

/// Registry of typed variable codecs keyed by versioned MutationKey.
class MutationCodecRegistry {
  final Map<MutationKey, _ErasedMutationCodec<Object?>> _codecs = {};

  /// Registers a codec for [key].
  void register<TVariables>(MutationKey key, MutationCodec<TVariables> codec) {
    if (_codecs.containsKey(key)) {
      throw DuplicateMutationRegistrationException(key.key);
    }
    _codecs[key] = _ErasedMutationCodec<TVariables>(codec);
  }

  /// Returns whether a codec exists for [key].
  bool contains(MutationKey key) => _codecs.containsKey(key);

  /// Encodes variables for [key].
  Object? encode(MutationKey key, Object? variables) {
    final codec = _codecs[key];
    if (codec == null) throw UnknownMutationKeyException(key.key);
    return codec.encode(variables);
  }

  /// Decodes persisted variables for [key].
  Object? decode(MutationKey key, Object? payload) {
    final codec = _codecs[key];
    if (codec == null) throw UnknownMutationKeyException(key.key);
    return codec.decode(payload);
  }

  /// Returns the registered keys in insertion order.
  List<MutationKey> get registeredKeys => List.unmodifiable(_codecs.keys);

  @override
  String toString() => 'MutationCodecRegistry(keys: ${_codecs.keys})';
}

/// Runtime-only registration of a typed codec and async executor.
class MutationRegistrationRegistry {
  final Map<MutationKey, _RegisteredMutation<Object?, Object?>> _registrations =
      {};

  /// Registers a mutation executor and its variable codec.
  void register<TData, TVariables>({
    required MutationKey key,
    required MutationCodec<TVariables> codec,
    required Future<TData> Function(TVariables variables) execute,
    AuthPolicy authPolicy = AuthPolicy.none,
  }) {
    if (_registrations.containsKey(key)) {
      throw DuplicateMutationRegistrationException(key.key);
    }
    _registrations[key] = _RegisteredMutation<TData, TVariables>(
      key: key,
      codec: codec,
      executeTyped: execute,
      authPolicy: authPolicy,
    );
  }

  /// Returns whether an executor is registered for [key].
  bool contains(MutationKey key) => _registrations.containsKey(key);

  /// Encodes variables using the runtime registration for [key].
  Object? encodeVariables(MutationKey key, Object? variables) {
    final registration = _registrations[key];
    if (registration == null) throw UnknownMutationKeyException(key.key);
    return registration.encode(variables);
  }

  /// Decodes variables using the runtime registration for [key].
  Object? decodeVariables(MutationKey key, Object? payload) {
    final registration = _registrations[key];
    if (registration == null) throw UnknownMutationKeyException(key.key);
    return registration.decode(payload);
  }

  /// Executes a registered mutation with decoded persisted variables.
  Future<Object?> execute(MutationKey key, Object? payload) async {
    final registration = _registrations[key];
    if (registration == null) throw UnknownMutationKeyException(key.key);
    return registration.execute(payload);
  }

  /// Returns the auth policy for [key].
  AuthPolicy authPolicyFor(MutationKey key) {
    final registration = _registrations[key];
    if (registration == null) throw UnknownMutationKeyException(key.key);
    return registration.authPolicy;
  }

  /// Returns the currently registered keys.
  List<MutationKey> get registeredKeys =>
      List.unmodifiable(_registrations.keys);
}

class _ErasedMutationCodec<TVariables> {
  const _ErasedMutationCodec(this._codec);

  final MutationCodec<TVariables> _codec;

  Object? encode(Object? variables) {
    if (variables is! TVariables) {
      throw InvalidMutationPayloadException(
        'Variables have type ${variables.runtimeType}, expected $TVariables',
      );
    }
    return _codec.encode(variables);
  }

  Object? decode(Object? payload) => _codec.decode(payload);
}

class _RegisteredMutation<TData, TVariables> {
  const _RegisteredMutation({
    required this.key,
    required this.codec,
    required this.executeTyped,
    required this.authPolicy,
  });

  final MutationKey key;
  final MutationCodec<TVariables> codec;
  final Future<TData> Function(TVariables variables) executeTyped;
  final AuthPolicy authPolicy;

  Object? encode(Object? variables) {
    if (variables is! TVariables) {
      throw InvalidMutationPayloadException(
        'Variables have type ${variables.runtimeType}, expected $TVariables',
      );
    }
    return codec.encode(variables);
  }

  Object? decode(Object? payload) => codec.decode(payload);

  Future<Object?> execute(Object? payload) async {
    final variables = decode(payload);
    if (variables is! TVariables) {
      throw InvalidMutationPayloadException(
        'Decoded variables have type ${variables.runtimeType}, '
        'expected $TVariables',
      );
    }
    return executeTyped(variables);
  }
}
