import 'dart:io';

import 'package:fasq/fasq.dart';
import 'package:fasq_security/fasq_security.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('manual durable mutation definition owns its queue contract', () {
    final mutation = DurableMutation<String, int>.define(
      key: 'test.echo',
      codec: const JsonMutationCodec<int>(
        encoder: _encodeInt,
        decoder: _decodeInt,
      ),
      execute: (value) async => '$value',
    );

    expect(mutation.key, MutationKey(namespace: 'test', name: 'echo'));
    expect(mutation.authPolicy, AuthPolicy.none);
  });

  test('unified bootstrap exposes an explicit memory-only lifecycle', () async {
    final fasq = await Fasq.initialize();

    expect(fasq.status, FasqStatus.ready);
    expect(fasq.mutationQueue, isNull);

    await fasq.close();
    await fasq.close();
    expect(fasq.status, FasqStatus.disposed);
  });

  test(
    'unified bootstrap registers custom durable mutations before open',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'fasq-bootstrap-',
      );
      final store = _RecordingOutboxStore(
        FileDurableOutbox(
          directoryPath: directory.path,
          encryption: _FakeOutboxEncryption(),
        ),
      );
      final mutation = DurableMutationDefinition<String, int>(
        key: MutationKey(namespace: 'test', name: 'echo'),
        codec: const JsonMutationCodec<int>(
          encoder: _encodeInt,
          decoder: _decodeInt,
        ),
        execute: (value) async => '$value',
      );

      try {
        final fasq = await Fasq.initialize(
          offlineSync: OfflineSync.custom(
            mutations: [mutation],
            store: store,
            encryption: _FakeOutboxEncryption(),
          ),
        );

        expect(fasq.mutationQueue, isNotNull);
        expect(fasq.mutationQueue!.hasRegistration(mutation.key), isTrue);
        await fasq.mutationQueue!.enqueue(key: mutation.key, variables: 7);
        await expectLater(
          fasq.rotateEncryptionKey('new-key'),
          throwsA(isA<FasqKeyRotationBlockedException>()),
        );
        await fasq.close();
        expect(store.closeCalls, 0);
      } finally {
        await store.close();
        if (directory.existsSync()) {
          await directory.delete(recursive: true);
        }
      }
    },
  );
}

Object? _encodeInt(int value) => value;

int _decodeInt(Object? value) => value! as int;

class _FakeOutboxEncryption implements OutboxEncryption {
  @override
  Future<void> prepare({required bool allowCreateKey}) async {}

  @override
  Future<List<int>> encrypt(List<int> plaintext) async => plaintext;

  @override
  Future<List<int>> decrypt(List<int> ciphertext) async => ciphertext;
}

class _RecordingOutboxStore implements DurableOutboxStore {
  _RecordingOutboxStore(this._delegate);

  final FileDurableOutbox _delegate;
  int closeCalls = 0;

  @override
  Future<OutboxSnapshot> open() => _delegate.open();

  @override
  OutboxSnapshot get snapshot => _delegate.snapshot;

  @override
  int get generation => _delegate.generation;

  @override
  Future<OutboxSnapshot> transact(
    DurableOutboxTransaction transaction, {
    int? expectedGeneration,
  }) => _delegate.transact(transaction, expectedGeneration: expectedGeneration);

  @override
  Future<void> close() async {
    closeCalls++;
    await _delegate.close();
  }
}
