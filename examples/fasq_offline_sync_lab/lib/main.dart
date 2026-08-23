import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

import 'bootstrap.dart';
import 'presentation/offline_sync_lab_app.dart';
import 'presentation/offline_sync_lab_scope.dart';

Future<void> main() async {
  final appBootstrap = await bootstrap();
  runApp(_OfflineSyncLabRoot(bootstrap: appBootstrap));
}

class _OfflineSyncLabRoot extends StatefulWidget {
  const _OfflineSyncLabRoot({required this.bootstrap});

  final OfflineSyncLabBootstrap bootstrap;

  @override
  State<_OfflineSyncLabRoot> createState() => _OfflineSyncLabRootState();
}

class _OfflineSyncLabRootState extends State<_OfflineSyncLabRoot> {
  @override
  void dispose() {
    widget.bootstrap.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OfflineSyncLabScope(
      lab: widget.bootstrap.lab,
      child: ValueListenableBuilder<FasqRuntime>(
        valueListenable: widget.bootstrap.runtime,
        builder: (context, runtime, _) {
          return FasqProvider(
            runtime: runtime,
            child: const OfflineSyncLabApp(),
          );
        },
      ),
    );
  }
}
