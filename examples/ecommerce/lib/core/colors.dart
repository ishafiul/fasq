import 'package:flutter/material.dart';

/// Semantic color palette contract used across the app.
sealed class AppPalette {
  Color get brand;

  Color get info;

  Color get warning;

  Color get success;

  Color get danger;

  Color get textPrimary;

  Color get textSecondary;

  Color get disabledText;

  Color get background;

  Color get surface;

  Color get border;

  Color get weak;

  Color get light;

  LinearGradient get gradientBrand;
}

class LightPalette implements AppPalette {
  const LightPalette();

  @override
  Color get brand => const Color(0xFF199F6F);

  @override
  Color get info => const Color(0xFF1677FF);

  @override
  Color get warning => const Color(0xFFFF8F1F);

  @override
  Color get success => const Color(0xFF00B578);

  @override
  Color get danger => const Color(0xFFFF3141);

  @override
  Color get textPrimary => const Color(0xFF212121);

  @override
  Color get textSecondary => const Color(0xFF71727A);

  @override
  Color get disabledText => const Color(0xFF838699);

  @override
  Color get background => const Color(0xFFF6F6F6);

  @override
  Color get surface => const Color(0xFFF4F4F4);

  @override
  Color get border => const Color(0xFFDCDCDC);

  @override
  Color get weak => const Color(0xFF999999);

  @override
  Color get light => const Color(0xFFCCCCCC);

  @override
  LinearGradient get gradientBrand => const LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [Color(0xFF0B63E5), Color(0xFF00A0E8)],
      );
}

class DarkPalette implements AppPalette {
  const DarkPalette();

  @override
  Color get brand => const Color(0xFF54D3A3);

  @override
  Color get info => const Color(0xFF4C8DFF);

  @override
  Color get warning => const Color(0xFFFFB547);

  @override
  Color get success => const Color(0xFF25D59A);

  @override
  Color get danger => const Color(0xFFFF5C6B);

  @override
  Color get textPrimary => const Color(0xFFF5F5F5);

  @override
  Color get textSecondary => const Color(0xFFB0B3C0);

  @override
  Color get disabledText => const Color(0xFF777A8A);

  @override
  Color get background => const Color(0xFF141414);

  @override
  Color get surface => const Color(0xFF1F1F1F);

  @override
  Color get border => const Color(0xFF434343);

  @override
  Color get weak => const Color(0xFF555555);

  @override
  Color get light => const Color(0xFF3A3A3A);

  @override
  LinearGradient get gradientBrand => const LinearGradient(
        begin: Alignment.centerRight,
        end: Alignment.centerLeft,
        colors: [Color(0xFF199F6F), Color(0xFF54D3A3)],
      );
}

AppPalette paletteFor(Brightness brightness) {
  return brightness == Brightness.dark ? const DarkPalette() : const LightPalette();
}

extension ContextColors on BuildContext {
  ColorScheme get colors => Theme.of(this).colorScheme;

  AppPalette get palette => paletteFor(Theme.of(this).brightness);
}

class ColorUtils {
  ColorUtils._();

  static Color tint(Color color, double amount) {
    return Color.lerp(color, Colors.white, amount)!;
  }

  static Color shade(Color color, double amount) {
    return Color.lerp(color, Colors.black, amount)!;
  }

  static double luminance(Color color) {
    return color.computeLuminance();
  }

  static Color onColor(Color color) {
    return luminance(color) > 0.5 ? Colors.black : Colors.white;
  }
}
