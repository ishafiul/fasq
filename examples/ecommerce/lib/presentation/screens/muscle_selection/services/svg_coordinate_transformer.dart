import 'package:ecommerce/presentation/screens/muscle_selection/services/svg_parser.dart';
import 'package:flutter/material.dart';

/// Service for transforming coordinates between different coordinate systems.
///
/// Handles conversion between:
/// - Global screen coordinates
/// - InteractiveViewer viewport coordinates
/// - SvgPicture widget coordinates (after transformation)
/// - SVG viewBox coordinates
class SvgCoordinateTransformer {
  SvgCoordinateTransformer._();

  /// Transforms a global tap position to SVG viewBox coordinates.
  ///
  /// [globalPosition] - Tap position in global screen coordinates
  /// [viewerRenderBox] - RenderBox of the InteractiveViewer viewport
  /// [svgRenderBox] - RenderBox of the SvgPicture widget
  /// [transformation] - Transformation matrix from InteractiveViewer
  /// [viewBox] - SVG viewBox definition
  ///
  /// Returns the position in SVG viewBox coordinate space, or null if invalid.
  static Offset? transformToSvgCoordinates({
    required Offset globalPosition,
    required RenderBox viewerRenderBox,
    required RenderBox svgRenderBox,
    required Matrix4 transformation,
    required SvgViewBox viewBox,
  }) {
    final svgSize = svgRenderBox.size;
    final viewerLocalPosition = viewerRenderBox.globalToLocal(globalPosition);

    final invertedMatrix = Matrix4.inverted(transformation);
    final childPosition = MatrixUtils.transformPoint(invertedMatrix, viewerLocalPosition);

    final svgAspectRatio = viewBox.width / viewBox.height;
    final widgetAspectRatio = svgSize.width / svgSize.height;

    final scaleInfo = _calculateBoxFitScale(
      svgAspectRatio: svgAspectRatio,
      widgetAspectRatio: widgetAspectRatio,
      svgSize: svgSize,
      viewBox: viewBox,
    );

    final adjustedX = childPosition.dx - scaleInfo.offsetX;
    final adjustedY = childPosition.dy - scaleInfo.offsetY;

    if (adjustedX < 0 || adjustedY < 0) return null;

    final svgX = adjustedX / scaleInfo.scale;
    final svgY = adjustedY / scaleInfo.scale;

    if (svgX < 0 || svgX > viewBox.width || svgY < 0 || svgY > viewBox.height) {
      return null;
    }

    return Offset(svgX, svgY);
  }

  static _ScaleInfo _calculateBoxFitScale({
    required double svgAspectRatio,
    required double widgetAspectRatio,
    required Size svgSize,
    required SvgViewBox viewBox,
  }) {
    double scale;
    double offsetX = 0;
    double offsetY = 0;

    if (svgAspectRatio > widgetAspectRatio) {
      scale = svgSize.width / viewBox.width;
      final scaledHeight = viewBox.height * scale;
      offsetY = (svgSize.height - scaledHeight) / 2;
    } else {
      scale = svgSize.height / viewBox.height;
      final scaledWidth = viewBox.width * scale;
      offsetX = (svgSize.width - scaledWidth) / 2;
    }

    return _ScaleInfo(scale: scale, offsetX: offsetX, offsetY: offsetY);
  }
}

class _ScaleInfo {
  const _ScaleInfo({
    required this.scale,
    required this.offsetX,
    required this.offsetY,
  });

  final double scale;
  final double offsetX;
  final double offsetY;
}
