import 'package:crypto/crypto.dart';
import 'package:fasq/fasq.dart';

/// Scope used to isolate persisted data and encryption keys.
class FasqDataScope {
  /// Creates an anonymous scope.
  const FasqDataScope.anonymous() : accountId = null, storageId = 'anonymous';

  /// Creates an account scope. The account ID never becomes a path segment.
  factory FasqDataScope.user(String accountId) {
    final normalized = accountId.trim();
    if (normalized.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'must not be empty');
    }
    final digest = sha256.convert(normalized.codeUnits).toString();
    return FasqDataScope._(accountId: normalized, storageId: 'user-$digest');
  }

  const FasqDataScope._({required this.accountId, required this.storageId});

  /// Original account identifier for application logic.
  final String? accountId;

  /// Safe stable identifier used for local paths and key namespaces.
  final String storageId;
}

enum PersistenceMode { disabled, secure, custom }

/// Query persistence selection for the unified bootstrap.
class QueryPersistence {
  /// Disables disk persistence.
  const QueryPersistence.disabled()
    : mode = PersistenceMode.disabled,
      plugin = null,
      options = null;

  /// Enables the default encrypted query database.
  const QueryPersistence.secure({this.options})
    : mode = PersistenceMode.secure,
      plugin = null;

  /// Uses an application-supplied security plugin.
  const QueryPersistence.custom({required this.plugin, this.options})
    : mode = PersistenceMode.custom;

  final PersistenceMode mode;
  final SecurityPlugin? plugin;
  final PersistenceOptions? options;

  /// Whether this configuration requests persistent storage.
  bool get enabled => mode != PersistenceMode.disabled;
}

enum OfflineSyncMode { disabled, secure, custom }

/// Durable mutation synchronization selection for the unified bootstrap.
class OfflineSync {
  /// Disables durable offline synchronization.
  const OfflineSync.disabled()
    : mode = OfflineSyncMode.disabled,
      mutations = const [],
      auth = null,
      connectivity = null,
      store = null,
      backgroundAdapter = null;

  /// Enables the default encrypted file outbox and lifecycle replay.
  const OfflineSync.secure({
    required this.mutations,
    this.auth,
    this.connectivity,
    this.backgroundAdapter,
  }) : mode = OfflineSyncMode.secure,
       store = null;

  /// Uses an application-supplied outbox.
  ///
  /// The store owns its persistence security. Use [FileDurableOutbox] with an
  /// [OutboxEncryption] adapter when encrypted file persistence is required.
  const OfflineSync.custom({
    required this.mutations,
    required this.store,
    this.auth,
    this.connectivity,
    this.backgroundAdapter,
  }) : mode = OfflineSyncMode.custom;

  final OfflineSyncMode mode;
  final List<DurableMutationDefinitionBase> mutations;
  final AuthSessionProvider? auth;
  final NetworkStatus? connectivity;
  final DurableOutboxStore? store;

  /// Optional platform adapter for best-effort background replay scheduling.
  final BackgroundReplayAdapter? backgroundAdapter;

  /// Whether this configuration requests durable synchronization.
  bool get enabled => mode != OfflineSyncMode.disabled;

  /// Whether Fasq should construct the default secure outbox.
  bool get usesDefaultSecurity => mode == OfflineSyncMode.secure;
}

/// Lifecycle state exposed by [Fasq].
enum FasqStatus { initializing, ready, failed, disposed }
