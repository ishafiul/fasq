import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/widgets/svg_icon.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:flutter/material.dart';

class Rating extends StatefulWidget {
  const Rating({
    super.key,
    this.value,
    this.defaultValue = 0,
    this.count = 5,
    this.allowHalf = false,
    this.allowClear = true,
    this.readOnly = false,
    this.starSize = 24,
    this.activeColor,
    this.inactiveColor,
    this.character,
    this.onChanged,
  });

  final double? value;
  final double defaultValue;
  final int count;
  final bool allowHalf;
  final bool allowClear;
  final bool readOnly;
  final double starSize;
  final Color? activeColor;
  final Color? inactiveColor;
  final Widget? character;
  final ValueChanged<double>? onChanged;

  @override
  State<Rating> createState() => _RatingState();
}

class _RatingState extends State<Rating> {
  late double _value;
  final GlobalKey _containerKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _value = widget.value ?? widget.defaultValue;
  }

  @override
  void didUpdateWidget(Rating oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      _value = widget.value ?? widget.defaultValue;
    }
  }

  void _updateValue(double newValue) {
    if (widget.readOnly) return;

    final clampedValue = newValue.clamp(0.0, widget.count.toDouble());
    final roundedValue = widget.allowHalf ? (clampedValue * 2).round() / 2 : clampedValue.ceil().toDouble();

    if (roundedValue == _value && widget.allowClear) {
      setState(() {
        _value = 0;
      });
      widget.onChanged?.call(0);
      return;
    }

    if (roundedValue != _value) {
      setState(() {
        _value = roundedValue;
      });
      widget.onChanged?.call(roundedValue);
    }
  }

  void _handleTapDown(TapDownDetails details) {
    if (widget.readOnly) return;
    _calculateValueFromPosition(details.localPosition.dx);
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (widget.readOnly) return;
    _calculateValueFromPosition(details.localPosition.dx);
  }

  void _calculateValueFromPosition(double x) {
    final RenderBox? renderBox = _containerKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final width = renderBox.size.width;
    if (width <= 0) return;

    final rawValue = (x / width) * widget.count;
    _updateValue(rawValue);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final activeColor = widget.activeColor ?? const Color(0xFFFFD21E);
    final inactiveColor = widget.inactiveColor ?? palette.light;

    final currentValue = widget.value ?? _value;

    if (currentValue <= 0 && widget.value == null && widget.defaultValue == 0) {
      return const SizedBox.shrink();
    }

    Widget buildStar(int index) {
      final starValue = index + 1.0;
      final isActive = currentValue >= starValue;
      final isHalfActive = widget.allowHalf && currentValue > index && currentValue < starValue;

      final inactiveStar = widget.character ??
          SvgIcon(
            svg: Assets.icons.outlined.star,
            size: widget.starSize,
            color: inactiveColor,
          );

      final activeStar = widget.character ??
          SvgIcon(
            svg: Assets.icons.filled.star,
            size: widget.starSize,
            color: activeColor,
          );

      if (isHalfActive) {
        return Stack(
          clipBehavior: Clip.none,
          children: [
            inactiveStar,
            Positioned(
              left: 0,
              top: 0,
              child: ClipRect(
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: 0.5,
                  child: activeStar,
                ),
              ),
            ),
          ],
        );
      }

      return isActive ? activeStar : inactiveStar;
    }

    return GestureDetector(
      onTapDown: widget.readOnly ? null : _handleTapDown,
      onPanUpdate: widget.readOnly ? null : _handlePanUpdate,
      child: Container(
        key: _containerKey,
        padding: const EdgeInsets.all(3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(widget.count, (index) {
            return Padding(
              padding: EdgeInsets.only(right: index < widget.count - 1 ? 10 : 0),
              child: SizedBox(
                width: widget.starSize + 6,
                height: widget.starSize + 6,
                child: buildStar(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}
