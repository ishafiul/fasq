import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import 'dart:async';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

class BasicMutationClassScreen extends StatefulWidget {
  const BasicMutationClassScreen({super.key});

  @override
  State<BasicMutationClassScreen> createState() =>
      _BasicMutationClassScreenState();
}

class _BasicMutationClassScreenState extends State<BasicMutationClassScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _userIdController = TextEditingController();

  late Mutation<Todo, CreateTodoRequest> _mutation;
  StreamSubscription? _subscription;

  @override
  void initState() {
    super.initState();
    // Create mutation instance using class-based approach
    _mutation = Mutation<Todo, CreateTodoRequest>(
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
    );

    // Subscribe to mutation state changes
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
    _userIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Mutation - Class-Based Approach',
      description:
          'Demonstrates class-based mutation pattern where you create and manage a Mutation instance directly. This gives you full control over the mutation lifecycle, state management, and cleanup.',
      codeSnippet: '''
// Class-based approach - Create mutation instance
Mutation<Todo, CreateTodoRequest> mutation = Mutation(
  mutationFn: (request) => ApiService.createTodo(request),
  options: MutationOptions(
    onSuccess: (result) => print('Todo created'),
    onError: (err) => print('Error occurred'),
  ),
);

// Subscribe to state changes
StreamSubscription subscription = mutation.stream.listen((state) {
  setState(() {}); // Trigger rebuild on state change
});

// Trigger mutation manually
mutation.mutate(CreateTodoRequest(
  userId: 1,
  title: 'New Todo',
));

// Access mutation state
if (mutation.state.isSuccess) {
  print('Success');
}

// Clean up when done
subscription.cancel();
mutation.dispose();

// Benefits of class-based approach:
// - Full control over lifecycle
// - Manual state management
// - Share mutation instance across widgets
// - More flexibility for complex scenarios
''',
      child: Column(
        children: [
          _buildInstructions(),
          const SizedBox(height: 16),
          Expanded(
            child: _buildContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    final state = _mutation.state;

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
        _buildForm(context, state),
      ],
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
            'Class-Based Approach:\n'
            '• Mutation instance created in initState\n'
            '• Manual subscription to state stream\n'
            '• Direct access to mutation.mutate()\n'
            '• Full control over lifecycle\n\n'
            'How to test:\n'
            '1️⃣ Fill in the form fields (title and userId)\n'
            '2️⃣ Click "Create Todo" to trigger _mutation.mutate()\n'
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

  Widget _buildForm(BuildContext context, [MutationState<Todo>? state]) {
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

                      _mutation.mutate(request);
                    },
              icon: Icon(
                  state?.isLoading == true ? Icons.hourglass_empty : Icons.add),
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
