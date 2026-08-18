import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';

/// Names that are never allowed in durable mutation payloads.
const Set<String> defaultOutboxSensitiveFieldNames = <String>{
  'access_token',
  'accesstoken',
  'client_secret',
  'clientsecret',
  'credential',
  'credentials',
  'password',
  'refresh_token',
  'refreshtoken',
  'secret',
  'token',
};

/// Validates data before it crosses the durable persistence boundary.
class OutboxSecurityPolicy {
  /// Creates a policy with the standard credential field deny-list.
  const OutboxSecurityPolicy({
    this.sensitiveFieldNames = defaultOutboxSensitiveFieldNames,
  });

  /// Case-insensitive field names rejected from durable data.
  final Set<String> sensitiveFieldNames;

  /// Throws when [value] contains a credential-like object key.
  void validate(Object? value) {
    _validate(value);
  }

  void _validate(Object? value) {
    if (value is Map<Object?, Object?>) {
      for (final entry in value.entries) {
        if (entry.key is String &&
            sensitiveFieldNames.contains(
              (entry.key! as String).toLowerCase().replaceAll('-', '_'),
            )) {
          throw const OutboxCredentialRejectedException();
        }
        _validate(entry.value);
      }
      return;
    }
    if (value is Iterable<Object?>) {
      value.forEach(_validate);
    }
  }
}
