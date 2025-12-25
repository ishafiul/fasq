# fasq_security

> **Security plugin for FASQ (Flutter Async State Query).**

Provides enterprise-grade security features for FASQ including encryption, secure storage, and persistence.

**Current Version:** 0.1.4

## 📚 Documentation

For full documentation and API reference, visit:  
**[https://fasq.shafi.dev/core/security](https://fasq.shafi.dev/core/security)**

## ✨ Features

- **🔒 Encryption**: AES-GCM encryption with 256-bit keys.
- **🛡️ Secure Storage**: Platform-specific secure key storage (Keychain/Keystore).
- **💾 Persistence**: Encrypted SQL persistence using Drift.
- **⚡ Performance**: Isolate-based encryption for large data sets.

## 📦 Installation

```yaml
dependencies:
  fasq: ^0.3.7
  fasq_security: ^0.1.4
```

## 🚀 Quick Start

Initialize `QueryClient` with the security plugin:

```dart
import 'package:fasq/fasq.dart';
import 'package:fasq_security/fasq_security.dart';

void main() async {
  // Create client with security plugin
  final client = QueryClient(
    securityPlugin: DefaultSecurityPlugin(),
  );

  // Initialize (generates/retrieves keys)
  await client.securityPlugin.initialize();

  runApp(QueryClientProvider(
    client: client,
    child: MyApp(),
  ));
}
```

## 🔐 Secure Queries

Mark specific queries as secure. Their data will be encrypted in memory/disk and cleared when the app goes to the background (configurable).

```dart
QueryBuilder<String>(
  queryKey: 'auth-token',
  queryFn: () => api.login(),
  options: QueryOptions(
    isSecure: true,                // Enable security
    maxAge: Duration(minutes: 15), // Enforce expiry
  ),
  builder: (context, state) {
    // state.data is available only when authenticated
    return Text('Token: ${state.data}');
  },
)
```

## 📄 License

MIT