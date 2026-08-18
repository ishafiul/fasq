import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';

/// Current on-disk envelope schema.
const int currentOutboxSchemaVersion = 1;

/// Unencrypted metadata surrounding an encrypted logical store payload.
class OutboxEnvelope {
  /// Creates an envelope.
  const OutboxEnvelope({
    required this.schemaVersion,
    required this.generation,
    required this.checksum,
    required this.payload,
  });

  /// Decodes and validates an envelope map.
  factory OutboxEnvelope.fromJson(Map<String, Object?> json) {
    final magic = json['magic'];
    final schemaVersion = json['schemaVersion'];
    final generation = json['generation'];
    final checksum = json['checksum'];
    final payload = json['payload'];
    if (magic != 'fasq.outbox' ||
        schemaVersion is! int ||
        generation is! int ||
        generation < 0 ||
        checksum is! String ||
        payload is! String) {
      throw const OutboxCorruptException();
    }
    return OutboxEnvelope(
      schemaVersion: schemaVersion,
      generation: generation,
      checksum: checksum,
      payload: payload,
    );
  }

  /// Schema version of the encrypted logical payload.
  final int schemaVersion;

  /// Compare-and-swap generation of this store state.
  final int generation;

  /// Integrity checksum of the encrypted payload bytes.
  final String checksum;

  /// Base64-encoded encrypted logical payload.
  final String payload;

  /// Encodes the envelope for atomic file replacement.
  Map<String, Object?> toJson() => {
    'magic': 'fasq.outbox',
    'schemaVersion': schemaVersion,
    'generation': generation,
    'checksum': checksum,
    'payload': payload,
  };
}
