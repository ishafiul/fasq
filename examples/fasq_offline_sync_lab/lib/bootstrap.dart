import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:fasq/fasq.dart';
import 'package:fasq_security/fasq_security.dart';

import 'application/notes_offline_sync_lab.dart';
import 'application/offline_sync_lab.dart';
import 'data/notes/notes_query.dart';
import 'data/notes/simulated_notes_transport.dart';
import 'data/sync/fasq_offline_sync_gateway.dart';
import 'data/sync/notes_mutations.dart';

/// Builds the application graph and opens Fasq's secure durable stores.
///
/// This is the composition root. Feature and application modules receive
/// ready-to-use seams; only this module chooses secure storage, persistence,
/// mutation registration, auth, and connectivity implementations.
Future<OfflineSyncLabBootstrap> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();

  const account = 'account-a';
  final networkStatus = NetworkStatus.instance;
  networkStatus.setOnline(online: false);
  final auth = InMemoryAuthSessionProvider(
    initial: AuthSessionSnapshot.ready(
      AuthScope(
        principalId: account,
        tenantId: 'demo',
        authRealm: 'offline-sync-lab',
      ),
    ),
  );
  final transport = SimulatedNotesTransport();
  final mutations = NotesMutations(transport: transport);

  Future<Fasq> openFasq() {
    return Fasq.initialize(
      scope: const FasqDataScope.anonymous(),
      persistence: QueryPersistence.secure(
        options: NotesQuery.persistenceOptions,
      ),
      offlineSync: OfflineSync.secure(
        mutations: mutations.definitions,
        auth: auth,
        connectivity: networkStatus,
      ),
    );
  }

  Fasq? fasq;
  ValueNotifier<FasqRuntime>? runtime;
  try {
    fasq = await openFasq();
    final runtimeNotifier = ValueNotifier<FasqRuntime>(fasq);
    runtime = runtimeNotifier;
    final gateway = await FasqOfflineSyncGateway.create(
      fasq: fasq,
      auth: auth,
      activeAccount: account,
      networkStatus: networkStatus,
      transport: transport,
      mutations: mutations,
      openFasq: openFasq,
      onRuntimeChanged: (nextRuntime) {
        runtimeNotifier.value = nextRuntime;
      },
    );
    return OfflineSyncLabBootstrap._(
      runtime: runtimeNotifier,
      lab: NotesOfflineSyncLab(gateway: gateway),
    );
  } on Object {
    runtime?.dispose();
    await fasq?.close();
    await auth.dispose();
    await mutations.dispose();
    rethrow;
  }
}

/// Initialized application graph consumed by the Flutter root.
class OfflineSyncLabBootstrap {
  OfflineSyncLabBootstrap._({
    required ValueNotifier<FasqRuntime> runtime,
    required this.lab,
  }) : _runtime = runtime;

  final ValueNotifier<FasqRuntime> _runtime;
  final OfflineSyncLab lab;

  ValueListenable<FasqRuntime> get runtime => _runtime;

  void dispose() => _runtime.dispose();
}
