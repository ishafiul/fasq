import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/button/button.dart';
import 'package:ecommerce/core/widgets/svg_icon.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:flutter/material.dart';

/// Reference interface for SearchBar imperative actions.
abstract class SearchBarRef {
  /// Clear the input field.
  void clear();

  /// Focus the input field.
  void focus();

  /// Blur (unfocus) the input field.
  void blur();

  /// The underlying input element.
  TextEditingController get controller;

  /// The underlying focus node.
  FocusNode get focusNode;
}

/// Configuration for when to show the cancel button.
typedef ShowCancelButtonFn = bool Function(bool hasFocus, String value);

/// A search bar widget matching React antd-mobile design.
///
/// Features:
/// - Search icon with customizable appearance
/// - Cancel button with show/hide logic
/// - Clearable input functionality
/// - Active state styling with brand color border
/// - Debounced onSearch callback
///
/// Usage:
/// ```dart
/// SearchBar(
///   placeholder: 'Search products...',
///   onSearch: (value) => performSearch(value),
///   onChange: (value) => updateFilter(value),
///   showCancelButton: true,
///   clearable: true,
/// )
/// ```
class SearchBar extends StatefulWidget {
  const SearchBar({
    super.key,
    this.value,
    this.defaultValue,
    this.maxLength,
    this.placeholder,
    this.clearable = true,
    this.onlyShowClearWhenFocus = false,
    this.showCancelButton = false,
    this.showCancelButtonFn,
    this.cancelText,
    this.searchIcon,
    this.clearOnCancel = true,
    this.onSearch,
    this.onChange,
    this.onCancel,
    this.onFocus,
    this.onBlur,
    this.onClear,
    this.autoFocus = false,
    this.height,
    this.paddingLeft,
    this.background,
    this.borderRadius,
    this.placeholderColor,
  });

  /// Current value of the input (controlled mode).
  final String? value;

  /// Initial value of the input (uncontrolled mode).
  final String? defaultValue;

  /// Maximum length of input.
  final int? maxLength;

  /// Placeholder text when input is empty.
  final String? placeholder;

  /// Whether to show clear button when there's text.
  final bool clearable;

  /// Only show clear button when input is focused.
  final bool onlyShowClearWhenFocus;

  /// Whether to show cancel button when focused.
  final bool showCancelButton;

  /// Custom function to determine if cancel button should show.
  /// Takes precedence over [showCancelButton] if provided.
  final ShowCancelButtonFn? showCancelButtonFn;

  /// Text for the cancel button. Defaults to 'Cancel'.
  final String? cancelText;

  /// Custom search icon widget. Set to null to hide.
  final Widget? searchIcon;

  /// Whether to clear input when cancel is pressed.
  final bool clearOnCancel;

  /// Called when search is submitted (enter key pressed).
  final ValueChanged<String>? onSearch;

  /// Called when input value changes.
  final ValueChanged<String>? onChange;

  /// Called when cancel button is pressed.
  final VoidCallback? onCancel;

  /// Called when input gains focus.
  final VoidCallback? onFocus;

  /// Called when input loses focus.
  final VoidCallback? onBlur;

  /// Called when clear button is pressed.
  final VoidCallback? onClear;

  /// Whether to auto-focus on mount.
  final bool autoFocus;

  /// Height of the search bar. Defaults to 32.
  final double? height;

  /// Left padding of the input box. Defaults to 8.
  final double? paddingLeft;

  /// Background color of the input box.
  final Color? background;

  /// Border radius of the input box. Defaults to 6.
  final double? borderRadius;

  /// Color of the placeholder text.
  final Color? placeholderColor;

  @override
  State<SearchBar> createState() => SearchBarState();
}

/// State class that implements [SearchBarRef] for imperative access.
class SearchBarState extends State<SearchBar> implements SearchBarRef {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _hasFocus = false;
  bool _isControlled = false;

