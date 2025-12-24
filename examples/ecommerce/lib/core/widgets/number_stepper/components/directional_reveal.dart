import 'package:ecommerce/core/widgets/number_stepper/number_stepper_config.dart';
import 'package:ecommerce/core/widgets/number_stepper/number_stepper_controller.dart';
import 'package:ecommerce/core/widgets/number_stepper/number_stepper_offsets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class DirectionalReveal extends StatefulWidget {
  const DirectionalReveal({
    super.key,
    required this.direction,
    required this.isExpanded,
    required this.showCollapsedPlusOnly,
    required this.config,
    required this.estimatedAnchorExtent,
    required this.gap,
    required this.numberBox,
    required this.minusOrDeleteButton,
    required this.plusButton,
    this.menu,
  });

  final NumberStepperExpandDirection direction;
  final bool isExpanded;
  final bool showCollapsedPlusOnly;
  final NumberStepperConfig config;
  final double estimatedAnchorExtent;
  final double gap;
  final Widget numberBox;
  final Widget minusOrDeleteButton;
  final Widget plusButton;
  final Widget? menu;

  @override
  State<DirectionalReveal> createState() => _DirectionalRevealState();
}

class _DirectionalRevealState extends State<DirectionalReveal> {
  Size _numberSize = Size.zero;
  Size _minusSize = Size.zero;
  Size _plusSize = Size.zero;

  void _setNumberSize(Size size) {
    if (_numberSize == size) return;
    setState(() => _numberSize = size);
  }

  void _setMinusSize(Size size) {
    if (_minusSize == size) return;
    setState(() => _minusSize = size);
  }

  void _setPlusSize(Size size) {
    if (_plusSize == size) return;
    setState(() => _plusSize = size);
  }

  @override
  Widget build(BuildContext context) {
    final numberW = _numberSize.width > 0 ? _numberSize.width : widget.estimatedAnchorExtent;
    final numberH = _numberSize.height > 0 ? _numberSize.height : widget.estimatedAnchorExtent;

    final calculator = NumberStepperOffsetCalculator(
      direction: widget.direction,
      gap: widget.gap,
    );

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: widget.isExpanded ? 1.0 : 0.0),
      duration: widget.config.animationDuration,
      curve: Curves.easeInOut,
      builder: (context, t, child) {
        final offsets = calculator.computeOffsets(
          t: t,
          numberW: numberW,
          numberH: numberH,
          minusSize: _minusSize,
          plusSize: _plusSize,
        );
        final showCollapsed = t < widget.config.collapseThreshold;
        final showExpanded = t > widget.config.expandThreshold;

        return SizedBox(
          width: numberW,
          height: numberH,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (widget.menu != null)
                Positioned(
                  right: -8,
                  top: -8,
                  child: widget.menu!,
                ),
              if (showCollapsed)
                IgnorePointer(
                  ignoring: t > 0.01,
                  child: Opacity(
                    opacity: 1.0 - t,
                    child: _MeasureSize(
                      onChange: _setNumberSize,
                      child: widget.showCollapsedPlusOnly ? widget.plusButton : widget.numberBox,
                    ),
                  ),
                ),
              if (showExpanded) ...[
                _buildExpandedElement(
                  offset: offsets.minus,
                  opacity: t,
                  child: _MeasureSize(
                    onChange: _setMinusSize,
                    child: widget.minusOrDeleteButton,
                  ),
                ),
                _buildExpandedElement(
                  offset: offsets.number,
                  opacity: t,
                  child: widget.numberBox,
                ),
                _buildExpandedElement(
                  offset: offsets.plus,
                  opacity: t,
                  child: _MeasureSize(
                    onChange: _setPlusSize,
                    child: widget.plusButton,
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpandedElement({
    required Offset offset,
    required double opacity,
    required Widget child,
  }) {
    final clampedOpacity = opacity.clamp(0.0, 1.0);
    return Transform.translate(
      offset: offset,
      child: Opacity(
        opacity: clampedOpacity,
        child: child,
      ),
    );
  }
}

class _MeasureSize extends SingleChildRenderObjectWidget {
  const _MeasureSize({
    required this.onChange,
    required super.child,
  });

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return _MeasureSizeRenderObject(onChange);
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _MeasureSizeRenderObject renderObject,
  ) {
    renderObject.onChange = onChange;
  }
}

class _MeasureSizeRenderObject extends RenderProxyBox {
  _MeasureSizeRenderObject(this.onChange);

  ValueChanged<Size> onChange;
  Size _oldSize = Size.zero;

  @override
  void performLayout() {
    super.performLayout();
    final newSize = size;
    if (_oldSize == newSize) return;
    _oldSize = newSize;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      onChange(newSize);
    });
  }
}
