# FASQ (Flutter Async State Query)

> **Caching-first async data management for Flutter.**

Fasq is a powerful library for managing asynchronous state in Flutter applications. It handles caching, synchronization, background updates, and error recovery with a simple, declarative API.

**Current Version:** 0.3.7

## 📚 Documentation

For full documentation, guides, and API reference, visit:  
**[https://fasq.shafi.dev](https://fasq.shafi.dev)**

## ✨ Features

- **🚀 Simple API**: Works with any Future-returning function.
- **💾 Intelligent Caching**: Automatic caching with configurable staleness and eviction policies (LRU, LFU, FIFO).
- **🔄 Auto Refetching**: Background updates keep your UI fresh without blocking the user.
- **⚡ Request Deduplication**: Multiple widgets requesting the same data trigger only one network call.
- **🛠️ Mutations**: Integrated mutation management with optimistic updates and offline queuing.
- **📱 Type Safe**: Built with strict typing for compile-time safety.
- **🔌 Adapter Ecosystem**: Official adapters for Bloc, Riverpod, and Hooks (or use standalone!).

## 📦 Installation

Add `fasq` to your `pubspec.yaml`:

```yaml
dependencies:
  fasq: ^0.3.7
```

## 🚀 Quick Start

### 1. Bootstrap and provide Fasq

Initialize your chosen runtime implementation, then expose query and mutation
resources through the single core provider:

```dart
Future<void> main() async {
  final fasq = await createFasqRuntime();
  runApp(
    FasqProvider(
      runtime: fasq,
      child: MyApp(),
    ),
  );
}
```

### 2. Fetch Data with QueryBuilder

Use `QueryBuilder` to handle loading, error, and success states automatically.

```dart
QueryBuilder<List<User>>(
  queryKey: 'users',
  queryFn: () => api.fetchUsers(),
  builder: (context, state) {
    if (state.isLoading) return CircularProgressIndicator();
    if (state.hasError) return Text('Error: ${state.error}');
    
    return ListView.builder(
      itemCount: state.data!.length,
      itemBuilder: (context, index) => Text(state.data![index].name),
    );
  },
)
```

### Unified Query and Durable Mutation Provider

`QueryClientProvider` remains a low-level compatibility API. New applications
should use `FasqProvider`. Integration packages can implement the core
`FasqRuntime` contract and expose
their initialized query client and optional durable mutation queue through one
provider:

```dart
final runtime = await createRuntime();

runApp(
  FasqProvider(
    runtime: runtime,
    child: const MyApp(),
  ),
);
```

`FasqProvider` borrows the runtime. Application bootstrap remains responsible
for initialization and `runtime.close()`. Security, storage, auth, and replay
implementations remain replaceable and do not become core dependencies.

### Typed Durable Mutation Dependencies

The mutation annotation owns the stable durable identity. The generator emits
the typed key for `MutationBuilder` and runtime registration:

```dart
@FasqMutation(
  namespace: 'posts',
  name: 'create',
  encodeResult: true,
)
Future<Post> createPost(CreatePost input) => api.createPost(input);

@FasqMutation(
  namespace: 'posts',
  name: 'update',
  dependencies: [
    FasqMutationDependencyDeclaration(
      dependsOn: FasqMutationSource<Post, CreatePost>(createPost),
      fromResult: FasqMutationField<Post, String>('id'),
      toInput: FasqMutationField<UpdatePost, String>('postId'),
    ),
  ],
)
Future<Post> updatePost(UpdatePost input) => api.updatePost(input);
```

The generator verifies the producer result model, current input model, field
names, and field value types. Fasq generates and persists the local reference;
create inputs do not carry an application-generated local ID. Completed parent
results are rewritten during child enqueue. Pending parent results become
durable edges and are rewritten during replay. Each mapping resolves
independently, so one child can depend on multiple completed and pending
parents. `MutationBuilder` returns the opaque local reference in its submission
receipt and resolves the bootstrapped executor and queue through `FasqProvider`.

## 🧩 Ecosystem

Fasq is designed to work with your favorite state management solution:

| Package | Description | Version |
|---------|-------------|---------|
| `fasq` | Core package (Widgets + Logic) | `^0.3.7` |
| `fasq_bloc` | Bloc/Cubit integration | `^0.2.4+1` |
| `fasq_riverpod` | Riverpod providers | `^0.2.4+1` |
| `fasq_hooks` | Flutter Hooks support (`useQuery`) | `^0.2.4+1` |
| `fasq_security` | Encrypted storage plugin | `^0.1.4` |

## 📄 License

MIT
