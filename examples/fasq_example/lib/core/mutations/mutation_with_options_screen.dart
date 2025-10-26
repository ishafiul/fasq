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

class _MutationWithOptionsScreenState extends State<MutationWithOptionsScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  late Mutation<User, UpdateUserRequest> _mutation;
  StreamSubscription? _subscription;
  final List<String> _eventLog = [];

  // Configuration toggles for testing options
  bool _simulateError = false;
  bool _enableOnSuccess = true;
  bool _enableOnError = true;
  bool _enableOnMutate = true;
  int _maxRetries = 3;
  bool _queueWhenOffline = false;
  int _currentRetryAttempt = 0;

  @override
  void initState() {
    super.initState();
    _initializeMutation();
  }

  Future<User> _executeWithRetry(UpdateUserRequest request) async {
    _currentRetryAttempt = 0;
    
    while (_currentRetryAttempt < _maxRetries) {
      _currentRetryAttempt++;
      
      if (_currentRetryAttempt > 1 && mounted) {
        setState(() {
          _addLog('🔄 Retry attempt $_currentRetryAttempt of $_maxRetries');
        });
      }
      
      try {
        // Wait before retrying (with exponential backoff)
        if (_currentRetryAttempt > 1) {
          final delay = Duration(milliseconds: 200 * _currentRetryAttempt);
          await Future.delayed(delay);
          
          if (mounted) {
            _addLog('⏳ Waiting ${delay.inMilliseconds}ms before retry...');
          }
        }
        
        // Simulate network delay
        await Future.delayed(const Duration(milliseconds: 800));

        // Simulate error based on toggle
        if (_simulateError) {
          throw Exception('Simulated error');
        }

        // Random error simulation (40% chance for testing retries)
        if (DateTime.now().millisecond % 10 < 4 && _currentRetryAttempt == 1) {
          throw Exception('Random network error on first attempt');
        }

        // Success
        final user = User(
          id: 1,
          name: request.name,
          email: request.email,
          username: 'updated_user',
          phone: request.phone,
          website: request.website,
        );
        
        if (_currentRetryAttempt > 1 && mounted) {
          _addLog('✅ Retry succeeded on attempt $_currentRetryAttempt');
        }
        
        _currentRetryAttempt = 0; // Reset
        return user;
      } catch (error) {
        if (mounted) {
          _addLog('❌ Attempt $_currentRetryAttempt failed: $error');
        }
        
        if (_currentRetryAttempt >= _maxRetries) {
          // Max retries reached, throw the error
          if (mounted) {
            _addLog('❌ Max retries ($_maxRetries) reached. Giving up.');
          }
          _currentRetryAttempt = 0; // Reset
          rethrow;
        }
        // Continue to retry
      }
    }
    
    throw Exception('Max retries reached');
  }

  void _initializeMutation() {
    _mutation = Mutation<User, UpdateUserRequest>(
      mutationFn: _executeWithRetry,
      options: MutationOptions<User, UpdateUserRequest>(
        onSuccess: _enableOnSuccess
            ? (data) {
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
              }
            : null,
        onError: _enableOnError
            ? (error) {
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
              }
            : null,
        onMutate: _enableOnMutate
            ? (data, variables) {
                if (mounted) {
                  _addLog('🔄 onMutate called with data: ${data.name}');
                }
              }
            : null,
        queueWhenOffline: _queueWhenOffline,
        maxRetries: _maxRetries,
      ),
    );

    // Subscribe to state changes
    _subscription?.cancel();
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
          _buildConfigurationPanel(state),
          const SizedBox(height: 16),
          _buildUpdateForm(state),
          const SizedBox(height: 16),
          _buildEventLog(),
        ],
      ),
    );
  }

  Widget _buildConfigurationPanel(MutationState<User> state) {
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
            '🔧 Configuration Panel - Test Mutation Options',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 16),

          // Error Simulation Toggle
          SwitchListTile(
            title: const Text('Simulate Error'),
            subtitle: Text(_simulateError
                ? 'Will force error on next mutation'
                : 'Mutation will succeed normally'),
            value: _simulateError,
            onChanged: (value) {
              setState(() {
                _simulateError = value;
              });
            },
            secondary: Icon(
              Icons.error,
              color: _simulateError ? Colors.red : Colors.grey,
            ),
          ),
          const Divider(),

          // Callback toggles
          SwitchListTile(
            title: const Text('onSuccess Callback'),
            subtitle: const Text('Called when mutation succeeds'),
            value: _enableOnSuccess,
            onChanged: (value) {
              setState(() {
                _enableOnSuccess = value;
                _initializeMutation();
              });
            },
            secondary: Icon(
              Icons.check_circle,
              color: _enableOnSuccess ? Colors.green : Colors.grey,
            ),
          ),

          SwitchListTile(
            title: const Text('onError Callback'),
            subtitle: const Text('Called when mutation fails'),
            value: _enableOnError,
            onChanged: (value) {
              setState(() {
                _enableOnError = value;
                _initializeMutation();
              });
            },
            secondary: Icon(
              Icons.error,
              color: _enableOnError ? Colors.red : Colors.grey,
            ),
          ),

          SwitchListTile(
            title: const Text('onMutate Callback'),
            subtitle: const Text('Called when mutation starts'),
            value: _enableOnMutate,
            onChanged: (value) {
              setState(() {
                _enableOnMutate = value;
                _initializeMutation();
              });
            },
            secondary: Icon(
              Icons.autorenew,
              color: _enableOnMutate ? Colors.blue : Colors.grey,
            ),
          ),
          const Divider(),

          // Max Retries Slider
          Text(
            'Max Retries: $_maxRetries',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
          ),
          Slider(
            value: _maxRetries.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            onChanged: (value) {
              setState(() {
                _maxRetries = value.round();
                _initializeMutation();
              });
            },
          ),

          // Queue When Offline Toggle
          SwitchListTile(
            title: const Text('Queue When Offline'),
            subtitle: const Text('Queue mutations when network is offline'),
            value: _queueWhenOffline,
            onChanged: (value) {
              setState(() {
                _queueWhenOffline = value;
                _initializeMutation();
              });
            },
            secondary: Icon(
              Icons.queue,
              color: _queueWhenOffline ? Colors.orange : Colors.grey,
            ),
          ),

          const Divider(),

          // Clear Log Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _eventLog.clear();
                  _currentRetryAttempt = 0;
                });
              },
              icon: const Icon(Icons.clear),
              label: const Text('Clear Event Log'),
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
            'Interactive Testing:\n'
            '1️⃣ Toggle callbacks on/off to test each one\n'
            '2️⃣ Toggle "Simulate Error" to test error handling\n'
            '3️⃣ Adjust "Max Retries" slider (0-5)\n'
            '4️⃣ Toggle "Queue When Offline" to test offline support\n'
            '5️⃣ Watch Event Log to see which callbacks fire\n'
            '6️⃣ Try with/without each option to understand behavior',
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
              icon:
                  Icon(state.isLoading ? Icons.hourglass_empty : Icons.update),
              label: Text(state.isLoading ? 'Updating...' : 'Update User'),
            ),
          ),
          if (state.isLoading) ...[
            const SizedBox(height: 16),
            Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 8),
                if (_currentRetryAttempt > 0)
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.autorenew, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Retrying: $_currentRetryAttempt/$_maxRetries',
                          style: TextStyle(
                            color: Colors.orange[700],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
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
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
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
