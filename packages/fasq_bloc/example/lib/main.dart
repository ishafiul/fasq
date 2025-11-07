import 'package:fasq_bloc/fasq_bloc.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const BlocExampleApp());
}

const TypedQueryKey<List<String>> greetingsKey = TypedQueryKey<List<String>>(
  'bloc-greetings',
  List<String>,
);

Future<List<String>> fetchGreetings() async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
  return const ['Hello', 'Hej', 'Ola', 'Szia'];
}

class GreetingsCubit extends QueryCubit<List<String>> {
  @override
  QueryKey get queryKey => greetingsKey;

  @override
  Future<List<String>> Function() get queryFn => fetchGreetings;
}

class BlocExampleApp extends StatelessWidget {
  const BlocExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GreetingsCubit(),
      child: MaterialApp(
        title: 'FASQ Bloc Example',
        theme: ThemeData(colorSchemeSeed: Colors.orange, useMaterial3: true),
        home: const GreetingsScreen(),
      ),
    );
  }
}

class GreetingsScreen extends StatelessWidget {
  const GreetingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<GreetingsCubit>();

    return Scaffold(
      appBar: AppBar(title: const Text('Greetings via Bloc + FASQ')),
      body: BlocBuilder<GreetingsCubit, QueryState<List<String>>>(
        builder: (context, state) {
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
                    onPressed: cubit.refetch,
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
        onPressed: cubit.invalidate,
        icon: const Icon(Icons.refresh),
        label: const Text('Invalidate'),
      ),
    );
  }
}
