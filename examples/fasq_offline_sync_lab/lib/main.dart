import 'package:flutter/material.dart';

import 'data/sync/notes_offline_sync_lab.dart';
import 'presentation/offline_sync_lab_app.dart';

void main() {
  final lab = NotesOfflineSyncLab();
  runApp(OfflineSyncLabApp(lab: lab));
}
