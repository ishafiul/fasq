import 'package:fasq/src/mutation/sync_engine/models/mutation_errors.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_identity.dart';
import 'package:fasq/src/mutation/sync_engine/models/mutation_json.dart';
import 'package:fasq/src/query/keys/query_key.dart';

typedef ProjectionReducer = Object? Function(Object? base, Object? value);

class ProjectionPlan {
  factory ProjectionPlan({
    required String id,
    required List<QueryKey> queryKeys,
    int version = 1,
  }) {
    final name = id.trim();
    final keys = queryKeys.map((key) => key.key.trim()).toSet();
    if (name.isEmpty ||
        keys.isEmpty ||
        keys.any((key) => key.isEmpty) ||
        version < 1) {
      throw ArgumentError('Projection plan has invalid identity or keys');
    }
    return ProjectionPlan._(name, version, List.unmodifiable(keys));
  }

  factory ProjectionPlan.fromJson(Map<String, Object?> json) {
    final id = json['id'];
    final version = json['version'];
    final keys = json['queryKeys'];
    if (id is! String ||
        version is! int ||
        keys is! List<Object?> ||
        keys.any((key) => key is! String)) {
      throw const InvalidMutationPayloadException('Invalid projection plan');
    }
    return ProjectionPlan(
      id: id,
      version: version,
      queryKeys: keys.cast<String>().map(StringQueryKey.new).toList(),
    );
  }

  const ProjectionPlan._(this.id, this.version, this.queryKeys);

  final String id;
  final int version;
  final List<String> queryKeys;
  String get registryKey => '$id:v$version';

  ProjectionPlan mapKeys(String from, String to) => ProjectionPlan._(
    id,
    version,
    queryKeys.map((key) => key.replaceAll(from, to)).toList(),
  );

  Map<String, Object?> toJson() => {
    'id': id,
    'version': version,
    'queryKeys': queryKeys,
  };
}

class ProjectionDefinition {
  const ProjectionDefinition({
    required this.plan,
    required this.apply,
    this.reconcile,
  });

  final ProjectionPlan plan;
  final ProjectionReducer apply;
  final ProjectionReducer? reconcile;
}

class ProjectionRegistry {
  final Map<String, ProjectionDefinition> _items = {};

  void register(ProjectionDefinition definition) {
    if (_items.containsKey(definition.plan.registryKey)) {
      throw StateError('Projection plan already registered');
    }
    _items[definition.plan.registryKey] = definition;
  }

  ProjectionDefinition? find(ProjectionPlan plan) => _items[plan.registryKey];
}

enum ProjectionOverlayState {
  pending,
  retryScheduled,
  authBlocked,
  blocked,
  conflicted,
  projectionError,
  resolved,
}

class ProjectionOverlay {
  factory ProjectionOverlay({
    required OperationId operationId,
    required LineageId lineageId,
    required ProjectionPlan plan,
    required Map<String, Object?> patches,
    Map<String, Object?> references = const {},
    Map<String, String> temporaryIds = const {},
    int sequence = 0,
    ProjectionOverlayState state = ProjectionOverlayState.pending,
  }) {
    if (sequence < 0 ||
        patches.keys.any((key) => !plan.queryKeys.contains(key))) {
      throw ArgumentError('Projection overlay does not match its plan');
    }
    _jsonMap(patches, 'patches');
    _jsonMap(references, 'references');
    return ProjectionOverlay._(
      operationId,
      lineageId,
      plan,
      _freezeMap(patches),
      _freezeMap(references),
      Map.unmodifiable(temporaryIds),
      sequence,
      state,
    );
  }

  factory ProjectionOverlay.fromJson(Map<String, Object?> json) {
    final plan = json['plan'];
    final patches = json['patches'];
    final refs = json['references'];
    final ids = json['temporaryIds'];
    final state = json['state'];
    if (json['operationId'] is! String ||
        json['lineageId'] is! String ||
        plan is! Map<Object?, Object?> ||
        patches is! Map<Object?, Object?> ||
        refs is! Map<Object?, Object?> ||
        ids is! Map<Object?, Object?> ||
        json['sequence'] is! int ||
        state is! String) {
      throw const InvalidMutationPayloadException('Invalid projection overlay');
    }
    final parsed = ProjectionOverlayState.values.where(
      (item) => item.name == state,
    );
    if (parsed.isEmpty) {
      throw const InvalidMutationPayloadException('Unknown projection state');
    }
    final rawIds = _stringMap(ids);
    if (rawIds.values.any((value) => value is! String)) {
      throw const InvalidMutationPayloadException('Invalid temporary ID map');
    }
    return ProjectionOverlay(
      operationId: OperationId(json['operationId']! as String),
      lineageId: LineageId(json['lineageId']! as String),
      plan: ProjectionPlan.fromJson(_stringMap(plan)),
      patches: _stringMap(patches),
      references: _stringMap(refs),
      temporaryIds: rawIds.cast<String, String>(),
      sequence: json['sequence']! as int,
      state: parsed.first,
    );
  }

