# fasq_security

> **Security plugin for FASQ (Flutter Async State Query).**

Provides enterprise-grade security features for FASQ including encryption, secure storage, and persistence.

**Current Version:** 0.3.0

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
  fasq: ^0.5.0
  fasq_security: ^0.3.0
```

## 🚀 Quick Start

Use the unified bootstrap for secure persistence and offline sync:

```dart
import 'package:flutter/widgets.dart';
import 'package:fasq_security/fasq_security.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final fasq = await Fasq.initialize(
    scope: FasqDataScope.anonymous(),
    persistence: const QueryPersistence.secure(),
  );

  runApp(FasqScope(instance: fasq, child: const MyApp()));
}
```

`Fasq.initialize` owns resources it creates and `close` is idempotent:

```dart
await fasq.close();
```

Manual `QueryClient`, `DefaultSecurityPlugin`, and durable queue composition
remain available for advanced integrations.

## Durable mutations without queue boilerplate

Only mutations that must survive an offline restart need a durable handle.
Online-only work keeps the normal core API:

```dart
MutationBuilder(
  mutationFn: api.updateProfile,
  builder: (context, state, mutate) => ProfileForm(onSave: mutate),
)
```

Define a durable mutation manually when code generation is not useful:

```dart
final addTodo = DurableMutation<Todo, AddTodo>.define(
  key: 'todos.add',
  codec: JsonMutationCodec<AddTodo>(
    encoder: (value) => value.toJson(),
    decoder: (payload) => AddTodo.fromJson(
      Map<String, Object?>.from(payload as Map),
    ),
  ),
  execute: api.addTodo,
);
```

Register the same handle during bootstrap and use it in the UI with the core
`MutationBuilder(mutation: ...)` API. With `fasq_serializer_generator`, annotate a
one-argument `Future<T>` function with `@FasqMutation`; the generated
...Durable handle removes the key, codec, and registration code.
The annotated function remains the only executor used online and during
replay.

For advanced queue composition, `DurableMutationDefinition` remains available
from `fasq` (and is re-exported by `fasq_security`). Most applications should
use `DurableMutation` instead.

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
