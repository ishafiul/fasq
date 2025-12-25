import 'package:ecommerce/core/colors.dart';
import 'package:flutter/material.dart';

enum BadgeContentWidth { hug, fixed }

class Badge extends StatelessWidget {
  const Badge({
    super.key,
    this.content,
    this.color,
    this.bordered = false,
    this.contentWidth = BadgeContentWidth.hug,
    this.right = 0,
    this.top = 0,
    this.child,
    this.isDot = false,
  });

  final Widget? content;
  final Color? color;
  final bool bordered;
  final BadgeContentWidth contentWidth;
  final double right;
  final double top;
  final Widget? child;
  final bool isDot;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final badgeColor = color ?? palette.danger;

    final badgeWidget = _buildBadge(context, badgeColor);

    if (child != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          child!,
          Positioned(
            right: right,
            top: top,
            child: FractionalTranslation(
              translation: const Offset(0.5, -0.5),
              child: badgeWidget,
            ),
          ),
        ],
      );
    }

    return badgeWidget;
  }

  Widget _buildBadge(
    BuildContext context,
    Color badgeColor,
  ) {
    if (isDot) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: badgeColor,
          shape: BoxShape.circle,
          border: bordered
              ? Border.all(
                  color: Colors.white,
                  width: 1,
                )
              : null,
        ),
      );
    }

    if (content == null) {
      return const SizedBox.shrink();
    }

    final borderRadius = BorderRadius.circular(100);

    if (contentWidth == BadgeContentWidth.fixed) {
      return SizedBox(
        width: 16,
        height: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: borderRadius,
            border: bordered
                ? Border.all(
                    color: Colors.white,
                    width: 1,
                  )
                : null,
          ),
          child: Center(
            child: content,
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: badgeColor,
        borderRadius: borderRadius,
        border: bordered
            ? Border.all(
                color: Colors.white,
                width: 1,
              )
            : null,
      ),
      child: content,
    );
  }
}