  const ProjectionOverlay._(
    this.operationId,
    this.lineageId,
    this.plan,
    this.patches,
    this.references,
    this.temporaryIds,
    this.sequence,
    this.state,
  );

  final OperationId operationId;
  final LineageId lineageId;
  final ProjectionPlan plan;
  final Map<String, Object?> patches;
  final Map<String, Object?> references;
  final Map<String, String> temporaryIds;
  final int sequence;
  final ProjectionOverlayState state;

  ProjectionOverlay withState(ProjectionOverlayState value) =>
      ProjectionOverlay._(
        operationId,
        lineageId,
        plan,
        patches,
        references,
        temporaryIds,
        sequence,
        value,
      );

  Map<String, Object?> toJson() => {
    'operationId': operationId.value,
    'lineageId': lineageId.value,
    'plan': plan.toJson(),
    'patches': patches,
    'references': references,
    'temporaryIds': temporaryIds,
    'sequence': sequence,
    'state': state.name,
  };
}

class ProjectionState {
  ProjectionState({
    Map<String, Object?> remoteBases = const {},
    Map<String, int?> revisions = const {},
    List<ProjectionOverlay> overlays = const [],
    Map<String, String?> idMappings = const {},
  }) : remoteBases = _freezeMap(remoteBases),
       revisions = Map.unmodifiable(revisions),
       overlays = List.unmodifiable(overlays),
       idMappings = Map.unmodifiable(idMappings);

  factory ProjectionState.fromJson(Map<String, Object?> json) {
    final bases = json['remoteBases'];
    final revisions = json['revisions'];
    final overlays = json['overlays'];
    final mappings = json['idMappings'];
    if (bases is! Map<Object?, Object?> ||
        revisions is! Map<Object?, Object?> ||
        overlays is! List<Object?> ||
        mappings is! Map<Object?, Object?>) {
      throw const InvalidMutationPayloadException('Invalid projection state');
    }
    final rawRevisions = _stringMap(revisions);
    if (rawRevisions.values.any((value) => value != null && value is! int)) {
      throw const InvalidMutationPayloadException(
        'Invalid projection revision',
      );
    }
    return ProjectionState(
      remoteBases: _stringMap(bases),
      revisions: rawRevisions.cast<String, int?>(),
      overlays: overlays
          .map((item) => ProjectionOverlay.fromJson(_objectMap(item)))
          .toList(),
      idMappings: _stringMap(mappings).cast<String, String?>(),
    );
  }

  final Map<String, Object?> remoteBases;
  final Map<String, int?> revisions;
  final List<ProjectionOverlay> overlays;
  final Map<String, String?> idMappings;

  Map<String, Object?> toJson() => {
    'remoteBases': remoteBases,
    'revisions': revisions,
    'overlays': overlays.map((item) => item.toJson()).toList(),
    'idMappings': idMappings,
  };
}

class ProjectionFailure {
  const ProjectionFailure(this.operationId, this.queryKey, this.messageKey);

  final OperationId? operationId;
  final String? queryKey;
  final String messageKey;
}

class ProjectionView {
  const ProjectionView(this.value, this.failure);

  final Object? value;
  final ProjectionFailure? failure;
}

class ProjectionOutcome {
  const ProjectionOutcome(this.state, this.changedKeys, [this.failure]);

  final ProjectionState state;
  final List<String> changedKeys;
  final ProjectionFailure? failure;
  bool get succeeded => failure == null;
}

enum ProjectionRepairAction { replace, discard }

class ProjectionCoordinator {
  ProjectionCoordinator({required this.registry, ProjectionState? state})
    : _state = state ?? ProjectionState();

  final ProjectionRegistry registry;
  ProjectionState _state;
  ProjectionState get state => _state;

  /// Restores durable projection state after the outbox has opened.
  void restore(ProjectionState state) {
    _state = state;
  }

  ProjectionOutcome enqueue(ProjectionOverlay overlay) {
    final next =
        _state.overlays.fold<int>(
          0,
          (max, item) => item.sequence > max ? item.sequence : max,
        ) +
        1;
    final stored = overlay.sequence >= next
        ? overlay
        : ProjectionOverlay(
            operationId: overlay.operationId,
            lineageId: overlay.lineageId,
            plan: overlay.plan,
            patches: overlay.patches,
            references: overlay.references,
            temporaryIds: overlay.temporaryIds,
            sequence: next,
            state: overlay.state,
          );
    _state = ProjectionState(
      remoteBases: _state.remoteBases,
      revisions: _state.revisions,
      overlays: [..._state.overlays, stored],
      idMappings: {
        ..._state.idMappings,
        for (final id in stored.temporaryIds.values) id: null,
      },
    );
    return ProjectionOutcome(_state, stored.plan.queryKeys);
  }

