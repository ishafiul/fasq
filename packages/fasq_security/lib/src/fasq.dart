import 'dart:async';
import 'package:fasq/fasq.dart';
import 'package:flutter/widgets.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'fasq_exceptions.dart';
import 'fasq_options.dart';
import 'plugins/default_security_plugin.dart';
import 'providers/crypto_encryption_provider.dart';
import 'providers/secure_storage_provider.dart';

/// Unified application composition root for secure Fasq features.
class Fasq {
  Fasq._({
    required this.scope,
    required QueryClient queryClient,
    required DurableMutationQueue? mutationQueue,
    required ReplayLifecycleController? replayLifecycle,
    required EncryptionProvider? outboxEncryption,
    required SecurityPlugin? querySecurity,
  }) : _queryClient = queryClient,
       _mutationQueue = mutationQueue,
       _replayLifecycle = replayLifecycle,
       _outboxEncryption = outboxEncryption,
       _querySecurity = querySecurity,
       _status = FasqStatus.ready;

  /// Initializes one explicit Fasq application scope.
  static Future<Fasq> initialize({
    FasqDataScope scope = const FasqDataScope.anonymous(),
    QueryPersistence persistence = const QueryPersistence.disabled(),
    OfflineSync offlineSync = const OfflineSync.disabled(),
    CacheConfig? cacheConfig,
  }) async {
    QueryClient? queryClient;
    SecurityPlugin? querySecurity;
    SecurityProvider? outboxStorage;
    EncryptionProvider? outboxEncryption;
    DurableMutationQueue? mutationQueue;
    ReplayLifecycleController? replayLifecycle;
    var querySecurityOwned = false;
    var outboxResourcesOwned = false;

    try {
      final queryEnabled = persistence.enabled;
      if (queryEnabled) {
        final activeQuerySecurity =
            persistence.plugin ??
            DefaultSecurityPlugin(
              storageNamespace: 'query-${scope.storageId}',
              persistenceFileName: 'fasq_cache_${scope.storageId}.sqlite',
            );
        querySecurity = activeQuerySecurity;
        querySecurityOwned = persistence.plugin == null;
        if (!activeQuerySecurity.isSupported) {
          throw const FasqInitializationException(
            'Secure query persistence is not supported on this platform',
          );
        }
        await activeQuerySecurity.initialize();
      }

      final queryOptions =
          persistence.options ?? const PersistenceOptions(enabled: true);
      if (queryEnabled && !queryOptions.enabled) {
        throw const FasqConfigurationException(
          'Secure query persistence requires enabled PersistenceOptions',
        );
      }
      queryClient = QueryClient.create(
        config: cacheConfig,
        persistenceOptions: queryEnabled ? queryOptions : null,
        securityPlugin: querySecurity,
        ownsSecurityResources: querySecurityOwned,
      );
      try {
        await queryClient.persistenceInitialization;
      } on Object catch (error, stackTrace) {
        Error.throwWithStackTrace(
          FasqStorageException(
            'Failed to initialize secure query persistence',
            error,
          ),
          stackTrace,
        );
      }

      if (offlineSync.enabled) {
        if (offlineSync.mutations.isEmpty) {
          throw const FasqConfigurationException(
            'OfflineSync requires at least one mutation definition',
          );
        }
        if (!offlineSync.usesDefaultSecurity) {
          mutationQueue = DurableMutationQueue(
            store: offlineSync.store!,
            ownsStore: false,
            authSessionProvider: offlineSync.auth,
            isOnline: () =>
                offlineSync.connectivity?.isOnline ??
                NetworkStatus.instance.isOnline,
          );
        } else {
          final supportDirectory = await getApplicationSupportDirectory();
          final namespace = 'outbox-${scope.storageId}';
          outboxStorage = SecureStorageProvider(namespace: namespace);
          outboxEncryption = CryptoEncryptionProvider();
          outboxResourcesOwned = true;
          await outboxStorage.initialize();
          final encryption = SecurityProviderOutboxEncryption(
            securityProvider: outboxStorage,
            encryptionProvider: outboxEncryption,
          );
          final outboxPath = p.join(
            supportDirectory.path,
            'fasq',
            scope.storageId,
            'offline_outbox',
          );
          final store = FileDurableOutbox(
            directoryPath: outboxPath,
            encryption: encryption,
          );
          mutationQueue = DurableMutationQueue(
            store: store,
            authSessionProvider: offlineSync.auth,
            isOnline: () =>
                offlineSync.connectivity?.isOnline ??
                NetworkStatus.instance.isOnline,
          );
        }

        for (final mutation in offlineSync.mutations) {
          try {
            mutation.register(mutationQueue);
          } on Object catch (error, stackTrace) {
            Error.throwWithStackTrace(
              FasqMutationRegistrationException(
                'Failed to register mutation ${mutation.runtimeType}',
                error,
              ),
              stackTrace,
            );
          }
        }
        try {
          await mutationQueue.open();
        } on OutboxOwnershipException catch (error, stackTrace) {
          Error.throwWithStackTrace(
            FasqOwnershipException(
              'The durable outbox is already owned by another process',
              error,
            ),
            stackTrace,
          );
        } on DurableOutboxException catch (error, stackTrace) {
          Error.throwWithStackTrace(
            FasqRecoveryException(
              'Failed to open and recover the durable outbox',
              error,
            ),
            stackTrace,
          );
        }
        final readiness = ReplayReadinessBarrier();
        final networkStatus =
            offlineSync.connectivity ?? NetworkStatus.instance;
        replayLifecycle = ReplayLifecycleController(
          readiness: readiness,
          replay: mutationQueue.replay,
          authSessionProvider: offlineSync.auth,
          networkStatus: networkStatus,
        );
        readiness.update(
          storeReady: true,
          registrationsReady: true,
          encryptionReady: true,
        );
        await replayLifecycle.onStartup();
      }

      return Fasq._(
        scope: scope,
        queryClient: queryClient,
        mutationQueue: mutationQueue,
        replayLifecycle: replayLifecycle,
        outboxEncryption: outboxResourcesOwned ? outboxEncryption : null,
        querySecurity: querySecurity,
      );
    } on FasqException {
      await _closePartial(
        replayLifecycle: replayLifecycle,
        mutationQueue: mutationQueue,
        queryClient: queryClient,
        outboxEncryption: outboxResourcesOwned ? outboxEncryption : null,
      );
      rethrow;
    } on Object catch (error, stackTrace) {
      await _closePartial(
        replayLifecycle: replayLifecycle,
        mutationQueue: mutationQueue,
        queryClient: queryClient,
        outboxEncryption: outboxResourcesOwned ? outboxEncryption : null,
      );
      Error.throwWithStackTrace(
        FasqInitializationException('Fasq initialization failed', error),
        stackTrace,
      );
    }
  }

