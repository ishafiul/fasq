import 'dart:async';

import 'package:flutter/foundation.dart';

enum NumberStepperExpandDirection {
  top,
  bottom,
  left,
  right,
  centerHorizontal,
  centerVertical,
}

class NumberStepperController extends ChangeNotifier {
  NumberStepperController({
    num? value,
    this.defaultValue = 0,
    this.min,
    this.max,
    this.step = 1,
    this.digits,
    this.allowEmpty = false,
    this.formatter,
    this.compact = false,
    NumberStepperExpandDirection expandDirection = NumberStepperExpandDirection.left,
    this.collapseDelay = const Duration(seconds: 2),
  })  : _value = value ?? defaultValue,
        _expandDirection = expandDirection;

  num? _value;
  bool _isExpanded = false;
  NumberStepperExpandDirection _expandDirection;
  Timer? _collapseTimer;

  final num defaultValue;
  final num? min;
  final num? max;
  final num step;
  final int? digits;
  final bool allowEmpty;
  final String Function(num? value)? formatter;
  final bool compact;
  final Duration collapseDelay;

  num? get value => _value;
  bool get isExpanded => _isExpanded;
  NumberStepperExpandDirection get expandDirection => _expandDirection;

  String get formattedValue => formatValue(_value);

  bool get isAtMin => _isAtMin();
  bool get isAtMax => _isAtMax();
  bool get canIncrement => _canIncrement();
  bool get canDecrement => _canDecrement();

  bool get isMinusDisabled {
    if (_value == null) return false;
    if (compact && isAtMin) return false;
    if (min == null) return false;
    return _value! <= min!;
  }

  bool get isPlusDisabled {
    if (_value == null) return false;
    if (max == null) return false;
    return _value! >= max!;
  }

  bool get shouldShowCollapsedPlusOnly {
    if (!compact) return false;
    if (_isExpanded) return false;
    return isAtMin;
  }

  bool get shouldShowCollapsedNumber {
    if (!compact) return false;
    if (_isExpanded) return false;
    return !isAtMin;
  }

  int _getValidDigits() {
    if (digits == null) return 0;
    return digits!.clamp(0, 20);
  }

  String formatValue(num? value) {
    if (value == null) return '';
    if (formatter != null) {
      return formatter!(value);
    }
    final validDigits = _getValidDigits();
    if (validDigits > 0) {
      return value.toStringAsFixed(validDigits);
    }
    return value.toString();
  }

  num _clampValue(num value) {
    var result = value;
    if (min != null && result < min!) {
      result = min!;
    }
    if (max != null && result > max!) {
      result = max!;
    }
    final validDigits = _getValidDigits();
    if (validDigits > 0) {
      result = num.parse(result.toStringAsFixed(validDigits));
    }
    return result;
  }

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

  void setExpandDirection(NumberStepperExpandDirection direction) {
    if (_expandDirection == direction) return;
    _expandDirection = direction;
    notifyListeners();
  }

  void increment() {
    final current = _value ?? defaultValue;
    setValue(current + step);
    if (compact) {
      expand();
    }
  }

  void decrement() {
    final current = _value ?? defaultValue;
    setValue(current - step);
    if (compact) {
      expand();
    }
  }

  void expand() {
    _collapseTimer?.cancel();
    _isExpanded = true;
    notifyListeners();
    _startCollapseTimer();
  }

  void collapse() {
    _collapseTimer?.cancel();
    _isExpanded = false;
    notifyListeners();
  }

  void _startCollapseTimer() {
    _collapseTimer?.cancel();
    _collapseTimer = Timer(collapseDelay, () {
      collapse();
    });
  }

  bool _isAtMin() {
    if (_value == null) return false;
    if (min == null) return false;
    return _value! <= min!;
  }

  bool _isAtMax() {
    if (_value == null) return false;
    if (max == null) return false;
    return _value! >= max!;
  }

  bool _canIncrement() {
    if (_value == null) return true;
    if (max == null) return true;
    return _value! < max!;
  }

  bool _canDecrement() {
    if (_value == null) return false;
    if (compact && isAtMin) return true;
    if (min == null) return true;
    return _value! > min!;
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    super.dispose();
  }
}
