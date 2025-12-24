import 'package:ecommerce/core/const.dart';
import 'package:flutter/material.dart';

class NumberBox extends StatelessWidget {
  const NumberBox({
    super.key,
    required this.backgroundColor,
    required this.borderColor,
    required this.textColor,
    required this.borderRadius,
    required this.height,
    required this.padding,
    required this.valueText,
    this.onTap,
  });

  final Color backgroundColor;
  final Color borderColor;
  final Color textColor;
  final double borderRadius;
  final double height;
  final EdgeInsets padding;
  final String valueText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: borderColor),
        ),
        padding: padding,
        alignment: Alignment.center,
        child: Text(
          valueText,
          textAlign: TextAlign.center,
          style: context.textTheme.bodySmall?.copyWith(
            fontSize: 14,
            color: textColor,
          ),
        ),
      ),
    );
  }
}
