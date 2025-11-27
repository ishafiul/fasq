import 'dart:async';
import 'dart:math' as math;

import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:flutter/material.dart';

/// A switch widget with animated sliding handle, loading state, and custom text support.
///
/// This widget provides a toggle switch similar to the React implementation with:
/// - Animated sliding handle with 200ms transitions
/// - Loading state with spinner inside handle
/// - Custom checked/unchecked text widgets
/// - Async onChange support (can return Future<void>)
/// - Disabled state with reduced opacity
/// - Controlled or uncontrolled state management
///
/// **Visual Design:**
/// - Rounded container with border
/// - Sliding circular handle with shadow
/// - Background color changes when checked
/// - Inner text area for checked/unchecked text
/// - Loading spinner inside handle when loading
///
/// Example:
/// ```dart
/// Switch(
///   checked: isEnabled,
///   onChange: (checked) => setState(() => isEnabled = checked),
///   checkedText: Text('ON'),
///   uncheckedText: Text('OFF'),
/// )
/// ```
///
/// Example with async onChange:
/// ```dart
/// Switch(
///   checked: isEnabled,
///   onChange: (checked) async {
///     await saveSettings(checked);
///     setState(() => isEnabled = checked);
///   },
///   loading: isSaving,
/// )
/// ```
class Switch extends StatefulWidget {
  const Switch({
    super.key,
    this.checked,
    this.defaultChecked = false,
    this.onChange,
    this.beforeChange,
    this.loading = false,
    this.disabled = false,
    this.checkedText,
    this.uncheckedText,
    this.checkedColor,
    this.width,
    this.height = 31.0,
    this.borderWidth = 2.0,
  });

  /// The checked state (controlled mode).
  /// If provided, the switch is controlled by the parent.
  final bool? checked;

  /// The default checked state (uncontrolled mode).
  /// Used when [checked] is null.
  final bool defaultChecked;

  /// Callback fired when the switch is toggled.
  /// Can return a Future<void> for async operations.
  final FutureOr<void> Function(bool checked)? onChange;

  /// Deprecated: Use [onChange] instead.
  /// Async hook called before the state changes.
  @Deprecated('Use onChange instead')
  final Future<void> Function(bool checked)? beforeChange;

  /// Whether the switch is in loading state.
  /// Shows a spinner inside the handle when true.
  final bool loading;

  /// Whether the switch is disabled.
  /// Disabled switches cannot be toggled and have reduced opacity.
  final bool disabled;

  /// Widget to display when the switch is checked.
  final Widget? checkedText;

  /// Widget to display when the switch is unchecked.
  final Widget? uncheckedText;

  /// Custom color when checked.
  /// Defaults to [AppPalette.brand] if not provided.
  final Color? checkedColor;

  /// Width of the switch.
  /// If not provided, will be calculated based on [checkedText] and [uncheckedText] content.
  /// Default: 51.0 (when no text is provided)
  final double? width;

  /// Height of the switch.
  /// Default: 31.0
  final double height;

  /// Border width of the switch.
  /// Default: 2.0
  final double borderWidth;

  @override
  State<Switch> createState() => _SwitchState();
}

class _SwitchState extends State<Switch> {
  late bool _checked;
  bool _changing = false;

  @override
  void initState() {
    super.initState();
    _checked = widget.checked ?? widget.defaultChecked;
  }

