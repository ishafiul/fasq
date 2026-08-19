import 'dart:async';

import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_operation.dart';

/// Readiness of the current authentication session.
enum AuthSessionStatus {
  /// Session state is not known yet.
  unknown,

  /// Credentials for the current scope are ready for execution.
  ready,

  /// The scope remains valid but user interaction is required.
  reauthenticationRequired,

  /// The account or tenant is no longer allowed to execute work.
  revoked,

  /// No authenticated session exists.
  signedOut,
}

/// Non-secret current authentication state.
class AuthSessionSnapshot {
  /// Creates an authentication snapshot.
  factory AuthSessionSnapshot({
    required AuthSessionStatus status,
    AuthScope? scope,
  }) {
    if (status == AuthSessionStatus.ready && scope == null) {
      throw ArgumentError.value(
        scope,
        'scope',
        'must be present for a ready session',
      );
    }
    if (status == AuthSessionStatus.signedOut && scope != null) {
      throw ArgumentError.value(
        scope,
        'scope',
        'must be absent for a signed-out session',
      );
    }
    return AuthSessionSnapshot._(status: status, scope: scope);
  }

  const AuthSessionSnapshot._({required this.status, this.scope});

  /// Creates an authentication state whose readiness is not known yet.
  const AuthSessionSnapshot.unknown()
    : status = AuthSessionStatus.unknown,
      scope = null;

  /// Creates a ready session for [scope].
  const AuthSessionSnapshot.ready(this.scope)
    : status = AuthSessionStatus.ready;

  /// Creates a signed-out session.
  const AuthSessionSnapshot.signedOut()
    : status = AuthSessionStatus.signedOut,
      scope = null;

  /// Current session status.
  final AuthSessionStatus status;

  /// Current non-secret scope, when known.
  final AuthScope? scope;
}

/// Injected auth boundary. Tokens and credential clients stay outside Fasq.
abstract interface class AuthSessionProvider {
  /// Resolves the latest current session before replay.
  Future<AuthSessionSnapshot> currentSession();

  /// Emits session changes that can request another replay attempt.
  Stream<AuthSessionSnapshot> get changes;
}

/// Result of checking one operation against current auth state.
enum AuthExecutionDecision {
  /// Operation may execute under the current session.
  allowed,

  /// Operation must wait for authentication readiness.
  blocked,

  /// Operation belongs to another or revoked scope and must be quarantined.
  quarantined,
}

/// Auth scope gate enforcing exact identity matching.
class AuthScopeGate {
  /// Creates an auth scope gate.
  const AuthScopeGate();

  /// Decides whether [operation] can run under [session].
  AuthExecutionDecision evaluate(
    MutationOperation operation,
    AuthSessionSnapshot session,
  ) {
    if (operation.authPolicy == AuthPolicy.none) {
      return AuthExecutionDecision.allowed;
    }
    final expectedScope = operation.authScope;
    final currentScope = session.scope;
    if (session.status == AuthSessionStatus.signedOut) {
      return expectedScope == null
          ? AuthExecutionDecision.blocked
          : AuthExecutionDecision.quarantined;
    }
    if (session.status == AuthSessionStatus.revoked) {
      return AuthExecutionDecision.quarantined;
    }
    if (session.status != AuthSessionStatus.ready) {
      return AuthExecutionDecision.blocked;
    }
    if (expectedScope == null || currentScope == null) {
      return AuthExecutionDecision.blocked;
    }
    if (currentScope != expectedScope) {
      return AuthExecutionDecision.quarantined;
    }
    return AuthExecutionDecision.allowed;
  }
}

/// In-memory provider useful for lifecycle integration and deterministic tests.
class InMemoryAuthSessionProvider implements AuthSessionProvider {
  /// Creates a provider with an unknown initial session.
  InMemoryAuthSessionProvider({AuthSessionSnapshot? initial})
    : _current = initial ?? const AuthSessionSnapshot.unknown();

  final StreamController<AuthSessionSnapshot> _controller =
      StreamController<AuthSessionSnapshot>.broadcast();
  AuthSessionSnapshot _current;

  @override
  Future<AuthSessionSnapshot> currentSession() async => _current;

  @override
  Stream<AuthSessionSnapshot> get changes => _controller.stream;

  /// Publishes a new non-secret session state.
  void update(AuthSessionSnapshot session) {
    _current = session;
    if (!_controller.isClosed) _controller.add(session);
  }

  /// Closes the provider stream.
  Future<void> dispose() => _controller.close();
}
