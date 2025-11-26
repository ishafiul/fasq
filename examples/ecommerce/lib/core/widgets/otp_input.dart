import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Custom text input formatter for OTP fields that allows paste but limits single input.
class _OTPInputFormatter extends TextInputFormatter {
  _OTPInputFormatter(this.pattern);

  final RegExp pattern;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    // Allow paste (length > 1) - we'll handle it in onChanged
    // Filter to only matching characters but keep all of them for paste detection
    if (newValue.text.length > 1) {
      final filtered = newValue.text.split('').where((char) => pattern.hasMatch(char)).join();
      return TextEditingValue(text: filtered, selection: TextSelection.collapsed(offset: filtered.length));
    }

    // For single character, filter if it doesn't match pattern
    if (newValue.text.isNotEmpty && !pattern.hasMatch(newValue.text)) {
      return oldValue;
    }

    return newValue;
  }
}

enum OTPInputType { numeric, alphanumeric, alphabet, numericSymbol, alphabetSymbol, alphabetNumeric, all }

class OTPInput extends StatefulWidget {
  const OTPInput({
    super.key,
    required this.length,
    this.onChange,
    this.onComplete,
    this.autoSubmit,
    this.mask = false,
    this.maskChar,
    this.disabled = false,
    this.autoFocus = false,
    this.inputType = OTPInputType.numeric,
    this.customPattern,
    this.textInputAction = TextInputAction.done,
    this.obscureText = false,
    this.placeholder,
    this.isPreservedFocus = false,
    this.inputStyle,
    this.errorText,
  });

  final int length;
  final ValueChanged<String>? onChange;
  final ValueChanged<String>? onComplete;
  final VoidCallback? autoSubmit;
  final bool mask;
  final String? maskChar;
  final bool disabled;
  final bool autoFocus;
  final OTPInputType inputType;
  final RegExp? customPattern;
  final TextInputAction textInputAction;
  final bool obscureText;
  final String? placeholder;
  final bool isPreservedFocus;
  final TextStyle? inputStyle;
  final String? errorText;

  @override
  State<OTPInput> createState() => _OTPInputState();
}

