import 'package:fasq/fasq.dart';

import '../../services/models.dart';

part 'offline_mutations.g.dart';

@FasqMutation(
  namespace: 'fasq_example',
  name: 'create_todo',
  encodeResult: true,
)
Future<Todo> createTodo(CreateTodoRequest request) async {
  if (!NetworkStatus.instance.isOnline) {
    throw StateError('Network is offline');
  }

  await Future<void>.delayed(const Duration(milliseconds: 500));
  return Todo(
    id: DateTime.now().millisecondsSinceEpoch,
    userId: request.userId,
    title: request.title,
    completed: request.completed,
  );
}
