import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import '../../widgets/example_scaffold.dart';
import '../../services/models.dart';

class BasicMutationWidgetScreen extends StatefulWidget {
  const BasicMutationWidgetScreen({super.key});

  @override
  State<BasicMutationWidgetScreen> createState() =>
      _BasicMutationWidgetScreenState();
}

class _BasicMutationWidgetScreenState
    extends State<BasicMutationWidgetScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  int _selectedUserId = 1;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Mutation with Widget Approach',
      description:
          'Demonstrates using MutationBuilder widget to handle create/update operations. Shows how mutations work for POST/PUT operations with form inputs and state management.',
      codeSnippet: '''
// Simple mutation for updating user
Future<User> updateUser(UpdateUserRequest request) {
  return ApiService.updateUser(request);
}

// Use MutationBuilder widget
MutationBuilder<User, UpdateUserRequest>(
  mutationFn: updateUser,
  builder: (context, state, mutate) {
    return Column(
      children: [
        // Form inputs
        TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: 'Name'),
        ),
        
        // Mutate button
        ElevatedButton(
          onPressed: state.isLoading ? null : () {
            mutate(UpdateUserRequest(
              name: nameController.text,
              email: emailController.text,
            ));
          },
          child: Text(state.isLoading ? 'Updating...' : 'Update User'),
        ),
        
        // Success state
        if (state.isSuccess)
          Text('User updated successfully'),
          
        // Error state
        if (state.isError)
          Text('Error occurred'),
      ],
    );
  },
)

// Benefits of MutationBuilder:
// - Automatic state management
// - Built-in loading/error handling
// - Stream-based updates
// - Lifecycle management
''',
      child: Column(
        children: [
          _buildInstructions(),
          const SizedBox(height: 16),
          Expanded(
            child: MutationBuilder<User, UpdateUserRequest>(
              mutationFn: (request) async {
                // Simulate API call - in real app this would call actual API
                await Future.delayed(const Duration(milliseconds: 500));
                // Return a mock updated user
                return User(
                  id: _selectedUserId,
                  name: request.name,
                  email: request.email,
                  username: 'updated_user',
                  phone: '+1-555-0000',
                  website: 'updated.com',
                );
              },
              options: MutationOptions<User, UpdateUserRequest>(
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
                    // Clear form
                    _nameController.clear();
                    _emailController.clear();
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
                      _buildUpdateForm(context, state, mutate),
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
            '1️⃣ Select a user ID from the dropdown\n'
            '2️⃣ Enter name and email for the user\n'
            '3️⃣ Click "Update User" to trigger mutation\n'
            '4️⃣ Watch loading state while mutation executes\n'
            '5️⃣ See updated user details in success card\n'
            '6️⃣ Form clears automatically after success',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateForm(BuildContext context, MutationState<User> state,
      void Function(UpdateUserRequest)? mutate) {
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
          DropdownButtonFormField<int>(
            value: _selectedUserId,
            decoration: const InputDecoration(
              labelText: 'User ID',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
            items: List.generate(10, (index) => index + 1)
                .map((id) => DropdownMenuItem(
                      value: id,
                      child: Text('User $id'),
                    ))
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  _selectedUserId = value;
                });
              }
            },
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
              onPressed: state.isLoading == true
                  ? null
                  : () {
                      if (_nameController.text.isEmpty ||
                          _emailController.text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill all fields'),
                            backgroundColor: Colors.orange,
                            duration: Duration(seconds: 2),
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

                      mutate?.call(request);
                    },
              icon: Icon(state.isLoading == true
                  ? Icons.hourglass_empty
                  : Icons.update),
              label: Text(
                state.isLoading == true ? 'Updating...' : 'Update User',
              ),
            ),
          ),
          if (state.isLoading == true) ...[
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
          _buildUserInfoRow('ID', user.id.toString()),
          _buildUserInfoRow('Name', user.name),
          _buildUserInfoRow('Email', user.email),
          _buildUserInfoRow('Username', user.username),
          _buildUserInfoRow('Phone', user.phone),
          _buildUserInfoRow('Website', user.website),
        ],
      ),
    );
  }

  Widget _buildUserInfoRow(String label, String value) {
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
}

