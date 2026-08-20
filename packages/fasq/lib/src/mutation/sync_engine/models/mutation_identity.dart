import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:meta/meta.dart';

/// Stable, versioned logical identity for a queueable mutation.
@immutable
class MutationKey {
  /// Creates a versioned mutation key.
  factory MutationKey({
    required String namespace,
    required String name,
    int version = 1,
  }) {
    final normalizedNamespace = _normalizeSegment(namespace, 'namespace');
    final normalizedName = _normalizeSegment(name, 'name');
    if (version < 1) {
      throw ArgumentError.value(version, 'version', 'must be positive');
    }
    return MutationKey._(
      namespace: normalizedNamespace,
      name: normalizedName,
      version: version,
    );
  }

  const MutationKey._({
    required this.namespace,
    required this.name,
    required this.version,
  });

  /// Recreates a key from its serialized fields.
  factory MutationKey.fromJson(Map<String, Object?> json) {
    final namespace = json['namespace'];
    final name = json['name'];
    final version = json['version'];
    if (namespace is! String || name is! String || version is! int) {
      throw const InvalidMutationPayloadException(
        'Invalid mutation key payload',
      );
    }
    return MutationKey(
      namespace: namespace,
      name: name,
      version: version,
    );
  }

  /// Namespace used to avoid collisions between application features.
  final String namespace;

  /// Stable logical mutation name.
  final String name;

  /// Schema version for this logical mutation contract.
  final int version;

  /// Canonical string key suitable for registry and storage lookup.
  String get key => '$namespace:$name:v$version';

  /// Serializes this key into a JSON-safe map.
  Map<String, Object?> toJson() => {
    'namespace': namespace,
    'name': name,
    'version': version,
  };

  @override
  String toString() => key;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MutationKey &&
          namespace == other.namespace &&
          name == other.name &&
          version == other.version;

  @override
  int get hashCode => Object.hash(namespace, name, version);

  static String _normalizeSegment(String value, String fieldName) {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized.contains(':')) {
      throw ArgumentError.value(
        value,
        fieldName,
        'must be non-empty and must not contain a colon',
      );
    }
    return normalized;
  }
}

/// Stable identifier for one durable operation occurrence.
@immutable
class OperationId {
  /// Creates an operation ID.
  factory OperationId(String value) => OperationId._(_requireValue(value));

  const OperationId._(this.value);

  /// Serialized identifier value.
  final String value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is OperationId && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Stable key reused across automatic retries and restarts.
@immutable
class IdempotencyKey {
  /// Creates an idempotency key.
  factory IdempotencyKey(String value) =>
      IdempotencyKey._(_requireValue(value));

  const IdempotencyKey._(this.value);

  /// Serialized key value.
  final String value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is IdempotencyKey && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Identifier connecting an operation and its explicit repairs.
@immutable
class LineageId {
  /// Creates a lineage ID.
  factory LineageId(String value) => LineageId._(_requireValue(value));

  const LineageId._(this.value);

  /// Serialized lineage value.
  final String value;

  @override
  String toString() => value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is LineageId && value == other.value;

  @override
  int get hashCode => value.hashCode;
}

/// Authentication policy selected by a queueable mutation.
enum AuthPolicy {
  /// The operation does not require an authenticated user.
  none,

  /// The operation must replay under its captured [AuthScope].
  required,
}

/// Exact non-secret identity under which required work was queued.
@immutable
class AuthScope {
  /// Creates an authentication scope.
  factory AuthScope({
    required String principalId,
    required String tenantId,
    required String authRealm,
  }) {
    return AuthScope._(
      principalId: _requireValue(principalId),
      tenantId: _requireValue(tenantId),
      authRealm: _requireValue(authRealm),
    );
  }

  const AuthScope._({
    required this.principalId,
    required this.tenantId,
    required this.authRealm,
  });

  /// Recreates a scope from serialized fields.
  factory AuthScope.fromJson(Map<String, Object?> json) {
    final principalId = json['principalId'];
    final tenantId = json['tenantId'];
    final authRealm = json['authRealm'];
    if (principalId is! String || tenantId is! String || authRealm is! String) {
      throw const InvalidMutationPayloadException('Invalid auth scope payload');
    }
    return AuthScope(
      principalId: principalId,
      tenantId: tenantId,
      authRealm: authRealm,
    );
  }

  /// Non-secret principal identifier.
  final String principalId;

  /// Non-secret tenant or account identifier.
  final String tenantId;

  /// Non-secret authentication realm identifier.
  final String authRealm;

  /// Stable scope key for filtering and ownership checks.
  String get scopeKey => '$authRealm:$tenantId:$principalId';

  /// Serializes this scope into a JSON-safe map.
  Map<String, Object?> toJson() => {
    'principalId': principalId,
    'tenantId': tenantId,
    'authRealm': authRealm,
  };

