import 'package:ecommerce_ui/src/theme/colors.dart';
import 'package:ecommerce_ui/src/theme/const.dart';
import 'package:ecommerce_ui/src/widgets/svg_icon.dart';
import 'package:ecommerce_ui/gen/assets.gen.dart';
import 'package:flutter/material.dart';

class TextInputField extends StatefulWidget {
  const TextInputField({
    super.key,
    this.controller,
    this.placeholder,
    this.validator,
    this.disabled = false,
    this.isRequired = false,
    this.readOnly = false,
    this.obscureText = false,
    this.suffixIcon,
    this.initialValue,
    this.labelText,
    this.minLines,
    this.maxLines,
    this.keyboardType,
    this.onChanged,
  });

  final String? Function(String? value)? validator;
  final TextEditingController? controller;
  final String? placeholder;
  final String? initialValue;
  final int? minLines;
  final int? maxLines;
  final bool disabled;
  final bool isRequired;
  final bool readOnly;
  final bool obscureText;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? labelText;
  final void Function(String value)? onChanged;

  @override
  State<TextInputField> createState() => _TextInputFieldState();
}

class _TextInputFieldState extends State<TextInputField> {
  late final TextEditingController _controller;
  bool _isVisibleClear = false;
  bool _isPasswordVisible = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    if (widget.initialValue != null && widget.controller == null) {
      _controller.text = widget.initialValue!;
      _isVisibleClear = widget.initialValue!.isNotEmpty;
    }
    _controller.addListener(_updateClearVisibility);
  }

  @override
  void didUpdateWidget(covariant TextInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      if (oldWidget.controller == null) {
        _controller.dispose();
      }
      _controller.removeListener(_updateClearVisibility);
      _controller = widget.controller ?? TextEditingController();
      _controller.addListener(_updateClearVisibility);
    }
    if (widget.initialValue != oldWidget.initialValue && widget.controller == null) {
      _controller.text = widget.initialValue ?? '';
      _updateClearVisibility();
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.removeListener(_updateClearVisibility);
    }
    super.dispose();
  }

  void _updateClearVisibility() {
    final isVisible = _controller.text.isNotEmpty;
    if (_isVisibleClear != isVisible) {
      setState(() {
        _isVisibleClear = isVisible;
      });
    }
  }

  void _clearText() {
    _controller.clear();
    widget.onChanged?.call('');
  }

  void _togglePasswordVisibility() {
    setState(() {
      _isPasswordVisible = !_isPasswordVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final iconSize = spacing.sm;

    return Opacity(
      opacity: widget.disabled ? 0.4 : 1,
      child: Container(
        color: palette.background,
        padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.labelText != null) ...[
              Padding(
                padding: EdgeInsets.only(bottom: spacing.xs / 2),
                child: Row(
                  children: [
                    Text(
                      widget.labelText!,
                      style: typography.labelMedium.toTextStyle(color: palette.textPrimary),
                    ),
                    if (widget.isRequired)
                      Padding(
                        padding: EdgeInsets.only(left: spacing.xs / 2),
                        child: Text(
                          '*',
                          style: typography.labelMedium.toTextStyle(color: palette.danger),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            TextFormField(
              validator: widget.validator,
              controller: _controller,
              readOnly: widget.readOnly,
              obscureText: widget.obscureText && !_isPasswordVisible,
              keyboardType: widget.keyboardType,
              minLines: widget.obscureText ? 1 : widget.minLines,
              maxLines: widget.obscureText ? 1 : widget.maxLines,
              style: typography.bodyMedium.toTextStyle(color: palette.textPrimary),
              onChanged: (value) {
                widget.onChanged?.call(value);
              },
              decoration: InputDecoration(
                hintText: widget.placeholder,
                hintStyle: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
                enabled: !widget.disabled,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 0,
                  vertical: spacing.xs,
                ),
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.suffixIcon != null) widget.suffixIcon!,
                    if (widget.obscureText)
                      Padding(
                        padding: EdgeInsets.only(right: _isVisibleClear ? spacing.xs / 2 : 0),
                        child: SvgIcon(
                          svg: _isPasswordVisible ? Assets.icons.outlined.eye : Assets.icons.outlined.eyeInvisible,
                          size: iconSize,
                          color: palette.textSecondary,
                          onTap: _togglePasswordVisibility,
                        ),
                      ),
                    if (_isVisibleClear)
                      SvgIcon(
                        svg: Assets.icons.outlined.closeCircle,
                        size: iconSize,
                        color: palette.weak,
                        onTap: _clearText,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
