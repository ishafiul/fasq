import 'package:flutter/material.dart';

import '../application/offline_sync_lab.dart';
import 'offline_sync_lab_screen.dart';

class OfflineSyncLabApp extends StatelessWidget {
  const OfflineSyncLabApp({required this.lab, super.key});

  final OfflineSyncLab lab;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fasq Offline Sync Lab',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: OfflineSyncLabScreen(lab: lab),
    );
  }
}
