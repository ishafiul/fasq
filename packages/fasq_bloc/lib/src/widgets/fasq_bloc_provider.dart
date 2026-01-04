import 'dart:async';

import 'package:fasq/fasq.dart';
import 'package:flutter/widgets.dart';

/// Provider widget for making QueryClient accessible through the widget tree.
///
/// This widget wraps the widget tree and provides a QueryClient instance
/// that can be accessed via context, similar to BlocProvider.
///
/// If no QueryClient is provided, a default one is created and automatically
/// disposed when the widget is removed from the tree.
///
/// Example:
/// ```dart
/// FasqBlocProvider(
///   child: MaterialApp(
///     home: UsersScreen(),
///   ),
/// )
/// ```
///
/// Provide an existing client to reuse:
/// ```dart
/// final client = QueryClient();
///
/// FasqBlocProvider(
///   client: client,
///   child: MyApp(),
/// )
/// ```
class FasqBlocProvider extends StatefulWidget {
  /// Optional pre-configured [QueryClient] instance to reuse.
  ///
  /// When provided, the provider will not dispose the client when removed.
  /// If not provided, a default QueryClient is created and disposed automatically.
  final QueryClient? client;

  /// The widget below this widget in the tree.
  final Widget child;

  const FasqBlocProvider({
    super.key,
    this.client,
    required this.child,
  });

  /// Gets the QueryClient from the nearest FasqBlocProvider.
  ///
  /// Throws if no FasqBlocProvider is found in the widget tree.
  ///
  /// Example:
  /// ```dart
  /// final client = FasqBlocProvider.of(context);
  /// ```
  static QueryClient of(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<_FasqBlocProviderInherited>();
    if (provider == null) {
      throw FlutterError(
        'FasqBlocProvider.of() called with a context that does not contain '
        'a FasqBlocProvider.\n'
        'No ancestor could be found starting from the context that was passed '
        'to FasqBlocProvider.of().\n'
        'The context used was:\n'
        '  $context',
      );
    }
    return provider.client;
  }

  /// Gets the QueryClient from the nearest FasqBlocProvider, or null if not found.
  ///
  /// Returns null if no FasqBlocProvider is found in the widget tree.
  ///
  /// Example:
  /// ```dart
  /// final client = FasqBlocProvider.maybeOf(context);
  /// if (client != null) {
  ///   // Use client
  /// }
  /// ```
  static QueryClient? maybeOf(BuildContext context) {
    final provider = context
        .dependOnInheritedWidgetOfExactType<_FasqBlocProviderInherited>();
    return provider?.client;
  }

  @override
  State<FasqBlocProvider> createState() => _FasqBlocProviderState();
}

class _FasqBlocProviderState extends State<FasqBlocProvider> {
  late final QueryClient _queryClient;
  late final bool _disposeClient;

  @override
  void initState() {
    super.initState();
    if (widget.client != null) {
      _queryClient = widget.client!;
      _disposeClient = false;
    } else {
      _queryClient = QueryClient();
      _disposeClient = true;
    }
  }

  @override
  void dispose() {
    if (_disposeClient) {
      unawaited(_queryClient.dispose());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _FasqBlocProviderInherited(
      client: _queryClient,
      child: widget.child,
    );
  }
}

/// Inherited widget that provides QueryClient to the widget tree.
class _FasqBlocProviderInherited extends InheritedWidget {
  final QueryClient client;

  const _FasqBlocProviderInherited({
    required this.client,
    required super.child,
  });

  @override
  bool updateShouldNotify(_FasqBlocProviderInherited oldWidget) {
    return client != oldWidget.client;
  }
}
