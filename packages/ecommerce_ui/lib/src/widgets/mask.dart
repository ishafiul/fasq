import 'package:flutter/material.dart';

/// Mask opacity presets.
enum MaskOpacity {
  thin,
  default_,
  thick,
}

/// Mask color presets.
enum MaskColor {
  black,
  white,
}

/// A full-screen overlay mask widget with fade animations.
///
/// Features:
/// - Fade in/out animations
/// - Customizable colors and opacity
/// - Body scroll locking
/// - Show/hide callbacks
/// - Custom container rendering
///
/// Usage:
/// ```dart
/// Mask(
///   visible: true,
///   onMaskClick: () => Navigator.pop(context),
///   child: Center(child: Text('Content')),
/// )
/// ```
class Mask extends StatefulWidget {
  const Mask({
    super.key,
    this.visible = true,
    this.onMaskClick,
    this.destroyOnClose = false,
    this.forceRender = false,
    this.disableBodyScroll = true,
    this.color = MaskColor.black,
    this.opacity = MaskOpacity.default_,
    this.customColor,
    this.customOpacity,
    this.afterShow,
    this.afterClose,
    this.zIndex = 1000,
    this.child,
  });

  /// Whether the mask is visible.
  final bool visible;

  /// Callback when mask is clicked.
  final VoidCallback? onMaskClick;

  /// Destroy widget when closed (removes from tree).
  final bool destroyOnClose;

  /// Force render even when not visible.
  final bool forceRender;

  /// Disable body scroll when visible.
  final bool disableBodyScroll;

  /// Mask color preset.
  final MaskColor color;

  /// Mask opacity preset.
  final MaskOpacity opacity;

  /// Custom color (overrides color preset).
  final Color? customColor;

  /// Custom opacity value (0.0 to 1.0, overrides opacity preset).
  final double? customOpacity;

  /// Callback after mask is shown.
  final VoidCallback? afterShow;

  /// Callback after mask is closed.
  final VoidCallback? afterClose;

  /// Z-index for the mask.
  final int zIndex;

  /// Child widget to display on top of the mask.
  final Widget? child;

  @override
  State<Mask> createState() => _MaskState();
}

class _MaskState extends State<Mask> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );

    _controller.addStatusListener(_handleAnimationStatus);

    if (widget.visible) {
      _active = true;
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(Mask oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _active = true;
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (!mounted) return;

    if (status == AnimationStatus.forward && _controller.value > 0) {
      widget.afterShow?.call();
    }

    if (status == AnimationStatus.reverse && _controller.value == 0) {
      setState(() {
        _active = false;
      });
      widget.afterClose?.call();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    if (widget.customColor != null) {
      return widget.customColor!;
    }

    switch (widget.color) {
      case MaskColor.black:
        return Colors.black;
      case MaskColor.white:
        return Colors.white;
    }
  }

  double _getOpacity() {
    if (widget.customOpacity != null) {
      return widget.customOpacity!.clamp(0.0, 1.0);
    }

    double opacityValue;
    switch (widget.opacity) {
      case MaskOpacity.thin:
        opacityValue = 0.35;
      case MaskOpacity.default_:
        opacityValue = 0.55;
      case MaskOpacity.thick:
        opacityValue = 0.75;
    }

    return opacityValue;
  }

  @override
  Widget build(BuildContext context) {
    if (!_active && !widget.forceRender && widget.destroyOnClose) {
      return const SizedBox.shrink();
    }

    final backgroundColor = _getBackgroundColor();
    final opacity = _getOpacity();
    final effectiveOpacity = _opacityAnimation.value * opacity;

    return _MaskContent(
      visible: widget.visible,
      active: _active,
      backgroundColor: backgroundColor,
      opacity: effectiveOpacity,
      zIndex: widget.zIndex,
      disableBodyScroll: widget.disableBodyScroll && widget.visible,
      onMaskClick: widget.onMaskClick,
      child: widget.child,
    );
  }
}

class _MaskContent extends StatefulWidget {
  const _MaskContent({
    required this.visible,
    required this.active,
    required this.backgroundColor,
    required this.opacity,
    required this.zIndex,
    required this.disableBodyScroll,
    this.onMaskClick,
    this.child,
  });

  final bool visible;
  final bool active;
  final Color backgroundColor;
  final double opacity;
  final int zIndex;
  final bool disableBodyScroll;
  final VoidCallback? onMaskClick;
  final Widget? child;

  @override
  State<_MaskContent> createState() => _MaskContentState();
}

class _MaskContentState extends State<_MaskContent> {
  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox.shrink();
    }

    final screenSize = MediaQuery.of(context).size;

    return IgnorePointer(
      ignoring: !widget.visible,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            // Mask background - covers full screen using absolute positioning
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onMaskClick,
                child: Container(
                  width: screenSize.width,
                  height: screenSize.height,
                  color: widget.backgroundColor.withValues(alpha: widget.opacity),
                ),
              ),
            ),
            // Content
            if (widget.child != null)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: false,
                  child: widget.child!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show a mask as an overlay.
///
/// Usage:
/// ```dart
/// showMask(
///   context: context,
///   onMaskClick: () => Navigator.pop(context),
///   child: Center(child: Text('Content')),
/// );
/// ```
OverlayEntry showMask({
  required BuildContext context,
  VoidCallback? onMaskClick,
  bool destroyOnClose = false,
  bool forceRender = false,
  bool disableBodyScroll = true,
  MaskColor color = MaskColor.black,
  MaskOpacity opacity = MaskOpacity.default_,
  Color? customColor,
  double? customOpacity,
  VoidCallback? afterShow,
  VoidCallback? afterClose,
  int zIndex = 1000,
  Widget? child,
}) {
  final overlayEntry = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: Mask(
        visible: true,
        onMaskClick: onMaskClick ?? () => Navigator.of(context).pop(),
        destroyOnClose: destroyOnClose,
        forceRender: forceRender,
        disableBodyScroll: disableBodyScroll,
        color: color,
        opacity: opacity,
        customColor: customColor,
        customOpacity: customOpacity,
        afterShow: afterShow,
        afterClose: afterClose,
        zIndex: zIndex,
        child: child,
      ),
    ),
  );

  Overlay.of(context).insert(overlayEntry);

  return overlayEntry;
}
