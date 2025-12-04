import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:flutter/material.dart';

class ListItem extends StatelessWidget {
  const ListItem({
    super.key,
    this.title,
    this.description,
    this.prefix,
    this.suffix,
    this.arrowIcon,
    this.onClick,
    this.disabled = false,
    this.contentPadding,
    this.child,
  });

  final Widget? title;
  final Widget? description;
  final Widget? prefix;
  final Widget? suffix;
  final Widget? arrowIcon;
  final VoidCallback? onClick;
  final bool disabled;
  final EdgeInsetsGeometry? contentPadding;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final colors = context.colors;

    if (child != null) {
      final effectivePadding = contentPadding ??
          EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.sm,
          );

      final Widget content = Container(
        padding: effectivePadding,
        child: DefaultTextStyle(
          style: typography.bodyMedium.toTextStyle(color: palette.textSecondary),
          child: child!,
        ),
      );

      if (onClick != null && !disabled) {
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onClick,
            splashColor: colors.primary.withValues(alpha: 0.08),
            highlightColor: colors.primary.withValues(alpha: 0.04),
            child: content,
          ),
        );
      }

      return content;
    }

    final effectivePadding = contentPadding ??
        EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.sm,
        );

    final Widget content = Container(
      padding: effectivePadding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (prefix != null) ...[
            DefaultTextStyle(
              style: typography.bodyMedium.toTextStyle(color: palette.textPrimary),
              child: prefix!,
            ),
            SizedBox(width: spacing.xs),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (title != null)
                  DefaultTextStyle(
                    style: typography.bodyMedium.toTextStyle(
                      color: disabled ? palette.disabledText : palette.textPrimary,
                    ),
                    child: title!,
                  ),
                if (description != null && title != null) ...[
                  SizedBox(height: spacing.xs / 2),
                  DefaultTextStyle(
                    style: typography.bodySmall.toTextStyle(
                      color: disabled ? palette.disabledText : palette.textSecondary,
                    ),
                    child: description!,
                  ),
                ] else if (description != null)
                  DefaultTextStyle(
                    style: typography.bodySmall.toTextStyle(
                      color: disabled ? palette.disabledText : palette.textSecondary,
                    ),
                    child: description!,
                  ),
              ],
            ),
          ),
          if (suffix != null) ...[
            SizedBox(width: spacing.xs),
            DefaultTextStyle(
              style: typography.bodyMedium.toTextStyle(color: palette.textPrimary),
              child: suffix!,
            ),
          ],
          if (arrowIcon != null) ...[
            SizedBox(width: spacing.xs),
            DefaultTextStyle(
              style: typography.bodyMedium.toTextStyle(color: palette.textPrimary),
              child: arrowIcon!,
            ),
          ],
        ],
      ),
    );

    if (onClick != null && !disabled) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onClick,
          splashColor: colors.primary.withValues(alpha: 0.08),
          highlightColor: colors.primary.withValues(alpha: 0.04),
          child: content,
        ),
      );
    }

    if (disabled) {
      return Opacity(
        opacity: 0.5,
        child: content,
      );
    }

    return content;
  }
}
