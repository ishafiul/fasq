import 'package:flutter/widgets.dart';
import '../core/query_client.dart';
import '../cache/cache_config.dart';
import '../persistence/persistence_options.dart';

/// Provider widget for QueryClient configuration.
///
/// This widget allows you to configure QueryClient with security options
/// and make it available to child widgets through the widget tree.
///
/// Example:
/// ```dart
/// QueryClientProvider(
///   config: CacheConfig(
///     defaultStaleTime: Duration(minutes: 5),
///     defaultCacheTime: Duration(minutes: 10),
///   ),
///   persistenceOptions: PersistenceOptions(
///     enabled: true,
///     encryptionKey: 'your-encryption-key',
///   ),
///   child: MyApp(),
/// )
/// ```
///
/// Provide an existing client instead to reuse global configuration:
/// ```dart
/// final client = QueryClient(
///   config: CacheConfig(
///     defaultCacheTime: const Duration(minutes: 10),
///   ),
/// );
///
/// QueryClientProvider(
///   client: client,
///   child: MyApp(),
/// )
/// ```
class QueryClientProvider extends StatefulWidget {
  /// Cache configuration for the QueryClient.
  final CacheConfig? config;

  /// Persistence options for encrypted cache storage.
  final PersistenceOptions? persistenceOptions;

  /// Optional pre-configured [QueryClient] instance to reuse.
  ///
  /// When provided, [config] and [persistenceOptions] are ignored.
  final QueryClient? client;

  /// The widget below this widget in the tree.
  final Widget child;

  const QueryClientProvider({
    super.key,
    this.config,
    this.persistenceOptions,
    this.client,
    required this.child,
  }) : assert(
          client == null || (config == null && persistenceOptions == null),
          'Provide either a client or configuration values, not both.',
        );

  @override
  State<QueryClientProvider> createState() => _QueryClientProviderState();
}

class _QueryClientProviderState extends State<QueryClientProvider> {
  late final QueryClient _client;
  late final bool _ownsClient;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _client = widget.client!;
      _ownsClient = false;
      return;
    }

    _ownsClient = true;
    _client = QueryClient(
      config: widget.config,
      persistenceOptions: widget.persistenceOptions,
    );
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _client.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _QueryClientInheritedWidget(
      client: _client,
      child: widget.child,
    );
  }
}

/// Inherited widget that provides QueryClient to the widget tree.
class _QueryClientInheritedWidget extends InheritedWidget {
  final QueryClient client;

  const _QueryClientInheritedWidget({
    required this.client,
    required super.child,
  });

  @override
  bool updateShouldNotify(_QueryClientInheritedWidget oldWidget) {
    return client != oldWidget.client;
  }

  static QueryClient? of(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<_QueryClientInheritedWidget>()
        ?.client;
  }
}

/// Extension on BuildContext to easily access QueryClient.
extension QueryClientContext on BuildContext {
  /// Gets the QueryClient from the nearest QueryClientProvider.
  ///
  /// Returns null if no QueryClientProvider is found in the widget tree.
  QueryClient? get queryClient => _QueryClientInheritedWidget.of(this);
}
