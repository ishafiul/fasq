// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_mutations.dart';

// **************************************************************************
// MutationGenerator
// **************************************************************************

// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
const createTodoMutationKey = FasqMutationKey<Todo, CreateTodoRequest>(
  namespace: "fasq_example",
  name: "create_todo",
  version: 1,
);

final createTodoDurable = createTodoDurableHandle(execute: createTodo);

DurableMutation<Todo, CreateTodoRequest> createTodoDurableHandle({
  required Future<Todo> Function(CreateTodoRequest) execute,
}) => DurableMutation<Todo, CreateTodoRequest>.define(
  key: createTodoMutationKey,
  codec: JsonMutationCodec<CreateTodoRequest>(
    encoder: (value) => value.toJson(),
    decoder: (payload) =>
        CreateTodoRequest.fromJson(Map<String, Object?>.from(payload as Map)),
  ),
  execute: execute,
  authPolicy: AuthPolicy.none,
  resultEncoder: (data) => data.toJson(),
);
