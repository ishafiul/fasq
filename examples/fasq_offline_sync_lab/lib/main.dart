import 'package:flutter/material.dart';

import 'application/offline_sync_lab_controller.dart';
import 'data/security/secure_outbox_factory.dart';
import 'data/sync/notes_sync_data_source.dart';
import 'presentation/offline_sync_lab_app.dart';

void main() {
  final dataSource = NotesSyncDataSource(outboxFactory: SecureOutboxFactory());
  final controller = OfflineSyncLabController(dataSource: dataSource);
  runApp(OfflineSyncLabApp(controller: controller));
}
