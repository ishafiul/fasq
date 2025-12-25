import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:flutter/material.dart';

class NoData extends StatelessWidget {
  final String message;

  const NoData({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final maxWidth = constraints.maxWidth;
        final isConstrained = maxHeight != double.infinity || maxWidth != double.infinity;

        double imageSize = 120;
        double spacing = 24;
        double fontSize = 20;
        double horizontalPadding = 16;

        if (isConstrained) {
          if (maxHeight < 200) {
            imageSize = maxHeight * 0.4;
            spacing = 12;
            fontSize = 16;
            horizontalPadding = 8;
          } else if (maxHeight < 300) {
            imageSize = maxHeight * 0.45;
            spacing = 16;
            fontSize = 18;
          }
        }

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: imageSize,
                height: imageSize,
                child: Assets.images.nodata.svg(),
              ),
              SizedBox(height: spacing),
              Flexible(
                child: Text(
                  message,
                  textAlign: TextAlign.center,
                  style: context.textTheme.bodyLarge?.copyWith(
                    color: Colors.black,
                    fontWeight: FontWeight.w700,
                    fontSize: fontSize,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
