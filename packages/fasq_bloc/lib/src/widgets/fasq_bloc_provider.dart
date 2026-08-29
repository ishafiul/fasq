import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Provider widget for making FASQ runtime resources available to Bloc and
/// core widgets.
///
/// Pass [runtime] for a fully initialized core runtime, or pass [client] for a
/// query-only scope. When neither is supplied, an existing ancestor client is
/// reused; otherwise the provider creates and owns the default singleton.
/// The resolved client and runtime are also available through
/// `context.read<QueryClient>()` and `context.read<FasqRuntime>()` when a
/// runtime-backed scope is used.
class FasqBlocProvider extends StatefulWidget {
  /// Optional initialized runtime containing a client and durable queue.
  final FasqRuntime? runtime;

  /// Optional pre-configured query client.
  final QueryClient? client;

  /// Cache configuration used to create an owned query client.
  final CacheConfig? config;

  /// Persistence configuration used to create an owned query client.
  final PersistenceOptions? persistenceOptions;

  /// Security plugin used by the owned query client.
  final SecurityPlugin? securityPlugin;

  /// The widget below this provider.
  final Widget child;

  const FasqBlocProvider({
    super.key,
    this.runtime,
    this.client,
    this.config,
    this.persistenceOptions,
    this.securityPlugin,
    required this.child,
  }) : assert(
         runtime == null || client == null,
         'Provide either runtime or client, not both.',
       ),
       assert(
         (runtime == null && client == null) ||
             (config == null &&
                 persistenceOptions == null &&
                 securityPlugin == null),
         'Provide either a runtime/client or configuration values, not both.',
       );

  /// Gets the nearest Bloc adapter client.
  static QueryClient of(BuildContext context) {
    final provider = context
        .getInheritedWidgetOfExactType<_FasqBlocProviderInherited>();
    if (provider == null) {
      throw FlutterError(
        'FasqBlocProvider.of() called with a context that does not contain '
        'a FasqBlocProvider.',
      );
    }
    return provider.client;
  }

  /// Gets the nearest Bloc adapter client, or null when absent.
  static QueryClient? maybeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<_FasqBlocProviderInherited>()
        ?.client;
  }

  /// Gets the nearest runtime, or null when this is a query-only scope.
  static FasqRuntime? maybeRuntimeOf(BuildContext context) {
    return context
        .getInheritedWidgetOfExactType<_FasqBlocProviderInherited>()
        ?.runtime;
  }

  /// Gets the nearest runtime or throws when none was provided.
  static FasqRuntime runtimeOf(BuildContext context) {
    final runtime = maybeRuntimeOf(context);
    if (runtime == null) {
      throw FlutterError(
        'FasqBlocProvider.runtimeOf() requires a provider with runtime.',
      );
    }
    return runtime;
  }

  @override
  State<FasqBlocProvider> createState() => _FasqBlocProviderState();
}

class _FasqBlocProviderState extends State<FasqBlocProvider> {
  QueryClient? _queryClient;
  var _ownsClient = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _synchronizeClient();
  }

  @override
  void didUpdateWidget(covariant FasqBlocProvider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.client, widget.client) ||
        !identical(oldWidget.runtime, widget.runtime) ||
        !identical(oldWidget.config, widget.config) ||
        !identical(oldWidget.persistenceOptions, widget.persistenceOptions) ||
        !identical(oldWidget.securityPlugin, widget.securityPlugin)) {
      _synchronizeClient();
    }
  }

  void _synchronizeClient() {
    final requestedClient = widget.runtime?.queryClient ?? widget.client;
    final hasConfiguration =
        widget.config != null ||
        widget.persistenceOptions != null ||
        widget.securityPlugin != null;
    final inheritedClient = hasConfiguration ? null : context.queryClient;
    final nextClient =
        requestedClient ??
        inheritedClient ??
        QueryClient(
          config: widget.config,
          persistenceOptions: widget.persistenceOptions,
          securityPlugin: widget.securityPlugin,
        );
    final nextOwnsClient = requestedClient == null && inheritedClient == null;

    if (identical(nextClient, _queryClient)) {
      _ownsClient = nextOwnsClient;
      return;
    }

    final previousClient = _queryClient;
    final previousOwned = _ownsClient;
    _queryClient = nextClient;
    _ownsClient = nextOwnsClient;

    if (previousOwned && previousClient != null) {
      _disposeOwnedClient(previousClient);
    }
  }

  @override
  void dispose() {
    final client = _queryClient;
    if (_ownsClient && client != null) {
      _disposeOwnedClient(client);
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
            library: 'fasq_bloc',
            context: ErrorDescription('disposing an owned QueryClient'),
          ),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final client = _queryClient ?? QueryClient();
    final hasConfiguration =
        widget.config != null ||
        widget.persistenceOptions != null ||
        widget.securityPlugin != null;
    final runtime = hasConfiguration
        ? null
        : widget.runtime ??
              (widget.client == null ? FasqProvider.maybeOf(context) : null);
    final inherited = _FasqBlocProviderInherited(
      client: client,
      runtime: runtime,
      child: widget.child,
    );

    Widget result;
    if (runtime != null) {
      result = FasqProvider(runtime: runtime, child: inherited);
      result = RepositoryProvider<FasqRuntime>.value(
        value: runtime,
        child: result,
      );
    } else {
      result = QueryClientProvider(client: client, child: inherited);
    }
    return RepositoryProvider<QueryClient>.value(value: client, child: result);
  }
}

/// Inherited value used by the Bloc adapter's static lookup helpers.
class _FasqBlocProviderInherited extends InheritedWidget {
  const _FasqBlocProviderInherited({
    required this.client,
    required this.runtime,
    required super.child,
  });

  final QueryClient client;
  final FasqRuntime? runtime;

  @override
  bool updateShouldNotify(_FasqBlocProviderInherited oldWidget) {
    return !identical(client, oldWidget.client) ||
        !identical(runtime, oldWidget.runtime);
  }
}
