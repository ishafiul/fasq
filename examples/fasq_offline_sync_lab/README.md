# Fasq offline sync lab

Small native Flutter app showing one complete Fasq setup:

`Fasq.initialize` → encrypted durable outbox → typed mutations → replay.

Transport is local and deterministic, so you can learn the sync flow without a
backend. File persistence, encryption, auth scope, and replay lifecycle are
real.

## Run it

From the repository root:

```bash
flutter pub get
flutter analyze examples/fasq_offline_sync_lab
flutter test examples/fasq_offline_sync_lab
cd examples/fasq_offline_sync_lab
flutter run -d macos
```

Use any native Flutter target supported by your machine. Web is not supported:
the lab exercises `dart:io`, platform file storage, and secure key storage.

## Read the code in this order

1. [`lib/main.dart`](lib/main.dart) creates the lab and starts Flutter.
2. [`lib/application/offline_sync_lab.dart`](lib/application/offline_sync_lab.dart)
   is the small UI contract.
3. [`lib/data/sync/notes_offline_sync_lab.dart`](lib/data/sync/notes_offline_sync_lab.dart)
   owns app lifecycle, auth, connectivity, queue actions, and the UI snapshot.
4. [`lib/data/sync/notes_mutations.dart`](lib/data/sync/notes_mutations.dart)
   owns Fasq mutation definitions, JSON codecs, and transport adaptation.
5. [`lib/data/notes/`](lib/data/notes/) contains feature commands and the fake
   transport. Replace this folder with your API client in a real app.
6. [`lib/presentation/`](lib/presentation/) only renders state and calls the
   application contract.

The important setup is in `_openFasq()`:

```dart
return Fasq.initialize(
  scope: const FasqDataScope.anonymous(),
  offlineSync: OfflineSync.secure(
    mutations: _mutations.definitions,
    auth: _auth,
    connectivity: _networkStatus,
  ),
);
```

`OfflineSync.secure` supplies the encrypted file outbox and secure key storage.
Your app provides only three things: typed mutation definitions, an auth
session provider, and connectivity.

## Walkthrough

1. Switch offline and create a note. The queue stores it locally.
2. Restart / reopen. The same encrypted outbox restores the pending operation.
3. Reconnect. Fasq lifecycle replay runs automatically; the Replay button is
   also available for explicit control.
4. Queue a dependent update. Fasq binds the created server ID into the update.
5. Switch accounts to see `AuthScope` filtering.
6. Fail one request, replay, then retry its dead letter.

## Boundary rules

- `presentation` knows no Fasq or security implementation.
- `application` exposes use cases and immutable screen state.
- `data/sync` adapts Fasq and owns queue lifecycle.
- `data/notes` owns feature payloads and transport behavior.
- `domain` owns values rendered by the app.

This lab does not promise exactly-once delivery or guaranteed background
execution. Production transports still need idempotency handling.
