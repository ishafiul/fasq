import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/steps/steps.dart';
import 'package:flutter/material.dart';

enum StepStatus { wait, process, finish, error }

class Step extends StatelessWidget {
  const Step({
    super.key,
    this.title,
    this.description,
    this.icon,
    this.status = StepStatus.wait,
    this.isFirst = false,
    this.isLast = false,
    this.direction = StepsDirection.horizontal,
    this.previousLineColor,
  });

  final Widget? title;
  final Widget? description;
  final Widget? icon;
  final StepStatus status;
  final bool isFirst;
  final bool isLast;
  final StepsDirection direction;
  final Color? previousLineColor;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    Color iconColor;
    Color? titleColor;
    Color lineColor;

    switch (status) {
      case StepStatus.wait:
        iconColor = palette.border;
        titleColor = palette.weak;
        lineColor = palette.border;
      case StepStatus.process:
        iconColor = palette.brand;
        titleColor = palette.brand;
        lineColor = palette.border;
      case StepStatus.finish:
        iconColor = palette.brand;
        titleColor = null;
        lineColor = palette.brand;
      case StepStatus.error:
        iconColor = palette.danger;
        titleColor = palette.danger;
        lineColor = palette.border;
    }

    if (direction == StepsDirection.horizontal) {
      return _HorizontalStep(
        icon: icon ?? _StepDot(color: iconColor),
        iconColor: iconColor,
        title: title,
        titleColor: titleColor,
        description: description,
        lineColor: lineColor,
        isFirst: isFirst,
        isLast: isLast,
        previousLineColor: previousLineColor ?? palette.border,
      );
    }

    return _VerticalStep(
      icon: icon ?? _StepDot(color: iconColor),
      iconColor: iconColor,
      title: title,
      titleColor: titleColor,
      description: description,
      lineColor: lineColor,
      isFirst: isFirst,
      isLast: isLast,
      previousLineColor: previousLineColor ?? palette.border,
    );
  }
}

class _HorizontalStep extends StatelessWidget {
  const _HorizontalStep({
    required this.icon,
    required this.iconColor,
    this.title,
    this.titleColor,
    this.description,
    required this.lineColor,
    required this.isFirst,
    required this.isLast,
    required this.previousLineColor,
  });

  final Widget icon;
  final Color iconColor;
  final Widget? title;
  final Color? titleColor;
  final Widget? description;
  final Color lineColor;
  final bool isFirst;
  final bool isLast;
  final Color previousLineColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 24,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  color: isFirst ? Colors.transparent : previousLineColor,
                ),
              ),
              Container(
                width: 18,
                height: 18,
                decoration: const BoxDecoration(
                  color: Colors.transparent,
                ),
                child: Center(
                  child: ColorFiltered(
                    colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                    child: IconTheme(
                      data: IconThemeData(color: iconColor, size: 18),
                      child: DefaultTextStyle(
                        style: TextStyle(color: iconColor, fontSize: 18),
                        child: icon,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  color: isLast ? Colors.transparent : lineColor,
                ),
              ),
            ],
          ),
        ),
        if (title != null || description != null)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (title != null) _StepTitle(title: title!, titleColor: titleColor),
                if (description != null) ...[
                  const SizedBox(height: 4),
                  _StepDescription(description: description!),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _VerticalStep extends StatelessWidget {
  const _VerticalStep({
    required this.icon,
    required this.iconColor,
    this.title,
    this.titleColor,
    this.description,
    required this.lineColor,
    required this.isFirst,
    required this.isLast,
    required this.previousLineColor,
  });

  final Widget icon;
  final Color iconColor;
  final Widget? title;
  final Color? titleColor;
  final Widget? description;
  final Color lineColor;
  final bool isFirst;
  final bool isLast;
  final Color previousLineColor;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 24,
            child: Column(
              children: [
                if (!isFirst)
                  Container(
                    width: 1,
                    height: 5,
                    color: previousLineColor,
                  ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: Colors.transparent,
                  ),
                  child: Center(
                    child: ColorFiltered(
                      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
                      child: IconTheme(
                        data: IconThemeData(color: iconColor, size: 18),
                        child: DefaultTextStyle(
                          style: TextStyle(color: iconColor, fontSize: 18),
                          child: icon,
                        ),
                      ),
                    ),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1,
                      color: lineColor,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (title != null) _StepTitle(title: title!, titleColor: titleColor),
                  if (description != null) ...[
                    const SizedBox(height: 4),
                    _StepDescription(description: description!),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepTitle extends StatelessWidget {
  const _StepTitle({
    required this.title,
    this.titleColor,
  });

  final Widget title;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final palette = context.palette;

    return DefaultTextStyle(
      style: typography.bodyMedium.toTextStyle(
        color: titleColor ?? palette.textPrimary,
      ),
      child: title,
    );
  }
}

class _StepDescription extends StatelessWidget {
  const _StepDescription({
    required this.description,
  });

  final Widget description;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;
    final palette = context.palette;

    return DefaultTextStyle(
      style: typography.labelSmall.toTextStyle(color: palette.weak),
      child: description,
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}
