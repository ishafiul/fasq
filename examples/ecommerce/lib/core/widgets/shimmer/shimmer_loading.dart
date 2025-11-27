import 'package:ecommerce/core/widgets/shimmer/shimmer.dart';
import 'package:flutter/material.dart';

/// A widget that conditionally shows shimmer effect or actual content.
///
/// This widget wraps any child widget and shows a shimmer loading effect when [isLoading]
/// is true. The shimmer effect takes the exact shape of the wrapped widget.
///
/// Usage:
/// ```dart
/// Shimmer(
///   child: ShimmerLoading(
///     isLoading: state.isLoading,
///     child: ProductCard(product: product),
///   ),
/// )
/// ```
///
/// Note: This widget must be a descendant of a [Shimmer] widget to work properly.
class ShimmerLoading extends StatefulWidget {
  /// Creates a shimmer loading widget.
  ///
  /// [isLoading] determines whether to show shimmer effect or actual content.
  /// [child] is the widget that will be wrapped with shimmer effect.
  const ShimmerLoading({super.key, required this.isLoading, required this.child});

  /// Whether to show the shimmer loading effect.
  final bool isLoading;

  /// The widget to wrap with shimmer effect.
  final Widget child;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> {
  Listenable? _shimmerChanges;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_shimmerChanges != null) {
      _shimmerChanges!.removeListener(_onShimmerChange);
    }
    _shimmerChanges = Shimmer.of(context)?.shimmerChanges;
    if (_shimmerChanges != null) {
      _shimmerChanges!.addListener(_onShimmerChange);
    }
  }

  @override
  void dispose() {
    _shimmerChanges?.removeListener(_onShimmerChange);
    super.dispose();
  }

  void _onShimmerChange() {
    if (widget.isLoading) {
      setState(() {
        // Update the shimmer painting when animation changes
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // If not loading, show the actual content
    if (!widget.isLoading) {
      return widget.child;
    }

    // Get the shimmer widget from ancestor
    final shimmer = Shimmer.of(context);
    if (shimmer == null) {
      // If no shimmer ancestor found, just show the child
      return widget.child;
    }

    // Wait for shimmer to be laid out
    if (!shimmer.isSized) {
      return const SizedBox();
    }

    final shimmerSize = shimmer.size;
    final gradient = shimmer.gradient;
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return const SizedBox();
    }

    final offsetWithinShimmer = shimmer.getDescendantOffset(descendant: renderBox);

    // Apply shimmer effect using ShaderMask
    return ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (bounds) {
        return gradient.createShader(
          Rect.fromLTWH(-offsetWithinShimmer.dx, -offsetWithinShimmer.dy, shimmerSize.width, shimmerSize.height),
        );
      },
      child: widget.child,
    );
  }
}