  @override
  void initState() {
    super.initState();
    _isControlled = widget.value != null;
    _controller = TextEditingController(
      text: widget.value ?? widget.defaultValue ?? '',
    );
    _focusNode = FocusNode();

    _controller.addListener(_handleTextChange);
    _focusNode.addListener(_handleFocusChange);

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusNode.requestFocus();
      });
    }
  }

  @override
  void didUpdateWidget(covariant SearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Update controlled value
    if (widget.value != oldWidget.value && widget.value != null) {
      if (_controller.text != widget.value) {
        _controller.text = widget.value ?? '';
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChange);
    _focusNode.removeListener(_handleFocusChange);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _handleTextChange() {
    if (!_isControlled) {
      setState(() {});
    }
    widget.onChange?.call(_controller.text);
  }

  void _handleFocusChange() {
    final hasFocus = _focusNode.hasFocus;
    if (_hasFocus != hasFocus) {
      setState(() {
        _hasFocus = hasFocus;
      });

      if (hasFocus) {
        widget.onFocus?.call();
      } else {
        widget.onBlur?.call();
      }
    }
  }

  @override
  void clear() {
    _controller.clear();
    widget.onClear?.call();
  }

  @override
  void focus() {
    _focusNode.requestFocus();
  }

  @override
  void blur() {
    _focusNode.unfocus();
  }

  @override
  TextEditingController get controller => _controller;

  @override
  FocusNode get focusNode => _focusNode;

  void _handleClear() {
    clear();
  }

  void _handleCancel() {
    if (widget.clearOnCancel) {
      clear();
    }
    blur();
    widget.onCancel?.call();
  }

  void _handleSubmit(String value) {
    blur();
    widget.onSearch?.call(value);
  }

  bool get _shouldShowCancel {
    if (widget.showCancelButtonFn != null) {
      return widget.showCancelButtonFn!(_hasFocus, _controller.text);
    }
    return widget.showCancelButton && _hasFocus;
  }

  bool get _shouldShowClear {
    if (!widget.clearable) return false;
    if (_controller.text.isEmpty) return false;
    if (widget.onlyShowClearWhenFocus && !_hasFocus) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    // Styling with defaults matching React implementation
    final effectiveHeight = widget.height ?? 32;
    final effectivePaddingLeft = widget.paddingLeft ?? spacing.xs;
    final effectiveBackground = widget.background ?? palette.surface;
    final effectiveBorderRadius = widget.borderRadius ?? 6.0;
    final effectivePlaceholderColor = widget.placeholderColor ?? palette.weak;

    // Active state styling
    final borderColor = _hasFocus ? palette.brand : Colors.transparent;
    final boxBackground = _hasFocus ? palette.background : effectiveBackground;

    return SizedBox(
      height: effectiveHeight,
      child: Row(
        children: [
          // Input box
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: boxBackground,
                borderRadius: BorderRadius.circular(effectiveBorderRadius),
                border: Border.all(color: borderColor),
              ),
              padding: EdgeInsets.only(left: effectivePaddingLeft),
              child: Row(
                children: [
                  // Search icon
                  if (widget.searchIcon != null)
                    widget.searchIcon!
                  else
                    SvgIcon(
                      svg: Assets.icons.outlined.search,
                      size: spacing.sm,
                      color: palette.light,
                    ),
                  // Input field
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      maxLength: widget.maxLength,
                      textInputAction: TextInputAction.search,
                      style: typography.bodySmall.toTextStyle(
                        color: palette.textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.placeholder,
                        hintStyle: typography.bodySmall.toTextStyle(
                          color: _hasFocus ? palette.light : effectivePlaceholderColor,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: spacing.xs / 2,
                          vertical: 0,
                        ),
                        counterText: '',
                        isDense: true,
                      ),
                      onSubmitted: _handleSubmit,
                    ),
                  ),
                  // Clear button
                  if (_shouldShowClear)
                    GestureDetector(
                      onTap: _handleClear,
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: spacing.xs / 2,
                        ),
                        child: SvgIcon(
                          svg: Assets.icons.outlined.closeCircle,
                          size: spacing.sm,
                          color: palette.weak,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // Cancel button
          if (_shouldShowCancel)
            Padding(
              padding: EdgeInsets.only(left: spacing.xs / 2),
              child: Button(
                fill: ButtonFill.none,
                buttonSize: ButtonSize.small,
                onPressed: _handleCancel,
                child: Text(
                  widget.cancelText ?? 'Cancel',
                  style: typography.bodySmall.toTextStyle(
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
