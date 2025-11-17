import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

ThemeData appTheme(Brightness brightness) {
  final palette = paletteFor(brightness);
  final spacing = Spacing.eightPoint();
  final radius = RadiusScale.fourPoint();
  final typography = TypographyScale.goldenRatio();

  final baseScheme = ColorScheme.fromSeed(seedColor: palette.brand, brightness: brightness);
  final scheme = baseScheme.copyWith(
    primary: palette.brand,
    secondary: palette.info,
    tertiary: palette.warning,
    error: palette.danger,
    surface: palette.background,
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
      filled: true,
      fillColor: scheme.surfaceContainerHighest,
      contentPadding: EdgeInsets.all(spacing.sm),
      hintStyle: TextStyle(color: scheme.onSurfaceVariant),
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
      errorStyle: typography.labelSmall.toTextStyle(color: scheme.error),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius.all(radius.md),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius.all(radius.md),
        borderSide: BorderSide(color: scheme.primary),
      ),
      errorBorder: OutlineInputBorder(borderRadius: radius.all(radius.md), borderSide: BorderSide(color: scheme.error)),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: radius.all(radius.md),
        borderSide: BorderSide(color: scheme.error),
      ),
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
        if (states.contains(WidgetState.selected)) return scheme.primary;
        return scheme.surfaceContainerHighest;
      }),
    ),
    radioTheme: RadioThemeData(fillColor: WidgetStatePropertyAll(scheme.primary)),
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
