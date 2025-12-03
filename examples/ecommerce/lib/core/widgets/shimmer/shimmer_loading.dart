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
/// With height constraint:
/// ```dart
/// Shimmer(
///   child: ShimmerLoading(
///     isLoading: state.isLoading,
///     height: 20,
///     child: Text('Loading...'),
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
  /// [height] is an optional height constraint. If provided, wraps the child with a SizedBox.
  const ShimmerLoading({
    super.key,
    required this.isLoading,
    required this.child,
    this.height,
  });

  /// Whether to show the shimmer loading effect.
  final bool isLoading;

  /// The widget to wrap with shimmer effect.
  final Widget child;

  /// Optional height constraint. If provided, wraps the child with a SizedBox.
  final double? height;

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

  Widget _buildChild() {
    final child = widget.height != null
        ? Container(
            color: Colors.transparent,
            height: widget.height,
            child: widget.child,
          )
        : widget.child;

    return child;
  }

  @override
  Widget build(BuildContext context) {
    final child = _buildChild();

    // If not loading, show the actual content
    if (!widget.isLoading) {
      return child;
    }

    // Get the shimmer widget from ancestor
    final shimmer = Shimmer.of(context);
    if (shimmer == null) {
      // If no shimmer ancestor found, just show the child
      return child;
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
      child: child,
    );
  }
}
