import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:ecommerce/core/widgets/svg_icon.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// Base stepper button widget - follows Open/Closed Principle.
/// Can be extended for different button types.
class _StepperButtonBase extends StatelessWidget {
  const _StepperButtonBase({
    required this.svg,
    required this.iconSize,
    required this.color,
    required this.disabledColor,
    required this.isDisabled,
    required this.onPressed,
  });

  final SvgGenImage svg;
  final double iconSize;
  final Color color;
  final Color disabledColor;
  final bool isDisabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Button(
      shape: ButtonShape.square,
      fill: ButtonFill.solid,
      onPressed: isDisabled ? null : onPressed,
      child: SvgIcon(
        svg: svg,
        size: iconSize,
        color: isDisabled ? disabledColor : color,
      ),
    );
  }
}

/// Plus button for incrementing the stepper value.
class StepperPlusButton extends StatelessWidget {
  const StepperPlusButton({
    super.key,
    required this.iconSize,
    required this.primaryColor,
    required this.disabledColor,
    required this.isDisabled,
    required this.onPressed,
  });

  final double iconSize;
  final Color primaryColor;
  final Color disabledColor;
  final bool isDisabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _StepperButtonBase(
      svg: Assets.icons.outlined.plus,
      iconSize: iconSize,
      color: primaryColor,
      disabledColor: disabledColor,
      isDisabled: isDisabled,
      onPressed: onPressed,
    );
  }
}

/// Minus button for decrementing the stepper value.
class StepperMinusButton extends StatelessWidget {
  const StepperMinusButton({
    super.key,
    required this.iconSize,
    required this.primaryColor,
    required this.disabledColor,
    required this.isDisabled,
    required this.onPressed,
  });

  final double iconSize;
  final Color primaryColor;
  final Color disabledColor;
  final bool isDisabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _StepperButtonBase(
      svg: Assets.icons.outlined.minus,
      iconSize: iconSize,
      color: primaryColor,
      disabledColor: disabledColor,
      isDisabled: isDisabled,
      onPressed: onPressed,
    );
  }
}

/// Delete button for removing item from cart.
class StepperDeleteButton extends StatelessWidget {
  const StepperDeleteButton({
    super.key,
    required this.iconSize,
    required this.dangerColor,
    required this.disabledColor,
    required this.isDisabled,
    required this.onPressed,
  });

  final double iconSize;
  final Color dangerColor;
  final Color disabledColor;
  final bool isDisabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return _StepperButtonBase(
      svg: Assets.icons.outlined.delete,
      iconSize: iconSize,
      color: dangerColor,
      disabledColor: disabledColor,
      isDisabled: isDisabled,
      onPressed: onPressed,
    );
  }
}
