import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:flutter/material.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    this.title,
    this.icon,
    this.extra,
    this.headerStyle,
    this.headerClassName,
    this.bodyStyle,
    this.bodyClassName,
    this.onClick,
    this.onBodyClick,
    this.onHeaderClick,
    this.children,
    this.padding,
    this.borderRadius,
    this.decoration,
    this.bodyMainAxisSize,
  });

  final Widget? title;
  final Widget? icon;
  final Widget? extra;
  final BoxDecoration? headerStyle;
  final String? headerClassName;
  final BoxDecoration? bodyStyle;
  final String? bodyClassName;
  final VoidCallback? onClick;
  final VoidCallback? onBodyClick;
  final VoidCallback? onHeaderClick;
  final List<Widget>? children;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;
  final BoxDecoration? decoration;
  final MainAxisSize? bodyMainAxisSize;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final colors = context.colors;
    final palette = context.palette;

    final hasHeader = title != null || extra != null;
    final hasBody = children != null && children!.isNotEmpty;

    final cardPadding = padding ?? EdgeInsets.symmetric(horizontal: spacing.sm);
    final cardBorderRadius = borderRadius ?? radius.all(radius.sm);

    final defaultCardDecoration = BoxDecoration(
      color: colors.surface,
      borderRadius: cardBorderRadius,
    );

    final cardDecoration = decoration != null
        ? decoration!.copyWith(
            color: decoration!.color ?? colors.surface,
            borderRadius: decoration!.borderRadius ?? cardBorderRadius,
            border: decoration!.border ??
                (decoration!.border == null && decoration!.color == null ? Border.all(color: palette.border) : null),
          )
        : defaultCardDecoration;

    final effectiveBorderRadius = (cardDecoration.borderRadius ?? cardBorderRadius) as BorderRadius;

    final cardChild = bodyMainAxisSize == MainAxisSize.max
        ? Column(
            mainAxisSize: MainAxisSize.max,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasHeader)
                _CardHeader(
                  title: title,
                  icon: icon,
                  extra: extra,
                  hasBody: hasBody,
                  headerStyle: headerStyle,
                  onHeaderClick: onHeaderClick,
                ),
              if (hasBody)
                Expanded(
                  child: _CardBody(
                    children: children!,
                    bodyStyle: bodyStyle,
                    onBodyClick: onBodyClick,
                    bodyPadding: bodyStyle == null ? null : EdgeInsets.zero,
                    mainAxisSize: bodyMainAxisSize,
                  ),
                ),
            ],
          )
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasHeader)
                _CardHeader(
                  title: title,
                  icon: icon,
                  extra: extra,
                  hasBody: hasBody,
                  headerStyle: headerStyle,
                  onHeaderClick: onHeaderClick,
                ),
              if (hasBody)
                _CardBody(
                  children: children!,
                  bodyStyle: bodyStyle,
                  onBodyClick: onBodyClick,
                  bodyPadding: bodyStyle == null ? null : EdgeInsets.zero,
                  mainAxisSize: bodyMainAxisSize,
                ),
            ],
          );

    if (onClick != null) {
      final cardColor = cardDecoration.color ?? colors.surface;
      final cardBorder = cardDecoration.border;

      return Material(
        color: cardColor,
        borderRadius: effectiveBorderRadius,
        child: Ink(
          decoration: cardBorder != null
              ? BoxDecoration(
                  borderRadius: effectiveBorderRadius,
                  border: cardBorder,
                )
              : null,
          child: InkWell(
            onTap: onClick,
            borderRadius: effectiveBorderRadius,
            splashColor: colors.primary.withValues(alpha: 0.08),
            highlightColor: colors.primary.withValues(alpha: 0.04),
            child: Padding(
              padding: cardPadding,
              child: cardChild,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: cardPadding,
      decoration: cardDecoration,
      child: cardChild,
    );
  }
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    this.title,
    this.icon,
    this.extra,
    required this.hasBody,
    this.headerStyle,
    this.onHeaderClick,
  });

  final Widget? title;
  final Widget? icon;
  final Widget? extra;
  final bool hasBody;
  final BoxDecoration? headerStyle;
  final VoidCallback? onHeaderClick;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    Widget headerContent = Container(
      padding: EdgeInsets.symmetric(vertical: spacing.sm),
      decoration: headerStyle ??
          (hasBody
              ? BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      width: 0.5,
                      color: palette.border,
                    ),
                  ),
                )
              : null),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            DefaultTextStyle(
              style: typography.bodyMedium.toTextStyle(color: palette.textPrimary),
              child: icon!,
            ),
            SizedBox(width: spacing.xs),
          ],
          if (title != null)
            Expanded(
              child: DefaultTextStyle(
                style: typography.bodyMedium
                    .toTextStyle(
                      color: palette.textPrimary,
                    )
                    .copyWith(
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                child: title!,
              ),
            ),
          if (extra != null) ...[
            if (title != null) SizedBox(width: spacing.xs),
            DefaultTextStyle(
              style: typography.bodyMedium.toTextStyle(color: palette.textPrimary),
              child: extra!,
            ),
          ],
        ],
      ),
    );

    if (onHeaderClick != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onHeaderClick,
          child: headerContent,
        ),
      );
    }

    return headerContent;
  }
}

class _CardBody extends StatelessWidget {
  const _CardBody({
    required this.children,
    this.bodyStyle,
    this.onBodyClick,
    this.bodyPadding,
    this.mainAxisSize,
  });

  final List<Widget> children;
  final BoxDecoration? bodyStyle;
  final VoidCallback? onBodyClick;
  final EdgeInsetsGeometry? bodyPadding;
  final MainAxisSize? mainAxisSize;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final colors = context.colors;

    final padding = bodyPadding ?? EdgeInsets.symmetric(vertical: spacing.sm);

    Widget bodyContent = Container(
      padding: padding,
      decoration: bodyStyle,
      child: Column(
        mainAxisSize: mainAxisSize ?? MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );

    final bodyBorderRadius = bodyStyle != null ? null : radius.all(radius.sm);

    if (onBodyClick != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: bodyBorderRadius,
        child: InkWell(
          onTap: onBodyClick,
          borderRadius: bodyBorderRadius,
          splashColor: colors.primary.withValues(alpha: 0.08),
          highlightColor: colors.primary.withValues(alpha: 0.04),
          child: bodyContent,
        ),
      );
    }

    return bodyContent;
  }
}
