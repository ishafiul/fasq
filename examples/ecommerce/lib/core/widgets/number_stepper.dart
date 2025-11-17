import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:ecommerce/core/widgets/svg_icon.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:flutter/material.dart';

class NumberStepper extends StatefulWidget {
  const NumberStepper({
    super.key,
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
  });

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

  @override
  State<NumberStepper> createState() => _NumberStepperState();
}

class _NumberStepperState extends State<NumberStepper> {
  late num? _value;

  @override
  void initState() {
    super.initState();
    _value = widget.value ?? widget.defaultValue;
  }

  @override
  void didUpdateWidget(covariant NumberStepper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _value = widget.value;
    }
  }

  int _getValidDigits() {
    if (widget.digits == null) return 0;
    return widget.digits!.clamp(0, 20);
  }

  String _formatValue(num? value) {
    if (value == null) return '';
    if (widget.formatter != null) {
      return widget.formatter!(value);
    }
    final digits = _getValidDigits();
    if (digits > 0) {
      return value.toStringAsFixed(digits);
    }
    return value.toString();
  }

  num _clampValue(num value) {
    var result = value;
    if (widget.min != null && result < widget.min!) {
      result = widget.min!;
    }
    if (widget.max != null && result > widget.max!) {
      result = widget.max!;
    }
    final digits = _getValidDigits();
    if (digits > 0) {
      result = num.parse(result.toStringAsFixed(digits));
    }
    return result;
  }

  void _setValue(num? newValue) {
    num? finalValue = newValue;
    if (finalValue == null && !widget.allowEmpty) {
      finalValue = widget.defaultValue;
    }
    if (finalValue != null) {
      finalValue = _clampValue(finalValue);
    }
    if (_value == finalValue) return;

    setState(() {
      _value = finalValue;
    });
    widget.onChanged?.call(finalValue);
  }

  void _handleOffset(bool positive) {
    final current = _value ?? widget.defaultValue;
    final stepValue = positive ? widget.step : -widget.step;
    _setValue(current + stepValue);
  }

  void _handleMinus() {
    _handleOffset(false);
  }

  void _handlePlus() {
    _handleOffset(true);
  }

  bool _isMinusDisabled() {
    if (widget.disabled) return true;
    if (_value == null) return false;
    if (widget.min != null) {
      return _value! <= widget.min!;
    }
    return false;
  }

  bool _isPlusDisabled() {
    if (widget.disabled) return true;
    if (_value == null) return false;
    if (widget.max != null) {
      return _value! >= widget.max!;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final radius = context.radius;

    final backgroundColor = palette.background;
    final borderColor = palette.border;
    final primaryColor = palette.info;
    final textColor = palette.textPrimary;
    final borderRadius = radius.xs / 2;
    const iconSize = 18.0;
    final inputHeight = 40.0 - (context.spacing.xs - 2);
    final inputPadding = EdgeInsets.symmetric(horizontal: context.spacing.xs, vertical: context.spacing.xs - 2);

    return Opacity(
      opacity: widget.disabled ? 0.4 : 1.0,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Button(
            shape: ButtonShape.square,
            fill: ButtonFill.solid,
            onPressed: _isMinusDisabled() ? null : _handleMinus,
            child: SvgIcon(
              svg: Assets.icons.outlined.minus,
              size: iconSize,
              color: _isMinusDisabled() ? palette.disabledText : primaryColor,
            ),
          ),
          Container(
            height: inputHeight,
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(color: borderColor),
            ),
            padding: inputPadding,
            alignment: Alignment.center,
            child: Text(
              _formatValue(_value),
              textAlign: TextAlign.center,
              style: context.textTheme.bodySmall?.copyWith(fontSize: 14, color: textColor),
            ),
          ),
          Button(
            shape: ButtonShape.square,
            fill: ButtonFill.solid,
            onPressed: _isPlusDisabled() ? null : _handlePlus,
            child: SvgIcon(
              svg: Assets.icons.outlined.plus,
              size: iconSize,
              color: _isPlusDisabled() ? palette.disabledText : primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
