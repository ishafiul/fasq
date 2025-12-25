import 'package:ecommerce/core/colors.dart';
import 'package:flutter/material.dart';

enum TagColor { default_, primary, success, warning, danger }

enum TagFill { solid, outline }

class Tag extends StatelessWidget {
  const Tag({
    super.key,
    required this.child,
    this.color = TagColor.default_,
    this.customColor,
    this.fill = TagFill.solid,
    this.round = false,
    this.onTap,
  });

  final Widget child;
  final TagColor color;
  final Color? customColor;
  final TagFill fill;
  final bool round;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final borderColor = _getBorderColor(palette);
    final backgroundColor = fill == TagFill.solid ? borderColor : Colors.transparent;
    final textColor = fill == TagFill.solid ? Colors.white : borderColor;
    final borderRadius = BorderRadius.circular(round ? 100 : 2);

    final container = Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: Border.all(
          color: borderColor,
          width: 1,
        ),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w400,
          height: 1,
          color: textColor,
        ),
        child: child,
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        child: container,
      );
    }

    return container;
  }

  Color _getBorderColor(AppPalette palette) {
    if (customColor != null) {
      return customColor!;
    }

    switch (color) {
      case TagColor.default_:
        return palette.weak;
      case TagColor.primary:
        return palette.info;
      case TagColor.success:
        return palette.success;
      case TagColor.warning:
        return palette.warning;
      case TagColor.danger:
        return palette.danger;
    }
  }
}
