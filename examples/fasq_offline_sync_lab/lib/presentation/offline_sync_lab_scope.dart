import 'dart:async';

import 'package:flutter/widgets.dart';

import '../application/offline_sync_lab.dart';
import '../domain/offline_sync_lab_snapshot.dart';

/// Provides the application lab and its current immutable snapshot to the
/// presentation tree.
///
/// The scope owns the subscription and lab lifecycle. Descendant widgets only
/// depend on the context seam, not on constructor plumbing.
class OfflineSyncLabScope extends StatefulWidget {
  const OfflineSyncLabScope({
    required this.lab,
    required this.child,
    super.key,
  });

  final OfflineSyncLab lab;
  final Widget child;

  static OfflineSyncLab of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_OfflineSyncLabInherited>();
    if (scope == null) {
      throw FlutterError(
        'No OfflineSyncLabScope found. Wrap the application in '
        'OfflineSyncLabScope.',
      );
    }
    return scope.lab;
  }

  static OfflineSyncLabSnapshot snapshotOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_OfflineSyncLabInherited>();
    if (scope == null) {
      throw FlutterError(
        'No OfflineSyncLabScope found. Wrap the application in '
        'OfflineSyncLabScope.',
      );
    }
    return scope.snapshot;
  }

  @override
  State<OfflineSyncLabScope> createState() => _OfflineSyncLabScopeState();
}

class _OfflineSyncLabScopeState extends State<OfflineSyncLabScope> {
  late OfflineSyncLabSnapshot _snapshot;
  StreamSubscription<OfflineSyncLabSnapshot>? _subscription;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.lab.snapshot;
    _subscribe(widget.lab);
  }

  @override
  void didUpdateWidget(OfflineSyncLabScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.lab, widget.lab)) {
      return;
    }
    unawaited(_subscription?.cancel());
    unawaited(oldWidget.lab.dispose());
    _snapshot = widget.lab.snapshot;
    _subscribe(widget.lab);
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    unawaited(widget.lab.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _OfflineSyncLabInherited(
      lab: widget.lab,
      snapshot: _snapshot,
      child: widget.child,
    );
  }

  void _subscribe(OfflineSyncLab lab) {
    _subscription = lab.snapshots.listen((snapshot) {
      if (mounted) setState(() => _snapshot = snapshot);
    });
  }
}

class _OfflineSyncLabInherited extends InheritedWidget {
  const _OfflineSyncLabInherited({
    required this.lab,
    required this.snapshot,
    required super.child,
  });

  final OfflineSyncLab lab;
  final OfflineSyncLabSnapshot snapshot;

  @override
  bool updateShouldNotify(_OfflineSyncLabInherited oldWidget) {
    return !identical(lab, oldWidget.lab) || snapshot != oldWidget.snapshot;
  }
}

extension OfflineSyncLabContext on BuildContext {
  OfflineSyncLab get offlineSyncLab => OfflineSyncLabScope.of(this);

  OfflineSyncLabSnapshot get offlineSyncLabSnapshot =>
      OfflineSyncLabScope.snapshotOf(this);
}
