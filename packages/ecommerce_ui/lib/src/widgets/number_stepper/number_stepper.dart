import 'package:ecommerce_ui/src/theme/colors.dart';
import 'package:ecommerce_ui/src/theme/const.dart';
import 'package:ecommerce_ui/src/widgets/number_stepper/components/compact.dart';
import 'package:ecommerce_ui/src/widgets/number_stepper/components/number_box.dart';
import 'package:ecommerce_ui/src/widgets/number_stepper/components/stepper_button.dart';
import 'package:ecommerce_ui/src/widgets/number_stepper/number_stepper_config.dart';
import 'package:ecommerce_ui/src/widgets/number_stepper/number_stepper_controller.dart';
import 'package:flutter/material.dart';

enum NumberStepperExpandDirection { left, right, top, bottom }

extension NumberStepperExpandDirectionExtension on NumberStepperExpandDirection {
  PopoverDirection toPopoverDirection() {
    return switch (this) {
      NumberStepperExpandDirection.left => PopoverDirection.left,
      NumberStepperExpandDirection.right => PopoverDirection.right,
      NumberStepperExpandDirection.top => PopoverDirection.top,
      NumberStepperExpandDirection.bottom => PopoverDirection.bottom,
    };
  }
}

class NumberStepper extends StatefulWidget {
  const NumberStepper({
    super.key,
    this.controller,
    this.value,
    this.defaultValue = 0,
    this.onChanged,
    this.min,
    this.max,
    this.step = 1,
    this.digits,
    this.disabled = false,
    this.allowEmpty = false,
    this.formatter,
    this.compact = false,
    this.expandDirection = NumberStepperExpandDirection.left,
    this.onDelete,
    this.collapseDelay = const Duration(seconds: 2),
    this.showDirectionMenu = false,
    this.config = const NumberStepperConfig(),
  });

  final NumberStepperController? controller;
  final num? value;
  final num defaultValue;
  final ValueChanged<num?>? onChanged;
  final num? min;
  final num? max;
  final num step;
  final int? digits;
  final bool disabled;
  final bool allowEmpty;
  final String Function(num? value)? formatter;
  final bool compact;
  final NumberStepperExpandDirection expandDirection;
  final VoidCallback? onDelete;
  final Duration collapseDelay;
  final bool showDirectionMenu;
  final NumberStepperConfig config;

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  late NumberStepperController _internalController;
  bool _usesExternalController = false;

  NumberStepperController get _controller {
    if (widget.controller != null) {
      return widget.controller!;
    }
    return _internalController;
  }

  @override
  void initState() {
    super.initState();
    _usesExternalController = widget.controller != null;
    if (!_usesExternalController) {
      _internalController = NumberStepperController(
        value: widget.value,
        defaultValue: widget.defaultValue,
        min: widget.min,
        max: widget.max,
        step: widget.step,
        digits: widget.digits,
        allowEmpty: widget.allowEmpty,
        formatter: widget.formatter,
      );
      _internalController.addListener(_onControllerChanged);
    } else {
      widget.controller!.addListener(_onControllerChanged);
    }
  }

  @override
  void dispose() {
    if (!_usesExternalController) {
      _internalController.removeListener(_onControllerChanged);
      _internalController.dispose();
    } else {
      widget.controller?.removeListener(_onControllerChanged);
    }
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NumberStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      if (widget.controller != null) {
        widget.controller!.addListener(_onControllerChanged);
        _usesExternalController = true;
      } else {
        _usesExternalController = false;
        _internalController.addListener(_onControllerChanged);
      }
    }
    if (!_usesExternalController && widget.value != oldWidget.value) {
      _internalController.setValue(widget.value);
    }
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
      widget.onChanged?.call(_controller.value);
    }
  }

  void _handleIncrement() {
    _controller.increment();
  }

  void _handleDecrement() {
    _controller.decrement();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = context.radius;
    final spacing = context.spacing;

    final backgroundColor = palette.background;
    final borderColor = palette.border;
    final primaryColor = palette.info;
    final textColor = palette.textPrimary;
    final disabledTextColor = palette.disabledText;
    final borderRadius = widget.config.calculateBorderRadius(radius.xs);
    final iconSize = widget.config.iconSize;
    final inputHeight = widget.config.calculateInputHeight(spacing.xs);
    final inputPadding = widget.config.calculateInputPadding(spacing.xs);

    if (!widget.compact) {
      return _buildFullStepper(
        palette: palette,
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        primaryColor: primaryColor,
        textColor: textColor,
        disabledTextColor: disabledTextColor,
        borderRadius: borderRadius,
        iconSize: iconSize,
        inputHeight: inputHeight,
        inputPadding: inputPadding,
      );
    }

    return NumberStepperCompact(
      direction: widget.expandDirection.toPopoverDirection(),
      controller: _controller,
      config: widget.config,
      disabled: widget.disabled,
      onDelete: widget.onDelete,
    );
  }

  Widget _buildFullStepper({
    required AppPalette palette,
    required Color backgroundColor,
    required Color borderColor,
    required Color primaryColor,
    required Color textColor,
    required Color disabledTextColor,
    required double borderRadius,
    required double iconSize,
    required double inputHeight,
    required EdgeInsets inputPadding,
  }) {
    final shouldShowDelete = widget.onDelete != null && _controller.shouldShowDelete;

    return Opacity(
      opacity: widget.disabled ? 0.4 : 1.0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (shouldShowDelete)
            StepperDeleteButton(
              iconSize: iconSize,
              dangerColor: palette.danger,
              disabledColor: disabledTextColor,
              isDisabled: widget.disabled,
              onPressed: widget.disabled
                  ? null
                  : () {
                      _controller.setValue(0);
                      widget.onDelete?.call();
                    },
            )
          else
            StepperMinusButton(
              iconSize: iconSize,
              primaryColor: primaryColor,
              disabledColor: disabledTextColor,
              isDisabled: widget.disabled || !_controller.canDecrement,
              onPressed: widget.disabled ? null : _handleDecrement,
            ),
          NumberBox(
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            textColor: textColor,
            borderRadius: borderRadius,
            height: inputHeight,
            padding: inputPadding,
            valueText: _controller.formattedValue,
          ),
          StepperPlusButton(
            iconSize: iconSize,
            primaryColor: primaryColor,
            disabledColor: disabledTextColor,
            isDisabled: widget.disabled || !_controller.canIncrement,
            onPressed: widget.disabled ? null : _handleIncrement,
          ),
        ],
      ),
    );
  }
}
