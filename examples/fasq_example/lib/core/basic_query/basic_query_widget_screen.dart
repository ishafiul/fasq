import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import '../../widgets/example_scaffold.dart';
import '../../services/api_service.dart';
import '../../services/models.dart';

class BasicQueryWidgetScreen extends StatelessWidget {
  const BasicQueryWidgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Basic Query - QueryBuilder Widget',
      description:
          'Demonstrates basic QueryBuilder widget usage with loading, error, and success states.',
      codeSnippet: '''
QueryBuilder<List<User>>(
  queryKey: 'users',
  queryFn: () => ApiService.fetchUsers(),
  builder: (context, state) {
    if (state.isLoading) {
      return LoadingWidget(message: 'Loading users...');
    }
    
    if (state.hasError) {
      return CustomErrorWidget(
        message: state.error.toString(),
        onRetry: () => // retry logic
      );
    }
    
    if (state.hasData) {
      return ListView.builder(
        itemCount: state.data!.length,
        itemBuilder: (context, index) {
          final user = state.data![index];
          return ListTile(
            leading: CircleAvatar(child: Text(user.name[0])),
            title: Text(user.name),
            subtitle: Text(user.email),
          );
        },
      );
    }
    
    return const EmptyWidget(message: 'No users found');
  },
)''',
      child: QueryBuilder<List<User>>(
        queryKey: 'users',
        queryFn: () => ApiService.fetchUsers(),
        builder: (context, state) {
          if (state.isLoading) {
            return const LoadingWidget(message: 'Loading users...');
          }

          if (state.hasError) {
            return CustomErrorWidget(
              message: state.error.toString(),
              onRetry: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const BasicQueryWidgetScreen(),
                  ),
                );
              },
            );
          }

          if (state.hasData) {
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: state.data!.length,
              itemBuilder: (context, index) {
                final user = state.data![index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: Text(
                        user.name[0],
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(user.name),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(user.email),
                        Text(
                          '@${user.username}',
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                    trailing: Text(
                      'ID: ${user.id}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                );
              },
            );
          }

          return const EmptyWidget(message: 'No users found');
        },
      ),
    );
  }
}
