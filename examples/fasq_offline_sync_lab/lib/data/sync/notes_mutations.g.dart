// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notes_mutations.dart';

// **************************************************************************
// MutationGenerator
// **************************************************************************

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
const createNoteMutationKey =
    FasqMutationKey<NoteMutationResult, CreateNoteCommand>(
      namespace: "offline_sync_lab",
      name: "create_note",
      version: 1,
    );

DurableMutation<NoteMutationResult, CreateNoteCommand> createNoteDurableHandle({
  required Future<NoteMutationResult> Function(CreateNoteCommand) execute,
}) => DurableMutation<NoteMutationResult, CreateNoteCommand>.define(
  key: createNoteMutationKey,
  codec: JsonMutationCodec<CreateNoteCommand>(
    encoder: (value) => value.toJson(),
    decoder: (payload) =>
        CreateNoteCommand.fromJson(Map<String, Object?>.from(payload as Map)),
  ),
  execute: execute,
  authPolicy: AuthPolicy.required,
  resultEncoder: (data) => data.toJson(),
);

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
const updateNoteMutationKey =
    FasqMutationKey<NoteMutationResult, UpdateNoteCommand>(
      namespace: "offline_sync_lab",
      name: "update_note",
      version: 1,
    );

DurableMutation<NoteMutationResult, UpdateNoteCommand> updateNoteDurableHandle({
  required Future<NoteMutationResult> Function(UpdateNoteCommand) execute,
}) => DurableMutation<NoteMutationResult, UpdateNoteCommand>.define(
  key: updateNoteMutationKey,
  codec: JsonMutationCodec<UpdateNoteCommand>(
    encoder: (value) => value.toJson(),
    decoder: (payload) =>
        UpdateNoteCommand.fromJson(Map<String, Object?>.from(payload as Map)),
  ),
  execute: execute,
  authPolicy: AuthPolicy.required,
  resultEncoder: (data) => data.toJson(),
  dependencies: <FasqMutationDependency<Object?, Object?, Object?, Object?>>[
    FasqMutationDependency<
      NoteMutationResult,
      CreateNoteCommand,
      UpdateNoteCommand,
      String
    >(
      dependsOn: const FasqMutationKey<NoteMutationResult, CreateNoteCommand>(
        namespace: "offline_sync_lab",
        name: "create_note",
        version: 1,
      ),
      fromResult: const FasqMutationField<NoteMutationResult, String>("id"),
      toInput: const FasqMutationField<UpdateNoteCommand, String>("noteId"),
    ),
  ],
);
