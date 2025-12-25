# Fasq (Flutter Async State Query)

> **The caching-first async state management library for Flutter.**

[![Pub Version](https://img.shields.io/pub/v/fasq?style=flat-square)](https://pub.dev/packages/fasq)
[![License: MIT](https://img.shields.io/badge/license-MIT-purple.svg?style=flat-square)](LICENSE)
[![Build Status](https://img.shields.io/github/actions/workflow/status/ishafiul/fasq/main.yml?branch=main&style=flat-square)](https://github.com/ishafiul/fasq/actions)

Fasq handles **async state management**, **server-state caching**, and **synchronization** for Flutter applications. It is designed to be:

- 🚀 **Performant**: Intelligent caching, background refetching, and request deduplication.
- 🛠️ **Flexible**: Works with any state management (Bloc, Riverpod, Hooks, or standalone).
- 🔒 **Secure**: Built-in encryption support for sensitive data.
- 📱 **Production Ready**: Robust error recovery, offline support, and 100% type safety.

Inspired by [TanStack Query](https://tanstack.com/query/latest) and [SWR](https://swr.vercel.app/).

## 📦 Packages

This monorepo manages the following packages:

| Package | Version | Description |
|---------|---------|-------------|
| **[fasq](./packages/fasq)** | [![Pub](https://img.shields.io/pub/v/fasq?style=flat-square)](https://pub.dev/packages/fasq) | The core caching, query, and mutation engine. |
| **[fasq_bloc](./packages/fasq_bloc)** | [![Pub](https://img.shields.io/pub/v/fasq_bloc?style=flat-square)](https://pub.dev/packages/fasq_bloc) | Integration with `flutter_bloc`. |
| **[fasq_hooks](./packages/fasq_hooks)** | [![Pub](https://img.shields.io/pub/v/fasq_hooks?style=flat-square)](https://pub.dev/packages/fasq_hooks) | React-style hooks (`useQuery`, `useMutation`). |
| **[fasq_riverpod](./packages/fasq_riverpod)** | [![Pub](https://img.shields.io/pub/v/fasq_riverpod?style=flat-square)](https://pub.dev/packages/fasq_riverpod) | Providers for `flutter_riverpod`. |
| **[fasq_security](./packages/fasq_security)** | [![Pub](https://img.shields.io/pub/v/fasq_security?style=flat-square)](https://pub.dev/packages/fasq_security) | Encryption and secure storage plugin. |
| **[fasq_serializer_generator](./packages/fasq_serializer_generator)** | [![Pub](https://img.shields.io/pub/v/fasq_serializer_generator?style=flat-square)](https://pub.dev/packages/fasq_serializer_generator) | Codegen for typed query keys. |

## 📚 Documentation

Detailed documentation is available at **[fasq.shafi.dev](https://fasq.shafi.dev)**.

- [Quick Start](https://fasq.shafi.dev/quick-start)
- [Core Concepts](https://fasq.shafi.dev/core/core-concepts)
- [Examples](https://fasq.shafi.dev/core/examples)

## 🚀 Quick Start

### 1. Install

Add `fasq` to your `pubspec.yaml` (or your preferred adapter):

```yaml
dependencies:
  fasq: ^0.3.7
  # Optional adapters:
  # fasq_bloc: ...
  # fasq_riverpod: ...
  # fasq_hooks: ...
```

### 2. Configure Client

Available anywhere in your app via `QueryClientProvider` or specific adapter providers.

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

### 3. Fetch Data

```dart
QueryBuilder<List<Todo>>(
  queryKey: 'todos',
  queryFn: () => api.fetchTodos(),
  builder: (context, state) {
    if (state.isLoading) return CircularProgressIndicator();
    if (state.hasError) return Text('Error: ${state.error}');
    
    return ListView.builder(
      itemCount: state.data!.length,
      itemBuilder: (context, index) => Text(state.data![index].title),
    );
  },
)
```

## 🤝 Contributing

We welcome contributions! Please see the [CONTRIBUTING.md](CONTRIBUTING.md) file for details on how to get started.

### Setup for Development

This project relies on [Melos](https://melos.invertase.dev) to manage the monorepo.

1.  **Clone the repo:**
    ```bash
    git clone https://github.com/ishafiul/fasq.git && cd fasq
    ```
2.  **Install Melos:**
    ```bash
    dart pub global activate melos
    ```
3.  **Bootstrap:**
    ```bash
    melos bootstrap
    ```

### Running Tests

Run unit and widget tests across all packages:

```bash
melos run test:all
```

## 📄 License

Fasq is released under the **MIT License**. See [LICENSE](LICENSE) for details.

## 🙏 Acknowledgements

- **TanStack Query (React Query)**: The primary inspiration for the architecture and API design.
- **SWR**: For the "stale-while-revalidate" philosophy.

---

Built with ❤️ by [Shafiul Islam](https://github.com/ishafiul).
