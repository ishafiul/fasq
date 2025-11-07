import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import 'dart:async';
import '../../widgets/example_scaffold.dart';
import '../../services/models.dart';

class OptimisticUpdatesScreen extends StatefulWidget {
  const OptimisticUpdatesScreen({super.key});

  @override
  State<OptimisticUpdatesScreen> createState() =>
      _OptimisticUpdatesScreenState();
}

class _OptimisticUpdatesScreenState extends State<OptimisticUpdatesScreen> {
  late Mutation<Todo, CreateTodoRequest> _mutation;
  StreamSubscription? _subscription;
  final List<Todo> _todoList = [];
  final TextEditingController _titleController = TextEditingController();
  int _nextId = 1000; // Temp ID counter for optimistic updates
  bool _hasText = false; // Track if text field has content

  @override
  void initState() {
    super.initState();
    _initializeMutation();
    // Listen to text changes to enable/disable button
    _titleController.addListener(() {
      setState(() {
        _hasText = _titleController.text.trim().isNotEmpty;
      });
    });
  }

  void _initializeMutation() {
    _mutation = Mutation<Todo, CreateTodoRequest>(
      mutationFn: (request) async {
        // Simulate network delay
        await Future.delayed(const Duration(milliseconds: 1500));

        // Simulate occasional error (20% chance)
        if (DateTime.now().millisecond % 10 < 2) {
          throw Exception('Network error - failed to create todo');
        }

        // Return the created todo
        return Todo(
          id: DateTime.now().millisecondsSinceEpoch,
          userId: request.userId,
          title: request.title,
          completed: request.completed,
        );
      },
      options: MutationOptions<Todo, CreateTodoRequest>(
        onMutate: (data, variables) {
          // Optimistic update: add immediately with temp ID
          final optimisticTodo = Todo(
            id: _nextId++, // Temporary ID
            userId: variables.userId,
            title: variables.title,
            completed: variables.completed,
          );

          setState(() {
            _todoList.insert(0, optimisticTodo);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.timer, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Creating "${variables.title}" (optimistic)...',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 1),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        onSuccess: (data) {
          // Replace temporary todo with real one from server
          setState(() {
            // Remove the optimistic todo (by finding the one with similar title)
            _todoList.removeWhere((todo) =>
                    todo.title == data.title &&
                    todo.id < 10000 // Temp IDs are < 10000
                );
            // Add the real todo
            _todoList.insert(0, data);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Todo created: "${data.title}"',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
            ),
          );

          _titleController.clear();
        },
        onError: (error) {
          // Rollback: remove the optimistic todo on error
          setState(() {
            _todoList.removeWhere((todo) => todo.id < 10000 // Remove temp IDs
                );
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Error: $error',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
      ),
    );

    _subscription = _mutation.stream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _mutation.dispose();
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Optimistic Updates',
      description:
          'Demonstrates optimistic updates pattern. The UI updates immediately with expected data before the server responds. If the mutation fails, the changes are rolled back. This provides instant feedback and better UX.',
      codeSnippet: '''
MutationOptions<Todo, CreateTodoRequest>(
  // Called when mutation starts
  onMutate: (data, variables) {
    // Add item optimistically with temp ID
    final optimisticTodo = Todo(
      id: generateTempId(),
      title: variables.title,
      completed: false,
    );
    
    setState(() {
      todos.insert(0, optimisticTodo);
    });
    
    // Show optimistic notification
    showSnackBar('Creating...');
  },
  
  // Called when mutation succeeds
  onSuccess: (data) {
    // Replace temp item with real one
    setState(() {
      todos.removeWhere((t) => t.isTemporary);
      todos.insert(0, data);
    });
    
    showSnackBar('Created: \${data.title}');
  },
  
  // Called when mutation fails
  onError: (error) {
    // Rollback the optimistic update
    setState(() {
      todos.removeWhere((t) => t.isTemporary);
    });
    
    showSnackBar('Error: \$error');
  },
)

// Benefits:
// - Instant UI feedback
// - Better perceived performance
// - Automatic rollback on error
// - Smooth user experience
''',
      child: Column(
        children: [
          _buildInstructions(),
          const SizedBox(height: 16),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildCreateForm(),
                  const SizedBox(height: 16),
                  _buildTodoList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Optimistic Updates:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1️⃣ Create a todo - it appears INSTANTLY (optimistic)\n'
            '2️⃣ Watch the blue snackbar "Creating..." (optimistic)\n'
            '3️⃣ After 1.5s, server confirms - green "Created" appears\n'
            '4️⃣ Temp ID is replaced with real server ID\n'
            '5️⃣ If error occurs (20% chance) - todo is rolled back\n'
            '6️⃣ Experience instant feedback without waiting for network',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildCreateForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Todo (Optimistic)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'Todo Title',
              hintText: 'Enter todo title...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.task),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _hasText
                  ? () {
                      final request = CreateTodoRequest(
                        userId: 1,
                        title: _titleController.text.trim(),
                        completed: false,
                      );

                      _mutation.mutate(request);
                    }
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('Create Todo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodoList() {
    if (_todoList.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          children: [
            Icon(
              Icons.inbox,
              size: 48,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'No todos yet',
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Create a todo to see optimistic updates',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  Icons.list,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Todos (${_todoList.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todoList.length,
            itemBuilder: (context, index) {
              final todo = _todoList[index];
              final isOptimistic = todo.id < 10000;

              return Container(
                decoration: BoxDecoration(
                  color: isOptimistic ? Colors.blue.withOpacity(0.1) : null,
                ),
                child: ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isOptimistic ? Colors.blue : Colors.green,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isOptimistic ? Icons.timer : Icons.check,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    todo.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: isOptimistic ? Colors.blue : null,
                    ),
                  ),
                  subtitle: Text(
                    isOptimistic
                        ? 'Creating... (optimistic)'
                        : 'ID: ${todo.id} • Created',
                  ),
                  trailing: isOptimistic
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle, color: Colors.green),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
