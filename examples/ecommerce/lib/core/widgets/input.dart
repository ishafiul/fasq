import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/svg_icon.dart';
import 'package:ecommerce/gen/assets.gen.dart';
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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final colors = context.colors;
    final iconSize = spacing.sm;

    return Opacity(
      opacity: widget.disabled ? 0.4 : 1,
      child: ColoredBox(
        color: colors.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.labelText != null)
              Padding(
                padding: EdgeInsets.only(
                  left: widget.isRequired ? spacing.xs : spacing.sm,
                  right: spacing.sm,
                  top: spacing.sm,
                  bottom: spacing.xs / 2,
                ),
                child: Row(
                  children: [
                    if (widget.isRequired) Text('*', style: typography.bodyMedium.toTextStyle(color: palette.danger)),
                    Text(widget.labelText!, style: typography.bodyMedium.toTextStyle(color: palette.textSecondary)),
                  ],
                ),
              ),
            TextFormField(
              validator: widget.validator,
              controller: _controller,
              readOnly: widget.readOnly,
              obscureText: widget.obscureText,
              keyboardType: widget.keyboardType,
              minLines: widget.minLines,
              maxLines: widget.maxLines,
              onChanged: (value) {
                widget.onChanged?.call(value);
              },
              decoration: InputDecoration(
                hintText: widget.placeholder,
                enabled: !widget.disabled,
                suffixIcon: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (widget.suffixIcon != null) widget.suffixIcon!,
                    if (_isVisibleClear)
                      Padding(
                        padding: EdgeInsets.only(right: spacing.xs / 2),
                        child: SvgIcon(
                          svg: Assets.icons.filled.closeCircle,
                          size: iconSize,
                          color: palette.weak,
                          onTap: _clearText,
                        ),
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
