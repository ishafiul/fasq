import 'package:ecommerce_ui/src/theme/colors.dart';
import 'package:ecommerce_ui/src/theme/const.dart';
import 'package:ecommerce_ui/src/widgets/number_stepper/components/number_box.dart';
import 'package:ecommerce_ui/src/widgets/number_stepper/components/stepper_button.dart';
import 'package:ecommerce_ui/src/widgets/number_stepper/number_stepper_config.dart';
import 'package:ecommerce_ui/src/widgets/number_stepper/number_stepper_controller.dart';
import 'package:flutter/material.dart';

/// Axis for stepper layout (DRY - used by both compact and full-size).
enum StepperAxis { horizontal, vertical }

/// Shared content widget for NumberStepper - follows DRY principle.
/// Used by both compact popover and full-size stepper.
class NumberStepperContent extends StatelessWidget {
  const NumberStepperContent({
    super.key,
    required this.controller,
    required this.config,
    required this.axis,
    this.showDeleteButton = false,
    this.onIncrement,
    this.onDecrement,
    this.onDelete,
    this.disabled = false,
  });

  final NumberStepperController controller;
  final NumberStepperConfig config;
  final StepperAxis axis;
  final bool showDeleteButton;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final VoidCallback? onDelete;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = context.radius;
    final spacing = context.spacing;

    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final decrementWidget = _DecrementButton(
          controller: controller,
          config: config,
          palette: palette,
          showDeleteButton: showDeleteButton,
          disabled: disabled,
          onDecrement: onDecrement,
          onDelete: onDelete,
        );
        final numberBox = _StepperNumberBox(
          controller: controller,
          config: config,
          palette: palette,
          radius: radius,
          spacing: spacing,
        );
        final incrementWidget = _IncrementButton(
          controller: controller,
          config: config,
          palette: palette,
          disabled: disabled,
          onIncrement: onIncrement,
        );

        return Opacity(
          opacity: disabled ? 0.4 : 1.0,
          child: switch (axis) {
            StepperAxis.horizontal => Row(
                mainAxisSize: MainAxisSize.min,
                children: [decrementWidget, numberBox, incrementWidget],
              ),
            StepperAxis.vertical => Column(
                mainAxisSize: MainAxisSize.min,
                children: [incrementWidget, numberBox, decrementWidget],
              ),
          },
        );
      },
    );
  }
}

class _DecrementButton extends StatelessWidget {
  const _DecrementButton({
    required this.controller,
    required this.config,
    required this.palette,
    required this.showDeleteButton,
    required this.disabled,
    this.onDecrement,
    this.onDelete,
  });

  final NumberStepperController controller;
  final NumberStepperConfig config;
  final AppPalette palette;
  final bool showDeleteButton;
  final bool disabled;
  final VoidCallback? onDecrement;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final shouldDelete = showDeleteButton && controller.shouldShowDelete;

    if (shouldDelete) {
      return StepperDeleteButton(
        iconSize: config.iconSize,
        dangerColor: palette.danger,
        disabledColor: palette.disabledText,
        isDisabled: disabled,
        onPressed: disabled
            ? null
            : () {
                controller.setValue(0);
                onDelete?.call();
              },
      );
    }

    return StepperMinusButton(
      iconSize: config.iconSize,
      primaryColor: palette.brand,
      disabledColor: palette.disabledText,
      isDisabled: disabled || controller.isAtMin,
      onPressed: disabled
          ? null
          : () {
              controller.decrement();
              onDecrement?.call();
            },
    );
  }
}

class _IncrementButton extends StatelessWidget {
  const _IncrementButton({
    required this.controller,
    required this.config,
    required this.palette,
    required this.disabled,
    this.onIncrement,
  });

  final NumberStepperController controller;
  final NumberStepperConfig config;
  final AppPalette palette;
  final bool disabled;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return StepperPlusButton(
      iconSize: config.iconSize,
      primaryColor: palette.brand,
      disabledColor: palette.disabledText,
      isDisabled: disabled || controller.isAtMax,
      onPressed: disabled
          ? null
          : () {
              controller.increment();
              onIncrement?.call();
            },
    );
  }
}

class _StepperNumberBox extends StatelessWidget {
  const _StepperNumberBox({
    required this.controller,
    required this.config,
    required this.palette,
    required this.radius,
    required this.spacing,
  });

  final NumberStepperController controller;
  final NumberStepperConfig config;
  final AppPalette palette;
  final RadiusScale radius;
  final Spacing spacing;

  @override
  Widget build(BuildContext context) {
    return NumberBox(
      backgroundColor: palette.background,
      borderColor: palette.border,
      textColor: palette.textPrimary,
      borderRadius: config.calculateBorderRadius(radius.xs),
      height: config.calculateInputHeight(spacing.xs),
      padding: config.calculateInputPadding(spacing.xs),
      valueText: controller.formattedValue,
    );
  }
}
