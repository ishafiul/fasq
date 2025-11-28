import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Seed types for generating text scales.
enum TextScaleSeed {
  majorThird,
  perfectFourth,
  goldenRatio,
}

/// Type-safe text scale with named properties for font sizes.
///
/// Usage:
/// ```dart
/// Text('Hello', style: TextStyle(fontSize: textScale.sm));
/// ```
class TextScale {
  const TextScale._({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.xxxl,
    required this.xxxxl,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double xxxl;
  final double xxxxl;

  /// Creates a text scale using the specified ratio.
  static TextScale _fromRatio(double ratio, {double base = 16}) {
    final values = List<double>.generate(
      8,
      (index) => base * math.pow(ratio, index).toDouble(),
    );
    return TextScale._(
      xs: values[0],
      sm: values[1],
      md: values[2],
      lg: values[3],
      xl: values[4],
      xxl: values[5],
      xxxl: values[6],
      xxxxl: values[7],
    );
  }

  /// Creates a text scale using Major Third ratio (1.250).
  factory TextScale.majorThird({double base = 16}) => _fromRatio(1.250, base: base);

  /// Creates a text scale using Perfect Fourth ratio (1.333).
  factory TextScale.perfectFourth({double base = 16}) => _fromRatio(1.333, base: base);

  /// Creates a text scale using Golden Ratio (1.618).
  factory TextScale.goldenRatio({double base = 16}) => _fromRatio(1.618, base: base);
}

/// Type-safe spacing scale using 8-point grid system.
///
/// Usage:
/// ```dart
/// SizedBox(height: spacing.xs);
/// Padding(padding: EdgeInsets.all(spacing.md));
/// ```
class Spacing {
  const Spacing._({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.xxxl,
    required this.xxxxl,
  });

  final double xs; // 8
  final double sm; // 16
  final double md; // 24
  final double lg; // 32
  final double xl; // 40
  final double xxl; // 48
  final double xxxl; // 64
  final double xxxxl; // 80

  /// Creates spacing using 8-point grid system.
  factory Spacing.eightPoint() {
    return const Spacing._(
      xs: 8,
      sm: 16,
      md: 24,
      lg: 32,
      xl: 40,
      xxl: 48,
      xxxl: 64,
      xxxxl: 80,
    );
  }
}

/// Type-safe radius scale using 4-point grid system.
///
/// Usage:
/// ```dart
/// BorderRadius.circular(radius.xs);
/// Container(decoration: BoxDecoration(borderRadius: radius.all(radius.md)));
/// ```
class RadiusScale {
  const RadiusScale._({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.xxxl,
  });

  final double xs; // 4
  final double sm; // 8
  final double md; // 12
  final double lg; // 16
  final double xl; // 20
  final double xxl; // 24
  final double xxxl; // 32

  /// Creates radius using 4-point grid system.
  factory RadiusScale.fourPoint() {
    return const RadiusScale._(
      xs: 4,
      sm: 8,
      md: 12,
      lg: 16,
      xl: 20,
      xxl: 24,
      xxxl: 32,
    );
  }
}

/// Extension on [RadiusScale] for creating border radius.
extension RadiusScaleExtension on RadiusScale {
  /// Creates a [Radius] from a scale value.
  Radius toRadius(double value) => Radius.circular(value);

  /// Creates a [BorderRadius] with all corners using the same radius.
  BorderRadius all(double value) => BorderRadius.circular(value);

  /// Creates a [BorderRadius] with top corners using the same radius.
  BorderRadius top(double value) => BorderRadius.vertical(top: Radius.circular(value));

  /// Creates a [BorderRadius] with bottom corners using the same radius.
  BorderRadius bottom(double value) => BorderRadius.vertical(bottom: Radius.circular(value));

  /// Creates a [BorderRadius] with left corners using the same radius.
  BorderRadius left(double value) => BorderRadius.horizontal(left: Radius.circular(value));

  /// Creates a [BorderRadius] with right corners using the same radius.
  BorderRadius right(double value) => BorderRadius.horizontal(right: Radius.circular(value));
}

/// Typography style configuration.
class _TypographyStyleConfig {
  const _TypographyStyleConfig({
    required this.sizeIndex,
    required this.lineHeightMultiplier,
    required this.letterSpacing,
    required this.fontWeight,
    this.sizeMultiplier = 1.0,
  });

  final int sizeIndex;
  final double lineHeightMultiplier;
  final double letterSpacing;
  final FontWeight fontWeight;
  final double sizeMultiplier;
}

/// Typography style with fontSize, lineHeight, letterSpacing, and fontWeight.
class TypographyStyle {
  const TypographyStyle({
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
    required this.fontWeight,
  });

  final double fontSize;
  final double lineHeight;
  final double letterSpacing;
  final FontWeight fontWeight;

  /// Creates a [TextStyle] from this typography style.
  TextStyle toTextStyle({Color? color}) {
    return TextStyle(
      fontSize: fontSize,
      height: lineHeight / fontSize,
      letterSpacing: letterSpacing,
      fontWeight: fontWeight,
      color: color,
    );
  }
}

/// Complete typography scale with all text styles.
///
/// Usage:
/// ```dart
/// Text('Display', style: typography.displayLarge.toTextStyle());
/// ```
class TypographyScale {
  const TypographyScale._({
    required this.displayLarge,
    required this.displayMedium,
    required this.displaySmall,
    required this.headlineLarge,
    required this.headlineMedium,
    required this.headlineSmall,
    required this.titleLarge,
    required this.titleMedium,
    required this.titleSmall,
    required this.bodyLarge,
    required this.bodyMedium,
    required this.bodySmall,
    required this.labelLarge,
    required this.labelMedium,
    required this.labelSmall,
  });

  final TypographyStyle displayLarge;
  final TypographyStyle displayMedium;
  final TypographyStyle displaySmall;
  final TypographyStyle headlineLarge;
  final TypographyStyle headlineMedium;
  final TypographyStyle headlineSmall;
  final TypographyStyle titleLarge;
  final TypographyStyle titleMedium;
  final TypographyStyle titleSmall;
  final TypographyStyle bodyLarge;
  final TypographyStyle bodyMedium;
  final TypographyStyle bodySmall;
  final TypographyStyle labelLarge;
  final TypographyStyle labelMedium;
  final TypographyStyle labelSmall;

  /// Typography style configurations.
  static const _styleConfigs = {
    'displayLarge': _TypographyStyleConfig(
      sizeIndex: 7,
      lineHeightMultiplier: 1.1,
      letterSpacing: -0.5,
      fontWeight: FontWeight.w300,
    ),
    'displayMedium': _TypographyStyleConfig(
      sizeIndex: 6,
      lineHeightMultiplier: 1.1,
      letterSpacing: -0.5,
      fontWeight: FontWeight.w300,
    ),
    'displaySmall': _TypographyStyleConfig(
      sizeIndex: 5,
      lineHeightMultiplier: 1.15,
      letterSpacing: -0.25,
      fontWeight: FontWeight.w400,
    ),
    'headlineLarge': _TypographyStyleConfig(
      sizeIndex: 4,
      lineHeightMultiplier: 1.2,
      letterSpacing: 0,
      fontWeight: FontWeight.w400,
    ),
    'headlineMedium': _TypographyStyleConfig(
      sizeIndex: 3,
      lineHeightMultiplier: 1.25,
      letterSpacing: 0,
      fontWeight: FontWeight.w500,
    ),
    'headlineSmall': _TypographyStyleConfig(
      sizeIndex: 2,
      lineHeightMultiplier: 1.3,
      letterSpacing: 0.15,
      fontWeight: FontWeight.w500,
    ),
    'titleLarge': _TypographyStyleConfig(
      sizeIndex: 2,
      lineHeightMultiplier: 1.4,
      letterSpacing: 0.15,
      fontWeight: FontWeight.w500,
    ),
    'titleMedium': _TypographyStyleConfig(
      sizeIndex: 1,
      lineHeightMultiplier: 1.5,
      letterSpacing: 0.1,
      fontWeight: FontWeight.w500,
    ),
    'titleSmall': _TypographyStyleConfig(
      sizeIndex: 0,
      lineHeightMultiplier: 1.5,
      letterSpacing: 0.1,
      fontWeight: FontWeight.w500,
    ),
    'bodyLarge': _TypographyStyleConfig(
      sizeIndex: 2,
      lineHeightMultiplier: 1.5,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w400,
    ),
    'bodyMedium': _TypographyStyleConfig(
      sizeIndex: 1,
      lineHeightMultiplier: 1.5,
      letterSpacing: 0.25,
      fontWeight: FontWeight.w400,
    ),
    'bodySmall': _TypographyStyleConfig(
      sizeIndex: 0,
      lineHeightMultiplier: 1.5,
      letterSpacing: 0.4,
      fontWeight: FontWeight.w400,
    ),
    'labelLarge': _TypographyStyleConfig(
      sizeIndex: 1,
      lineHeightMultiplier: 1.4,
      letterSpacing: 0.1,
      fontWeight: FontWeight.w500,
    ),
    'labelMedium': _TypographyStyleConfig(
      sizeIndex: 0,
      lineHeightMultiplier: 1.4,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w500,
    ),
    'labelSmall': _TypographyStyleConfig(
      sizeIndex: 0,
      lineHeightMultiplier: 1.4,
      letterSpacing: 0.5,
      fontWeight: FontWeight.w500,
      sizeMultiplier: 0.875,
    ),
  };

  /// Creates a typography style from configuration.
  static TypographyStyle _createStyle(
    TextScale textScale,
    _TypographyStyleConfig config,
  ) {
    final sizes = [
      textScale.xs,
      textScale.sm,
      textScale.md,
      textScale.lg,
      textScale.xl,
      textScale.xxl,
      textScale.xxxl,
      textScale.xxxxl,
    ];
    final fontSize = sizes[config.sizeIndex] * config.sizeMultiplier;
    return TypographyStyle(
      fontSize: fontSize,
      lineHeight: fontSize * config.lineHeightMultiplier,
      letterSpacing: config.letterSpacing,
      fontWeight: config.fontWeight,
    );
  }

  /// Creates a typography scale from a text scale.
  static TypographyScale _fromTextScale(TextScale textScale) {
    return TypographyScale._(
      displayLarge: _createStyle(textScale, _styleConfigs['displayLarge']!),
      displayMedium: _createStyle(textScale, _styleConfigs['displayMedium']!),
      displaySmall: _createStyle(textScale, _styleConfigs['displaySmall']!),
      headlineLarge: _createStyle(textScale, _styleConfigs['headlineLarge']!),
      headlineMedium: _createStyle(textScale, _styleConfigs['headlineMedium']!),
      headlineSmall: _createStyle(textScale, _styleConfigs['headlineSmall']!),
      titleLarge: _createStyle(textScale, _styleConfigs['titleLarge']!),
      titleMedium: _createStyle(textScale, _styleConfigs['titleMedium']!),
      titleSmall: _createStyle(textScale, _styleConfigs['titleSmall']!),
      bodyLarge: _createStyle(textScale, _styleConfigs['bodyLarge']!),
      bodyMedium: _createStyle(textScale, _styleConfigs['bodyMedium']!),
      bodySmall: _createStyle(textScale, _styleConfigs['bodySmall']!),
      labelLarge: _createStyle(textScale, _styleConfigs['labelLarge']!),
      labelMedium: _createStyle(textScale, _styleConfigs['labelMedium']!),
      labelSmall: _createStyle(textScale, _styleConfigs['labelSmall']!),
    );
  }

  /// Creates a typography scale using Major Third ratio (1.250).
  factory TypographyScale.majorThird({double base = 16}) => _fromTextScale(TextScale.majorThird(base: base));

  /// Creates a typography scale using Perfect Fourth ratio (1.333).
  factory TypographyScale.perfectFourth({double base = 16}) => _fromTextScale(TextScale.perfectFourth(base: base));

  /// Creates a typography scale using Golden Ratio (1.618).
  factory TypographyScale.goldenRatio({double base = 16}) => _fromTextScale(TextScale.goldenRatio(base: base));

  /// Converts this typography scale to Flutter's [TextTheme].
  TextTheme toTextTheme({Color? color}) {
    return TextTheme(
      displayLarge: displayLarge.toTextStyle(color: color),
      displayMedium: displayMedium.toTextStyle(color: color),
      displaySmall: displaySmall.toTextStyle(color: color),
      headlineLarge: headlineLarge.toTextStyle(color: color),
      headlineMedium: headlineMedium.toTextStyle(color: color),
      headlineSmall: headlineSmall.toTextStyle(color: color),
      titleLarge: titleLarge.toTextStyle(color: color),
      titleMedium: titleMedium.toTextStyle(color: color),
      titleSmall: titleSmall.toTextStyle(color: color),
      bodyLarge: bodyLarge.toTextStyle(color: color),
      bodyMedium: bodyMedium.toTextStyle(color: color),
      bodySmall: bodySmall.toTextStyle(color: color),
      labelLarge: labelLarge.toTextStyle(color: color),
      labelMedium: labelMedium.toTextStyle(color: color),
      labelSmall: labelSmall.toTextStyle(color: color),
    );
  }
}

/// Extension on [BuildContext] to access spacing (8-point grid).
extension ContextSpacing on BuildContext {
  /// Returns a type-safe spacing scale using 8-point grid system.
  ///
  /// Usage:
  /// ```dart
  /// SizedBox(height: context.spacing.md);
  /// Padding(padding: EdgeInsets.all(context.spacing.lg));
  /// ```
  Spacing get spacing => Spacing.eightPoint();
}

/// Extension on [BuildContext] to access text scales.
extension ContextTextScale on BuildContext {
  /// Returns a type-safe text scale using Golden Ratio (default).
  ///
  /// Usage:
  /// ```dart
  /// Text('Hello', style: TextStyle(fontSize: context.textScale.md));
  /// ```
  TextScale get textScale => TextScale.goldenRatio();

  /// Returns a type-safe text scale using Major Third ratio (1.250).
  ///
  /// Usage:
  /// ```dart
  /// Text('Hello', style: TextStyle(fontSize: context.majorThirdTextScale.xl));
  /// ```
  TextScale get majorThirdTextScale => TextScale.majorThird();

  /// Returns a type-safe text scale using Perfect Fourth ratio (1.333).
  ///
  /// Usage:
  /// ```dart
  /// Text('Hello', style: TextStyle(fontSize: context.perfectFourthTextScale.xl));
  /// ```
  TextScale get perfectFourthTextScale => TextScale.perfectFourth();
}

/// Extension on [BuildContext] to access typography scales.
extension ContextTypography on BuildContext {
  /// Returns a complete typography scale using Golden Ratio (default).
  ///
  /// Usage:
  /// ```dart
  /// Text('Display', style: context.typography.displayLarge.toTextStyle());
  /// Text('Body', style: context.typography.bodyLarge.toTextStyle());
  /// ```
  TypographyScale get typography => TypographyScale.goldenRatio(base: 10);

  /// Returns a complete typography scale using Major Third ratio (1.250).
  TypographyScale get majorThirdTypography => TypographyScale.majorThird();

  /// Returns a complete typography scale using Perfect Fourth ratio (1.333).
  TypographyScale get perfectFourthTypography => TypographyScale.perfectFourth();
  TextTheme get textTheme => Theme.of(this).textTheme;
}

/// Extension on [BuildContext] to access radius scale.
extension ContextRadius on BuildContext {
  /// Returns a type-safe radius scale using 4-point grid system.
  ///
  /// Usage:
  /// ```dart
  /// BorderRadius.circular(context.radius.md);
  /// Container(decoration: BoxDecoration(borderRadius: context.radius.all(context.radius.lg)));
  /// ```
  RadiusScale get radius => RadiusScale.fourPoint();
}
