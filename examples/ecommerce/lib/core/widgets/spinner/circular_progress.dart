import 'dart:async';
import 'dart:math' as math;

import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:flutter/material.dart';

class CircularProgressSpinner extends StatefulWidget {
  const CircularProgressSpinner({
    super.key,
    this.color,
    this.size,
    this.strokeWidth,
    this.duration = const Duration(milliseconds: 1200),
    this.controller,
  });

  final Color? color;
  final double? size;
  final double? strokeWidth;
  final Duration duration;
  final AnimationController? controller;

  @override
  State<CircularProgressSpinner> createState() => _CircularProgressSpinnerState();
}

class _CircularProgressSpinnerState extends State<CircularProgressSpinner> with TickerProviderStateMixin {
  late AnimationController _controller;
  late AnimationController _rotationController;
  late Animation<double> _percentAnimation;
  late Animation<double> _rotationAnimation;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? AnimationController(vsync: this, duration: widget.duration);
    _rotationController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000));
    _percentAnimation = Tween<double>(
      begin: 0.80,
      end: 0.30,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    _rotationAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _rotationController, curve: Curves.linear));
    unawaited(_controller.repeat(reverse: true));
    unawaited(_rotationController.repeat());
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
    }
    _rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final size = widget.size ?? spacing.xxl;
    final strokeWidth = widget.strokeWidth ?? (size * 0.0625);
    final color = widget.color ?? palette.brand;

    return Center(
      child: SizedBox(
        width: size,
        height: size,
        child: AnimatedBuilder(
          animation: Listenable.merge([_rotationAnimation, _percentAnimation]),
          builder: (context, child) {
            return Transform.rotate(
              angle: _rotationAnimation.value * math.pi * 2,
              child: CustomPaint(
                painter: _CircularProgressPainter(
                  color: color,
                  strokeWidth: strokeWidth,
                  percent: _percentAnimation.value,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _CircularProgressPainter extends CustomPainter {
  const _CircularProgressPainter({required this.color, required this.strokeWidth, required this.percent});

  final Color color;
  final double strokeWidth;
  final double percent;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    final circumference = radius * 2 * math.pi;
    final strokeDasharray = circumference;
    final strokeDashoffset = circumference * percent;

    final path = Path()..addArc(Rect.fromCircle(center: center, radius: radius), -math.pi / 2, math.pi * 2);

    final dashPath = _createDashPath(path, strokeDasharray, strokeDashoffset);
    canvas.drawPath(dashPath, paint);
  }

  Path _createDashPath(Path source, double dashArray, double dashOffset) {
    final dashPath = Path();
    final pathMetrics = source.computeMetrics();
    final offset = dashOffset % dashArray;

    for (final pathMetric in pathMetrics) {
      double distance = -offset;
      while (distance < pathMetric.length) {
        final segment = pathMetric.extractPath(
          math.max(0, distance),
          math.min(pathMetric.length, distance + dashArray),
        );
        dashPath.addPath(segment, Offset.zero);
        distance += dashArray * 2;
      }
    }
    return dashPath;
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter oldDelegate) {
    return color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth || percent != oldDelegate.percent;
  }
}