  @override
  void didUpdateWidget(covariant Switch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.checked != null && widget.checked != _checked) {
      _checked = widget.checked!;
    }
  }

  Future<void> _handleTap() async {
    if (widget.disabled || widget.loading || _changing) {
      return;
    }

    final nextChecked = !_checked;

    if (widget.beforeChange != null) {
      setState(() => _changing = true);
      try {
        await widget.beforeChange!(nextChecked);
        setState(() => _changing = false);
      } catch (e) {
        setState(() => _changing = false);
        rethrow;
      }
    }

    if (widget.checked == null) {
      setState(() => _checked = nextChecked);
    }

    final result = widget.onChange?.call(nextChecked);
    if (result is Future<void>) {
      setState(() => _changing = true);
      try {
        await result;
        setState(() => _changing = false);
      } catch (e) {
        setState(() => _changing = false);
        rethrow;
      }
    }
  }

  double _calculateWidth(BuildContext context) {
    if (widget.width != null) {
      return widget.width!;
    }

    const defaultWidth = 51.0;
    final handleSize = widget.height - (widget.borderWidth * 2);
    final minWidth = handleSize + (widget.borderWidth * 2) + 16;

    if (widget.checkedText == null && widget.uncheckedText == null) {
      return defaultWidth;
    }

    double maxTextWidth = 0;

    if (widget.checkedText != null) {
      final textWidth = _measureWidgetWidth(context, widget.checkedText!);
      maxTextWidth = math.max(maxTextWidth, textWidth);
    }

    if (widget.uncheckedText != null) {
      final textWidth = _measureWidgetWidth(context, widget.uncheckedText!);
      maxTextWidth = math.max(maxTextWidth, textWidth);
    }

    final calculatedWidth = handleSize + (widget.borderWidth * 2) + maxTextWidth + 16 + 5;
    return math.max(calculatedWidth, minWidth);
  }

  double _measureWidgetWidth(BuildContext context, Widget widget) {
    if (widget is Text) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: widget.data ?? '',
          style: TextStyle(
            fontSize: widget.style?.fontSize ?? 14,
            fontWeight: widget.style?.fontWeight,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      );
      textPainter.layout();
      return textPainter.size.width;
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final isDisabled = widget.disabled || widget.loading || _changing;
    final isChecked = widget.checked ?? _checked;
    final checkedColor = widget.checkedColor ?? palette.brand;
    final switchWidth = _calculateWidth(context);
    final handleSize = widget.height - (widget.borderWidth * 2);
    final handleLeft = isChecked ? switchWidth - handleSize - widget.borderWidth : widget.borderWidth;

    return GestureDetector(
      onTap: _handleTap,
      child: Opacity(
        opacity: isDisabled ? 0.4 : 1.0,
        child: MouseRegion(
          cursor: isDisabled ? SystemMouseCursors.forbidden : SystemMouseCursors.click,
          child: SizedBox(
            width: switchWidth,
            height: widget.height,
            child: Stack(
              children: [
                Container(
                  width: switchWidth,
                  height: widget.height,
                  decoration: BoxDecoration(
                    color: isChecked ? checkedColor : palette.border,
                    borderRadius: BorderRadius.circular(widget.height),
                  ),
                  child: Stack(
                    children: [
                      AnimatedScale(
                        scale: isChecked ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          width: switchWidth - (widget.borderWidth * 2),
                          height: widget.height - (widget.borderWidth * 2),
                          margin: EdgeInsets.all(widget.borderWidth),
                          decoration: BoxDecoration(
                            color: palette.background,
                            borderRadius: BorderRadius.circular(widget.height - (widget.borderWidth * 2)),
                          ),
                        ),
                      ),
                      if (widget.checkedText != null || widget.uncheckedText != null)
                        Positioned(
                          left: isChecked ? widget.borderWidth + 8 : handleSize + widget.borderWidth + 5,
                          right: isChecked ? handleSize + widget.borderWidth + 5 : widget.borderWidth + 8,
                          top: 0,
                          bottom: 0,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Center(
                              key: ValueKey(isChecked),
                              child: DefaultTextStyle(
                                style: TextStyle(
                                  color: isChecked ? palette.textPrimary : palette.weak,
                                  fontSize: 14,
                                ),
                                child: isChecked
                                    ? (widget.checkedText ?? const SizedBox.shrink())
                                    : (widget.uncheckedText ?? const SizedBox.shrink()),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  left: handleLeft,
                  top: widget.borderWidth,
                  child: Container(
                    width: handleSize,
                    height: handleSize,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: palette.border,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 2,
                          offset: const Offset(0, 0),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 11.5,
                          offset: const Offset(0, 2),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 2,
                          offset: const Offset(-1, 2),
                        ),
                      ],
                    ),
                    child: (widget.loading || _changing)
                        ? Center(
                            child: CircularProgressSpinner(
                              size: 14,
                              strokeWidth: 2,
                              color: palette.brand,
                            ),
                          )
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