  ProjectionOutcome setRemoteBase(
    QueryKey key,
    Object? value, {
    int? revision,
  }) {
    try {
      validateJsonValue(value, 'remoteBase');
      final oldRevision = _state.revisions[key.key];
      if (oldRevision != null && revision != null && revision < oldRevision) {
        return ProjectionOutcome(_state, const []);
      }
      _state = ProjectionState(
        remoteBases: {..._state.remoteBases, key.key: value},
        revisions: {..._state.revisions, key.key: revision},
        overlays: _state.overlays,
        idMappings: _state.idMappings,
      );
      return ProjectionOutcome(_state, [key.key]);
    } on Object {
      return ProjectionOutcome(
        _state,
        const [],
        const ProjectionFailure(null, null, 'projection.remote_base_failed'),
      );
    }
  }

  ProjectionView materialize(QueryKey key) {
    Object? value = _state.remoteBases[key.key];
    ProjectionFailure? failure;
    final overlays = [..._state.overlays]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    for (final overlay in overlays.where(
      (item) =>
          item.state != ProjectionOverlayState.resolved &&
          item.patches.containsKey(key.key),
    )) {
      final definition = registry.find(overlay.plan);
      if (definition == null) {
        failure = ProjectionFailure(
          overlay.operationId,
          key.key,
          'projection.plan_unregistered',
        );
        continue;
      }
      try {
        value = definition.apply(value, overlay.patches[key.key]);
      } on Object {
        failure = ProjectionFailure(
          overlay.operationId,
          key.key,
          'projection.apply_failed',
        );
      }
    }
    return ProjectionView(value, failure);
  }

  ProjectionOutcome complete(OperationId operationId, Object? result) {
    final index = _indexOf(operationId);
    if (index < 0) return ProjectionOutcome(_state, const []);
    final overlay = _state.overlays[index];
    final definition = registry.find(overlay.plan);
    if (definition == null)
      return _error(index, 'projection.plan_unregistered');
    try {
      final bases = {..._state.remoteBases};
      if (definition.reconcile != null) {
        for (final key in overlay.plan.queryKeys) {
          bases[key] = definition.reconcile!(bases[key], result);
        }
      }
      _state = ProjectionState(
        remoteBases: bases,
        revisions: _state.revisions,
        overlays: [..._state.overlays]..removeAt(index),
        idMappings: _state.idMappings,
      );
      return ProjectionOutcome(_state, overlay.plan.queryKeys);
    } on Object {
      return _error(index, 'projection.reconcile_failed');
    }
  }

  ProjectionOutcome markConflict(
    OperationId operationId, {
    QueryKey? remoteKey,
    Object? remoteValue,
    int? revision,
  }) {
    final index = _indexOf(operationId);
    if (index < 0) return ProjectionOutcome(_state, const []);
    final overlay = _state.overlays[index];
    _state = ProjectionState(
      remoteBases: _state.remoteBases,
      revisions: _state.revisions,
      overlays: [..._state.overlays]
        ..[index] = overlay.withState(ProjectionOverlayState.conflicted),
      idMappings: _state.idMappings,
    );
    final base = remoteKey == null
        ? ProjectionOutcome(_state, const [])
        : setRemoteBase(remoteKey, remoteValue, revision: revision);
    return ProjectionOutcome(
      _state,
      {...base.changedKeys, ...overlay.plan.queryKeys}.toList(),
    );
  }

  ProjectionOutcome fail(OperationId operationId) => _remove(operationId);
  ProjectionOutcome discard(OperationId operationId) => _remove(operationId);

  ProjectionOutcome repair({
    required OperationId conflictedOperationId,
    required ProjectionRepairAction action,
    OperationId? replacementOperationId,
    LineageId? replacementLineageId,
    ProjectionPlan? replacementPlan,
    Map<String, Object?> replacementPatches = const {},
  }) {
    final index = _indexOf(conflictedOperationId);
    if (index < 0) return ProjectionOutcome(_state, const []);
    if (action == ProjectionRepairAction.discard)
      return discard(conflictedOperationId);
    if (replacementOperationId == null ||
        replacementLineageId == null ||
        replacementPlan == null) {
      return ProjectionOutcome(
        _state,
        const [],
        const ProjectionFailure(
          null,
          null,
          'projection.repair_identity_required',
        ),
      );
    }
    final old = _state.overlays[index].withState(
      ProjectionOverlayState.resolved,
    );
    _state = ProjectionState(
      remoteBases: _state.remoteBases,
      revisions: _state.revisions,
      overlays: [..._state.overlays]..[index] = old,
      idMappings: _state.idMappings,
    );
    return enqueue(
      ProjectionOverlay(
        operationId: replacementOperationId,
        lineageId: replacementLineageId,
        plan: replacementPlan,
        patches: replacementPatches,
      ),
    );
  }

