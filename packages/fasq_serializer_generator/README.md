# fasq_serializer_generator

> ⚠️ **WARNING: NOT READY FOR PRODUCTION USE**
> 
> This package is currently in active development and is **NOT ready for production use**. 
> APIs may change, features may be incomplete, and there may be bugs. Use at your own risk.

Build runner generator for automatically registering serializers from `TypedQueryKey` declarations in QueryKeys classes.

## Usage

1. Annotate your QueryKeys class with `@AutoRegisterSerializers()`:

```dart
import 'package:fasq/fasq.dart';

@AutoRegisterSerializers()
class QueryKeys {
  static TypedQueryKey<List<Product>> get products =>
      const TypedQueryKey<List<Product>>('products', List<Product>);
}
```

2. Run build_runner:

```bash
dart run build_runner build
```

3. Use the generated function in your QueryClientService:

```dart
import 'query_keys.serializers.g.dart';

final codecRegistry = registerQueryKeySerializers(
  CacheDataCodecRegistry(),
);
```

## How It Works

The generator:
- Scans your QueryKeys class for all `TypedQueryKey<T>` declarations
- Extracts type information (including `List<T>` types)
- Generates serializer registration code
- Handles `fromJson` factory detection automatically

