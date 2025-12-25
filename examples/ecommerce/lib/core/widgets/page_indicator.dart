import 'package:ecommerce/core/colors.dart';
import 'package:flutter/material.dart';

enum PageIndicatorDirection {
  horizontal,
  vertical,
}

enum PageIndicatorColor {
  primary,
  white,
}

/// A page indicator widget that displays dots for pagination/carousel navigation.
///
/// Features:
/// - Horizontal and vertical layouts
/// - Primary and white color variants
/// - Customizable dot sizes, spacing, and colors
/// - Follows Ant Design mobile patterns
///
/// Usage:
/// ```dart
/// PageIndicator(
///   total: 5,
///   current: 2,
///   direction: PageIndicatorDirection.horizontal,
///   color: PageIndicatorColor.primary,
/// )
/// ```
class PageIndicator extends StatelessWidget {
  const PageIndicator({
    super.key,
    required this.total,
    required this.current,
    this.direction = PageIndicatorDirection.horizontal,
    this.color = PageIndicatorColor.primary,
    this.dotSize,
    this.activeDotSize,
    this.dotSpacing,
    this.dotBorderRadius,
    this.dotColor,
    this.activeDotColor,
  });

  /// Total number of dots/pages.
  final int total;

  /// Current active page index (0-based).
  final int current;

  /// Layout direction of the indicator.
  final PageIndicatorDirection direction;

  /// Color variant of the indicator.
  final PageIndicatorColor color;

  /// Size of inactive dots. Defaults to 3.0.
  final double? dotSize;

  /// Size of active dot. Defaults to 13.0.
  final double? activeDotSize;

  /// Spacing between dots. Defaults to 3.0.
  final double? dotSpacing;

  /// Border radius for dots. Defaults to 1.0.
  final double? dotBorderRadius;

  /// Custom color for inactive dots. Overrides color variant.
  final Color? dotColor;

  /// Custom color for active dot. Overrides color variant.
  final Color? activeDotColor;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) {
      return const SizedBox.shrink();
    }

    // Clamp current index to valid range
    final clampedCurrent = current.clamp(0, total - 1);

    final palette = context.palette;
    final effectiveDotSize = dotSize ?? 3.0;
    final effectiveActiveDotSize = activeDotSize ?? 13.0;
    final effectiveDotSpacing = dotSpacing ?? 3.0;
    final effectiveDotBorderRadius = dotBorderRadius ?? 1.0;

    // Determine colors based on variant, allowing individual overrides
    final Color inactiveColor;
    final Color activeColor;

    switch (color) {
      case PageIndicatorColor.primary:
        inactiveColor = dotColor ?? palette.light;
        activeColor = activeDotColor ?? palette.brand;
      case PageIndicatorColor.white:
        inactiveColor = dotColor ?? Colors.white.withValues(alpha: 0.5);
        activeColor = activeDotColor ?? Colors.white;
    }

    final dots = List.generate(
      total,
      (index) => _Dot(
        isActive: index == clampedCurrent,
        dotSize: effectiveDotSize,
        activeDotSize: effectiveActiveDotSize,
        dotBorderRadius: effectiveDotBorderRadius,
        inactiveColor: inactiveColor,
        activeColor: activeColor,
        direction: direction,
      ),
    );

    if (direction == PageIndicatorDirection.horizontal) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < dots.length; i++) ...[
            dots[i],
            if (i < dots.length - 1) SizedBox(width: effectiveDotSpacing),
          ],
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < dots.length; i++) ...[
          dots[i],
          if (i < dots.length - 1) SizedBox(height: effectiveDotSpacing),
        ],
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    required this.isActive,
    required this.dotSize,
    required this.activeDotSize,
    required this.dotBorderRadius,
    required this.inactiveColor,
    required this.activeColor,
    required this.direction,
  });

  final bool isActive;
  final double dotSize;
  final double activeDotSize;
  final double dotBorderRadius;
  final Color inactiveColor;
  final Color activeColor;
  final PageIndicatorDirection direction;

  @override
  Widget build(BuildContext context) {
    final size = isActive ? activeDotSize : dotSize;
    final color = isActive ? activeColor : inactiveColor;
    final borderRadius = BorderRadius.circular(dotBorderRadius);

    if (direction == PageIndicatorDirection.horizontal) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: size,
        height: dotSize,
        decoration: BoxDecoration(
          color: color,
          borderRadius: borderRadius,
        ),
      );
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeInOut,
      width: dotSize,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
      ),
    );
  }
}
