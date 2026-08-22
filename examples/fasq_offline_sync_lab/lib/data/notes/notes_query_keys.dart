import 'package:fasq/fasq.dart';

import '../../domain/lab_note.dart';

part 'notes_query_keys.g.dart';

/// Typed query keys used by the durable notes cache.
@AutoRegisterSerializers()
class NotesQueryKeys {
  NotesQueryKeys._();

  static TypedQueryKey<List<LabNote>> notes(String owner) =>
      TypedQueryKey<List<LabNote>>(
        'offline_sync_lab:notes:v1:$owner',
        List<LabNote>,
      );
}
