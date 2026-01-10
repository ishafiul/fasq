import 'package:auto_route/auto_route.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:ecommerce/core/widgets/tag.dart';
import 'package:ecommerce/presentation/screens/muscle_selection/interactive_svg_viewer.dart';
import 'package:ecommerce/presentation/screens/muscle_selection/services/svg_parser.dart';
import 'package:ecommerce/presentation/screens/muscle_selection/svg_interaction_controller.dart';
import 'package:flutter/material.dart';

@RoutePage()
class MuscleSelectionScreen extends StatefulWidget {
  const MuscleSelectionScreen({super.key});

  @override
  State<MuscleSelectionScreen> createState() => _MuscleSelectionScreenState();
}

class _MuscleSelectionScreenState extends State<MuscleSelectionScreen> {
  SvgInteractionController? _controller;

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    // Controller is disposed by InteractiveSvgViewer if created internally
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typography = context.typography;

    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: palette.textPrimary),
          onPressed: () => context.router.pop(),
        ),
        title: Text(
          'Choose Muscle',
          style: typography.titleMedium.toTextStyle(color: palette.textPrimary),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          Expanded(
            child: InteractiveSvgViewer(
              svgPath: 'assets/images/muscle_diagram.svg',
              filter: const SvgGroupFilter.byClass('muscle'),
              selectedFillColor: '#00FF88',
              unselectedFillColor: '#3A3A3A',
              className: 'muscle',
              onControllerReady: (controller) {
                _controller?.removeListener(_onControllerChanged);
                controller.addListener(_onControllerChanged);
                setState(() {
                  _controller = controller;
                });
              },
              onTap: (elementId) {
                if (elementId != null) {
                  _controller?.toggleElement(elementId);
                }
              },
            ),
          ),
          _buildSelectedMusclesSection(),
          _buildDoneButton(),
        ],
      ),
    );
  }

  Widget _buildSelectedMusclesSection() {
    if (_controller == null || _controller!.selectedIds.isEmpty) {
      return const SizedBox.shrink();
    }

    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final selectedIds = _controller!.selectedIds;

    return Container(
      padding: EdgeInsets.all(spacing.md),
      color: palette.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Selected Muscles',
            style: typography.titleSmall.toTextStyle(color: palette.textPrimary),
          ),
          SizedBox(height: spacing.sm),
          Wrap(
            spacing: spacing.xs,
            runSpacing: spacing.xs,
            children: selectedIds.map((muscleId) {
              return Tag(
                color: TagColor.success,
                onTap: () {
                  _controller?.deselectElement(muscleId);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_formatMuscleName(muscleId)),
                    SizedBox(width: spacing.xs / 2),
                    Icon(
                      Icons.close,
                      size: 14,
                      color: Colors.white,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  String _formatMuscleName(String muscleId) {
    return muscleId.split('-').map((word) => word[0].toUpperCase() + word.substring(1)).join(' ');
  }

  Widget _buildDoneButton() {
    final spacing = context.spacing;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.all(spacing.md),
      child: Button.primary(
        onPressed: () {
          final selectedIds = _controller?.selectedIds.toList() ?? [];
          context.router.pop(selectedIds);
        },
        isBlock: true,
        child: const Text('Done'),
      ),
    );
  }
}
