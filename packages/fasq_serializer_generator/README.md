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
dart run build_runner build
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

## 📄 License

MIT
