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

  runApp(FasqProvider(runtime: fasq, child: const MyApp()));
}
```

`Fasq.initialize` owns resources it creates and `close` is idempotent:

```dart
await fasq.close();
```

The runtime automatically maps Flutter `resumed` events to foreground replay
and `paused` events to an optional best-effort background wake-up. Mobile
platform execution is not guaranteed; startup and reconnect replay remain the
correctness path.

With `OfflineSync.custom`, the supplied `DurableOutboxStore` is borrowed and
owns its persistence security. Construct `FileDurableOutbox` with an
`OutboxEncryption` adapter when encrypted custom file persistence is required.
If opening an outbox fails, `FasqRecoveryException.recovery` exposes a safe
typed recovery code and message after partial bootstrap resources are closed.

Manual `QueryClient`, `DefaultSecurityPlugin`, and durable queue composition
remain available for advanced integrations.

`FasqProvider` lives in core `fasq`. This package supplies one secure
`FasqRuntime` implementation; applications and other packages can provide
their own implementation without depending on `fasq_security`.

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
  key: const FasqMutationKey<Todo, AddTodo>(
    namespace: 'todos',
    name: 'add',
  ),
  codec: JsonMutationCodec<AddTodo>(
    encoder: (value) => value.toJson(),
    decoder: (payload) => AddTodo.fromJson(
      Map<String, Object?>.from(payload as Map),
    ),
  ),
  execute: api.addTodo,
);
```

Register the same handle during bootstrap and reference its typed key in the
core `MutationBuilder(mutationKey: ...)` API. `FasqProvider` resolves the
executor and durable queue from the bootstrapped runtime. With
`fasq_serializer_generator`, annotate a
one-argument `Future<T>` function with `@FasqMutation`; the generated
...Durable handle removes the key, codec, and registration code.
The annotated function remains the only executor used online and during
replay. Durable handles use write-ahead execution: online work is persisted
first and replayed immediately; offline work remains queued.

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