class _OTPInputState extends State<OTPInput> {
  final List<FocusNode> _focusNodes = [];
  final List<TextEditingController> _controllers = [];
  final List<GlobalKey> _inputKeys = [];
  String _value = '';

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < widget.length; i++) {
      _focusNodes.add(FocusNode());
      _controllers.add(TextEditingController());
      _inputKeys.add(GlobalKey());
    }
    if (widget.autoFocus && _focusNodes.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _focusNodes[0].requestFocus();
      });
    }
  }

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  RegExp get _pattern {
    if (widget.customPattern != null) {
      return widget.customPattern!;
    }
    switch (widget.inputType) {
      case OTPInputType.numeric:
        return RegExp('[0-9]');
      case OTPInputType.alphanumeric:
        return RegExp('[0-9a-zA-Z]');
      case OTPInputType.alphabet:
        return RegExp('[a-zA-Z]');
      case OTPInputType.numericSymbol:
        return RegExp('[0-9!@#\$%^&*()_+\\-=\\[\\]{};\':"\\\\|,.<>/?]');
      case OTPInputType.alphabetSymbol:
        return RegExp('[a-zA-Z!@#\$%^&*()_+\\-=\\[\\]{};\':"\\\\|,.<>/?]');
      case OTPInputType.alphabetNumeric:
        return RegExp('[0-9a-zA-Z]');
      case OTPInputType.all:
        return RegExp('.');
    }
  }

  TextInputType get _keyboardType {
    switch (widget.inputType) {
      case OTPInputType.numeric:
      case OTPInputType.numericSymbol:
        return TextInputType.number;
      case OTPInputType.alphabet:
      case OTPInputType.alphanumeric:
      case OTPInputType.alphabetSymbol:
      case OTPInputType.alphabetNumeric:
      case OTPInputType.all:
        return TextInputType.text;
    }
  }

  void _updateValue() {
    final newValue = _controllers.map((c) => c.text).join();
    if (_value != newValue) {
      _value = newValue;
      widget.onChange?.call(_value);
      if (_value.length == widget.length) {
        widget.onComplete?.call(_value);
        if (widget.autoSubmit != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            widget.autoSubmit?.call();
          });
        }
        if (!widget.isPreservedFocus) {
          _focusNodes[widget.length - 1].unfocus();
        }
      }
    }
  }

  void _handleChange(int index, String value) {
    // Handle paste: if value length > 1, it means user pasted text
    if (value.length > 1) {
      _handlePaste(index, value);
      return;
    }

    if (value.isEmpty) {
      _controllers[index].text = '';
      _updateValue();
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
      return;
    }

    final char = value;
    if (_pattern.hasMatch(char)) {
      _controllers[index].text = char;
      _updateValue();
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else if (!widget.isPreservedFocus) {
        _focusNodes[index].unfocus();
      }
    } else {
      _controllers[index].text = '';
    }
  }

  void _handlePaste(int startIndex, String pastedText) {
    final pattern = _pattern;
    final cleanedText = pastedText.split('').where((char) => pattern.hasMatch(char)).join();
    if (cleanedText.isEmpty) {
      // Clear the current field if paste didn't match pattern
      _controllers[startIndex].text = '';
      return;
    }

    // Clear all fields that will be affected by the paste
    final endIndex = startIndex + cleanedText.length < widget.length ? startIndex + cleanedText.length : widget.length;
    for (int i = startIndex; i < endIndex; i++) {
      _controllers[i].text = '';
    }

    // Distribute cleaned text across fields starting from startIndex
    int currentIndex = startIndex;
    for (int i = 0; i < cleanedText.length && currentIndex < widget.length; i++) {
      _controllers[currentIndex].text = cleanedText[i];
      currentIndex++;
    }

    // Clear any remaining fields beyond what was pasted
    for (int i = currentIndex; i < widget.length; i++) {
      _controllers[i].text = '';
    }

    _updateValue();

    if (currentIndex < widget.length) {
      _focusNodes[currentIndex].requestFocus();
    } else if (!widget.isPreservedFocus) {
      _focusNodes[widget.length - 1].unfocus();
    }
  }

  String? _getPlaceholder(int index) {
    if (widget.placeholder == null) return null;
    if (widget.placeholder!.length == 1) {
      return widget.placeholder;
    }
    if (widget.placeholder!.length == widget.length) {
      return widget.placeholder![index];
    }
    return widget.placeholder;
  }

  void _handleKeyDown(int index, KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (widget.disabled) return;

    final logicalKey = event.logicalKey;

    if (logicalKey == LogicalKeyboardKey.arrowLeft) {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    } else if (logicalKey == LogicalKeyboardKey.arrowRight) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      }
    } else if (logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
        _controllers[index - 1].text = '';
        _updateValue();
      }
    }
  }

  void _syncSelection(int index) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _controllers[index];
      if (controller.text.isNotEmpty) {
        controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
      }
    });
  }

  String _getMaskValue(int index) {
    if (!widget.mask) return '';
    if (_controllers[index].text.isEmpty) return '';
    if (widget.maskChar != null) return widget.maskChar!;
    return '•';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final radius = context.radius;
    final colors = context.colors;
    final typography = context.typography;
    final hasError = widget.errorText != null && widget.errorText!.isNotEmpty;

    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.length,
              (index) => Padding(
                padding: EdgeInsets.only(right: index < widget.length - 1 ? spacing.sm : 0),
                child: _OTPInputField(
                  key: _inputKeys[index],
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  index: index,
                  totalLength: widget.length,
                  mask: widget.mask,
                  maskValue: _getMaskValue(index),
                  obscureText: widget.obscureText,
                  disabled: widget.disabled,
                  keyboardType: _keyboardType,
                  textInputAction: index == widget.length - 1 ? widget.textInputAction : TextInputAction.next,
                  placeholder: _getPlaceholder(index),
                  pattern: _pattern,
                  inputStyle: widget.inputStyle,
                  onChanged: (value) => _handleChange(index, value),
                  onKeyDown: (event) => _handleKeyDown(index, event),
                  onFocus: () => _syncSelection(index),
                  palette: palette,
                  spacing: spacing,
                  radius: radius,
                  colors: colors,
                  typography: typography,
                  autofillHints: index == 0 ? const [AutofillHints.oneTimeCode] : null,
                  hasError: hasError,
                ),
              ),
            ),
          ),
          if (hasError) ...[
            SizedBox(height: spacing.xs),
            Text(widget.errorText!, style: typography.labelSmall.toTextStyle(color: palette.danger)),
          ],
        ],
      ),
    );
  }
}

