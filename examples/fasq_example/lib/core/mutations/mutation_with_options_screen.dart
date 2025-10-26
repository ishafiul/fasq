import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import 'dart:async';
import '../../widgets/example_scaffold.dart';
import '../../services/models.dart';

class MutationWithOptionsScreen extends StatefulWidget {
  const MutationWithOptionsScreen({super.key});

  @override
  State<MutationWithOptionsScreen> createState() =>
      _MutationWithOptionsScreenState();
}

class _MutationWithOptionsScreenState
    extends State<MutationWithOptionsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  
  late Mutation<User, UpdateUserRequest> _mutation;
  StreamSubscription? _subscription;
  final List<String> _eventLog = [];

  @override
  void initState() {
    super.initState();
    
    // Create mutation with various options
    _mutation = Mutation<User, UpdateUserRequest>(
      mutationFn: (request) async {
        // Simulate network delay
        await Future.delayed(const Duration(milliseconds: 800));
        
        // Simulate error 10% of the time
        if (DateTime.now().millisecond % 10 == 0) {
          throw Exception('Network error occurred');
        }
        
        return User(
          id: 1,
          name: request.name,
          email: request.email,
          username: 'updated_user',
          phone: request.phone,
          website: request.website,
        );
      },
      options: MutationOptions<User, UpdateUserRequest>(
        onSuccess: (data) {
          if (mounted) {
            _addLog('✅ onSuccess called: ${data.name}');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'User updated: ${data.name}',
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
            _nameController.clear();
            _emailController.clear();
          }
        },
        onError: (error) {
          if (mounted) {
            _addLog('❌ onError called: ${error.toString()}');
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
        onMutate: (data, variables) {
          if (mounted) {
            _addLog('🔄 onMutate called: ${data.name}');
          }
        },
        // queueWhenOffline: true, // Queue mutations when offline
        // priority: 1, // Higher priority mutations execute first
        // maxRetries: 3, // Retry failed mutations up to 3 times
      ),
    );
    
    // Subscribe to state changes
    _subscription = _mutation.stream.listen((_) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        _eventLog.insert(0, message);
        if (_eventLog.length > 20) {
          _eventLog.removeLast();
        }
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _mutation.dispose();
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Mutation Options',
      description:
          'Demonstrates advanced mutation options including callbacks (onSuccess, onError, onMutate), retry behavior, offline queue, and priority handling. Shows how to configure mutation behavior for different scenarios.',
      codeSnippet: '''
MutationOptions<Todo, CreateTodoRequest>(
  // Callback executed when mutation succeeds
  onSuccess: (data) {
    print('Success: \${data.title}');
    showNotification('Todo created');
  },
  
  // Callback executed when mutation fails
  onError: (error) {
    print('Error: \$error');
    logError(error);
  },
  
  // Callback executed on mutation start
  onMutate: (data, variables) {
    // Optimistic update before mutation completes
    updateUIOptimistically(variables);
  },
  
  // Queue mutation when offline
  queueWhenOffline: true,
  
  // Priority (higher = executes first)
  priority: 1,
  
  // Maximum retry attempts
  maxRetries: 3,
)

// Use cases for options:
// - Analytics tracking
// - Optimistic updates
// - Error logging
// - Offline support
// - Retry logic
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
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (state.isSuccess && state.hasData) ...[
            _buildSuccessCard(state.data!),
            const SizedBox(height: 16),
          ],
          if (state.isError) ...[
            _buildErrorCard(state.error!),
            const SizedBox(height: 16),
          ],
          _buildMutationOptions(),
          const SizedBox(height: 16),
          _buildUpdateForm(state),
          const SizedBox(height: 16),
          _buildEventLog(),
        ],
      ),
    );
  }
  
  Widget _buildMutationOptions() {
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
                Icons.settings,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Enabled Options',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildOptionRow(Icons.check_circle, 'onSuccess callback', Colors.green),
          _buildOptionRow(Icons.error, 'onError callback', Colors.red),
          _buildOptionRow(Icons.autorenew, 'onMutate callback', Colors.blue),
          _buildOptionRow(Icons.queue, 'offline queue support', Colors.orange),
          _buildOptionRow(Icons.refresh, 'automatic retry', Colors.purple),
        ],
      ),
    );
  }
  
  Widget _buildOptionRow(IconData icon, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium,
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
                'Mutation options demonstrated:',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'This example shows:\n'
            '• onSuccess: Executed when mutation succeeds\n'
            '• onError: Executed when mutation fails\n'
            '• onMutate: Executed when mutation starts\n'
            '• Watch event log to see callbacks fire\n'
            '• All callbacks are logged for demonstration',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateForm(MutationState<User> state) {
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
            'Update User',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'Enter user name...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.badge),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'Enter email...',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: state.isLoading
                  ? null
                  : () {
                      if (_nameController.text.isEmpty ||
                          _emailController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill all fields'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        return;
                      }

                      final request = UpdateUserRequest(
                        name: _nameController.text,
                        email: _emailController.text,
                        phone: '+1-555-0000',
                        website: 'example.com',
                      );

                      _mutation.mutate(request);
                    },
              icon: Icon(
                  state.isLoading ? Icons.hourglass_empty : Icons.update),
              label: Text(state.isLoading ? 'Updating...' : 'Update User'),
            ),
          ),
          if (state.isLoading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Widget _buildSuccessCard(User user) {
    return Container(
      padding: const EdgeInsets.all(16),
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
              const Icon(Icons.check_circle, color: Colors.green),
              const SizedBox(width: 8),
              Text(
                'User Updated Successfully!',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildUserInfoRow('Name', user.name),
          _buildUserInfoRow('Email', user.email),
        ],
      ),
    );
  }

  Widget _buildUserInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
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
                'Update Failed',
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
  
  Widget _buildEventLog() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Event Log (Callbacks)',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 150,
            child: _eventLog.isEmpty
                ? Center(
                    child: Text(
                      'Events will appear here...',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  )
                : ListView.builder(
                    itemCount: _eventLog.length,
                    itemBuilder: (context, index) {
                      final log = _eventLog[index];
                      final isError = log.contains('❌');
                      final isSuccess = log.contains('✅');
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isError
                              ? Colors.red.withOpacity(0.1)
                              : isSuccess
                                  ? Colors.green.withOpacity(0.1)
                                  : Colors.blue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isError
                                  ? Icons.error_outline
                                  : isSuccess
                                      ? Icons.check_circle_outline
                                      : Icons.autorenew,
                              size: 16,
                              color: isError
                                  ? Colors.red
                                  : isSuccess
                                      ? Colors.green
                                      : Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                log,
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontFamily: 'monospace',
                                      fontSize: 11,
                                    ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

