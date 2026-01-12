import 'package:ecommerce/core/widgets/number_stepper/components/compact.dart';
import 'package:ecommerce/core/widgets/number_stepper/components/number_stepper_content.dart';
import 'package:ecommerce/core/widgets/number_stepper/number_stepper_config.dart';
import 'package:ecommerce/core/widgets/number_stepper/number_stepper_controller.dart';
import 'package:flutter/material.dart';

/// A number stepper widget that allows users to increment/decrement a value.
///
/// Can be used in two modes:
/// - Full-size mode (default): Shows minus button, value, and plus button inline
/// - Compact mode: Shows only the value (or plus button when zero),
///   with a popover for controls
///
/// The stepper can be controlled via:
/// - External [controller] for full control over the value and state
/// - Direct [value] property for simpler use cases
///
/// Example:
/// ```dart
/// NumberStepper(
///   value: 1,
///   min: 0,
///   max: 10,
///   onChanged: (value) => print('Value: $value'),
/// )
/// ```
class NumberStepper extends StatefulWidget {
  /// Creates a NumberStepper widget.
  ///
  /// Assertions ensure proper configuration:
  /// - Either [controller] or [value] should be provided, not both for updates
  /// - [step] must be positive
  /// - [min] must be <= [max] if both provided
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
    this.config = const NumberStepperConfig(),
    this.compact = false,
    this.direction = PopoverDirection.right,
  })  : assert(step > 0, 'step must be positive'),
        assert(
          min == null || max == null || min <= max,
          'min must be less than or equal to max',
        );

  /// External controller for the stepper value.
  /// If provided, the widget will use this controller instead of creating one.
  final NumberStepperController? controller;

  /// Initial/current value of the stepper.
  final num? value;

  /// Default value when value is null and allowEmpty is false.
  final num defaultValue;

  /// Callback when the value changes.
  final ValueChanged<num?>? onChanged;

  /// Minimum allowed value.
  final num? min;

  /// Maximum allowed value.
  final num? max;

  /// Step size for increment/decrement.
  final num step;

  /// Number of decimal digits to display.
  final int? digits;

  /// Whether the stepper is disabled.
  final bool disabled;

  /// Whether the value can be empty/null.
  final bool allowEmpty;

  /// Custom value formatter.
  final String Function(num? value)? formatter;

  /// Configuration for visual appearance.
  final NumberStepperConfig config;

  /// Whether to use compact mode (popover-based).
  final bool compact;

  /// Direction for the popover in compact mode.
  final PopoverDirection direction;

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  late NumberStepperController _internalController;
  bool _usesExternalController = false;

  NumberStepperController get _controller {
    final externalController = widget.controller;
    if (externalController != null) {
      return externalController;
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
      widget.controller?.addListener(_onControllerChanged);
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
      final newController = widget.controller;
      if (newController != null) {
        newController.addListener(_onControllerChanged);
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
      widget.onChanged?.call(_controller.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return NumberStepperCompact(
        direction: widget.direction,
        controller: _controller,
        config: widget.config,
        disabled: widget.disabled,
      );
    }

    return NumberStepperContent(
      controller: _controller,
      config: widget.config,
      axis: StepperAxis.horizontal,
      disabled: widget.disabled,
    );
  }
}
