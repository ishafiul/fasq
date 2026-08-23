import 'dart:async';

import 'package:fasq/src/cache/cache_config.dart';
import 'package:fasq/src/client/query_client.dart';
import 'package:fasq/src/persistence/persistence_options.dart';
import 'package:fasq/src/security/security_plugin.dart';
import 'package:flutter/widgets.dart';

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
  /// Creates a provider that exposes a [QueryClient] to descendants.
  const QueryClientProvider({
    required this.child,
    super.key,
    this.config,
    this.persistenceOptions,
    this.securityPlugin,
    this.client,
  }) : assert(
         client == null ||
             (config == null &&
                 persistenceOptions == null &&
                 securityPlugin == null),
         'Provide either a client or configuration values, not both.',
       );

  /// Cache configuration for the QueryClient.
  final CacheConfig? config;

  /// Persistence options for encrypted cache storage.
  final PersistenceOptions? persistenceOptions;

  /// Security plugin required when [persistenceOptions] enables persistence.
  final SecurityPlugin? securityPlugin;

  /// Optional pre-configured [QueryClient] instance to reuse.
  ///
  /// When provided, [config] and [persistenceOptions] are ignored.
  final QueryClient? client;

  /// The widget below this widget in the tree.
  final Widget child;

  @override
  State<QueryClientProvider> createState() => _QueryClientProviderState();
}

class _QueryClientProviderState extends State<QueryClientProvider> {
  late QueryClient _client;
  late bool _ownsClient;

  @override
  void initState() {
    super.initState();
    _initializeClient();
  }

  @override
  void didUpdateWidget(QueryClientProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.client, widget.client)) return;

    final previousClient = _client;
    final ownedPreviousClient = _ownsClient;
    _initializeClient();
    if (ownedPreviousClient) {
      _disposeOwnedClient(previousClient);
    }
  }

  void _initializeClient() {
    final client = widget.client;
    if (client != null) {
      _client = client;
      _ownsClient = false;
      return;
    }

    _ownsClient = true;
    _client = QueryClient(
      config: widget.config,
      persistenceOptions: widget.persistenceOptions,
      securityPlugin: widget.securityPlugin,
    );
  }

  @override
  void dispose() {
    if (_ownsClient) {
      _disposeOwnedClient(_client);
    }
    super.dispose();
  }

  void _disposeOwnedClient(QueryClient client) {
    unawaited(
      client.dispose().catchError((Object error, StackTrace stackTrace) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: 'fasq',
            context: ErrorDescription('disposing an owned QueryClient'),
          ),
        );
      }),
    );
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
  const _QueryClientInheritedWidget({
    required this.client,
    required super.child,
  });
  final QueryClient client;

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
