import 'dart:async';
import 'dart:math' as math;

import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/page_indicator.dart';
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

/// An item widget for the [Swiper] widget.
///
/// The [child] widget will be displayed as a slide in the swiper.
///
/// Example:
/// ```dart
/// SwiperItem(
///   child: Image.network('https://example.com/image.jpg'),
/// )
/// ```
class SwiperItem extends StatelessWidget {
  const SwiperItem({
    super.key,
    required this.child,
  });

  /// The widget to display in this swiper item.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return child;
  }
}

/// Autoplay mode for the [Swiper] widget.
enum SwiperAutoplay {
  /// No autoplay.
  none,

  /// Autoplay forward (next slides).
  forward,

  /// Autoplay reverse (previous slides).
  reverse,
}

/// Indicator position for the [Swiper] widget.
enum SwiperIndicatorPosition {
  /// Position at the start (left for horizontal, top for vertical).
  start,

  /// Position at the center.
  center,

  /// Position at the end (right for horizontal, bottom for vertical).
  end,
}

/// Event types that can stop propagation.
enum SwiperPropagationEvent {
  /// Stop propagation on tap down.
  tapDown,

  /// Stop propagation on tap up.
  tapUp,

  /// Stop propagation on pan start.
  panStart,

  /// Stop propagation on pan update.
  panUpdate,

  /// Stop propagation on pan end.
  panEnd,
}

/// Properties for customizing the [PageIndicator] appearance.
class SwiperIndicatorProps {
  const SwiperIndicatorProps({
    this.color,
    this.dotSize,
    this.activeDotSize,
    this.dotSpacing,
    this.dotBorderRadius,
    this.dotColor,
    this.activeDotColor,
    this.position,
  });

  final PageIndicatorColor? color;
  final double? dotSize;
  final double? activeDotSize;
  final double? dotSpacing;
  final double? dotBorderRadius;
  final Color? dotColor;
  final Color? activeDotColor;
  final SwiperIndicatorPosition? position;
}

/// A controller for programmatically controlling the [Swiper] widget.
class SwiperRef {
  SwiperRef();

  _SwiperState? _state;

  /// Navigate to a specific slide index.
  void swipeTo(int index) {
    _state?._swipeTo(index, immediate: false);
  }

  /// Navigate to the next slide.
  void swipeNext() {
    _state?._swipeNext();
  }

  /// Navigate to the previous slide.
  void swipePrev() {
    _state?._swipePrev();
  }
}

/// A swiper widget that supports horizontal and vertical swiping with drag gestures,
/// autoplay, loop mode, and customizable slide sizes.
///
/// Features:
/// - Horizontal and vertical swiping
/// - Autoplay (forward/reverse)
/// - Loop mode for infinite scrolling
/// - Drag gestures with velocity-based snapping
/// - Customizable slide size and track offset
/// - Rubberband effect at boundaries
/// - Integration with [PageIndicator]
/// - Custom indicator builder support
///
/// Usage:
/// ```dart
/// Swiper(
///   children: [
///     SwiperItem(child: Image.network('https://example.com/image1.jpg')),
///     SwiperItem(child: Image.network('https://example.com/image2.jpg')),
///     SwiperItem(child: Image.network('https://example.com/image3.jpg')),
///   ],
///   autoplay: SwiperAutoplay.forward,
///   autoplayInterval: Duration(seconds: 3),
///   loop: true,
///   onIndexChange: (index) => print('Current index: $index'),
/// )
/// ```
class Swiper extends StatefulWidget {
  const Swiper({
    super.key,
    required this.children,
    this.defaultIndex = 0,
    this.allowTouchMove = true,
    this.autoplay = SwiperAutoplay.none,
    this.autoplayInterval = const Duration(milliseconds: 3000),
    this.loop = false,
    this.direction = Axis.horizontal,
    this.onIndexChange,
    this.indicatorProps,
    this.indicator,
    this.showIndicator = true,
    this.slideSize = 100.0,
    this.trackOffset = 0.0,
    this.stuckAtBoundary = true,
    this.rubberband = true,
    this.stopPropagation = const [],
    this.ref,
  });

  /// The list of [SwiperItem] widgets to display.
  final List<Widget> children;

  /// Initial slide index (0-based).
  final int defaultIndex;

  /// Whether touch gestures are enabled.
  final bool allowTouchMove;

  /// Autoplay mode.
  final SwiperAutoplay autoplay;

  /// Interval between autoplay transitions.
  final Duration autoplayInterval;

  /// Whether to enable loop mode (infinite scrolling).
  final bool loop;

  /// Swiping direction.
  final Axis direction;

  /// Callback fired when the slide index changes.
  final ValueChanged<int>? onIndexChange;

