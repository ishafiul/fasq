# Fasq offline sync lab

Small native Flutter app showing one complete Fasq setup:

`Fasq.initialize` → encrypted durable query cache + outbox → typed mutations → replay.

Transport is local and deterministic, so you can learn the sync flow without a
backend. Query persistence, file persistence, encryption, auth scope, and
replay lifecycle are real.

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

1. [`lib/bootstrap.dart`](lib/bootstrap.dart) is the composition root. It
   initializes Fasq with secure query persistence and the durable encrypted
   mutation outbox.
2. [`lib/main.dart`](lib/main.dart) awaits the bootstrap, installs core
   `FasqProvider`, then installs the lab in
   [`lib/presentation/offline_sync_lab_scope.dart`](lib/presentation/offline_sync_lab_scope.dart).
3. [`lib/application/notes_offline_sync_lab.dart`](lib/application/notes_offline_sync_lab.dart)
   owns use-case coordination and the UI snapshot projection.
4. [`lib/data/sync/fasq_offline_sync_gateway.dart`](lib/data/sync/fasq_offline_sync_gateway.dart)
   adapts Fasq queue lifecycle, auth, connectivity, and the notes read model.
5. [`lib/data/sync/notes_mutations.dart`](lib/data/sync/notes_mutations.dart)
   declares typed keys and producer-result-to-child-input mappings inside
   annotated mutation contracts. Generated handles provide durable details;
   Fasq owns local references while this adapter supplies instance transport.
6. [`lib/data/notes/notes_query.dart`](lib/data/notes/notes_query.dart) owns the
   typed durable notes query, optimistic list updates, and server-result
   reconciliation.
7. [`lib/data/notes/notes_query_keys.dart`](lib/data/notes/notes_query_keys.dart)
   declares typed keys; `fasq_serializer_generator` generates its cache codec.
8. [`lib/data/notes/`](lib/data/notes/) contains feature commands and the fake
   transport. Replace this folder with your API client in a real app.
9. [`lib/presentation/`](lib/presentation/) renders state and invokes durable
   mutations through `MutationBuilder`; only status, replay, restart, and
   repair controls call the application contract directly.

The important setup is in `bootstrap()`:

```dart
return Fasq.initialize(
  scope: const FasqDataScope.anonymous(),
  persistence: QueryPersistence.secure(options: NotesQuery.persistenceOptions),
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
2. Fasq returns an opaque local reference after the durable write succeeds.
3. Restart / reopen. The encrypted query cache and outbox restore local data.
4. Reconnect. Fasq lifecycle replay runs automatically; the Replay button is
   also available for explicit control.
5. Successful replay reconciles the list with the actual server mutation result.
6. Queue a dependent update using the Fasq-owned note reference. Fasq resolves
   the exact create operation and binds its returned server ID automatically.
7. Switch accounts to see `AuthScope` filtering.
8. Fail one request, replay, then retry its dead letter.

## Boundary rules

- `presentation` uses core Fasq widgets but knows no queue or security
  implementation.
- `OfflineSyncLabScope` exposes the application seam and immutable snapshot
  through Flutter context; child widgets do not receive the lab by props.
- Core `FasqProvider` exposes the active query client and durable mutation
  queue; restart swaps the runtime without remounting the application layer.
- `application` exposes use cases and immutable screen state.
- `bootstrap` owns composition and secure Fasq initialization.
- `data/sync` adapts Fasq and owns queue lifecycle.
- Mutation dependency construction stays inside Fasq; presentation and
  application code never handle operation IDs or `MutationDependency`.
- `data/notes` owns feature payloads and transport behavior.
- `domain` owns values rendered by the app.

This lab does not promise exactly-once delivery or guaranteed background
execution. Production transports still need idempotency handling.
