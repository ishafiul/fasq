import 'package:flutter/material.dart';
import 'package:fasq/fasq.dart';
import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:fasq_riverpod/fasq_riverpod.dart';

/// Example showing how to use security features with adapters
class SecurityExampleApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return QueryClientProvider(
      // Configure cache with security options
      config: CacheConfig(
        defaultStaleTime: Duration(minutes: 5),
        defaultCacheTime: Duration(minutes: 10),
      ),
      // Enable encrypted persistence
      persistenceOptions: PersistenceOptions(
        enabled: true,
        encryptionKey: 'your-secure-encryption-key-here',
      ),
      child: MaterialApp(
        title: 'Security Example',
        home: SecurityExampleHome(),
      ),
    );
  }
}

class SecurityExampleHome extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Security Features Example')),
      body: Column(
        children: [
          // Example 1: Using secure queries with fasq_bloc
          BlocProvider(
            create: (_) => QueryCubit<String>(
              key: 'secure-user-token',
              queryFn: () => _fetchSecureToken(),
              options: QueryOptions(
                isSecure: true, // Mark as secure
                maxAge: Duration(minutes: 15), // Required for secure queries
                staleTime: Duration(minutes: 5),
              ),
              client: context.queryClient, // Use configured client
            ),
            child: BlocBuilder<QueryCubit<String>, QueryState<String>>(
              builder: (context, state) {
                if (state.isLoading) return CircularProgressIndicator();
                if (state.hasError) return Text('Error: ${state.error}');
                return Text('Secure Token: ${state.data}');
              },
            ),
          ),
          
          SizedBox(height: 20),
          
          // Example 2: Using secure queries with fasq_hooks
          _HooksExample(),
          
          SizedBox(height: 20),
          
          // Example 3: Using secure queries with fasq_riverpod
          _RiverpodExample(),
          
          SizedBox(height: 20),
          
          // Example 4: Secure mutation
          BlocProvider(
            create: (_) => MutationCubit<String, String>(
              mutationFn: (data) => _secureMutation(data),
              options: MutationOptions(
                queueWhenOffline: true,
                maxRetries: 3,
              ),
              client: context.queryClient,
            ),
            child: BlocBuilder<MutationCubit<String, String>, MutationState<String>>(
              builder: (context, state) {
                return ElevatedButton(
                  onPressed: state.isLoading
                      ? null
                      : () => context.read<MutationCubit<String, String>>().mutate('secure-data'),
                  child: state.isLoading
                      ? CircularProgressIndicator()
                      : Text('Secure Mutation'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HooksExample extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final client = context.queryClient;
    
    final secureQuery = useQuery<String>(
      'secure-user-profile',
      () => _fetchSecureProfile(),
      options: QueryOptions(
        isSecure: true,
        maxAge: Duration(minutes: 30),
        staleTime: Duration(minutes: 10),
      ),
      client: client, // Use configured client
    );
    
    if (secureQuery.isLoading) return CircularProgressIndicator();
    if (secureQuery.hasError) return Text('Error: ${secureQuery.error}');
    return Text('Secure Profile: ${secureQuery.data}');
  }
}

class _RiverpodExample extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final client = context.queryClient;
    
    final secureProvider = queryProvider<String>(
      'secure-settings',
      () => _fetchSecureSettings(),
      options: QueryOptions(
        isSecure: true,
        maxAge: Duration(hours: 1),
        staleTime: Duration(minutes: 15),
      ),
      client: client, // Use configured client
    );
    
    final secureQuery = ref.watch(secureProvider);
    
    if (secureQuery.isLoading) return CircularProgressIndicator();
    if (secureQuery.hasError) return Text('Error: ${secureQuery.error}');
    return Text('Secure Settings: ${secureQuery.data}');
  }
}

// Mock API functions
Future<String> _fetchSecureToken() async {
  await Future.delayed(Duration(seconds: 1));
  return 'secure-jwt-token-12345';
}

Future<String> _fetchSecureProfile() async {
  await Future.delayed(Duration(seconds: 1));
  return '{"name": "John Doe", "email": "john@example.com"}';
}

Future<String> _fetchSecureSettings() async {
  await Future.delayed(Duration(seconds: 1));
  return '{"theme": "dark", "notifications": true}';
}

Future<String> _secureMutation(String data) async {
  await Future.delayed(Duration(seconds: 1));
  return 'Processed: $data';
}
