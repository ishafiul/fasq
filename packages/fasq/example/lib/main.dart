import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const ExampleApp());
}

const TypedQueryKey<List<String>> greetingsKey = TypedQueryKey<List<String>>(
  'example-greetings',
  List<String>,
);

Future<List<String>> loadGreetings() async {
  await Future<void>.delayed(const Duration(milliseconds: 600));
  return const ['Hello', 'Bonjour', 'Hola', 'Ciao'];
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return QueryClientProvider(
      child: MaterialApp(
        title: 'FASQ Example',
        theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
        home: const GreetingsScreen(),
      ),
    );
  }
}

class GreetingsScreen extends StatelessWidget {
  const GreetingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('FASQ Greetings')),
      body: QueryBuilder<List<String>>(
        queryKey: greetingsKey,
        queryFn: loadGreetings,
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Something went wrong'),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () => QueryClient()
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
        onPressed: () => QueryClient().invalidateQuery(greetingsKey),
        icon: const Icon(Icons.refresh),
        label: const Text('Refetch'),
      ),
    );
  }
}
