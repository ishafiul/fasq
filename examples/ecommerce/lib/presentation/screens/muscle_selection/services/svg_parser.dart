import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Represents the viewBox of an SVG element.
class SvgViewBox {
  const SvgViewBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SvgViewBox &&
          runtimeType == other.runtimeType &&
          x == other.x &&
          y == other.y &&
          width == other.width &&
          height == other.height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'SvgViewBox(x: $x, y: $y, width: $width, height: $height)';
}

/// Represents a parsed SVG element with its geometric path.
class SvgElement {
  const SvgElement({
    required this.id,
    required this.path,
    this.className,
    this.attributes = const {},
  });

  /// The unique identifier of the SVG element (from `id` attribute).
  final String id;

  /// The geometric path representing the element's shape.
  final Path path;

  /// The CSS class name of the element (from `class` attribute).
  final String? className;

  /// Additional attributes of the SVG element.
  final Map<String, String> attributes;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SvgElement && runtimeType == other.runtimeType && id == other.id && className == other.className;

  @override
  int get hashCode => Object.hash(id, className);

  @override
  String toString() => 'SvgElement(id: $id, className: $className)';
}

/// Filter options for parsing SVG groups.
class SvgGroupFilter {
  const SvgGroupFilter({
    this.className,
    this.idPrefix,
    this.idSuffix,
    this.requiredAttributes = const [],
  });

  /// Filter by CSS class name (exact match).
  final String? className;

  /// Filter by ID prefix.
  final String? idPrefix;

  /// Filter by ID suffix.
  final String? idSuffix;

  /// List of attribute names that must be present.
  final List<String> requiredAttributes;

  /// Creates a filter for elements with a specific class name.
  const SvgGroupFilter.byClass(String className)
      : className = className,
        idPrefix = null,
        idSuffix = null,
        requiredAttributes = const [];

  /// Creates a filter for elements with a specific ID prefix.
  const SvgGroupFilter.byIdPrefix(String prefix)
      : className = null,
        idPrefix = prefix,
        idSuffix = null,
        requiredAttributes = const [];

  bool _matches(String id, String? className, Map<String, String> attributes) {
    if (this.className != null && className != this.className) {
      return false;
    }
    if (idPrefix != null && !id.startsWith(idPrefix!)) {
      return false;
    }
    if (idSuffix != null && !id.endsWith(idSuffix!)) {
      return false;
    }
    for (final requiredAttr in requiredAttributes) {
      if (!attributes.containsKey(requiredAttr)) {
        return false;
      }
    }
    return true;
  }
}

/// Generic SVG parser for extracting elements and their geometric paths.
class SvgParser {
  SvgParser._();

  /// Parses the viewBox attribute from an SVG string.
  static SvgViewBox? parseViewBox(String svgString) {
    final viewBoxMatch = RegExp(r'viewBox\s*=\s*"([^"]+)"').firstMatch(svgString);
    if (viewBoxMatch == null) return null;

    final values = viewBoxMatch.group(1)?.split(RegExp(r'[\s,]+')) ?? [];
    if (values.length != 4) return null;

    final x = double.tryParse(values[0]) ?? 0;
    final y = double.tryParse(values[1]) ?? 0;
    final width = double.tryParse(values[2]) ?? 0;
    final height = double.tryParse(values[3]) ?? 0;

    return SvgViewBox(x: x, y: y, width: width, height: height);
  }

  /// Parses all SVG groups from the SVG string.
  ///
  /// Returns a list of [SvgElement] objects, one for each group with an `id` attribute.
  static List<SvgElement> parseGroups(String svgString, {SvgGroupFilter? filter}) {
    final elements = <SvgElement>[];

    final groupPattern = RegExp(
      r'<g\s+([^>]*)>(.*?)</g>',
      dotAll: true,
    );

    final matches = groupPattern.allMatches(svgString);

    for (final match in matches) {
      final attributesString = match.group(1);
      final content = match.group(2);

      if (attributesString == null || content == null) continue;

      final attributes = _parseAttributes(attributesString);
      final id = attributes['id'];
      final className = attributes['class'];

      if (id == null) continue;

      if (filter != null && !filter._matches(id, className, attributes)) {
        continue;
      }

      final path = _extractPathFromGroup(content);
      if (path != null) {
        elements.add(SvgElement(
          id: id,
          path: path,
          className: className,
          attributes: attributes,
        ));
      }
    }

    return elements;
  }

