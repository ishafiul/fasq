import 'dart:async';

import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/number_stepper/components/number_box.dart';
import 'package:ecommerce/core/widgets/number_stepper/components/number_stepper_content.dart';
import 'package:ecommerce/core/widgets/number_stepper/components/stepper_button.dart';
import 'package:ecommerce/core/widgets/number_stepper/number_stepper_config.dart';
import 'package:ecommerce/core/widgets/number_stepper/number_stepper_controller.dart';
import 'package:ecommerce/core/widgets/number_stepper/popover_position_calculator.dart';
import 'package:flutter/material.dart';

/// Direction for the popover menu to open.
enum PopoverDirection { left, right, top, bottom }

/// Compact version of NumberStepper that shows a popover on tap.
/// When value is 0, shows only a plus button. Otherwise shows the value
/// which opens a popover with increment/decrement controls on tap.
class NumberStepperCompact extends StatefulWidget {
  const NumberStepperCompact({
    super.key,
    required this.direction,
    required this.controller,
    required this.config,
    this.disabled = false,
    this.onDelete,
  });

  final PopoverDirection direction;
  final NumberStepperController controller;
  final NumberStepperConfig config;
  final bool disabled;
  final VoidCallback? onDelete;

  @override
  State<NumberStepperCompact> createState() => _NumberStepperCompactState();
}

class _NumberStepperCompactState extends State<NumberStepperCompact> {
  Timer? _autoCloseTimer;
  bool _isMenuOpen = false;

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  void _startAutoClose() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(seconds: 2), () {
      if (mounted && _isMenuOpen) {
        _closeMenu();
      }
    });
  }

  void _resetAutoCloseTimer() {
    _startAutoClose();
  }

  void _closeMenu() {
    _autoCloseTimer?.cancel();
    if (mounted && _isMenuOpen) {
      setState(() => _isMenuOpen = false);
      Navigator.of(context).pop();
    }
  }

  void _showButtonMenu() {
    if (_isMenuOpen) return;

    final renderObject = context.findRenderObject();
    if (renderObject is! RenderBox) return;

    final offset = renderObject.localToGlobal(Offset.zero);
    final position = PopoverPositionCalculator.calculate(
      anchorOffset: offset,
      anchorSize: renderObject.size,
      direction: widget.direction,
    );

    setState(() => _isMenuOpen = true);
    _startAutoClose();

    unawaited(
      showMenu<void>(
        context: context,
        useRootNavigator: true,
        position: position,
        elevation: 0,
        color: Colors.transparent,
        items: [
          PopupMenuItem<void>(
            enabled: false,
            padding: EdgeInsets.zero,
            child: NumberStepperContent(
              controller: widget.controller,
              config: widget.config,
              axis: _axisForDirection(widget.direction),
              showDeleteButton: widget.onDelete != null,
              onIncrement: _resetAutoCloseTimer,
              onDecrement: _resetAutoCloseTimer,
              onDelete: () {
                widget.onDelete?.call();
                _closeMenu();
              },
            ),
          ),
        ],
      ).then((_) {
        if (mounted) {
          setState(() => _isMenuOpen = false);
          _autoCloseTimer?.cancel();
        }
      }),
    );
  }

  StepperAxis _axisForDirection(PopoverDirection direction) {
    return switch (direction) {
      PopoverDirection.left || PopoverDirection.right => StepperAxis.horizontal,
      PopoverDirection.top || PopoverDirection.bottom => StepperAxis.vertical,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final currentValue = widget.controller.value ?? 0;
        final isZero = currentValue <= 0;

        if (isZero) {
          return _ZeroStateTrigger(
            controller: widget.controller,
            config: widget.config,
            disabled: widget.disabled,
            onIncrementAndShowMenu: () {
              widget.controller.increment();
              WidgetsBinding.instance.addPostFrameCallback((_) {
                _showButtonMenu();
              });
            },
          );
        }

        return _ValueTrigger(
          controller: widget.controller,
          config: widget.config,
          disabled: widget.disabled,
          isMenuOpen: _isMenuOpen,
          onTap: widget.disabled ? null : _showButtonMenu,
        );
      },
    );
  }
}

/// Trigger widget shown when value is zero - displays plus button.
class _ZeroStateTrigger extends StatelessWidget {
  const _ZeroStateTrigger({
    required this.controller,
    required this.config,
    required this.disabled,
    required this.onIncrementAndShowMenu,
  });

  final NumberStepperController controller;
  final NumberStepperConfig config;
  final bool disabled;
  final VoidCallback onIncrementAndShowMenu;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return StepperPlusButton(
      iconSize: config.iconSize,
      primaryColor: palette.brand,
      disabledColor: palette.disabledText,
      isDisabled: disabled,
      onPressed: disabled ? null : onIncrementAndShowMenu,
    );
  }
}

/// Trigger widget shown when value is non-zero - displays the value box.
class _ValueTrigger extends StatelessWidget {
  const _ValueTrigger({
    required this.controller,
    required this.config,
    required this.disabled,
    required this.isMenuOpen,
    this.onTap,
  });

  final NumberStepperController controller;
  final NumberStepperConfig config;
  final bool disabled;
  final bool isMenuOpen;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = context.radius;
    final spacing = context.spacing;

    final backgroundColor = palette.background;
    final borderColor = palette.border;
    final textColor = palette.textPrimary;
    final borderRadius = config.calculateBorderRadius(radius.xs);
    final inputHeight = config.calculateInputHeight(spacing.xs);
    final inputPadding = config.calculateInputPadding(spacing.xs);
    final valueText = controller.formattedValue;

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Opacity(
          opacity: isMenuOpen ? 0.0 : (disabled ? 0.4 : 1.0),
          child: NumberBox(
            backgroundColor: backgroundColor,
            borderColor: borderColor,
            textColor: textColor,
            borderRadius: borderRadius,
            height: inputHeight,
            padding: inputPadding,
            valueText: valueText,
          ),
        ),
      ),
    );
  }
}
