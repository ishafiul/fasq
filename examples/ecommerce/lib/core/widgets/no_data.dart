import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:flutter/material.dart';

class NoData extends StatelessWidget {
  final String message;

  const NoData({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 24,
      mainAxisSize: MainAxisSize.min,
      children: [
        Assets.images.nodata.svg(),
        Text(
          message,
          style: context.textTheme.bodyLarge?.copyWith(
            color: Colors.black,
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
      ],
    );
  }
}