  ProjectionOutcome remapId({
    required String temporaryId,
    required String serverId,
  }) {
    if (temporaryId.isEmpty || serverId.isEmpty) {
      return ProjectionOutcome(
        _state,
        const [],
        const ProjectionFailure(null, null, 'projection.id_mapping_failed'),
      );
    }
    final remap = (Object? value) => _replace(value, temporaryId, serverId);
    final bases = <String, Object?>{};
    for (final entry in _state.remoteBases.entries) {
      bases[_replace(entry.key, temporaryId, serverId) as String] = remap(
        entry.value,
      );
    }
    final overlays = _state.overlays
        .map(
          (overlay) => ProjectionOverlay(
            operationId: overlay.operationId,
            lineageId: overlay.lineageId,
            plan: overlay.plan.mapKeys(temporaryId, serverId),
            patches: overlay.patches.map(
              (key, value) => MapEntry(
                _replace(key, temporaryId, serverId) as String,
                remap(value),
              ),
            ),
            references: _stringMap(
              remap(overlay.references) as Map<Object?, Object?>,
            ),
            temporaryIds: overlay.temporaryIds.map(
              (key, value) => MapEntry(
                key,
                value == temporaryId ? serverId : value,
              ),
            ),
            sequence: overlay.sequence,
            state: overlay.state,
          ),
        )
        .toList();
    _state = ProjectionState(
      remoteBases: bases,
      revisions: _state.revisions.map(
        (key, value) =>
            MapEntry(_replace(key, temporaryId, serverId) as String, value),
      ),
      overlays: overlays,
      idMappings: {..._state.idMappings, temporaryId: serverId},
    );
    return ProjectionOutcome(_state, [...bases.keys]);
  }

  int _indexOf(OperationId id) =>
      _state.overlays.indexWhere((item) => item.operationId == id);

  ProjectionOutcome _remove(OperationId id) {
    final index = _indexOf(id);
    if (index < 0) return ProjectionOutcome(_state, const []);
    final overlay = _state.overlays[index];
    _state = ProjectionState(
      remoteBases: _state.remoteBases,
      revisions: _state.revisions,
      overlays: [..._state.overlays]..removeAt(index),
      idMappings: _state.idMappings,
    );
    return ProjectionOutcome(_state, overlay.plan.queryKeys);
  }

  ProjectionOutcome _error(int index, String key) {
    final overlay = _state.overlays[index];
    _state = ProjectionState(
      remoteBases: _state.remoteBases,
      revisions: _state.revisions,
      overlays: [..._state.overlays]
        ..[index] = overlay.withState(ProjectionOverlayState.projectionError),
      idMappings: _state.idMappings,
    );
    return ProjectionOutcome(
      _state,
      overlay.plan.queryKeys,
      ProjectionFailure(overlay.operationId, null, key),
    );
  }
}

void _jsonMap(Map<String, Object?> value, String path) {
  for (final item in value.entries)
    validateJsonValue(item.value, '$path.${item.key}');
}

Map<String, Object?> _freezeMap(Map<String, Object?> value) => Map.unmodifiable(
  value.map((key, item) => MapEntry(key, _freeze(item))),
);

Object? _freeze(Object? value) {
  validateJsonValue(value);
  if (value is List<Object?>) {
    return List<Object?>.unmodifiable(value.map(_freeze));
  }
  if (value is Map<Object?, Object?>) return _freezeMap(_stringMap(value));
  return value;
}

Map<String, Object?> _stringMap(Map<Object?, Object?> value) {
  final result = <String, Object?>{};
  for (final item in value.entries) {
    if (item.key is! String) {
      throw const InvalidMutationPayloadException(
        'Projection map key is not a string',
      );
    }
    result[item.key! as String] = item.value;
  }
  return result;
}

Map<String, Object?> _objectMap(Object? value) {
  if (value is! Map<Object?, Object?>) {
    throw const InvalidMutationPayloadException('Expected projection object');
  }
  return _stringMap(value);
}

Object? _replace(Object? value, String from, String to) {
  if (value is String) return value.replaceAll(from, to);
  if (value is List<Object?>)
    return value.map((item) => _replace(item, from, to)).toList();
  if (value is Map<Object?, Object?>) {
    return value.map(
      (key, item) => MapEntry(
        (key as String).replaceAll(from, to),
        _replace(item, from, to),
      ),
    );
  }
  return value;
}