  static Future<void> _closePartial({
    required ReplayLifecycleController? replayLifecycle,
    required DurableMutationQueue? mutationQueue,
    required QueryClient? queryClient,
    required EncryptionProvider? outboxEncryption,
  }) async {
    await replayLifecycle?.dispose();
    await mutationQueue?.close();
    await queryClient?.dispose();
    await outboxEncryption?.dispose();
  }

  final FasqDataScope scope;
  final QueryClient _queryClient;
  final DurableMutationQueue? _mutationQueue;
  final ReplayLifecycleController? _replayLifecycle;
  final EncryptionProvider? _outboxEncryption;
  final SecurityPlugin? _querySecurity;
  FasqStatus _status;

  /// Current lifecycle state.
  FasqStatus get status => _status;

  /// Explicit query client owned by this Fasq instance.
  QueryClient get queryClient => _queryClient;

  /// Durable mutation queue, when offline sync is enabled.
  DurableMutationQueue? get mutationQueue => _mutationQueue;

  /// Rotates the encrypted query persistence key.
  ///
  /// Durable mutations use an independent key namespace. Pending mutations
  /// are rejected here so a future coordinated outbox rotation cannot make
  /// queued work unreadable.
  Future<void> rotateEncryptionKey(String newKey) async {
    if (_status == FasqStatus.disposed) {
      throw const FasqDisposedException();
    }
    final queue = _mutationQueue;
    if (queue != null && queue.snapshot.active.isNotEmpty) {
      throw const FasqKeyRotationBlockedException();
    }
    final security = _querySecurity;
    if (security is! DefaultSecurityPlugin) {
      throw const FasqConfigurationException(
        'Key rotation requires the default secure query provider',
      );
    }
    await security.updateEncryptionKey(newKey);
  }

  /// Closes all resources created by this instance.
  Future<void> close() async {
    if (_status == FasqStatus.disposed) return;
    await _replayLifecycle?.dispose();
    await _mutationQueue?.close();
    await _queryClient.cache.flushPersistence();
    await _queryClient.dispose();
    await _outboxEncryption?.dispose();
    _status = FasqStatus.disposed;
  }
}

/// Exposes one [Fasq] instance and its query client to a widget subtree.
class FasqScope extends StatelessWidget {
  /// Creates a Fasq scope.
  const FasqScope({required this.instance, required this.child, super.key});

  /// Explicit Fasq instance supplied by the application root.
  final Fasq instance;

  /// Widget subtree that consumes [instance].
  final Widget child;

  /// Finds the nearest Fasq scope.
  static Fasq of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<_FasqInherited>();
    if (scope == null) {
      throw FlutterError('No FasqScope found in the widget tree.');
    }
    return scope.instance;
  }

  @override
  Widget build(BuildContext context) {
    Widget scopedChild = _FasqInherited(instance: instance, child: child);
    final mutationQueue = instance.mutationQueue;
    if (mutationQueue != null) {
      scopedChild = DurableMutationScope(
        queue: mutationQueue,
        child: scopedChild,
      );
    }
    return QueryClientProvider(
      client: instance.queryClient,
      child: scopedChild,
    );
  }
}

class _FasqInherited extends InheritedWidget {
  const _FasqInherited({required this.instance, required super.child});

  final Fasq instance;

  @override
  bool updateShouldNotify(_FasqInherited oldWidget) =>
      !identical(instance, oldWidget.instance);
}

/// Convenient access to the nearest [Fasq] instance.
extension FasqContext on BuildContext {
  /// Returns the nearest Fasq instance.
  Fasq get fasq => FasqScope.of(this);
}
