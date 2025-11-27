import 'package:ecommerce/core/colors.dart';
import 'package:flutter/material.dart';

/// A widget that provides shimmer animation to its children.
///
/// This widget creates a sliding gradient effect that can be applied to child widgets
/// via [ShimmerLoading]. The shimmer effect uses theme-aware colors from the app palette.
///
/// Usage:
/// ```dart
/// Shimmer(
///   child: ShimmerLoading(
///     isLoading: true,
///     child: YourWidget(),
///   ),
/// )
/// ```
class Shimmer extends StatefulWidget {
  /// Creates a shimmer widget.
  ///
  /// [child] is the widget tree that will receive the shimmer effect.
  /// [linearGradient] is optional - if not provided, uses theme-aware default gradient.
  const Shimmer({super.key, this.linearGradient, this.child});

  /// Optional custom linear gradient for the shimmer effect.
  ///
  /// If not provided, a default theme-aware gradient will be used.
  final LinearGradient? linearGradient;

  /// The widget tree that will receive the shimmer effect.
  final Widget? child;

  /// Finds the [ShimmerState] in the widget tree.
  ///
  /// Returns null if no [Shimmer] ancestor is found.
  static ShimmerState? of(BuildContext context) {
    return context.findAncestorStateOfType<ShimmerState>();
  }

  @override
  State<Shimmer> createState() => ShimmerState();
}

/// State for the [Shimmer] widget.
///
/// Manages the animation controller and provides the shimmer gradient to child widgets.
class ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late AnimationController _shimmerController;
  LinearGradient? _defaultGradient;

  @override
  void initState() {
    super.initState();

    // Create animation controller that repeats continuously
    _shimmerController = AnimationController.unbounded(vsync: this)
      ..repeat(min: -0.5, max: 1.5, period: const Duration(milliseconds: 1000));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Initialize default gradient based on theme
    // This is called after initState when context is available
    if (_defaultGradient == null) {
      final brightness = Theme.of(context).brightness;
      final palette = paletteFor(brightness);
      _defaultGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.weak, palette.light, palette.weak],
        stops: const [0.0, 0.5, 1.0],
      );
    }
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  /// Gets the current shimmer gradient with the sliding transform applied.
  LinearGradient get gradient {
    // Ensure default gradient is initialized
    if (_defaultGradient == null) {
      final brightness = Theme.of(context).brightness;
      final palette = paletteFor(brightness);
      _defaultGradient = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.weak, palette.light, palette.weak],
        stops: const [0.0, 0.5, 1.0],
      );
    }

    final baseGradient = widget.linearGradient ?? _defaultGradient!;
    return LinearGradient(
      colors: baseGradient.colors,
      stops: baseGradient.stops,
      begin: baseGradient.begin,
      end: baseGradient.end,
      transform: _SlidingGradientTransform(slidePercent: _shimmerController.value),
    );
  }

  /// Checks if the shimmer widget has been laid out and has a size.
  bool get isSized => (context.findRenderObject() as RenderBox?)?.hasSize ?? false;

  /// Gets the size of the shimmer widget.
  ///
  /// Throws if the widget hasn't been laid out yet.
  Size get size => (context.findRenderObject() as RenderBox).size;

  /// Gets the offset of a descendant widget relative to this shimmer widget.
  Offset getDescendantOffset({required RenderBox descendant, Offset offset = Offset.zero}) {
    final shimmerBox = context.findRenderObject() as RenderBox?;
    if (shimmerBox == null) return Offset.zero;
    return descendant.localToGlobal(offset, ancestor: shimmerBox);
  }

  /// Listenable for shimmer animation changes.
  ///
  /// Child widgets can listen to this to update when the shimmer animation changes.
  Listenable get shimmerChanges => _shimmerController;

  @override
  Widget build(BuildContext context) {
    return widget.child ?? const SizedBox();
  }
}

/// Transform that slides the gradient horizontally based on animation value.
class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * slidePercent, 0.0, 0.0);
  }
}
