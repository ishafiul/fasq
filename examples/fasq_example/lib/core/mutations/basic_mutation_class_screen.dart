import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

class BasicMutationClassScreen extends StatefulWidget {
  const BasicMutationClassScreen({super.key});

  @override
  State<BasicMutationClassScreen> createState() =>
      _BasicMutationClassScreenState();
}

class _BasicMutationClassScreenState
    extends State<BasicMutationClassScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();

  @override
  void dispose() {
    _titleController.dispose();
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Basic Mutation',
      description:
          'Demonstrates how to create and update data using mutations. Mutations are used for creating, updating, and deleting data, unlike queries which are for reading data.',
      codeSnippet: '''
// Define mutation function
Future<Todo> createTodo(CreateTodoRequest request) {
  return ApiService.createTodo(request);
}

// Use MutationBuilder
MutationBuilder<Todo, CreateTodoRequest>(
  mutationFn: createTodo,
  builder: (context, state, mutate) {
    // state: Current mutation state (idle, loading, success, error)
    // mutate: Function to trigger the mutation
    
    if (state.isLoading) {
      return LoadingButton(message: 'Creating...');
    }
    
    if (state.isSuccess) {
      return SuccessWidget(data: state.data!);
    }
    
    if (state.isError) {
      return ErrorWidget(error: state.error);
    }
    
    return CreateButton(
      onPressed: () => mutate(CreateTodoRequest(
        userId: 1,
        title: 'New Todo',
      )),
    );
  },
)

// Key differences from queries:
// - Mutations are triggered manually (no auto-fetch)
// - Mutations are for write operations (POST, PUT, DELETE)
// - Mutations have onSuccess/onError callbacks
// - Mutations support optimistic updates and rollback
''',
      child: Column(
        children: [
          _buildInstructions(),
          const SizedBox(height: 16),
          _buildForm(context),
          const SizedBox(height: 16),
          Expanded(
            child: MutationBuilder<Todo, CreateTodoRequest>(
              mutationFn: (request) => ApiService.createTodo(request),
              options: MutationOptions<Todo, CreateTodoRequest>(
                onSuccess: (data) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Todo created: ${data.title}',
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
                    // Clear form
                    _titleController.clear();
                    _userIdController.clear();
                  }
                },
                onError: (error) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(Icons.error, color: Colors.white),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Error: ${error.toString()}',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              builder: (context, state, mutate) {
                return Column(
                  children: [
                    if (state.isSuccess && state.hasData) ...[
                      _buildSuccessCard(state.data!, isSuccess: true),
                      const SizedBox(height: 16),
                    ],
                    if (state.isError) ...[
                      _buildErrorCard(state.error!),
                      const SizedBox(height: 16),
                    ],
                    _buildForm(context, state, mutate),
                  ],
                );
              },
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
                'How to use mutations:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '1️⃣ Fill in the form fields (title and userId)\n'
            '2️⃣ Click "Create Todo" button to trigger mutation\n'
            '3️⃣ Watch loading state while mutation executes\n'
            '4️⃣ See success message when mutation completes\n'
            '5️⃣ Created todo appears in the result card\n'
            '6️⃣ Create another todo - previous results persist',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildForm(BuildContext context,
      [MutationState<Todo>? state, void Function(CreateTodoRequest)? mutate]) {
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
            'Create Todo',
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
          TextField(
            controller: _userIdController,
            decoration: const InputDecoration(
              labelText: 'User ID',
              hintText: 'Enter user ID (1-10)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state?.isLoading == true
                  ? null
                  : () {
                      if (_titleController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please enter a title'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 2),
                          ),
                        );
                        return;
                      }

                      final userId = int.tryParse(_userIdController.text) ?? 1;
                      final request = CreateTodoRequest(
                        userId: userId,
                        title: _titleController.text,
                      );

                      mutate?.call(request);
                    },
              icon: Icon(state?.isLoading == true
                  ? Icons.hourglass_empty
                  : Icons.add),
              label: Text(
                state?.isLoading == true ? 'Creating...' : 'Create Todo',
              ),
            ),
          ),
          if (state?.isLoading == true) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessCard(Todo todo, {required bool isSuccess}) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'Todo Created Successfully!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTodoInfoRow('ID', todo.id.toString()),
          _buildTodoInfoRow('User ID', todo.userId.toString()),
          _buildTodoInfoRow('Title', todo.title),
          _buildTodoInfoRow(
              'Status',
              todo.completed
                  ? Row(
                      children: [
                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                        const SizedBox(width: 4),
                        const Text('Completed'),
                      ],
                    )
                  : Row(
                      children: [
                        Icon(Icons.pending, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        const Text('Pending'),
                      ],
                    )),
        ],
      ),
    );
  }

  Widget _buildTodoInfoRow(String label, Object value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: value is Widget
                ? value
                : Text(
                    value.toString(),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(Object error) {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error, color: Colors.red),
              const SizedBox(width: 8),
              Text(
                'Mutation Failed',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

