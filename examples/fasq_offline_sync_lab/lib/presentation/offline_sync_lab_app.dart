import 'package:flutter/material.dart';

import 'offline_sync_lab_screen.dart';

class OfflineSyncLabApp extends StatelessWidget {
  const OfflineSyncLabApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fasq Offline Sync Lab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const OfflineSyncLabScreen(),
    );
  }
}
