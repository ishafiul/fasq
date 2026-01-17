import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/presentation/widget/cart/cart_icon_button.dart';
import 'package:ecommerce_ui/ecommerce_ui.dart';
import 'package:flutter/material.dart';

@RoutePage()
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Menu'),
        backgroundColor: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: const [
          CartIconButton(),
        ],
      ),
      body: ListView(
        padding: EdgeInsets.all(spacing.md),
        children: [
          Card(
            child: ListTile(
              leading: Icon(Icons.analytics, color: palette.brand),
              title: const Text('Performance Metrics'),
              subtitle: const Text('View FASQ performance metrics'),
              trailing: Icon(Icons.chevron_right, color: palette.textSecondary),
              onTap: () => context.router.push(const MetricsRoute()),
            ),
          ),
          SizedBox(height: spacing.sm),
          Card(
            child: ListTile(
              leading: Icon(Icons.fitness_center, color: palette.brand),
              title: const Text('Muscle Selection'),
              subtitle: const Text('Select target muscles for workouts'),
              trailing: Icon(Icons.chevron_right, color: palette.textSecondary),
              onTap: () => context.router.push(const MuscleSelectionRoute()),
            ),
          ),
        ],
      ),
    );
  }
}
