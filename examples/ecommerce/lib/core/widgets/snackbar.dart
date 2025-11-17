import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/svg_icon.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

enum SnackBarType { base, alert, error, info }

Future<void> showSnackBar({
  required BuildContext context,
  SnackBarType type = SnackBarType.base,
  bool closable = true,
  bool withIcon = false,
  SvgGenImage? leadingIcon,
  required String message,
}) async {
  final palette = context.palette;
  final spacing = context.spacing;
  final typography = context.typography;
  final messenger = ScaffoldMessenger.of(context);
  final iconSize = spacing.sm;

  await Vibration.vibrate(duration: 10);

  late final Color backgroundColor;
  late final Color textColor;
  late final Color borderColor;
  late final SvgGenImage defaultIcon;

  switch (type) {
    case SnackBarType.base:
      backgroundColor = palette.weak;
      textColor = Colors.white;
      borderColor = palette.weak;
      defaultIcon = Assets.icons.filled.sound;
    case SnackBarType.alert:
      backgroundColor = const Color(0xFFFFF9ED);
      textColor = palette.warning;
      borderColor = const Color(0xFFFFF3E9);
      defaultIcon = Assets.icons.filled.alert;
    case SnackBarType.error:
      backgroundColor = palette.danger;
      textColor = Colors.white;
      borderColor = palette.danger;
      defaultIcon = Assets.icons.filled.alert;
    case SnackBarType.info:
      backgroundColor = const Color(0xFFD0E4FF);
      textColor = palette.info;
      borderColor = const Color(0xFFBCD8FF);
      defaultIcon = Assets.icons.filled.infoCircle;
  }

  final snackBar = SnackBar(
    backgroundColor: Colors.transparent,
    elevation: 0,
    content: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor,
        border: Border(top: BorderSide(color: borderColor), bottom: BorderSide(color: borderColor)),
      ),
      child: Padding(
        padding: EdgeInsets.all(spacing.sm),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (withIcon) ...[
              SvgIcon(svg: leadingIcon ?? defaultIcon, size: iconSize, color: textColor),
              SizedBox(width: spacing.xs),
            ],
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(child: Text(message, style: typography.bodyMedium.toTextStyle(color: textColor))),
                  if (closable) ...[
                    SizedBox(width: spacing.xs),
                    SvgIcon(
                      svg: Assets.icons.outlined.close,
                      size: iconSize,
                      color: textColor,
                      onTap: () {
                        messenger.removeCurrentSnackBar();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  messenger.removeCurrentSnackBar();
  messenger.showSnackBar(snackBar);
}
