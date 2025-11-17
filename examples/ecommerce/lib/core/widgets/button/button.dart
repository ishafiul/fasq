import 'package:ecommerce/core/colors.dart';
import 'package:flutter/material.dart';

/// enum for button type
enum ButtonType { base, primary, success, warning, danger }

enum ButtonFill { solid, outline, none }

enum ButtonShape { pill, base, rectangular, rounded, square }

enum ButtonSize { large, middle, mini, small }

BoxConstraints _buttonConstants({
  ButtonSize buttonSize = ButtonSize.middle,
  bool isBlock = false,
  ButtonShape shape = ButtonShape.base,
}) {
  // For rounded shape, use content-based sizing
  if (shape == ButtonShape.rounded) {
    return BoxConstraints(minWidth: isBlock ? double.infinity : 0);
  }

  // For square shape, ensure equal width and height
  if (shape == ButtonShape.square) {
    if (isBlock) {
      return const BoxConstraints(minWidth: double.infinity);
    }
    // Use content-based sizing - the equal padding will make it square
    return const BoxConstraints();
  }

  // Original fixed sizing for other shapes
  switch (buttonSize) {
    case ButtonSize.large:
      return BoxConstraints(minWidth: isBlock ? double.infinity : 87, minHeight: 49, maxHeight: 49);
    case ButtonSize.middle:
      return BoxConstraints(minWidth: isBlock ? double.infinity : 78, minHeight: 40, maxHeight: 40);
    case ButtonSize.mini:
      return BoxConstraints(minWidth: isBlock ? double.infinity : 66, minHeight: 26, maxHeight: 26);
    case ButtonSize.small:
      return BoxConstraints(minWidth: isBlock ? double.infinity : 72, minHeight: 29, maxHeight: 29);
  }
}

EdgeInsetsGeometry _buttonPadding({ButtonSize buttonSize = ButtonSize.middle, ButtonShape shape = ButtonShape.base}) {
  // For rounded shape, use minimal padding to allow true square/circle shapes
  if (shape == ButtonShape.rounded) {
    switch (buttonSize) {
      case ButtonSize.large:
        return const EdgeInsets.all(8);
      case ButtonSize.middle:
        return const EdgeInsets.all(6);
      case ButtonSize.mini:
        return const EdgeInsets.all(4);
      case ButtonSize.small:
        return const EdgeInsets.all(4);
    }
  }

  // For square shape, use equal padding on all sides
  if (shape == ButtonShape.square) {
    switch (buttonSize) {
      case ButtonSize.large:
        return const EdgeInsets.all(12);
      case ButtonSize.middle:
        return const EdgeInsets.all(8);
      case ButtonSize.mini:
        return const EdgeInsets.all(6);
      case ButtonSize.small:
        return const EdgeInsets.all(6);
    }
  }

  // Original padding for other shapes
  switch (buttonSize) {
    case ButtonSize.large:
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 12);
    case ButtonSize.middle:
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 8);
    case ButtonSize.mini:
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 4);
    case ButtonSize.small:
      return const EdgeInsets.symmetric(horizontal: 12, vertical: 4);
  }
}

ShapeBorder _buttonShape(
  BuildContext context, {
  ButtonFill? fill = ButtonFill.solid,
  ButtonShape shape = ButtonShape.base,
  ButtonType buttonType = ButtonType.base,
}) {
  switch (shape) {
    case ButtonShape.base:
      return RoundedRectangleBorder(
        side:
            () {
              if (buttonType == ButtonType.base) {
                return BorderSide(color: _buttonColor(context, buttonType: buttonType));
              }
              return fill != ButtonFill.outline
                  ? BorderSide.none
                  : BorderSide(color: _buttonColor(context, buttonType: buttonType));
            }.call(),
        borderRadius: BorderRadius.circular(8),
      );

    case ButtonShape.pill:
      return RoundedRectangleBorder(
        side:
            () {
              if (buttonType == ButtonType.base) {
                return BorderSide(color: _buttonColor(context, buttonType: buttonType));
              }
              return fill != ButtonFill.outline
                  ? BorderSide.none
                  : BorderSide(color: _buttonColor(context, buttonType: buttonType));
            }.call(),
        borderRadius: BorderRadius.circular(1000),
      );

    case ButtonShape.rectangular:
      return RoundedRectangleBorder(
        side:
            () {
              if (buttonType == ButtonType.base) {
                return BorderSide(color: _buttonColor(context, buttonType: buttonType));
              }
              return fill != ButtonFill.outline
                  ? BorderSide.none
                  : BorderSide(color: _buttonColor(context, buttonType: buttonType));
            }.call(),
      );

    case ButtonShape.rounded:
      return RoundedRectangleBorder(
        side:
            () {
              if (buttonType == ButtonType.base) {
                return BorderSide(color: _buttonColor(context, buttonType: buttonType));
              }
              return fill != ButtonFill.outline
                  ? BorderSide.none
                  : BorderSide(color: _buttonColor(context, buttonType: buttonType));
            }.call(),
        borderRadius: BorderRadius.circular(1000), // Fully rounded
      );

    case ButtonShape.square:
      return RoundedRectangleBorder(
        side:
            () {
              if (buttonType == ButtonType.base) {
                return BorderSide(color: _buttonColor(context, buttonType: buttonType));
              }
              return fill != ButtonFill.outline
                  ? BorderSide.none
                  : BorderSide(color: _buttonColor(context, buttonType: buttonType));
            }.call(),
        borderRadius: BorderRadius.zero, // Square with no border radius
      );
  }
}

