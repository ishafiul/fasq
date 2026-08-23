import 'package:fasq/src/mutation/sync_engine/store/outbox_errors.dart';

/// Names that are never allowed in durable mutation payloads.
const Set<String> defaultOutboxSensitiveFieldNames = <String>{
  'api_key',
  'apikey',
  'access_token',
  'accesstoken',
  'auth_header',
  'auth_token',
  'authorization',
  'authorization_header',
  'bearer_token',
  'cookie',
  'cookie_header',
  'client_secret',
  'clientsecret',
  'credential',
  'credentials',
  'encryption_key',
  'id_token',
  'jwt',
  'password',
  'private_key',
  'privatekey',
  'refresh_token',
  'refreshtoken',
  'secret',
  'secret_key',
  'session_token',
  'sessiontoken',
  'signing_key',
  'ssh_key',
  'token',
  'x_api_key',
  'x_auth_token',
  'oauth_token',
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
            sensitiveFieldNames.any(
              (fieldName) =>
                  _normalizeFieldName(fieldName) ==
                  _normalizeFieldName(entry.key! as String),
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

String _normalizeFieldName(String value) {
  return value.toLowerCase().replaceAll(RegExp('[-_]'), '');
}