  /// Properties for customizing the [PageIndicator] appearance.
  final SwiperIndicatorProps? indicatorProps;

  /// Custom indicator builder. If `null`, uses default [PageIndicator].
  /// If the function returns `null`, no indicator is shown.
  final Widget? Function(int total, int current)? indicator;

  /// Whether to show the indicator. Defaults to `true`.
  /// If `false`, no indicator is shown regardless of [indicator] value.
  final bool showIndicator;

  /// Slide size as a percentage (0-100).
  final double slideSize;

  /// Track offset as a percentage (0-100).
  final double trackOffset;

  /// Whether to stick at boundaries.
  final bool stuckAtBoundary;

  /// Whether to enable rubberband effect at boundaries.
  final bool rubberband;

  /// List of events to stop propagation for.
  final List<SwiperPropagationEvent> stopPropagation;

  /// Optional controller for programmatic navigation.
  final SwiperRef? ref;

  @override
  State<Swiper> createState() => _SwiperState();
}

class _SwiperState extends State<Swiper> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _positionAnimation;
  Timer? _autoplayTimer;
  bool _isDragging = false;
  double _dragStartTouchPosition = 0.0;
  double _dragStartAnimationPosition = 0.0;
  int _currentIndex = 0;
  double _position = 0.0;
  final GlobalKey _trackKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.defaultIndex.clamp(0, _maxIndex);
    _position = _boundIndex(_currentIndex.toDouble()) * 100.0;
    _controller = AnimationController(
      vsync: this,
      upperBound: double.infinity,
      lowerBound: double.negativeInfinity,
    );
    _positionAnimation = _controller;
    _controller.value = _position;
    if (widget.ref != null) {
      widget.ref!._state = this;
    }
    _startAutoplay();
  }

  @override
  void didUpdateWidget(Swiper oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.children.length != oldWidget.children.length) {
      _currentIndex = _currentIndex.clamp(0, _maxIndex);
      _updatePosition(immediate: true);
    }
    if (widget.autoplay != oldWidget.autoplay || widget.autoplayInterval != oldWidget.autoplayInterval) {
      _stopAutoplay();
      _startAutoplay();
    }
    if (widget.ref != oldWidget.ref) {
      if (widget.ref != null) {
        widget.ref!._state = this;
      }
      if (oldWidget.ref != null) {
        oldWidget.ref!._state = null;
      }
    }
  }

  @override
  void dispose() {
    _stopAutoplay();
    _controller.dispose();
    super.dispose();
  }

  int get _maxIndex => math.max(0, widget.children.length - 1);
  int get _total => widget.children.length;
  bool get _isVertical => widget.direction == Axis.vertical;
  double get _slideRatio => widget.slideSize / 100.0;
  double get _offsetRatio => widget.trackOffset / 100.0;

  double _getSlidePixels() {
    final RenderBox? renderBox = _trackKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return 0.0;
    return _isVertical ? renderBox.size.height * _slideRatio : renderBox.size.width * _slideRatio;
  }

  double _boundIndex(double index) {
    if (widget.children.isEmpty) return 0.0;
    double min = 0.0;
    double max = _maxIndex.toDouble();
    if (widget.stuckAtBoundary) {
      min += _offsetRatio / _slideRatio;
      max -= (1.0 - _slideRatio - _offsetRatio) / _slideRatio;
    }
    return clampDouble(index, min, max);
  }

  double _modulus(double value, double division) {
    final remainder = value % division;
    return remainder < 0 ? remainder + division : remainder;
  }

  void _updatePosition({bool immediate = false}) {
    if (widget.children.isEmpty) return;
    final currentPositionValue = _controller.value;
    final targetPosition = widget.loop ? _currentIndex * 100.0 : _boundIndex(_currentIndex.toDouble()) * 100.0;
    if (immediate) {
      _position = targetPosition;
      _controller.value = targetPosition;
    } else {
      _position = targetPosition;
      final spring = SpringSimulation(
        const SpringDescription(
          mass: 1.0,
          stiffness: 200.0,
          damping: 30.0,
        ),
        currentPositionValue,
        targetPosition,
        0.0,
      );
      _controller.animateWith(spring).then((_) {
        if (!mounted || _isDragging) return;
        if (!widget.loop) return;
        final rawPosition = _controller.value;
        final totalWidth = 100.0 * _total;
        final standardPosition = _modulus(rawPosition, totalWidth);
        if ((standardPosition - rawPosition).abs() > 0.01) {
          _controller.value = standardPosition;
        }
      });
    }
  }

  void _swipeTo(int index, {bool immediate = false}) {
    if (widget.children.isEmpty) return;
    final roundedIndex = index.round();
    final targetIndex =
        widget.loop ? _modulus(roundedIndex.toDouble(), _total.toDouble()).toInt() : roundedIndex.clamp(0, _maxIndex);
    if (targetIndex != _currentIndex) {
      widget.onIndexChange?.call(targetIndex);
    }
    setState(() {
      _currentIndex = targetIndex;
    });
    _updatePosition(immediate: immediate);
  }

  void _swipeNext() {
    if (widget.children.isEmpty) return;
    final currentPositionValue = _controller.value / 100.0;
    _swipeTo(currentPositionValue.round() + 1);
  }

  void _swipePrev() {
    if (widget.children.isEmpty) return;
    final currentPositionValue = _controller.value / 100.0;
    _swipeTo(currentPositionValue.round() - 1);
  }

  void _startAutoplay() {
    if (widget.autoplay == SwiperAutoplay.none || widget.children.length <= 1 || _isDragging) return;
    _autoplayTimer?.cancel();
    _autoplayTimer = Timer.periodic(widget.autoplayInterval, (_) {
      if (!mounted || _isDragging) return;
      if (widget.autoplay == SwiperAutoplay.reverse) {
        _swipePrev();
      } else {
        _swipeNext();
      }
    });
  }

  void _stopAutoplay() {
    _autoplayTimer?.cancel();
    _autoplayTimer = null;
  }

  void _handlePanStart(DragStartDetails details) {
    if (!widget.allowTouchMove) return;
    _stopAutoplay();
    _controller.stop();
    _dragStartTouchPosition = _isVertical ? details.localPosition.dy : details.localPosition.dx;
    _dragStartAnimationPosition = _controller.value;
    setState(() {
      _isDragging = true;
    });
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.allowTouchMove || !_isDragging) return;
    final slidePixels = _getSlidePixels();
    if (slidePixels <= 0) return;
    final currentTouchPosition = _isVertical ? details.localPosition.dy : details.localPosition.dx;
    final dragOffset = _dragStartTouchPosition - currentTouchPosition;
    final offsetInPixels = (_dragStartAnimationPosition / 100.0) * slidePixels + dragOffset;
    final newPositionValue = (offsetInPixels / slidePixels) * 100.0;

    if (widget.loop) {
      _position = newPositionValue;
      _controller.value = newPositionValue;
    } else {
      final boundedValue = _boundIndex(newPositionValue / 100.0) * 100.0;
      if (widget.rubberband) {
        final rawValue = newPositionValue / 100.0;
        if (rawValue < 0 || rawValue > _maxIndex) {
          final overscroll = rawValue < 0 ? -rawValue : (rawValue - _maxIndex);
          final resistance = 1.0 / (1.0 + overscroll * 0.1);
          _position = boundedValue + (newPositionValue - boundedValue) * resistance;
        } else {
          _position = boundedValue;
        }
      } else {
        _position = boundedValue;
      }
      _controller.value = _position;
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (!widget.allowTouchMove || !_isDragging) return;
    final slidePixels = _getSlidePixels();
    if (slidePixels <= 0) {
      setState(() {
        _isDragging = false;
      });
      _startAutoplay();
      return;
    }
    final velocity = _isVertical ? details.velocity.pixelsPerSecond.dy : details.velocity.pixelsPerSecond.dx;
    final currentTouchPosition = _isVertical ? details.localPosition.dy : details.localPosition.dx;
    final dragOffset = _dragStartTouchPosition - currentTouchPosition;
    final direction = dragOffset > 0 ? 1.0 : (dragOffset < 0 ? -1.0 : 0.0);

    final offsetInPixels = (_dragStartAnimationPosition / 100.0) * slidePixels + dragOffset;
    final minIndex = (offsetInPixels / slidePixels).floor();
    final maxIndex = minIndex + 1;
    final predictedOffset = offsetInPixels + (velocity * 0.002 * direction);
    final predictedIndex = (predictedOffset / slidePixels).round();

    int targetIndex = clampDouble(predictedIndex.toDouble(), minIndex.toDouble(), maxIndex.toDouble()).round();

    if (widget.loop) {
      targetIndex = _modulus(targetIndex.toDouble(), _total.toDouble()).toInt();
    } else {
      targetIndex = targetIndex.clamp(0, _maxIndex);
    }

    setState(() {
      _isDragging = false;
    });
    _swipeTo(targetIndex);
    _startAutoplay();
  }

  void _handlePanCancel() {
    if (!widget.allowTouchMove || !_isDragging) return;
    setState(() {
      _isDragging = false;
    });
    _updatePosition();
    _startAutoplay();
  }

  bool _shouldStopPropagation(SwiperPropagationEvent event) {
    return widget.stopPropagation.contains(event);
  }

  Widget _buildIndicatorPosition(Widget indicator, SwiperIndicatorPosition position, Spacing spacing) {
    if (_isVertical) {
      switch (position) {
        case SwiperIndicatorPosition.start:
          return Positioned(
            top: spacing.xs,
            right: spacing.xs,
            child: indicator,
          );
        case SwiperIndicatorPosition.center:
          return Positioned(
            right: spacing.xs,
            top: 0.0,
            bottom: 0.0,
            child: Center(child: indicator),
          );
        case SwiperIndicatorPosition.end:
          return Positioned(
            bottom: spacing.xs,
            right: spacing.xs,
            child: indicator,
          );
      }
    } else {
      switch (position) {
        case SwiperIndicatorPosition.start:
          return Positioned(
            bottom: spacing.xs,
            left: spacing.xs,
            child: indicator,
          );
        case SwiperIndicatorPosition.center:
          return Positioned(
            bottom: spacing.xs,
            left: 0.0,
            right: 0.0,
            child: Center(child: indicator),
          );
        case SwiperIndicatorPosition.end:
          return Positioned(
            bottom: spacing.xs,
            right: spacing.xs,
            child: indicator,
          );
      }
    }
  }

  Widget? _buildIndicator() {
    if (!widget.showIndicator || widget.children.isEmpty) return null;
    if (widget.indicator == null) {
      final props = widget.indicatorProps ?? const SwiperIndicatorProps();
      return PageIndicator(
        total: _total,
        current: _currentIndex,
        direction: _isVertical ? PageIndicatorDirection.vertical : PageIndicatorDirection.horizontal,
        color: props.color ?? PageIndicatorColor.primary,
        dotSize: props.dotSize,
        activeDotSize: props.activeDotSize,
        dotSpacing: props.dotSpacing,
        dotBorderRadius: props.dotBorderRadius,
        dotColor: props.dotColor,
        activeDotColor: props.activeDotColor,
      );
    }
    return widget.indicator!(_total, _currentIndex);
  }

  Widget _buildSlide(int index, Widget child, double viewportWidth, double viewportHeight, bool isLoop) {
    return AnimatedBuilder(
      animation: _positionAnimation,
      builder: (context, _) {
        final position = _positionAnimation.value;
        double finalPosition;

        if (isLoop) {
          final slidePosition = -position + index * 100.0;
          final totalWidth = _total * 100.0;
          final flagWidth = totalWidth / 2.0;
          finalPosition = _modulus(slidePosition + flagWidth, totalWidth) - flagWidth;
        } else {
          finalPosition = (-position + index * 100.0);
        }

        final positionPercent = finalPosition / 100.0;
        final left = _isVertical ? 0.0 : positionPercent * viewportWidth;
        final top = _isVertical ? positionPercent * viewportHeight : 0.0;

        return Positioned(
          left: left,
          top: top,
          child: SizedBox(
            width: viewportWidth,
            height: viewportHeight,
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.children.isEmpty) {
      return const SizedBox.shrink();
    }
    final validChildren = widget.children.whereType<SwiperItem>().toList();
    if (validChildren.length != widget.children.length) {
      return const SizedBox.shrink();
    }
    final spacing = context.spacing;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onPanStart: _shouldStopPropagation(SwiperPropagationEvent.panStart)
                ? (details) {
                    _handlePanStart(details);
                  }
                : _handlePanStart,
            onPanUpdate: _shouldStopPropagation(SwiperPropagationEvent.panUpdate)
                ? (details) {
                    _handlePanUpdate(details);
                  }
                : _handlePanUpdate,
            onPanEnd: _shouldStopPropagation(SwiperPropagationEvent.panEnd)
                ? (details) {
                    _handlePanEnd(details);
                  }
                : _handlePanEnd,
            onPanCancel: _handlePanCancel,
            child: ClipRect(
              child: LayoutBuilder(
                key: _trackKey,
                builder: (context, constraints) {
                  final viewportWidth = constraints.maxWidth;
                  final viewportHeight = constraints.maxHeight;
                  return Stack(
                    children: [
                      for (int i = 0; i < validChildren.length; i++)
                        _buildSlide(
                          i,
                          validChildren[i],
                          viewportWidth,
                          viewportHeight,
                          widget.loop,
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
        Builder(
          builder: (context) {
            final indicator = _buildIndicator();
            if (indicator == null) return const SizedBox.shrink();
            final props = widget.indicatorProps ?? const SwiperIndicatorProps();
            final position = props.position ?? SwiperIndicatorPosition.end;
            return _buildIndicatorPosition(indicator, position, spacing);
          },
        ),
      ],
    );
  }
}
