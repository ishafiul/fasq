import 'dart:io';

import 'package:fasq/fasq.dart';
import 'package:fasq_security/fasq_security.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

const _echoMutationKey = FasqMutationKey<String, int>(
  namespace: 'test',
  name: 'echo',
);
const _offlineEchoMutationKey = FasqMutationKey<String, int>(
  namespace: 'test',
  name: 'offline-echo',
);

void main() {
  test('manual durable mutation definition owns its queue contract', () {
    final mutation = DurableMutation<String, int>.define(
      key: _echoMutationKey,
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

  testWidgets('secure runtime plugs into the core FasqProvider', (
    tester,
  ) async {
    final fasq = await Fasq.initialize();
    late FasqRuntime resolvedRuntime;
    late Fasq resolvedSecureRuntime;

    await tester.pumpWidget(
      FasqProvider(
        runtime: fasq,
        child: Builder(
          builder: (context) {
            resolvedRuntime = context.fasqRuntime;
            resolvedSecureRuntime = context.fasq;
            return const SizedBox.shrink();
          },
        ),
      ),
    );

    expect(resolvedRuntime, same(fasq));
    expect(resolvedSecureRuntime, same(fasq));

    await tester.pumpWidget(const SizedBox.shrink());
    await fasq.close();
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
        contractKey: _echoMutationKey,
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
        expect(fasq.mutations.resolve(_echoMutationKey), same(mutation));
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

  test(
    'unified bootstrap completes while offline and defers startup replay',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'fasq-offline-bootstrap-',
      );
      final store = _RecordingOutboxStore(
        FileDurableOutbox(
          directoryPath: directory.path,
          encryption: _FakeOutboxEncryption(),
        ),
      );
      final mutation = DurableMutationDefinition<String, int>(
        contractKey: _offlineEchoMutationKey,
        codec: const JsonMutationCodec<int>(
          encoder: _encodeInt,
          decoder: _decodeInt,
        ),
        execute: (value) async => '$value',
      );
      final networkStatus = NetworkStatus.instance;
      Fasq? fasq;

      networkStatus.setOnline(online: false);
      try {
        fasq = await Fasq.initialize(
          offlineSync: OfflineSync.custom(
            mutations: [mutation],
            store: store,
            encryption: _FakeOutboxEncryption(),
            connectivity: networkStatus,
          ),
        );

        expect(fasq.mutationQueue, isNotNull);
        expect(fasq.mutationQueue!.hasRegistration(mutation.key), isTrue);
      } finally {
        await fasq?.close();
        await store.close();
        networkStatus.setOnline(online: true);
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
