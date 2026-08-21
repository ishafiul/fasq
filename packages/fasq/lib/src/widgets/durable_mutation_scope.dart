import 'package:fasq/src/mutation/durable_mutation_queue.dart';
import 'package:flutter/widgets.dart';

/// Supplies the durable queue to core mutation widgets.
///
/// Application bootstrap packages may populate this scope with their owned
/// queue. Core UI primitives stay independent of security and persistence
/// implementations.
class DurableMutationScope extends InheritedWidget {
  /// Creates a durable mutation scope.
  const DurableMutationScope({
    required this.queue,
    required super.child,
    super.key,
  });

  /// Queue used to bind durable mutation handles.
  final DurableMutationQueue queue;

  /// Finds the nearest queue or throws a clear configuration error.
  static DurableMutationQueue of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<DurableMutationScope>();
    if (scope == null) {
      throw FlutterError(
        'No DurableMutationScope found. Wrap the app in FasqScope and '
        'enable OfflineSync.',
      );
    }
    return scope.queue;
  }

  @override
  bool updateShouldNotify(DurableMutationScope oldWidget) =>
      !identical(queue, oldWidget.queue);
}
