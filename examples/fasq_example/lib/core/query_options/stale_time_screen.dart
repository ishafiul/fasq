import 'package:flutter/material.dart';
import '../../widgets/example_scaffold.dart';

class StaleTimeScreen extends StatelessWidget {
  const StaleTimeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ExampleScaffold(
      title: 'Stale Time',
      description:
          'Coming soon - Demonstrate fresh vs stale data with configurable stale time.',
      child: const Center(
        child: Text('This example will be implemented soon'),
      ),
    );
  }
}