  @override
  String toString() => scopeKey;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthScope &&
          principalId == other.principalId &&
          tenantId == other.tenantId &&
          authRealm == other.authRealm;

  @override
  int get hashCode => Object.hash(principalId, tenantId, authRealm);
}

/// Explicit dependency edge from a child operation to a parent operation.
@immutable
class MutationDependency {
  /// Creates a dependency descriptor.
  factory MutationDependency({
    required OperationId parentOperationId,
    String? parentResultPath,
    String? childVariablePath,
  }) {
    return MutationDependency._(
      parentOperationId: parentOperationId,
      parentResultPath: _normalizeOptionalPath(parentResultPath),
      childVariablePath: _normalizeOptionalPath(childVariablePath),
    );
  }

  const MutationDependency._({
    required this.parentOperationId,
    required this.parentResultPath,
    required this.childVariablePath,
  });

  /// Recreates a dependency from serialized fields.
  factory MutationDependency.fromJson(Map<String, Object?> json) {
    final parentId = json['parentOperationId'];
    if (parentId is! String) {
      throw const InvalidMutationPayloadException(
        'Invalid mutation dependency payload',
      );
    }
    return MutationDependency(
      parentOperationId: OperationId(parentId),
      parentResultPath: _optionalString(json['parentResultPath']),
      childVariablePath: _optionalString(json['childVariablePath']),
    );
  }

  /// Parent operation that must complete before the child can execute.
  final OperationId parentOperationId;

  /// Optional selected path from the parent result.
  final String? parentResultPath;

  /// Optional child-variable path receiving the selected parent result.
  final String? childVariablePath;

  /// Serializes this dependency into a JSON-safe map.
  Map<String, Object?> toJson() => {
    'parentOperationId': parentOperationId.value,
    'parentResultPath': parentResultPath,
    'childVariablePath': childVariablePath,
  };

  static String? _normalizeOptionalPath(String? path) {
    final normalized = path?.trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static String? _optionalString(Object? value) {
    if (value == null) return null;
    if (value is String) return value;
    throw const InvalidMutationPayloadException(
      'Dependency paths must be strings',
    );
  }
}

/// Explicit cache projection plan reference.
@immutable
class MutationProjectionDescriptor {
  /// Creates a projection descriptor.
  factory MutationProjectionDescriptor({
    required String id,
    required List<String> queryKeys,
  }) {
    final normalizedId = _requireValue(id);
    final normalizedKeys = queryKeys.map(_requireValue).toList();
    if (normalizedKeys.isEmpty) {
      throw ArgumentError.value(queryKeys, 'queryKeys', 'must not be empty');
    }
    return MutationProjectionDescriptor._(
      id: normalizedId,
      queryKeys: List.unmodifiable(normalizedKeys),
    );
  }

  const MutationProjectionDescriptor._({
    required this.id,
    required this.queryKeys,
  });

  /// Recreates a descriptor from serialized fields.
  factory MutationProjectionDescriptor.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final rawKeys = json['queryKeys'];
    if (id is! String || rawKeys is! List<Object?>) {
      throw const InvalidMutationPayloadException(
        'Invalid mutation projection payload',
      );
    }
    return MutationProjectionDescriptor(
      id: id,
      queryKeys: rawKeys.map(_decodeQueryKey).toList(),
    );
  }

  /// Stable projection plan identifier.
  final String id;

  /// Query keys explicitly affected by the plan.
  final List<String> queryKeys;

  /// Returns this descriptor with references to one identifier remapped.
  MutationProjectionDescriptor mapKeys(String from, String to) =>
      MutationProjectionDescriptor(
        id: id,
        queryKeys: queryKeys
            .map((key) => remapQueryKeyIdentifier(key, from, to))
            .toList(),
      );

  /// Serializes this descriptor into a JSON-safe map.
  Map<String, Object?> toJson() => {'id': id, 'queryKeys': queryKeys};

  static String _decodeQueryKey(Object? value) {
    if (value is String) return value;
    throw const InvalidMutationPayloadException(
      'Projection query keys must be strings',
    );
  }
}

/// Remaps one exact identifier segment in a serialized query key.
///
/// Query keys are opaque to the mutation payload, so only their established
/// `:` or `/`-delimited identifier segments are eligible for remapping.
String remapQueryKeyIdentifier(String queryKey, String from, String to) {
  if (from.isEmpty || to.isEmpty || queryKey == from) {
    return queryKey == from && to.isNotEmpty ? to : queryKey;
  }
  final segment = RegExp(
    '(^|[:/])${RegExp.escape(from)}(?=[:/]|\$)',
  );
  return queryKey.replaceAllMapped(
    segment,
    (match) => '${match.group(1) ?? ''}$to',
  );
}

String _requireValue(String value) {
  final normalized = value.trim();
  if (normalized.isEmpty) {
    throw ArgumentError.value(value, 'value', 'must not be empty');
  }
  return normalized;
}
