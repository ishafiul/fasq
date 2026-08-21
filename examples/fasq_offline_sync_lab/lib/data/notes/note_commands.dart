class CreateNoteCommand {
  const CreateNoteCommand({
    required this.localId,
    required this.title,
    required this.owner,
  });

  final String localId;
  final String title;
  final String owner;

  Map<String, Object?> toJson() => {
    'localId': localId,
    'title': title,
    'owner': owner,
  };

  static CreateNoteCommand fromJson(Object? payload) {
    final map = _jsonObject(payload);
    return CreateNoteCommand(
      localId: _requiredString(map, 'localId'),
      title: _requiredString(map, 'title'),
      owner: _requiredString(map, 'owner'),
    );
  }
}

class UpdateNoteCommand {
  const UpdateNoteCommand({
    required this.noteId,
    required this.title,
    required this.owner,
  });

  final String noteId;
  final String title;
  final String owner;

  Map<String, Object?> toJson() => {
    'noteId': noteId,
    'title': title,
    'owner': owner,
  };

  static UpdateNoteCommand fromJson(Object? payload) {
    final map = _jsonObject(payload);
    return UpdateNoteCommand(
      noteId: _requiredString(map, 'noteId'),
      title: _requiredString(map, 'title'),
      owner: _requiredString(map, 'owner'),
    );
  }
}

class NoteMutationResult {
  const NoteMutationResult({required this.id, this.localId, this.title});

  final String id;
  final String? localId;
  final String? title;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    if (localId != null) 'localId': localId,
    if (title != null) 'title': title,
  };
}

Map<String, Object?> _jsonObject(Object? payload) {
  if (payload is! Map) {
    throw const FormatException('Expected JSON object');
  }
  return <String, Object?>{
    for (final entry in payload.entries)
      if (entry.key is String) entry.key as String: entry.value,
  };
}

String _requiredString(Map<String, Object?> payload, String key) {
  final value = payload[key];
  if (value is! String || value.isEmpty) {
    throw FormatException('Expected non-empty string for $key');
  }
  return value;
}
