import 'dart:async';

import 'package:fasq_offline_sync_lab/application/offline_sync_lab_controller.dart';
import 'package:fasq_offline_sync_lab/application/offline_sync_lab_data_source.dart';
import 'package:fasq_offline_sync_lab/domain/lab_note.dart';
import 'package:fasq_offline_sync_lab/domain/offline_sync_lab_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller exposes state and delegates lifecycle', () async {
    final dataSource = _FakeDataSource();
    final controller = OfflineSyncLabController(dataSource: dataSource);

    await controller.initialize();
    await controller.setOnline(true);
    await controller.createNote('offline note');

    expect(controller.state.initialized, isTrue);
    expect(dataSource.receivedTitle, 'offline note');
    expect(dataSource.receivedOnline, isTrue);

    await controller.dispose();
    expect(dataSource.wasDisposed, isTrue);
  });
}

class _FakeDataSource implements OfflineSyncLabDataSource {
  final StreamController<OfflineSyncLabSnapshot> _controller =
      StreamController<OfflineSyncLabSnapshot>.broadcast();
  OfflineSyncLabSnapshot _state = const OfflineSyncLabSnapshot.empty();
  String? receivedTitle;
  bool? receivedOnline;
  bool wasDisposed = false;

  @override
  OfflineSyncLabSnapshot get snapshot => _state;

  @override
  Stream<OfflineSyncLabSnapshot> get snapshots => _controller.stream;

  @override
  Future<void> initialize() async {
    _state = const OfflineSyncLabSnapshot(
      initialized: true,
      isOnline: false,
      account: 'account-a',
      queueAggregateState: 'idle',
      entries: <LabQueueEntry>[],
      notes: <LabNote>[],
      events: <String>[],
      lastAction: 'initialized',
    );
    _controller.add(_state);
  }

  @override
  Future<void> setOnline(bool online) async => receivedOnline = online;

  @override
  Future<void> createNote(String title) async => receivedTitle = title;

  @override
  Future<void> dispose() async {
    wasDisposed = true;
    await _controller.close();
  }

  @override
  Future<void> failNextRequest() async {}

  @override
  Future<void> replay() async {}

  @override
  Future<void> restart() async {}

  @override
  Future<void> retryFirstDeadLetter() async {}

  @override
  Future<void> signInAs(String principalId) async {}

  @override
  Future<void> updateNoteAfterCreate() async {}
}
