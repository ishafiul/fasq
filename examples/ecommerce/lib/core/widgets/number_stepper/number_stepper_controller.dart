import 'package:flutter/foundation.dart';

/// Controller for NumberStepper widget that manages value state and validation.
/// All business logic is encapsulated here, following Single Responsibility.
class NumberStepperController extends ChangeNotifier {
  /// Creates a NumberStepperController with the given configuration.
  ///
  /// Assertions validate the configuration:
  /// - [step] must be positive
  /// - [min] must be less than or equal to [max] if both are provided
  /// - [digits] must be between 0 and 20 if provided
  NumberStepperController({
    num? value,
    this.defaultValue = 0,
    this.min,
    this.max,
    this.step = 1,
    this.digits,
    this.allowEmpty = false,
    this.formatter,
  })  : assert(step > 0, 'step must be positive'),
        assert(
          min == null || max == null || min <= max,
          'min must be less than or equal to max',
        ),
        assert(
          digits == null || (digits >= 0 && digits <= 20),
          'digits must be between 0 and 20',
        ),
        _value = value ?? defaultValue;

  num? _value;

  /// Default value used when value is null and allowEmpty is false.
  final num defaultValue;

  /// Minimum allowed value. If null, no minimum is enforced.
  final num? min;

  /// Maximum allowed value. If null, no maximum is enforced.
  final num? max;

  /// Step size for increment/decrement operations.
  final num step;

  /// Number of decimal digits to display.
  final int? digits;

  /// Whether the value can be null/empty.
  final bool allowEmpty;

  /// Custom formatter for displaying the value.
  final String Function(num? value)? formatter;

  /// Current value of the stepper.
  num? get value => _value;

  /// Formatted string representation of the current value.
  String get formattedValue => formatValue(_value);

  /// Returns true if the value is at or below the minimum.
  bool get isAtMin {
    final currentValue = _value;
    final minValue = min;
    if (currentValue == null || minValue == null) return false;
    return currentValue <= minValue;
  }

  /// Returns true if the value is at or above the maximum.
  bool get isAtMax {
    final currentValue = _value;
    final maxValue = max;
    if (currentValue == null || maxValue == null) return false;
    return currentValue >= maxValue;
  }

  /// Returns true if increment is possible.
  bool get canIncrement => !isAtMax;

  /// Returns true if decrement is possible.
  bool get canDecrement => _value != null && !isAtMin;

  /// Whether the value should trigger deletion (show delete button).
  /// Returns true when value is 1 or at the minimum value (but above 0).
  bool get shouldShowDelete {
    final currentValue = _value ?? defaultValue;
    final minValue = min;
    return currentValue == 1 || (minValue != null && currentValue == minValue && currentValue > 0);
  }

  int _getValidDigits() {
    final digitValue = digits;
    if (digitValue == null) return 0;
    return digitValue.clamp(0, 20);
  }

  /// Formats the value for display.
  String formatValue(num? value) {
    if (value == null) return '';
    final formatterFn = formatter;
    if (formatterFn != null) {
      return formatterFn(value);
    }
    final validDigits = _getValidDigits();
    if (validDigits > 0) {
      return value.toStringAsFixed(validDigits);
    }
    return value.toString();
  }

  num _clampValue(num value) {
    var result = value;
    final minValue = min;
    final maxValue = max;

    if (minValue != null && result < minValue && result != 0) {
      result = minValue;
    }
    if (maxValue != null && result > maxValue) {
      result = maxValue;
    }

    final validDigits = _getValidDigits();
    if (validDigits > 0) {
      result = num.parse(result.toStringAsFixed(validDigits));
    }
    return result;
  }

  /// Sets a new value, clamping it to min/max bounds.
  void setValue(num? newValue) {
    num? finalValue = newValue;
    if (finalValue == null && !allowEmpty) {
      finalValue = defaultValue;
    }
    if (finalValue != null) {
      finalValue = _clampValue(finalValue);
    }
    if (_value == finalValue) return;

    _value = finalValue;
    notifyListeners();
  }

  /// Increments the value by step.
  void increment() {
    final current = _value ?? defaultValue;
    final minValue = min;
    if (minValue != null && current < minValue) {
      setValue(minValue);
      return;
    }
    setValue(current + step);
  }

  /// Decrements the value by step.
  void decrement() {
    final current = _value ?? defaultValue;
    setValue(current - step);
  }
}