Color _buttonColor(BuildContext context, {ButtonType buttonType = ButtonType.base}) {
  final palette = context.palette;
  switch (buttonType) {
    case ButtonType.base:
      return palette.border;
    case ButtonType.primary:
      return palette.brand;
    case ButtonType.success:
      return palette.success;
    case ButtonType.warning:
      return palette.warning;
    case ButtonType.danger:
      return palette.danger;
  }
}

/// [TextStyle] based on [ButtonSize] and [ButtonType]
TextStyle _buttonTextStyle(
  BuildContext context, {
  ButtonType buttonType = ButtonType.base,
  ButtonSize buttonSize = ButtonSize.middle,
  ButtonFill? fill = ButtonFill.solid,
}) {
  final palette = context.palette;
  final baseColor = _buttonColor(context, buttonType: buttonType);
  final textColor =
      buttonType == ButtonType.base
          ? palette.textPrimary
          : fill == ButtonFill.solid
          ? ColorUtils.onColor(baseColor)
          : baseColor;
  switch (buttonSize) {
    case ButtonSize.large:
      return TextStyle(fontSize: 18, color: textColor, fontWeight: FontWeight.w400);
    case ButtonSize.middle:
      return TextStyle(fontSize: 17, color: textColor, fontWeight: FontWeight.w400);
    case ButtonSize.mini:
      return TextStyle(fontSize: 13, color: textColor, fontWeight: FontWeight.w400);
    case ButtonSize.small:
      return TextStyle(fontSize: 15, color: textColor, fontWeight: FontWeight.w400);
  }
}

class Button extends StatelessWidget {
  final Function()? onPressed;
  final ButtonType? buttonType;
  final ButtonFill? fill;
  final ButtonShape? shape;
  final ButtonSize? buttonSize;
  final bool? isBlock;
  final Widget child;

  const Button({
    super.key,
    this.onPressed,
    this.fill,
    this.shape,
    this.buttonSize = ButtonSize.middle,
    this.isBlock = false,
    required this.child,
  }) : buttonType = ButtonType.base;

  const Button.primary({
    super.key,
    this.onPressed,
    this.fill,
    this.shape,
    this.buttonSize = ButtonSize.middle,
    this.isBlock = false,
    required this.child,
  }) : buttonType = ButtonType.primary;

  const Button.success({
    super.key,
    this.onPressed,
    this.fill,
    this.shape,
    this.buttonSize = ButtonSize.middle,
    this.isBlock = false,
    required this.child,
  }) : buttonType = ButtonType.success;

  const Button.warning({
    super.key,
    this.onPressed,
    this.fill,
    this.shape,
    this.buttonSize = ButtonSize.middle,
    this.isBlock = false,
    required this.child,
  }) : buttonType = ButtonType.warning;

  const Button.danger({
    super.key,
    this.onPressed,
    this.fill,
    this.shape,
    this.buttonSize = ButtonSize.middle,
    this.isBlock = false,
    required this.child,
  }) : buttonType = ButtonType.danger;

  @override
  Widget build(BuildContext context) {
    final isBlockValue = isBlock ?? false; // Handle null case for isBlock

    return _ButtonImpl(
      buttonType: buttonType ?? ButtonType.base,
      fill: fill ?? ButtonFill.solid,
      onPressed: onPressed,
      shape: shape ?? ButtonShape.base,
      isBlock: isBlockValue,
      buttonSize: buttonSize ?? ButtonSize.middle,
      child: child,
    );
  }
}

class _ButtonImpl extends StatelessWidget {
  const _ButtonImpl({
    required this.buttonType,
    this.fill = ButtonFill.solid,
    this.onPressed,
    this.shape = ButtonShape.base,
    this.buttonSize = ButtonSize.middle,
    this.isBlock = false,
    required this.child,
  });

  final ButtonType buttonType;
  final ButtonFill fill;
  final ButtonShape shape;
  final ButtonSize buttonSize;
  final void Function()? onPressed;
  final bool isBlock;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final effectiveFill = fill;
    final effectiveShape = shape;
    final effectiveSize = buttonSize;

    final isBase = buttonType == ButtonType.base;
    final baseColor = _buttonColor(context, buttonType: buttonType);
    final palette = context.palette;

    final Color fillColor;
    if (effectiveFill == ButtonFill.solid) {
      fillColor = isBase ? palette.background : baseColor;
    } else {
      fillColor = Colors.transparent;
    }

    final Color splashColor;
    if (isBase) {
      final neutral = palette.weak;
      splashColor = ColorUtils.tint(neutral, 0.2).withValues(alpha: 0.2);
    } else {
      splashColor = ColorUtils.tint(baseColor, 0.8).withValues(alpha: 0.4);
    }

    return Opacity(
      opacity: onPressed != null ? 1 : 0.4,
      child: RawMaterialButton(
        shape: _buttonShape(context, shape: effectiveShape, fill: effectiveFill, buttonType: buttonType),
        textStyle: _buttonTextStyle(context, buttonType: buttonType, buttonSize: effectiveSize, fill: effectiveFill),
        elevation: 0,
        focusElevation: 0,
        highlightElevation: 0,
        splashColor: splashColor,
        fillColor: fillColor,
        constraints: _buttonConstants(buttonSize: effectiveSize, isBlock: isBlock, shape: effectiveShape),
        padding: _buttonPadding(buttonSize: effectiveSize, shape: effectiveShape),
        onPressed: onPressed,
        child: child,
      ),
    );
  }
}