  /// Parses all SVG elements (paths, ellipses, rects) with IDs from the SVG string.
  ///
  /// This method extracts individual elements, not just groups.
  /// Use [filter] to restrict which elements are parsed.
  static List<SvgElement> parseElements(String svgString, {SvgGroupFilter? filter}) {
    final elements = <SvgElement>[];

    // Parse path elements
    final pathPattern = RegExp(r'<path\s+([^>]*)>', dotAll: true);
    final pathMatches = pathPattern.allMatches(svgString);
    for (final match in pathMatches) {
      final attributesString = match.group(1);
      if (attributesString == null) continue;

      final attributes = _parseAttributes(attributesString);
      final id = attributes['id'];
      if (id == null) continue;

      if (filter != null && !filter._matches(id, attributes['class'], attributes)) {
        continue;
      }

      final pathData = attributes['d'];
      if (pathData != null) {
        final path = _parseSvgPath(pathData);
        elements.add(SvgElement(
          id: id,
          path: path,
          className: attributes['class'],
          attributes: attributes,
        ));
      }
    }

    // Parse ellipse elements
    final ellipsePattern = RegExp(r'<ellipse\s+([^>]*)>', dotAll: true);
    final ellipseMatches = ellipsePattern.allMatches(svgString);
    for (final match in ellipseMatches) {
      final attributesString = match.group(1);
      if (attributesString == null) continue;

      final attributes = _parseAttributes(attributesString);
      final id = attributes['id'];
      if (id == null) continue;

      if (filter != null && !filter._matches(id, attributes['class'], attributes)) {
        continue;
      }

      final cx = double.tryParse(attributes['cx'] ?? '') ?? 0;
      final cy = double.tryParse(attributes['cy'] ?? '') ?? 0;
      final rx = double.tryParse(attributes['rx'] ?? '') ?? 0;
      final ry = double.tryParse(attributes['ry'] ?? '') ?? 0;
      final transform = attributes['transform'];

      final path = _createEllipsePath(cx, cy, rx, ry, transform);
      elements.add(SvgElement(
        id: id,
        path: path,
        className: attributes['class'],
        attributes: attributes,
      ));
    }

    // Parse rect elements
    final rectPattern = RegExp(r'<rect\s+([^>]*)>', dotAll: true);
    final rectMatches = rectPattern.allMatches(svgString);
    for (final match in rectMatches) {
      final attributesString = match.group(1);
      if (attributesString == null) continue;

      final attributes = _parseAttributes(attributesString);
      final id = attributes['id'];
      if (id == null) continue;

      if (filter != null && !filter._matches(id, attributes['class'], attributes)) {
        continue;
      }

      final x = double.tryParse(attributes['x'] ?? '') ?? 0;
      final y = double.tryParse(attributes['y'] ?? '') ?? 0;
      final width = double.tryParse(attributes['width'] ?? '') ?? 0;
      final height = double.tryParse(attributes['height'] ?? '') ?? 0;
      final rx = double.tryParse(attributes['rx'] ?? '0') ?? 0;

      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, width, height),
          Radius.circular(rx),
        ));
      elements.add(SvgElement(
        id: id,
        path: path,
        className: attributes['class'],
        attributes: attributes,
      ));
    }

    return elements;
  }

  /// Parses attributes from an HTML/SVG attribute string.
  static Map<String, String> _parseAttributes(String attributesString) {
    final attributes = <String, String>{};
    final attrPattern = RegExp(r'(\w+)\s*=\s*"([^"]+)"');
    final matches = attrPattern.allMatches(attributesString);

    for (final match in matches) {
      final key = match.group(1);
      final value = match.group(2);
      if (key != null && value != null) {
        attributes[key] = value;
      }
    }

    return attributes;
  }

  static Path? _extractPathFromGroup(String groupContent) {
    Path? path;

    final pathPattern = RegExp(r'<path\s+[^>]*d="([^"]+)"', dotAll: true);
    final ellipsePattern = RegExp(
      r'<ellipse\s+[^>]*cx="([^"]+)"\s+cy="([^"]+)"\s+rx="([^"]+)"\s+ry="([^"]+)"[^>]*(?:transform="([^"]+)")?',
      dotAll: true,
    );
    final rectPattern = RegExp(
      r'<rect\s+[^>]*x="([^"]+)"\s+y="([^"]+)"\s+width="([^"]+)"\s+height="([^"]+)"[^>]*(?:rx="([^"]+)")?',
      dotAll: true,
    );

    final pathMatch = pathPattern.firstMatch(groupContent);
    if (pathMatch != null) {
      final pathData = pathMatch.group(1);
      if (pathData != null) {
        path = _parseSvgPath(pathData);
      }
    }

    final ellipseMatch = ellipsePattern.firstMatch(groupContent);
    if (ellipseMatch != null && path == null) {
      final cx = double.tryParse(ellipseMatch.group(1) ?? '') ?? 0;
      final cy = double.tryParse(ellipseMatch.group(2) ?? '') ?? 0;
      final rx = double.tryParse(ellipseMatch.group(3) ?? '') ?? 0;
      final ry = double.tryParse(ellipseMatch.group(4) ?? '') ?? 0;
      final transform = ellipseMatch.group(5);

      path = _createEllipsePath(cx, cy, rx, ry, transform);
    }

    final rectMatch = rectPattern.firstMatch(groupContent);
    if (rectMatch != null && path == null) {
      final x = double.tryParse(rectMatch.group(1) ?? '') ?? 0;
      final y = double.tryParse(rectMatch.group(2) ?? '') ?? 0;
      final width = double.tryParse(rectMatch.group(3) ?? '') ?? 0;
      final height = double.tryParse(rectMatch.group(4) ?? '') ?? 0;
      final rx = double.tryParse(rectMatch.group(5) ?? '0') ?? 0;

      path = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, width, height),
          Radius.circular(rx),
        ));
    }

    return path;
  }

  static Path _parseSvgPath(String pathData) {
    final path = Path();
    final numbers = RegExp(r'-?\d+\.?\d*');

    double? lastX, lastY;

    final allNumbers = numbers.allMatches(pathData).map((m) => double.tryParse(m.group(0) ?? '') ?? 0).toList();
    final commands = RegExp(r'[MLQZmlqz]').allMatches(pathData).map((m) => m.group(0)?.toUpperCase() ?? '').toList();

    int numberIndex = 0;

    for (final command in commands) {
      switch (command) {
        case 'M':
          if (numberIndex + 1 < allNumbers.length) {
            lastX = allNumbers[numberIndex];
            lastY = allNumbers[numberIndex + 1];
            path.moveTo(lastX, lastY);
            numberIndex += 2;
          }
          break;
        case 'L':
          if (numberIndex + 1 < allNumbers.length) {
            lastX = allNumbers[numberIndex];
            lastY = allNumbers[numberIndex + 1];
            path.lineTo(lastX, lastY);
            numberIndex += 2;
          }
          break;
        case 'Q':
          if (numberIndex + 3 < allNumbers.length) {
            final cx = allNumbers[numberIndex];
            final cy = allNumbers[numberIndex + 1];
            lastX = allNumbers[numberIndex + 2];
            lastY = allNumbers[numberIndex + 3];
            path.quadraticBezierTo(cx, cy, lastX, lastY);
            numberIndex += 4;
          }
          break;
        case 'Z':
          path.close();
          break;
      }
    }

    return path;
  }

  static Path _createEllipsePath(double cx, double cy, double rx, double ry, String? transform) {
    double angleDegrees = 0;

    if (transform != null) {
      final rotateMatch = RegExp(r'rotate\(([^)]+)\)').firstMatch(transform);
      if (rotateMatch != null) {
        final values = rotateMatch.group(1)?.split(RegExp(r'[\s,]+')) ?? [];
        if (values.isNotEmpty) {
          angleDegrees = double.tryParse(values[0]) ?? 0;
        }
      }
    }

    if (angleDegrees == 0) {
      return Path()..addOval(Rect.fromCenter(center: Offset(cx, cy), width: rx * 2, height: ry * 2));
    }

    final angle = angleDegrees * math.pi / 180;
    final cosA = math.cos(angle);
    final sinA = math.sin(angle);

    final path = Path();
    final halfWidth = rx;
    final halfHeight = ry;

    for (int i = 0; i <= 360; i += 5) {
      final radians = i * math.pi / 180;
      final x = halfWidth * math.cos(radians);
      final y = halfHeight * math.sin(radians);

      final rotatedX = x * cosA - y * sinA + cx;
      final rotatedY = x * sinA + y * cosA + cy;

      if (i == 0) {
        path.moveTo(rotatedX, rotatedY);
      } else {
        path.lineTo(rotatedX, rotatedY);
      }
    }
    path.close();
    return path;
  }
}

/// Extension methods for [SvgElement] collections.
extension SvgElementListExtension on List<SvgElement> {
  /// Converts a list of SVG elements to a map keyed by element ID.
  Map<String, Path> toPathMap() {
    return {for (final element in this) element.id: element.path};
  }

  /// Converts a list of SVG elements to a map keyed by element ID.
  Map<String, SvgElement> toElementMap() {
    return {for (final element in this) element.id: element};
  }

  /// Filters elements by class name.
  List<SvgElement> whereClass(String className) {
    return where((element) => element.className == className).toList();
  }

  /// Filters elements by ID prefix.
  List<SvgElement> whereIdPrefix(String prefix) {
    return where((element) => element.id.startsWith(prefix)).toList();
  }

  /// Finds an element by ID.
  SvgElement? findById(String id) {
    try {
      return firstWhere((element) => element.id == id);
    } catch (_) {
      return null;
    }
  }
}




