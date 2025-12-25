import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/number_stepper/components/direction_menu.dart';
import 'package:ecommerce/core/widgets/number_stepper/components/directional_reveal.dart';
import 'package:ecommerce/core/widgets/number_stepper/components/number_box.dart';
import 'package:ecommerce/core/widgets/number_stepper/components/stepper_buttons.dart';
import 'package:ecommerce/core/widgets/number_stepper/number_stepper_config.dart';
import 'package:ecommerce/core/widgets/number_stepper/number_stepper_controller.dart';
import 'package:flutter/material.dart';

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
        compact: widget.compact,
        expandDirection: widget.expandDirection,
        collapseDelay: widget.collapseDelay,
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

  void _handleDelete() {
    widget.onDelete?.call();
    _controller.collapse();
  }

  void _handleNumberTap() {
    if (_controller.compact && !_controller.isExpanded) {
      _controller.expand();
    }
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
    final dangerColor = palette.danger;
    final borderRadius = widget.config.calculateBorderRadius(radius.xs);
    final iconSize = widget.config.iconSize;
    final inputHeight = widget.config.calculateInputHeight(spacing.xs);
    final inputPadding = widget.config.calculateInputPadding(spacing.xs);

    if (!_controller.compact) {
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

    return Opacity(
      opacity: widget.disabled ? 0.4 : 1.0,
      child: _buildCompactStepper(
        backgroundColor: backgroundColor,
        borderColor: borderColor,
        primaryColor: primaryColor,
        textColor: textColor,
        disabledTextColor: disabledTextColor,
        dangerColor: dangerColor,
        borderRadius: borderRadius,
        iconSize: iconSize,
        inputHeight: inputHeight,
        inputPadding: inputPadding,
        gap: widget.config.calculateGap(spacing.xs),
      ),
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
    return Opacity(
      opacity: widget.disabled ? 0.4 : 1.0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StepperButtons.buildMinusButton(
            iconSize: iconSize,
            primaryColor: primaryColor,
            disabledTextColor: disabledTextColor,
            isDisabled: widget.disabled || _controller.isMinusDisabled,
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
          StepperButtons.buildPlusButton(
            iconSize: iconSize,
            primaryColor: primaryColor,
            disabledTextColor: disabledTextColor,
            isDisabled: widget.disabled || _controller.isPlusDisabled,
            onPressed: widget.disabled ? null : _handleIncrement,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactStepper({
    required Color backgroundColor,
    required Color borderColor,
    required Color primaryColor,
    required Color textColor,
    required Color disabledTextColor,
    required Color dangerColor,
    required double borderRadius,
    required double iconSize,
    required double inputHeight,
    required EdgeInsets inputPadding,
    required double gap,
  }) {
    final numberBox = NumberBox(
      backgroundColor: backgroundColor,
      borderColor: borderColor,
      textColor: textColor,
      borderRadius: borderRadius,
      height: inputHeight,
      padding: inputPadding,
      valueText: _controller.formattedValue,
      onTap: widget.disabled ? null : _handleNumberTap,
    );

    final isPlusDisabled = widget.disabled || _controller.isPlusDisabled;
    final plusButton = StepperButtons.buildPlusButton(
      iconSize: iconSize,
      primaryColor: primaryColor,
      disabledTextColor: disabledTextColor,
      isDisabled: isPlusDisabled,
      //onPressed: widget.disabled ? null : _handleIncrement,
      onPressed: widget.disabled ? null : _handleIncrement,
    );

    final minusOrDeleteButton = _controller.isAtMin && widget.onDelete != null
        ? StepperButtons.buildDeleteButton(
            iconSize: iconSize,
            dangerColor: dangerColor,
            disabledTextColor: disabledTextColor,
            isDisabled: widget.disabled,
            onPressed: widget.disabled ? null : _handleDelete,
          )
        : StepperButtons.buildMinusButton(
            iconSize: iconSize,
            primaryColor: primaryColor,
            disabledTextColor: disabledTextColor,
            isDisabled: widget.disabled || _controller.isMinusDisabled,
            onPressed: widget.disabled ? null : _handleDecrement,
          );

    final menu = widget.showDirectionMenu && widget.controller != null
        ? DirectionMenu(
            onSelected: (direction) => widget.controller!.setExpandDirection(direction),
          )
        : null;

    return DirectionalReveal(
      direction: _controller.expandDirection,
      isExpanded: _controller.isExpanded,
      showCollapsedPlusOnly: _controller.shouldShowCollapsedPlusOnly,
      config: widget.config,
      estimatedAnchorExtent: inputHeight,
      gap: gap,
      numberBox: numberBox,
      minusOrDeleteButton: minusOrDeleteButton,
      plusButton: plusButton,
      menu: menu,
    );
  }
}
