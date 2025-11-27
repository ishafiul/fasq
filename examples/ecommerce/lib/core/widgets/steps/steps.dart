import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/widgets/steps/step.dart' as steps;
import 'package:flutter/material.dart';

enum StepsDirection { horizontal, vertical }

class Steps extends StatelessWidget {
  const Steps({
    super.key,
    this.current = 0,
    this.direction = StepsDirection.horizontal,
    required this.children,
  });

  final int current;
  final StepsDirection direction;
  final List<steps.Step> children;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final processedChildren = _processChildren(
      children,
      current,
      primaryColor: palette.brand,
      borderColor: palette.border,
    );

    if (direction == StepsDirection.horizontal) {
      return _HorizontalSteps(children: processedChildren);
    }
    return _VerticalSteps(children: processedChildren);
  }

  List<steps.Step> _processChildren(
    List<steps.Step> children,
    int current, {
    required Color primaryColor,
    required Color borderColor,
  }) {
    final List<steps.StepStatus> statuses = [];

    for (int index = 0; index < children.length; index++) {
      final step = children[index];
      steps.StepStatus status = step.status;
      if (step.status == steps.StepStatus.wait) {
        if (index < current) {
          status = steps.StepStatus.finish;
        } else if (index == current) {
          status = steps.StepStatus.process;
        }
      }
      statuses.add(status);
    }

    return List.generate(children.length, (index) {
      final step = children[index];
      final isFirst = index == 0;
      final isLast = index == children.length - 1;
      final status = statuses[index];

      Color? previousLineColor;
      if (!isFirst) {
        final previousStatus = statuses[index - 1];
        previousLineColor = previousStatus == steps.StepStatus.finish ? primaryColor : borderColor;
      }

      return steps.Step(
        title: step.title,
        description: step.description,
        icon: step.icon,
        status: status,
        isFirst: isFirst,
        isLast: isLast,
        direction: direction,
        previousLineColor: previousLineColor,
      );
    });
  }
}

class _HorizontalSteps extends StatelessWidget {
  const _HorizontalSteps({
    required this.children,
  });

  final List<steps.Step> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: children.map((step) => Expanded(child: step)).toList(),
      ),
    );
  }
}

class _VerticalSteps extends StatelessWidget {
  const _VerticalSteps({
    required this.children,
  });

  final List<steps.Step> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
