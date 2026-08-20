# Fasq durable offline-sync lab

Separate native Flutter app for verifying Fasq durable mutation sync in a real
application shell. Existing examples remain unchanged.

## Architecture

```text
presentation → application → data/sync → fasq
                                  └────→ data/security → fasq_security
domain ← application
```

- `domain/` contains app-owned immutable note and queue-view models.
- `data/security/` owns security-plugin initialization, key storage, and the
  encrypted `FileDurableOutbox` construction.
- `data/sync/` owns typed mutation registration, local transport simulation,
  auth session, queue lifecycle, replay, and repair operations.
- `application/` exposes one small controller interface to the UI and maps
  infrastructure observations into domain state.
- `presentation/` renders controls and state; it never constructs Fasq or
  security infrastructure.

## Run

From repository root:

```bash
flutter pub get
flutter analyze examples/fasq_offline_sync_lab
flutter test examples/fasq_offline_sync_lab
cd examples/fasq_offline_sync_lab
flutter run -d macos
```

Native target required. Web is intentionally unsupported: this lab exercises
`dart:io`, platform path storage, and secure key storage.

## Walkthrough

1. Go offline, create a note, then inspect the durable pending entry.
2. Select restart/reopen. The encrypted file store is reopened and pending
   work remains.
3. Reconnect and replay. Create executes, then dependent update can execute
   using the parent result binding.
4. Switch accounts to observe exact `AuthScope` behavior.
5. Inject one terminal failure, then use replay/repair controls.

Transport is deterministic and local. Store persistence and encryption are real.
This example does not promise exactly-once delivery or guaranteed background
execution; server mutations still need idempotency handling.
