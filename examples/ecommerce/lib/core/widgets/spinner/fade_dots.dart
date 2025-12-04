import 'dart:async';
import 'dart:math' as math;

import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/spinner/tween/delay.dart';
import 'package:flutter/material.dart';

class FadingFourSpinner extends StatefulWidget {
  const FadingFourSpinner({
    super.key,
    this.color,
    this.shape = BoxShape.circle,
    this.size,
    this.itemBuilder,
    this.duration = const Duration(milliseconds: 1200),
    this.controller,
  }) : assert(
          !(itemBuilder is IndexedWidgetBuilder && color is Color) && !(itemBuilder == null && color == null),
          'You should specify either a itemBuilder or a color',
        );

  final Color? color;
  final BoxShape shape;
  final double? size;
  final IndexedWidgetBuilder? itemBuilder;
  final Duration duration;
  final AnimationController? controller;

  @override
  State<FadingFourSpinner> createState() => _FadingFourSpinnerState();
}

class _FadingFourSpinnerState extends State<FadingFourSpinner> with TickerProviderStateMixin {
  static const List<double> _delays = [.0, -0.9, -0.6, -0.3];
  late AnimationController _controller;
  late AnimationController _controller2;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _controller = widget.controller ?? AnimationController(vsync: this, duration: widget.duration);
    unawaited(_controller.repeat());

    _controller2 = widget.controller ?? AnimationController(vsync: this, duration: widget.duration);
    _controller2.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });
    unawaited(_controller2.repeat());
    _animation = Tween(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller2, curve: const Interval(0.0, 1.0)));
  }

  @override
  void dispose() {
    if (widget.controller == null) {
      _controller.dispose();
      _controller2.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final size = widget.size ?? spacing.xxl;
    final color = widget.color ?? palette.brand;

    return Center(
      child: Transform(
        transform: Matrix4.identity()..rotateZ((_animation.value) * math.pi * 2),
        alignment: FractionalOffset.center,
        child: SizedBox.fromSize(
          size: Size.square(size),
          child: Stack(
            children: List.generate(4, (i) {
              final position = size * .5;
              return Positioned.fill(
                left: position,
                top: position,
                child: Transform(
                  transform: Matrix4.rotationZ(30.0 * (i * 3) * 0.0174533),
                  child: Align(
                    child: FadeTransition(
                      opacity: DelayTween(begin: 0.0, end: 1.0, delay: _delays[i]).animate(_controller),
                      child: SizedBox.fromSize(size: Size.square(size * 0.25), child: _itemBuilder(i, color)),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  Widget _itemBuilder(int index, Color defaultColor) => widget.itemBuilder != null
      ? widget.itemBuilder!(context, index)
      : DecoratedBox(decoration: BoxDecoration(color: widget.color ?? defaultColor, shape: widget.shape));
}
