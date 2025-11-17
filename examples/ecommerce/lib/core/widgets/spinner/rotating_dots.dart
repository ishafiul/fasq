import 'dart:async';

import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:flutter/material.dart';

class WaveDots extends StatefulWidget {
  const WaveDots({
    super.key,
    this.color,
    this.size,
    this.duration = const Duration(milliseconds: 2000),
    this.controller,
  });

  final Color? color;
  final double? size;
  final Duration duration;
  final AnimationController? controller;

  @override
  State<WaveDots> createState() => _WaveDotsState();
}

class _WaveDotsState extends State<WaveDots> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AnimationController(vsync: this, duration: widget.duration);
    _controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    unawaited(_controller.repeat());
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    super.dispose();
  }

  double _calculateYPosition(double animationValue, double delay) {
    final adjustedValue = (animationValue - delay) % 1.0;
    if (adjustedValue < 0) {
      final adjusted = adjustedValue + 1.0;
      return _getYForValue(adjusted);
    }
    return _getYForValue(adjustedValue);
  }

  double _getYForValue(double value) {
    if (value <= 0.1) {
      final t = value / 0.1;
      return 16.0 + (6.0 - 16.0) * t;
    } else if (value <= 0.3) {
      final t = (value - 0.1) / 0.2;
      return 6.0 + (26.0 - 6.0) * t;
    } else if (value <= 0.4) {
      final t = (value - 0.3) / 0.1;
      return 26.0 + (16.0 - 26.0) * t;
    } else {
      return 16.0;
    }
  }

  Widget _buildAnimatedDot({
    required double delay,
    required double dotSize,
    required Color dotColor,
    required double scale,
  }) {
    final yPosition = _calculateYPosition(_controller.value, delay);
    final normalizedY = (yPosition - 16.0) * scale;

    return Transform.translate(
      offset: Offset(0.0, normalizedY),
      child: Container(
        width: dotSize,
        height: dotSize,
        decoration: BoxDecoration(color: dotColor, borderRadius: BorderRadius.circular(dotSize / 4)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final size = widget.size ?? spacing.xxl;
    final dotColor = widget.color ?? palette.weak;
    final dotSize = size / 10;
    final scale = size / 40.0;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildAnimatedDot(delay: 0.0, dotSize: dotSize, dotColor: dotColor, scale: scale),
                _buildAnimatedDot(delay: 0.1, dotSize: dotSize, dotColor: dotColor, scale: scale),
                _buildAnimatedDot(delay: 0.2, dotSize: dotSize, dotColor: dotColor, scale: scale),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
