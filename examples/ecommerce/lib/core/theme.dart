import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

ThemeData appTheme(Brightness brightness) {
  final palette = paletteFor(brightness);
  final spacing = Spacing.eightPoint();
  final radius = RadiusScale.fourPoint();
  final typography = TypographyScale.goldenRatio(base: 10);

  final baseScheme = ColorScheme.fromSeed(seedColor: palette.brand, brightness: brightness);
  final scheme = baseScheme.copyWith(
    primary: palette.brand,
    secondary: palette.info,
    tertiary: palette.warning,
    error: palette.danger,
    surface: palette.surface,
    onSurface: palette.textPrimary,
    onSurfaceVariant: palette.textSecondary,
    outline: palette.border,
    outlineVariant: palette.light,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    fontFamily: 'Arial',
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 0,
      shadowColor: Colors.transparent,
    ),
    inputDecorationTheme: InputDecorationTheme(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(vertical: spacing.sm),
      hintStyle: typography.bodySmall.toTextStyle(color: palette.textSecondary),
      labelStyle: typography.labelSmall.toTextStyle(color: palette.textSecondary),
      errorStyle: typography.labelSmall.toTextStyle(color: palette.danger),
      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: palette.border)),
      focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: palette.brand)),
      errorBorder: UnderlineInputBorder(borderSide: BorderSide(color: palette.danger)),
      focusedErrorBorder: UnderlineInputBorder(borderSide: BorderSide(color: palette.danger)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: scheme.primary,
        shape: RoundedRectangleBorder(borderRadius: radius.all(radius.md)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surface,
      indicatorColor: scheme.secondaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: scheme.primary,
      unselectedLabelColor: scheme.onSurface,
      indicator: UnderlineTabIndicator(borderSide: BorderSide(color: scheme.primary, width: 2)),
      dividerColor: Colors.transparent,
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerHigh,
      selectedColor: scheme.secondaryContainer,
      labelStyle: TextStyle(color: scheme.onSurface),
      side: BorderSide(color: scheme.outlineVariant),
      shape: const StadiumBorder(),
    ),
    cardTheme: CardThemeData(
      color: scheme.surface,
      shadowColor: scheme.shadow.withValues(alpha: 0.06),
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: radius.all(radius.md)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: radius.all(radius.lg)),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      modalBackgroundColor: scheme.surface,
    ),
    listTileTheme: ListTileThemeData(
      tileColor: scheme.surface,
      iconColor: scheme.onSurfaceVariant,
      textColor: scheme.onSurface,
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: TextStyle(color: scheme.onInverseSurface),
      actionTextColor: scheme.secondary,
      behavior: SnackBarBehavior.floating,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return states.contains(WidgetState.selected) ? scheme.primary.withValues(alpha: 0.4) : Colors.transparent;
        }
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return Colors.white.withValues(alpha: 0.4);
        }
        return Colors.white;
      }),
      side: BorderSide(color: palette.border, width: 1.5),
      shape: const CircleBorder(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      splashRadius: 0,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
      visualDensity: VisualDensity.standard,
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return scheme.primary.withValues(alpha: 0.4);
        }
        return scheme.primary;
      }),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      splashRadius: 0,
      overlayColor: const WidgetStatePropertyAll(Colors.transparent),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStatePropertyAll(scheme.onPrimary),
      trackColor: WidgetStatePropertyAll(scheme.primary),
    ),
    textTheme: _textTheme(scheme, typography),
  );
}

TextTheme _textTheme(ColorScheme scheme, TypographyScale typography) {
  return typography.toTextTheme(color: scheme.onSurface);
}

extension GetItAppThemeExtension on GetIt {
  ThemeData get lightTheme => appTheme(Brightness.light);
  ThemeData get darkTheme => appTheme(Brightness.dark);
}
