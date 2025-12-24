import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:ecommerce/core/widgets/svg_icon.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:flutter/material.dart';

mixin StepperButtons {
  static Widget buildPlusButton({
    required double iconSize,
    required Color primaryColor,
    required Color disabledTextColor,
    required bool isDisabled,
    required VoidCallback? onPressed,
  }) {
    return Button(
      shape: ButtonShape.square,
      fill: ButtonFill.solid,
      onPressed: isDisabled ? null : onPressed,
      child: SvgIcon(
        svg: Assets.icons.outlined.plus,
        size: iconSize,
        color: isDisabled ? disabledTextColor : primaryColor,
      ),
    );
  }

  static Widget buildMinusButton({
    required double iconSize,
    required Color primaryColor,
    required Color disabledTextColor,
    required bool isDisabled,
    required VoidCallback? onPressed,
  }) {
    return Button(
      shape: ButtonShape.square,
      fill: ButtonFill.solid,
      onPressed: isDisabled ? null : onPressed,
      child: SvgIcon(
        svg: Assets.icons.outlined.minus,
        size: iconSize,
        color: isDisabled ? disabledTextColor : primaryColor,
      ),
    );
  }

  static Widget buildDeleteButton({
    required double iconSize,
    required Color dangerColor,
    required Color disabledTextColor,
    required bool isDisabled,
    required VoidCallback? onPressed,
  }) {
    return Button(
      shape: ButtonShape.square,
      fill: ButtonFill.solid,
      onPressed: isDisabled ? null : onPressed,
      child: SvgIcon(
        svg: Assets.icons.outlined.delete,
        size: iconSize,
        color: isDisabled ? disabledTextColor : dangerColor,
      ),
    );
  }
}
