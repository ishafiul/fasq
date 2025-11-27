import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum OTPInputType { numeric, text }

class OTPInput extends StatefulWidget {
  const OTPInput({
    super.key,
    this.value,
    this.defaultValue = '',
    this.length = 6,
    this.plain = true,
    this.error = false,
    this.errorText,
    this.caret = true,
    this.separated = false,
    this.inputMode = OTPInputType.numeric,
    this.cellSize,
    this.cellGap,
    this.dotSize,
    this.borderColor,
    this.borderRadius,
    this.onBlur,
    this.onFocus,
    this.onChange,
    this.onFill,
  });

  final String? value;
  final String defaultValue;
  final int length;
  final bool plain;
  final bool error;
  final String? errorText;
  final bool caret;
  final bool separated;
  final OTPInputType inputMode;
  final double? cellSize;
  final double? cellGap;
  final double? dotSize;
  final Color? borderColor;
  final BorderRadius? borderRadius;
  final VoidCallback? onBlur;
  final VoidCallback? onFocus;
  final ValueChanged<String>? onChange;
  final ValueChanged<String>? onFill;

  @override
  State<OTPInput> createState() => _OTPInputState();
}

class _OTPInputState extends State<OTPInput> with SingleTickerProviderStateMixin {
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();
  final GlobalKey _containerKey = GlobalKey();
  bool _focused = false;
  late AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _controller.text = widget.value ?? widget.defaultValue;
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _focusNode.addListener(_handleFocusChange);
    _controller.addListener(_handleValueChange);

