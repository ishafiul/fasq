import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:flutter/material.dart';

typedef SegmentedValue = String;

class SegmentedOption {
  const SegmentedOption({required this.value, this.label, this.icon, this.disabled = false});

  final SegmentedValue value;
  final String? label;
  final Widget? icon;
  final bool disabled;
}

class Segmented extends StatefulWidget {
  const Segmented({super.key, required this.options, this.value, this.onValueChanged, this.block = false});

  final List<SegmentedOption> options;
  final SegmentedValue? value;
  final ValueChanged<SegmentedValue>? onValueChanged;
  final bool block;

  @override
  State<Segmented> createState() => _SegmentedState();
}

class _SegmentedState extends State<Segmented> {
  late SegmentedValue? _selectedValue;

  @override
  void initState() {
    super.initState();
    _selectedValue = widget.value;
  }

  @override
  void didUpdateWidget(covariant Segmented oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _selectedValue = widget.value;
    }
  }

  void _handleSelection(SegmentedValue value) {
    if (_selectedValue == value) return;
    setState(() {
      _selectedValue = value;
    });
    widget.onValueChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final colors = context.colors;

    return Container(
      width: widget.block ? double.infinity : null,
      decoration: BoxDecoration(color: colors.surfaceContainerHighest, borderRadius: radius.all(radius.xs)),
      padding: EdgeInsets.all(spacing.xs / 2),
      child: Row(
        mainAxisSize: widget.block ? MainAxisSize.max : MainAxisSize.min,
        children: List.generate(widget.options.length, (index) {
          final option = widget.options[index];
          final isSelected = _selectedValue == option.value;
          final isFirst = index == 0;
          final isLast = index == widget.options.length - 1;

          return Expanded(
            child: _SegmentedItem(
              option: option,
              isSelected: isSelected,
              isFirst: isFirst,
              isLast: isLast,
              onTap: option.disabled ? null : () => _handleSelection(option.value),
            ),
          );
        }),
      ),
    );
  }
}

class _SegmentedItem extends StatelessWidget {
  const _SegmentedItem({
    required this.option,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    this.onTap,
  });

  final SegmentedOption option;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final radius = context.radius;
    final typography = context.typography;
    final colors = context.colors;

    final backgroundColor = isSelected ? colors.surface : Colors.transparent;
    final textColor =
        option.disabled
            ? palette.disabledText
            : isSelected
            ? palette.textPrimary
            : palette.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.only(left: isFirst ? 0 : spacing.xs / 4, right: isLast ? 0 : spacing.xs / 4),
        padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
        decoration: BoxDecoration(color: backgroundColor, borderRadius: radius.all(radius.xs)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (option.icon != null) ...[
              SizedBox(width: spacing.sm, height: spacing.sm, child: option.icon),
              if (option.label != null) SizedBox(width: spacing.xs / 2),
            ],
            if (option.label != null)
              Flexible(
                child: Text(
                  option.label!,
                  style: typography.bodyMedium.toTextStyle(color: textColor),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
