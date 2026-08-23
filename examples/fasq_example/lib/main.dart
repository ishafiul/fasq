import 'package:fasq/fasq.dart';
import 'package:fasq_security/fasq_security.dart';
import 'package:flutter/material.dart';

import 'core/global_effects.dart';
import 'core/mutations/offline_mutations.dart';
import 'core/screens/core_examples_screen.dart';

final EffectMessenger _messenger = EffectMessenger();
late QueryClient _queryClient;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NetworkStatus.instance.setOnline(online: true);
  final fasq = await Fasq.initialize(
    persistence: const QueryPersistence.secure(),
    offlineSync: OfflineSync.secure(mutations: [createTodoDurable]),
  );
  _queryClient = fasq.queryClient;
  GlobalQueryEffects.install(
    client: fasq.queryClient,
    messenger: _messenger,
    resolveMessage: _resolveMessage,
    onMutationCritical: _handleCriticalMutation,
  );
  runApp(MyApp(runtime: fasq, scaffoldMessengerKey: _messenger.key));
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.runtime,
    required this.scaffoldMessengerKey,
  });

  final FasqRuntime runtime;
  final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey;

  @override
  Widget build(BuildContext context) {
    return FasqProvider(
      runtime: runtime,
      child: MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        title: 'FASQ Examples',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const HomeScreen(),
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FASQ Examples'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome to FASQ Examples',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Explore comprehensive examples of FASQ (Flutter Async State Query) features. Each example demonstrates both widget-based and class-based usage patterns.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Available Examples',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  _buildExampleCard(
                    context,
                    title: 'Core Package Examples',
                    subtitle:
                        'QueryBuilder, Mutations, Caching, Infinite Queries',
                    icon: Icons.settings,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CoreExamplesScreen(),
                      ),
                    ),
                    isAvailable: true,
                  ),
                  const SizedBox(height: 12),
                  _buildExampleCard(
                    context,
                    title: 'Flutter Hooks Examples',
                    subtitle: 'useQuery, useMutation, useInfiniteQuery',
                    icon: Icons.extension,
                    onTap: null,
                    isAvailable: false,
                  ),
                  const SizedBox(height: 12),
                  _buildExampleCard(
                    context,
                    title: 'Bloc Examples',
                    subtitle: 'QueryCubit, MutationCubit',
                    icon: Icons.view_module,
                    onTap: null,
                    isAvailable: false,
                  ),
                  const SizedBox(height: 12),
                  _buildExampleCard(
                    context,
                    title: 'Riverpod Examples',
                    subtitle: 'queryProvider, mutationProvider',
                    icon: Icons.water_drop,
                    onTap: null,
                    isAvailable: false,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExampleCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback? onTap,
    required bool isAvailable,
  }) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isAvailable
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.outline,
          child: Icon(
            icon,
            color: isAvailable
                ? Theme.of(context).colorScheme.onPrimary
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: isAvailable
            ? Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.outline,
              )
            : Chip(
                label: const Text('Coming Soon'),
                backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
                labelStyle: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
        onTap: isAvailable ? onTap : null,
        enabled: isAvailable,
      ),
    );
  }
}

void _handleCriticalMutation(
  MutationSnapshot<dynamic, dynamic> snapshot,
  MutationMeta meta,
) {
  _queryClient.clearSecureCache();
}

String _resolveMessage(String message) {
  return message;
}
