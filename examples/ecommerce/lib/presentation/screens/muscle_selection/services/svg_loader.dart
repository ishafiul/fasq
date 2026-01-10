import 'package:ecommerce/presentation/screens/muscle_selection/services/svg_parser.dart';
import 'package:flutter/material.dart';

/// Result of loading and parsing an SVG file.
class SvgLoadResult {
  const SvgLoadResult({
    required this.svgString,
    required this.viewBox,
    required this.elements,
  });

  final String svgString;
  final SvgViewBox? viewBox;
  final List<SvgElement> elements;
}

/// Service for loading and parsing SVG files.
class SvgLoader {
  SvgLoader._();

  /// Loads an SVG file from assets and parses it.
  ///
  /// [context] - BuildContext for accessing asset bundle
  /// [svgPath] - Path to the SVG asset file
  /// [filter] - Optional filter for parsing SVG groups
  ///
  /// Returns [SvgLoadResult] with parsed data, or null if loading fails.
  static Future<SvgLoadResult?> loadAndParse({
    required BuildContext context,
    required String svgPath,
    SvgGroupFilter? filter,
  }) async {
    try {
      final svgString = await DefaultAssetBundle.of(context).loadString(svgPath);

      final viewBox = SvgParser.parseViewBox(svgString);
      final elements =
          filter != null ? SvgParser.parseGroups(svgString, filter: filter) : SvgParser.parseGroups(svgString);

      if (viewBox == null || elements.isEmpty) {
        debugPrint('Failed to parse SVG: viewBox or elements missing');
        return null;
      }

      return SvgLoadResult(
        svgString: svgString,
        viewBox: viewBox,
        elements: elements,
      );
    } catch (e) {
      debugPrint('Failed to load SVG from $svgPath: $e');
      return null;
    }
  }

  /// Loads only the SVG string from assets (without parsing).
  static Future<String?> loadString({
    required BuildContext context,
    required String svgPath,
  }) async {
    try {
      return await DefaultAssetBundle.of(context).loadString(svgPath);
    } catch (e) {
      debugPrint('Failed to load SVG string from $svgPath: $e');
      return null;
    }
  }
}
