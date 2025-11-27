import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/router/app_router.gr.dart';
import 'package:ecommerce/core/widgets/input.dart';
import 'package:flutter/material.dart';

/// Custom app bar for the home screen.
///
/// This app bar includes:
/// - Search bar
/// - Profile icon button
/// - Menu icon button
class HomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  const HomeAppBar({super.key, this.onSearchChanged, this.onSearchSubmitted});

  final ValueChanged<String>? onSearchChanged;
  final ValueChanged<String>? onSearchSubmitted;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 16);

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;

    return AppBar(
      backgroundColor: palette.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      automaticallyImplyLeading: false,
      title: Row(
        children: [
          // Search Bar
          Expanded(
            child: TextInputField(
              placeholder: 'Search products...',
              onChanged: (value) {
                onSearchChanged?.call(value);
                if (value.isEmpty) {
                  onSearchSubmitted?.call(value);
                }
              },
            ),
          ),
          SizedBox(width: spacing.sm),
          // Profile Icon
          IconButton(
            onPressed: () {
              context.router.push(const ProfileRoute());
            },
            icon: Icon(Icons.person, color: palette.textPrimary),
            tooltip: 'Profile',
          ),
          // Menu Icon
          IconButton(
            onPressed: () {
              // TODO: Implement menu drawer or bottom sheet
            },
            icon: Icon(Icons.menu, color: palette.textPrimary),
            tooltip: 'Menu',
          ),
        ],
      ),
    );
  }
}
