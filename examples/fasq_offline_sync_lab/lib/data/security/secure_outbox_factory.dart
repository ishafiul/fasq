import 'package:fasq/fasq.dart';
import 'package:fasq_security/fasq_security.dart';

/// Owns platform key setup and construction of the encrypted outbox.
class SecureOutboxFactory {
  SecureOutboxFactory({DefaultSecurityPlugin? securityPlugin})
    : _securityPlugin = securityPlugin ?? DefaultSecurityPlugin();

  final DefaultSecurityPlugin _securityPlugin;

  Future<FileDurableOutbox> open() async {
    await _securityPlugin.initialize();
    final encryption = SecurityProviderOutboxEncryption(
      securityProvider: _securityPlugin.createStorageProvider(),
      encryptionProvider: _securityPlugin.createEncryptionProvider(),
    );
    return FileDurableOutbox.inApplicationSupportDirectory(
      encryption: encryption,
    );
  }
}