class _OTPInputField extends StatefulWidget {
  const _OTPInputField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.index,
    required this.totalLength,
    required this.mask,
    required this.maskValue,
    required this.obscureText,
    required this.disabled,
    required this.keyboardType,
    required this.textInputAction,
    required this.placeholder,
    required this.pattern,
    this.inputStyle,
    required this.onChanged,
    required this.onKeyDown,
    required this.onFocus,
    required this.palette,
    required this.spacing,
    required this.radius,
    required this.colors,
    required this.typography,
    this.autofillHints,
    this.hasError = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final int index;
  final int totalLength;
  final bool mask;
  final String maskValue;
  final bool obscureText;
  final bool disabled;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final String? placeholder;
  final RegExp pattern;
  final TextStyle? inputStyle;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyDown;
  final VoidCallback onFocus;
  final AppPalette palette;
  final Spacing spacing;
  final RadiusScale radius;
  final ColorScheme colors;
  final TypographyScale typography;
  final Iterable<String>? autofillHints;
  final bool hasError;

  @override
  State<_OTPInputField> createState() => _OTPInputFieldState();
}

class _OTPInputFieldState extends State<_OTPInputField> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocusChange);
    super.dispose();
  }

  void _handleFocusChange() {
    final isFocused = widget.focusNode.hasFocus;
    if (_isFocused != isFocused) {
      setState(() {
        _isFocused = isFocused;
      });
      if (isFocused) {
        widget.onFocus();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasValue = widget.controller.text.isNotEmpty;
    final showMask = widget.mask && hasValue;

    final inputStyle =
        widget.inputStyle ?? widget.typography.titleMedium.toTextStyle(color: widget.palette.textPrimary);
    final maskStyle = widget.typography.titleLarge.toTextStyle(color: widget.palette.textPrimary);
    final hintStyle = widget.typography.titleMedium.toTextStyle(color: widget.palette.textSecondary);
    final fieldWidth = widget.spacing.xxl + widget.spacing.xs;
    final fieldHeight = widget.spacing.xxxl + widget.spacing.xs;

    return Opacity(
      opacity: widget.disabled ? 0.4 : 1,
      child: Container(
        width: fieldWidth,
        height: fieldHeight,
        decoration: BoxDecoration(
          color: widget.palette.background,
          border: Border.all(
            color:
                widget.hasError ? widget.palette.danger : (_isFocused ? widget.palette.brand : widget.palette.border),
            width: (_isFocused || widget.hasError) ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(widget.radius.sm),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showMask) Text(widget.maskValue, style: maskStyle),
            Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent) {
                  widget.onKeyDown(event);
                }
                return KeyEventResult.ignored;
              },
              child: TextField(
                controller: widget.controller,
                focusNode: widget.focusNode,
                enabled: !widget.disabled,
                keyboardType: widget.keyboardType,
                textInputAction: widget.textInputAction,
                obscureText: widget.obscureText && !widget.mask,
                textAlign: TextAlign.center,
                autofillHints: widget.autofillHints,
                style: inputStyle,
                inputFormatters: [_OTPInputFormatter(widget.pattern)],
                decoration: InputDecoration(
                  counterText: '',
                  filled: false,
                  hintText: widget.placeholder,
                  hintStyle: hintStyle,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  disabledBorder: InputBorder.none,
                  errorBorder: InputBorder.none,
                  focusedErrorBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                onChanged: widget.onChanged,
                onTap: () {
                  widget.onFocus();
                },
                onSubmitted: (_) {
                  if (widget.index < widget.totalLength - 1) {
                    widget.focusNode.nextFocus();
                  } else {
                    widget.focusNode.unfocus();
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
