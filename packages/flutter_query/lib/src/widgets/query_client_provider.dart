import 'package:flutter/widgets.dart';

import '../core/query_client.dart';

class QueryClientProvider extends InheritedWidget {
  final QueryClient client;

  const QueryClientProvider({
    required this.client,
    required super.child,
    super.key,
  });

  static QueryClient of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<QueryClientProvider>();
    return provider?.client ?? QueryClient();
  }

  @override
  bool updateShouldNotify(QueryClientProvider oldWidget) {
    return client != oldWidget.client;
  }
}

