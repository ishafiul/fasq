import 'package:ecommerce/gen/assets.gen.dart';
import 'package:flutter/material.dart';

class SvgIcon extends StatelessWidget {
  final SvgGenImage svg;

  final double size;

  final Color? color;

  final VoidCallback? onTap;

  final String? semanticLabel;

  final BoxFit fit;

  const SvgIcon({
    super.key,
    required this.svg,
    this.size = 24.0,
    this.color,
    this.onTap,
    this.semanticLabel,
    this.fit = BoxFit.contain,
  });

  @override
  Widget build(BuildContext context) {
    final Widget picture = svg.svg(
      width: size,
      height: size,
      fit: fit,
      colorFilter: color != null ? ColorFilter.mode(color!, BlendMode.srcIn) : null,
      semanticsLabel: semanticLabel,
    );

    final Widget icon = SizedBox(
      width: size,
      height: size,
      child: Center(child: picture),
    );

    if (onTap != null) {
      return Semantics(
        label: semanticLabel,
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkResponse(
            onTap: onTap,
            radius: size * 0.75,
            child: icon,
          ),
        ),
      );
    }

    return Semantics(
      label: semanticLabel,
      child: icon,
    );
  }
}
