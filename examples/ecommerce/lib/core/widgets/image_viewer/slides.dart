import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/image_viewer/slide.dart';
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

class ImageViewerSlides extends StatefulWidget {
  const ImageViewerSlides({
    super.key,
    required this.images,
    required this.defaultIndex,
    required this.onTap,
    required this.maxZoom,
    this.onIndexChange,
    this.imageRender,
    this.onZoomChange,
    this.dragLockRef,
  });

  final List<String> images;
  final int defaultIndex;
  final VoidCallback onTap;
  final double? maxZoom;
  final ValueChanged<int>? onIndexChange;
  final Widget Function(String image, {required ImageProvider imageProvider, required int index})? imageRender;
  final ValueChanged<double>? onZoomChange;
  final ValueNotifier<bool>? dragLockRef;

  @override
  State<ImageViewerSlides> createState() => _ImageViewerSlidesState();
}

class _ImageViewerSlidesState extends State<ImageViewerSlides> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  int _currentIndex = 0;
  double _position = 0.0;
  bool _isDragging = false;
  double _dragStartPosition = 0.0;
  double _dragStartAnimationPosition = 0.0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.defaultIndex.clamp(0, widget.images.length - 1);
    _controller = AnimationController(
      vsync: this,
      upperBound: double.infinity,
      lowerBound: double.negativeInfinity,
    );
    _positionAnimation = _controller;
    _position = 0.0;
    _controller.value = _position;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final slideWidth = _getSlideWidth();
    _position = _currentIndex * slideWidth;
    _controller.value = _position;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _getSlideWidth() {
    return MediaQuery.of(context).size.width + 16;
  }

  void _swipeTo(int index, {bool immediate = false}) {
    if (widget.images.isEmpty) return;
    final clampedIndex = clampDouble(index.toDouble(), 0, widget.images.length - 1).toInt();
    if (clampedIndex != _currentIndex) {
      widget.onIndexChange?.call(clampedIndex);
    }
    setState(() {
      _currentIndex = clampedIndex;
    });
    final slideWidth = _getSlideWidth();
    final targetPosition = clampedIndex * slideWidth;
    if (immediate) {
      _position = targetPosition;
      _controller.value = targetPosition;
    } else {
      _position = targetPosition;
      final spring = SpringSimulation(
        const SpringDescription(
          mass: 1.0,
          stiffness: 250.0,
          damping: 30.0,
        ),
        _controller.value,
        targetPosition,
        0.0,
      );
      _controller.animateWith(spring);
    }
  }

  void _handlePanStart(DragStartDetails details) {
    if (widget.dragLockRef?.value ?? false) return;
    _controller.stop();
    _dragStartPosition = details.localPosition.dx;
    _dragStartAnimationPosition = _controller.value;
    setState(() {
      _isDragging = true;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (widget.dragLockRef?.value ?? false) return;
    if (!_isDragging) return;
    final slideWidth = _getSlideWidth();
    if (slideWidth <= 0) return;
    final currentTouchPosition = details.localPosition.dx;
    final dragOffset = _dragStartPosition - currentTouchPosition;
    final offsetInPixels = _dragStartAnimationPosition + dragOffset;
    final boundedValue = clampDouble(offsetInPixels, 0, (widget.images.length - 1) * slideWidth);
    _position = boundedValue;
    _controller.value = boundedValue;
  }

  void _handlePanEnd(DragEndDetails details) {
    if (widget.dragLockRef?.value ?? false) return;
    if (!_isDragging) return;
    final slideWidth = _getSlideWidth();
    if (slideWidth <= 0) {
      setState(() {
        _isDragging = false;
      });
      return;
    }
    final velocity = details.velocity.pixelsPerSecond.dx;
    final direction = velocity > 0 ? 1.0 : (velocity < 0 ? -1.0 : 0.0);
    final velocityOffset = clampDouble(velocity * 0.002, -slideWidth, slideWidth) * direction;
    final predictedIndex = ((_controller.value + velocityOffset) / slideWidth).round();
    final minIndex = (_controller.value / slideWidth).floor();
    final maxIndex = minIndex + 1;
    final targetIndex = clampDouble(predictedIndex.toDouble(), minIndex.toDouble(), maxIndex.toDouble()).toInt();
    setState(() {
      _isDragging = false;
    });
    _swipeTo(targetIndex);
  }

  void _handlePanCancel() {
    if (widget.dragLockRef?.value ?? false) return;
    if (!_isDragging) return;
    setState(() {
      _isDragging = false;
    });
    final slideWidth = _getSlideWidth();
    final targetIndex = (_controller.value / slideWidth).round();
    _swipeTo(targetIndex);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final slideWidth = _getSlideWidth();

    if (widget.images.isEmpty) {
      return const SizedBox.shrink();
    }

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _handlePanStart,
            onPanUpdate: _handlePanUpdate,
            onPanEnd: _handlePanEnd,
            onPanCancel: _handlePanCancel,
            child: ClipRect(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final screenWidth = constraints.maxWidth;
                  return AnimatedBuilder(
                    animation: _positionAnimation,
                    builder: (context, child) {
                      final position = _positionAnimation.value;
                      return Stack(
                        clipBehavior: Clip.hardEdge,
                        children: widget.images.asMap().entries.map((entry) {
                          final slideIndex = entry.key;
                          final image = entry.value;
                          final slidePosition = -position + slideIndex * slideWidth;
                          return Transform.translate(
                            offset: Offset(slidePosition, 0),
                            child: SizedBox(
                              width: screenWidth,
                              height: constraints.maxHeight,
                              child: ImageViewerSlide(
                                image: image,
                                maxZoom: widget.maxZoom,
                                onTap: widget.onTap,
                                onZoomChange: (zoom) {
                                  if (zoom != 1.0) {
                                    final currentIndex = clampDouble(
                                            (_controller.value / slideWidth).round().toDouble(),
                                            0,
                                            widget.images.length - 1)
                                        .toInt();
                                    _swipeTo(currentIndex);
                                  }
                                  widget.onZoomChange?.call(zoom);
                                },
                                dragLockRef: widget.dragLockRef,
                                imageRender: widget.imageRender,
                                index: slideIndex,
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
        Positioned(
          top: spacing.sm,
          left: 0,
          right: 0,
          child: Center(
            child: AnimatedBuilder(
              animation: _positionAnimation,
              builder: (context, child) {
                final position = _positionAnimation.value;
                final index =
                    clampDouble((position / slideWidth).round().toDouble(), 0, widget.images.length - 1).toInt();
                return Container(
                  padding: EdgeInsets.symmetric(horizontal: spacing.sm, vertical: spacing.xs),
                  decoration: BoxDecoration(
                    color: palette.background.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(context.radius.md),
                  ),
                  child: Text(
                    '${index + 1} / ${widget.images.length}',
                    style: typography.bodySmall.toTextStyle(color: palette.textPrimary),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
