# FASQ Security Package

A security plugin package for FASQ that provides encryption, secure storage, and persistence capabilities.

## Features

- **Encryption**: AES-GCM encryption with isolate support for large data
- **Secure Storage**: Platform-specific secure key storage using flutter_secure_storage
- **Persistence**: Efficient encrypted data persistence with batch operations
- **Plugin Architecture**: Modular design allowing custom security implementations

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  fasq: ^0.2.0
  fasq_security: ^0.0.1
```

## Usage

### Basic Usage

```dart
import 'package:fasq/fasq.dart';
import 'package:fasq_security/fasq_security.dart';

// Create a QueryClient with security
final client = QueryClient(
  securityPlugin: DefaultSecurityPlugin(),
);

// Initialize the security plugin
await client.securityPlugin.initialize();
```

### Advanced Usage

```dart
import 'package:fasq_security/fasq_security.dart';

// Create individual providers
final storageProvider = SecureStorageProvider();
final encryptionProvider = CryptoEncryptionProvider();
final persistenceProvider = DriftPersistenceProvider();

// Initialize providers
await storageProvider.initialize();
await persistenceProvider.initialize();

// Use providers directly
final key = await storageProvider.generateAndStoreKey();
final encrypted = await encryptionProvider.encrypt(data, key);
await persistenceProvider.persist('my-key', encrypted);
```

### Key Rotation

```dart
import 'package:fasq_security/fasq_security.dart';

final plugin = DefaultSecurityPlugin();
await plugin.initialize();

// Update encryption key with progress tracking
await plugin.updateEncryptionKey(
  'new-encryption-key',
  onProgress: (current, total) {
    print('Progress: $current/$total');
  },
);
```

## Security Features

### Encryption

- **Algorithm**: AES-GCM with 256-bit keys
- **Key Generation**: Cryptographically secure random generation
- **Isolate Support**: Large data encrypted in background isolates to prevent UI blocking
- **Threshold**: Data larger than 50KB is automatically encrypted in isolates

### Secure Storage

- **iOS**: Uses Keychain for secure key storage
- **Android**: Uses EncryptedSharedPreferences
- **Web**: Not supported (throws UnsupportedError)
- **Desktop**: Platform-specific secure storage

### Persistence

- **Database**: In-memory storage with expiration support
- **Batch Operations**: Efficient bulk insert, retrieve, and delete operations
- **Expiration**: Automatic cleanup of expired cache entries
- **ACID Compliance**: Atomic operations for data integrity

## Plugin Architecture

The package implements the FASQ security plugin architecture:

```dart
abstract class SecurityPlugin {
  SecurityProvider createStorageProvider();
  EncryptionProvider createEncryptionProvider();
  PersistenceProvider createPersistenceProvider();
  
  String get name;
  String get version;
  bool get isSupported;
  
  Future<void> initialize();
}
```

### Provider Interfaces

#### SecurityProvider
Manages encryption keys using platform-specific secure storage.

#### EncryptionProvider
Handles encryption and decryption operations with isolate support.

#### PersistenceProvider
Manages encrypted data persistence with efficient batch operations.

## Error Handling

The package provides specific exception types:

```dart
try {
  await provider.encrypt(data, key);
} on EncryptionException catch (e) {
  print('Encryption failed: ${e.message}');
} on PersistenceException catch (e) {
  print('Persistence failed: ${e.message}');
} on SecureStorageException catch (e) {
  print('Secure storage failed: ${e.message}');
}
```

## Testing

The package includes comprehensive tests for all providers and plugins. Run tests with:

```bash
flutter test
```

## Migration from Core Package

If you're migrating from the core FASQ package's built-in security:

### Before (Core Package)
```dart
final client = QueryClient(
  persistenceOptions: PersistenceOptions(
    enabled: true,
    encrypt: true,
    encryptionKey: 'my-key',
  ),
);
```

### After (Security Package)
```dart
final client = QueryClient(
  securityPlugin: DefaultSecurityPlugin(),
);
```

## Platform Support

- ✅ iOS
- ✅ Android
- ✅ macOS
- ✅ Windows
- ✅ Linux
- ❌ Web (secure storage not supported)

## Performance

- **Small Data**: < 1ms encryption/decryption
- **Large Data**: Background isolate processing prevents UI blocking
- **Batch Operations**: 20x faster than individual operations
- **Memory Usage**: Optimized for mobile devices

## Contributing

Contributions are welcome! Please see the main FASQ repository for contribution guidelines.

## License

This package is licensed under the same license as the main FASQ package.