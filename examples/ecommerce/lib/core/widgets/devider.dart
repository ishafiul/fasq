import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:flutter/material.dart';

enum DividerType { text, base }

class AppDivider extends StatelessWidget {
  AppDivider.base({
    super.key,
    this.width,
    this.thickness,
    this.indent,
    this.endIndent,
    this.height,
    required this.axis,
  }) {
    dividerType = DividerType.base;
  }

  AppDivider.text({super.key, required this.text, this.position = TextDividerPosition.center}) {
    dividerType = DividerType.text;
  }

  late final double? width;
  late final double? height;
  late final double? thickness;
  late final double? indent;
  late final double? endIndent;
  late final String? text;
  late final Axis? axis;
  late final DividerType? dividerType;
  late final TextDividerPosition? position;

  @override
  Widget build(BuildContext context) {
    switch (dividerType!) {
      case DividerType.text:
        return TextDivider(text: text!, position: position);
      case DividerType.base:
        return BaseDivider(
          axis: axis!,
          width: width,
          thickness: thickness,
          indent: indent,
          endIndent: endIndent,
          height: height,
        );
    }
  }
}

enum TextDividerPosition { left, right, center }

class TextDivider extends StatelessWidget {
  const TextDivider({required this.text, this.position = TextDividerPosition.center});

  final String text;

  final TextDividerPosition? position;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(flex: position == TextDividerPosition.right ? 7 : 1, child: BaseDivider(axis: Axis.horizontal)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.sm),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: typography.bodySmall.toTextStyle(color: palette.textSecondary),
          ),
        ),
        Flexible(flex: position == TextDividerPosition.left ? 7 : 1, child: BaseDivider(axis: Axis.horizontal)),
      ],
    );
  }
}

class BaseDivider extends StatelessWidget {
  const BaseDivider({
    super.key,
    this.width,
    this.thickness,
    this.indent,
    this.endIndent,
    this.height,
    required this.axis,
  }) : assert(width == null || width >= 0.0),
       assert(thickness == null || thickness >= 0.0),
       assert(indent == null || indent >= 0.0),
       assert(endIndent == null || endIndent >= 0.0);

  Color _getColor(BuildContext context) {
    return context.palette.border;
  }

  final double? width;
  final double? height;
  final double? thickness;
  final double? indent;
  final double? endIndent;
  final Axis axis;

  @override
  Widget build(BuildContext context) {
    final color = _getColor(context);

    switch (axis) {
      case Axis.horizontal:
        return Divider(thickness: thickness, indent: indent, height: height, endIndent: endIndent, color: color);
      case Axis.vertical:
        return VerticalDivider(thickness: thickness, indent: indent, endIndent: endIndent, width: width, color: color);
    }
  }
}
