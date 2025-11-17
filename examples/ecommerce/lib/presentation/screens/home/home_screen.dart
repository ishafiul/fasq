import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/segmented.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/core/widgets/spinner/rotating_dots.dart';
import 'package:flutter/material.dart';

@RoutePage()
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text('E-commerce Home', style: typography.titleLarge.toTextStyle()),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Text('You have pushed the button this many times:', style: typography.bodyLarge.toTextStyle()),
            ),
            Text('$_counter', style: typography.headlineMedium.toTextStyle()),
            WaveDots(),
            CircularProgressSpinner(),
            Segmented(
              options: [
                SegmentedOption(value: '1', label: "ded"),
                SegmentedOption(value: '2', label: "ddded"),
                SegmentedOption(value: '3', label: "s"),
              ],
              value: '1',
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ),
    );
  }
}
