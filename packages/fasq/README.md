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

### 1. Wrap your App

Wrap your application with `QueryClientProvider`:

```dart
void main() {
  runApp(
    QueryClientProvider(
      client: QueryClient(),
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
