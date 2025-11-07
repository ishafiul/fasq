import 'package:fasq_riverpod/fasq_riverpod.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ProviderScope(child: RiverpodExampleApp()));
}

const TypedQueryKey<List<String>> greetingsKey = TypedQueryKey<List<String>>(
  'riverpod-greetings',
  List<String>,
);

Future<List<String>> fetchGreetings() async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
  return const ['Hello', 'Halo', 'Kia ora', 'Namaste'];
}

final greetingsProvider = queryProvider<List<String>>(
  greetingsKey,
  fetchGreetings,
);

class RiverpodExampleApp extends StatelessWidget {
  const RiverpodExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FASQ Riverpod Example',
      theme: ThemeData(colorSchemeSeed: Colors.blueGrey, useMaterial3: true),
      home: const GreetingsScreen(),
    );
  }
}

class GreetingsScreen extends ConsumerWidget {
  const GreetingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(greetingsProvider);
    final notifier = ref.read(greetingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Greetings via Riverpod')),
      body: Builder(
        builder: (context) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Failed to load greetings'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: notifier.refetch,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          final greetings = state.data ?? const <String>[];
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: greetings.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(greetings[index]),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: notifier.invalidate,
        icon: const Icon(Icons.refresh),
        label: const Text('Invalidate'),
      ),
    );
  }
}
