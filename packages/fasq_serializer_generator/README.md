# fasq_serializer_generator

> **Code generator for FASQ (Flutter Async State Query).**

Automatically registers serializers from your `TypedQueryKey` declarations, eliminating boilerplate code for complex data types.

**Current Version:** 0.1.1

## 📚 Documentation

For full documentation and API reference, visit:  
**[https://fasq.shafi.dev/core/type-safety](https://fasq.shafi.dev/core/type-safety)**

## ✨ Features

- **🤖 Automatic Detection**: Scans for `TypedQueryKey<T>` in your `QueryKeys` classes.
- **📦 Serializer Registration**: Generates registration code for `fromJson`/`toJson`.
- **🏗️ Build Runner**: Integrates seamlessly with `build_runner`.
- **📡 Durable Mutations**: Generates typed durable mutation handles from
  `@FasqMutation` functions.

## 📦 Installation

```yaml
dev_dependencies:
  fasq_serializer_generator: ^0.1.1
  build_runner: ^2.4.0
```

## 🚀 Usage

### 1. Annotate Keys

Add `@AutoRegisterSerializers()` to your keys class.

```dart
import 'package:fasq/fasq.dart';
import 'package:fasq_serializer_generator/fasq_serializer_generator.dart';

@AutoRegisterSerializers()
class QueryKeys {
  static const products = TypedQueryKey<List<Product>>('products', List<Product>);
  static const user = TypedQueryKey<User>('user', User);
}
```

### 2. Run Builder

```bash
flutter pub run build_runner build
```

### 3. Register

Use the generated `registerQueryKeySerializers` function.

```dart
import 'query_keys.serializers.g.dart';

void main() {
  // Pass the registry to register helper
  final registry = registerQueryKeySerializers(CacheDataCodecRegistry());
  
  // Use registry in your client
  final client = QueryClient(
    config: CacheConfig(codecRegistry: registry),
  );
}
```

### Durable mutation generation

Annotate only operations that must be queued across offline restarts. The
function must accept one JSON-serializable request and return `Future<T>`:

```dart
@FasqMutation(namespace: 'todos', name: 'create', encodeResult: true)
Future<Todo> createTodo(CreateTodo request) => api.createTodo(request);

@FasqMutation(
  namespace: 'todos',
  name: 'update',
  dependencies: [
    FasqMutationDependencyDeclaration(
      dependsOn: FasqMutationSource<Todo, CreateTodo>(createTodo),
      fromResult: FasqMutationField<Todo, String>('id'),
      toInput: FasqMutationField<UpdateTodo, String>('todoId'),
    ),
  ],
)
Future<Todo> updateTodo(UpdateTodo request) => api.updateTodo(request);
```

Mutation keys and field descriptors carry their model and value types. The
generator verifies those types and the named model fields, so an incompatible
mapping or field rename fails generation. Fasq creates local references; the
application does not add a local ID to `CreateTodo`. During execution, Fasq
treats an unrecognized value as a server ID. A known local reference is either
rewritten from completed history or linked to its exact pending operation.

The generated `addTodoDurable` handle is passed to
`OfflineSync.secure(mutations: [...])` and the core
`MutationBuilder(mutationKey: ...)`. Ordinary online-only mutations continue
using `MutationBuilder(mutationFn: ...)`.

Adapters with instance-scoped transports can use the generated
`createTodoDurableHandle(execute: ...)` factory. The annotation still owns the
stable key, schema version, codec, auth policy, and result encoding; the
adapter supplies only its executor instance.

Contract-only declarations can set `factoryOnly: true` to generate only the
executor factory and avoid a global handle for the declaration function.

## 📄 License

MIT