    final hasError = widget.error || (widget.errorText != null && widget.errorText!.isNotEmpty);
    if (hasError) {
      _triggerShake();
    }
  }

  @override
  void didUpdateWidget(OTPInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != null) {
      _controller.text = widget.value!;
    }
    final hasError = widget.error || (widget.errorText != null && widget.errorText!.isNotEmpty);
    final hadError = oldWidget.error || (oldWidget.errorText != null && oldWidget.errorText!.isNotEmpty);
    if (hasError && !hadError) {
      _triggerShake();
    }
  }

  @override
  void dispose() {
    _focusNode.removeListener(_handleFocusChange);
    _controller.removeListener(_handleValueChange);
    _focusNode.dispose();
    _controller.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  void _handleFocusChange() {
    final isFocused = _focusNode.hasFocus;
    if (_focused != isFocused) {
      setState(() {
        _focused = isFocused;
      });
      if (isFocused) {
        widget.onFocus?.call();
        _scrollIntoView();
      } else {
        widget.onBlur?.call();
      }
    }
  }

  void _handleValueChange() {
    final value = _controller.text;
    final filteredValue = _filterValue(value);
    if (filteredValue != value) {
      _controller.value = TextEditingValue(
        text: filteredValue,
        selection: TextSelection.collapsed(offset: filteredValue.length),
      );
      return;
    }

    widget.onChange?.call(filteredValue);
    if (filteredValue.length >= widget.length) {
      widget.onFill?.call(filteredValue.substring(0, widget.length));
    }
  }

  String _filterValue(String value) {
    final pattern = widget.inputMode == OTPInputType.numeric ? RegExp(r'[0-9]') : RegExp(r'.');
    return value.split('').where((char) => pattern.hasMatch(char)).join();
  }

  void _scrollIntoView() {
    Future.delayed(const Duration(milliseconds: 100), () {
      final context = _containerKey.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.5,
        );
      }
    });
  }

  void _triggerShake() {
    _shakeController.repeat(reverse: true);
    Future.delayed(const Duration(milliseconds: 300), () {
      _shakeController.stop();
      _shakeController.reset();
    });
  }

  int get _cellLength {
    if (widget.length > 0 && widget.length < double.infinity) {
      return widget.length;
    }
    return 6;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final radius = context.radius;
    final colors = context.colors;

    final cellSize = widget.cellSize ?? spacing.xxxxl;
    final cellGap = widget.cellGap ?? spacing.xs / 2;
    final dotSize = widget.dotSize ?? 10.0;
    final borderColor = widget.borderColor ?? palette.border;
    final borderRadius = widget.borderRadius ?? radius.all(radius.sm);
    final primaryColor = colors.primary;
    final dangerColor = palette.danger;
    final textColor = palette.textPrimary;
    final backgroundColor = colors.surface;

    final value = _controller.text;
    final chars = value.split('');
    final caretIndex = chars.length;
    final focusedIndex = chars.length.clamp(0, _cellLength - 1);
    final typography = context.typography;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(_shakeController.value * 4, 0),
              child: _buildInput(
                palette: palette,
                spacing: spacing,
                radius: radius,
                colors: colors,
                cellSize: cellSize,
                cellGap: cellGap,
                dotSize: dotSize,
                borderColor: borderColor,
                borderRadius: borderRadius,
                primaryColor: primaryColor,
                dangerColor: dangerColor,
                textColor: textColor,
                backgroundColor: backgroundColor,
                chars: chars,
                caretIndex: caretIndex,
                focusedIndex: focusedIndex,
              ),
            );
          },
        ),
        if (widget.errorText != null && widget.errorText!.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(top: spacing.xs),
            child: Text(
              widget.errorText!,
              style: typography.labelSmall.toTextStyle(color: dangerColor),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  Widget _buildInput({
    required AppPalette palette,
    required Spacing spacing,
    required RadiusScale radius,
    required ColorScheme colors,
    required double cellSize,
    required double cellGap,
    required double dotSize,
    required Color borderColor,
    required BorderRadius borderRadius,
    required Color primaryColor,
    required Color dangerColor,
    required Color textColor,
    required Color backgroundColor,
    required List<String> chars,
    required int caretIndex,
    required int focusedIndex,
  }) {
    final hasError = widget.error || (widget.errorText != null && widget.errorText!.isNotEmpty);
    final effectiveBorderColor = hasError ? dangerColor : (_focused ? primaryColor : borderColor);
    final showErrorShadow = hasError;
    final showFocusShadow = _focused && !hasError;

    if (widget.separated) {
      return Stack(
        children: [
          Focus(
            focusNode: _focusNode,
            onKeyEvent: (node, event) {
              if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
                if (_controller.text.isNotEmpty) {
                  _controller.text = _controller.text.substring(0, _controller.text.length - 1);
                }
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: GestureDetector(
              onTap: () => _focusNode.requestFocus(),
              child: Container(
                key: _containerKey,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(_cellLength, (index) {
                    final hasValue = index < chars.length;
                    final isFocused = focusedIndex == index && _focused;
                    final showCaret = widget.caret && caretIndex == index && _focused;

                    return Padding(
                      padding: EdgeInsets.only(right: index < _cellLength - 1 ? cellGap : 0),
                      child: _buildCell(
                        index: index,
                        hasValue: hasValue,
                        isFocused: isFocused,
                        showCaret: showCaret,
                        char: hasValue ? chars[index] : '',
                        cellSize: cellSize,
                        dotSize: dotSize,
                        borderRadius: borderRadius,
                        borderColor: effectiveBorderColor,
                        showFocusShadow: showFocusShadow && isFocused,
                        showErrorShadow: showErrorShadow && isFocused,
                        primaryColor: primaryColor,
                        dangerColor: dangerColor,
                        textColor: textColor,
                        backgroundColor: backgroundColor,
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
          Positioned(
            left: -2000,
            top: 0,
            child: Opacity(
              opacity: 0,
              child: SizedBox(
                width: 50,
                height: 20,
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: widget.inputMode == OTPInputType.numeric ? TextInputType.number : TextInputType.text,
                  inputFormatters: [
                    LengthLimitingTextInputFormatter(_cellLength),
                    FilteringTextInputFormatter.allow(
                      widget.inputMode == OTPInputType.numeric ? RegExp(r'[0-9]') : RegExp(r'.'),
                    ),
                  ],
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return Stack(
      children: [
        Focus(
          focusNode: _focusNode,
          onKeyEvent: (node, event) {
            if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
              if (_controller.text.isNotEmpty) {
                _controller.text = _controller.text.substring(0, _controller.text.length - 1);
              }
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: GestureDetector(
            onTap: () => _focusNode.requestFocus(),
            child: Container(
              key: _containerKey,
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                border: Border.all(
                  color: effectiveBorderColor,
                  width: showErrorShadow || showFocusShadow ? 2 : 1,
                ),
                boxShadow: showErrorShadow
                    ? [
                        BoxShadow(
                          color: dangerColor.withValues(alpha: 0.3),
                          blurRadius: 2,
                        ),
                      ]
                    : showFocusShadow
                        ? [
                            BoxShadow(
                              color: primaryColor.withValues(alpha: 0.3),
                              blurRadius: 2,
                            ),
                          ]
                        : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(_cellLength, (index) {
                  final hasValue = index < chars.length;
                  final isFocused = focusedIndex == index && _focused;
                  final showCaret = widget.caret && caretIndex == index && _focused;

                  final isFirst = index == 0;
                  final isLast = index == _cellLength - 1;
                  final cellBorderRadius = isFirst
                      ? BorderRadius.only(
                          topLeft: borderRadius.topLeft,
                          bottomLeft: borderRadius.bottomLeft,
                        )
                      : isLast
                          ? BorderRadius.only(
                              topRight: borderRadius.topRight,
                              bottomRight: borderRadius.bottomRight,
                            )
                          : null;

                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        border: index < _cellLength - 1
                            ? Border(
                                right: BorderSide(
                                  color: effectiveBorderColor,
                                ),
                              )
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: cellBorderRadius ?? BorderRadius.zero,
                        child: _buildCell(
                          index: index,
                          hasValue: hasValue,
                          isFocused: isFocused,
                          showCaret: showCaret,
                          char: hasValue ? chars[index] : '',
                          cellSize: cellSize,
                          dotSize: dotSize,
                          borderRadius: null,
                          borderColor: effectiveBorderColor,
                          showFocusShadow: false,
                          showErrorShadow: false,
                          primaryColor: primaryColor,
                          dangerColor: dangerColor,
                          textColor: textColor,
                          backgroundColor: backgroundColor,
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
        ),
        Positioned(
          left: -2000,
          top: 0,
          child: SizedBox(
            width: 50,
            height: 20,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              keyboardType: widget.inputMode == OTPInputType.numeric ? TextInputType.number : TextInputType.text,
              inputFormatters: [
                LengthLimitingTextInputFormatter(_cellLength),
                FilteringTextInputFormatter.allow(
                  widget.inputMode == OTPInputType.numeric ? RegExp(r'[0-9]') : RegExp(r'.'),
                ),
              ],
              style: const TextStyle(color: Colors.transparent),
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCell({
    required int index,
    required bool hasValue,
    required bool isFocused,
    required bool showCaret,
    required String char,
    required double cellSize,
    required double dotSize,
    required BorderRadius? borderRadius,
    required Color borderColor,
    required bool showFocusShadow,
    required bool showErrorShadow,
    required Color primaryColor,
    required Color dangerColor,
    required Color textColor,
    required Color backgroundColor,
  }) {
    return Container(
      width: cellSize,
      height: cellSize,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: borderRadius,
        border: borderRadius != null
            ? Border.all(
                color: borderColor,
                width: showErrorShadow || showFocusShadow ? 2 : 1,
              )
            : null,
        boxShadow: showErrorShadow
            ? [
                BoxShadow(
                  color: dangerColor.withValues(alpha: 0.3),
                  blurRadius: 2,
                ),
              ]
            : showFocusShadow
                ? [
                    BoxShadow(
                      color: primaryColor.withValues(alpha: 0.3),
                      blurRadius: 2,
                    ),
                  ]
                : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (hasValue && !widget.plain)
            Container(
              width: dotSize,
              height: dotSize,
              decoration: BoxDecoration(
                color: textColor,
                shape: BoxShape.circle,
              ),
            ),
          if (hasValue && widget.plain)
            Text(
              char,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          if (showCaret)
            _Caret(
              color: primaryColor,
            ),
        ],
      ),
    );
  }
}

class _Caret extends StatefulWidget {
  const _Caret({
    required this.color,
  });

  final Color color;

  @override
  State<_Caret> createState() => _CaretState();
}

class _CaretState extends State<_Caret> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final opacity = _controller.value < 0.6 ? 1.0 : 0.0;
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 2,
            height: 22,
            color: widget.color,
            margin: const EdgeInsets.only(left: 1),
          ),
        );
      },
    );
  }
}
