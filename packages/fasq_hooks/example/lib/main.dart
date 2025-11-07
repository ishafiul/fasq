import 'package:fasq_hooks/fasq_hooks.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

void main() {
  runApp(const HooksExampleApp());
}

const TypedQueryKey<List<String>> greetingsKey = TypedQueryKey<List<String>>(
  'hooks-greetings',
  List<String>,
);

Future<List<String>> fetchGreetings() async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
  return const ['Hello', 'Hola', 'Salut', 'Ciao'];
}

class HooksExampleApp extends StatelessWidget {
  const HooksExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryClientProvider(
      child: MaterialApp(
        title: 'FASQ Hooks Example',
        theme: ThemeData(colorSchemeSeed: Colors.teal, useMaterial3: true),
        home: const GreetingsScreen(),
      ),
    );
  }
}

class GreetingsScreen extends HookWidget {
  const GreetingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final client = useQueryClient();
    final state = useQuery<List<String>>(greetingsKey, fetchGreetings);

    return Scaffold(
      appBar: AppBar(title: const Text('Greetings via Hooks')),
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
                    onPressed: () => client
                        .getQueryByKey<List<String>>(greetingsKey)
                        ?.fetch(),
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
        onPressed: () => client.invalidateQuery(greetingsKey),
        icon: const Icon(Icons.refresh),
        label: const Text('Refetch'),
      ),
    );
  }
}
