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
  const ShimmerLoading({super.key, required this.isLoading, required this.child, this.height, this.loadingChild});

  /// Whether to show the shimmer loading effect.
  final bool isLoading;

  /// The widget to wrap with shimmer effect.
  final Widget child;

  /// Optional height constraint. If provided, wraps the child with a SizedBox.
  final double? height;

  /// Optional lightweight placeholder rendered while loading.
  ///
  /// Use this to avoid animating heavy widget trees (images, gradients, clips)
  /// during shimmer.
  final Widget? loadingChild;

  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading> {
  ShimmerState? _shimmer;
  bool _isRegistered = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextShimmer = Shimmer.of(context);
    if (!identical(_shimmer, nextShimmer)) {
      _setRegistered(false);
      _shimmer = nextShimmer;
    }
    _syncRegistration();
  }

  @override
  void didUpdateWidget(covariant ShimmerLoading oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isLoading != widget.isLoading) {
      _syncRegistration();
    }
  }

  @override
  void dispose() {
    _setRegistered(false);
    super.dispose();
  }

  void _syncRegistration() {
    _setRegistered(widget.isLoading && _shimmer != null);
  }

  void _setRegistered(bool shouldRegister) {
    if (shouldRegister == _isRegistered) return;
    if (shouldRegister) {
      _shimmer?.registerLoading();
      _isRegistered = true;
      return;
    }
    _shimmer?.unregisterLoading();
    _isRegistered = false;
  }

  Widget _withHeight(Widget child) {
    if (widget.height == null) return child;
    return SizedBox(height: widget.height, child: child);
  }

  @override
  Widget build(BuildContext context) {
    final child = _withHeight(widget.child);

    // If not loading, show the actual content
    if (!widget.isLoading) {
      return child;
    }

    final loadingChild = _withHeight(widget.loadingChild ?? widget.child);

    // Get the shimmer widget from ancestor
    final shimmer = _shimmer ?? Shimmer.of(context);
    if (shimmer == null) {
      // If no shimmer ancestor found, just show the child
      return loadingChild;
    }

    // Wait for shimmer to be laid out
    if (!shimmer.isSized) {
      return const SizedBox();
    }

    // Rebuild only the shader layer on each tick, not the whole child subtree.
    return AnimatedBuilder(
      animation: shimmer.shimmerChanges,
      child: loadingChild,
      builder: (context, child) {
        final renderBox = context.findRenderObject() as RenderBox?;
        if (renderBox == null) {
          return child ?? const SizedBox();
        }

        final shimmerSize = shimmer.size;
        final gradient = shimmer.gradient;
        final offsetWithinShimmer = shimmer.getDescendantOffset(descendant: renderBox);

        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (bounds) {
            return gradient.createShader(
              Rect.fromLTWH(-offsetWithinShimmer.dx, -offsetWithinShimmer.dy, shimmerSize.width, shimmerSize.height),
            );
          },
          child: child,
        );
      },
    );
  }
}
