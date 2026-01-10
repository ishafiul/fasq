import 'package:ecommerce/presentation/screens/muscle_selection/services/svg_coordinate_transformer.dart';
import 'package:ecommerce/presentation/screens/muscle_selection/services/svg_parser.dart';
import 'package:flutter/material.dart';

/// Result of tap detection.
class SvgTapDetectionResult {
  const SvgTapDetectionResult({
    required this.elementId,
    required this.position,
  });

  final String elementId;
  final Offset position;
}

/// Service for detecting which SVG element was tapped.
class SvgTapDetector {
  SvgTapDetector._();

  /// Detects which element was tapped at the given position.
  ///
  /// [globalPosition] - Tap position in global screen coordinates
  /// [viewerRenderBox] - RenderBox of the InteractiveViewer viewport
  /// [svgRenderBox] - RenderBox of the SvgPicture widget
  /// [transformation] - Transformation matrix from InteractiveViewer
  /// [viewBox] - SVG viewBox definition
  /// [elementMap] - Map of element IDs to their paths
  ///
  /// Returns [SvgTapDetectionResult] with element ID and position, or null if no element was tapped.
  static SvgTapDetectionResult? detectTappedElement({
    required Offset globalPosition,
    required RenderBox viewerRenderBox,
    required RenderBox svgRenderBox,
    required Matrix4 transformation,
    required SvgViewBox viewBox,
    required Map<String, Path> elementMap,
  }) {
    final svgPosition = SvgCoordinateTransformer.transformToSvgCoordinates(
      globalPosition: globalPosition,
      viewerRenderBox: viewerRenderBox,
      svgRenderBox: svgRenderBox,
      transformation: transformation,
      viewBox: viewBox,
    );

    if (svgPosition == null) return null;

    final elementId = _findElementAtPosition(svgPosition, elementMap);
    if (elementId == null) return null;

    return SvgTapDetectionResult(
      elementId: elementId,
      position: svgPosition,
    );
  }

  static String? _findElementAtPosition(Offset position, Map<String, Path> elementMap) {
    for (final entry in elementMap.entries) {
      if (entry.value.contains(position)) {
        return entry.key;
      }
    }
    return null;
  }
}
