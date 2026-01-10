import 'package:ecommerce/presentation/screens/muscle_selection/services/svg_parser.dart';
import 'package:ecommerce/presentation/screens/muscle_selection/services/svg_tap_detector.dart';
import 'package:flutter/material.dart';

/// Event emitted when an SVG element is tapped.
class SvgTapEvent {
  const SvgTapEvent({
    required this.elementId,
    required this.position,
    required this.element,
  });

  /// The ID of the tapped element.
  final String elementId;

  /// The position in SVG coordinate space where the tap occurred.
  final Offset position;

  /// The SVG element that was tapped.
  final SvgElement element;
}

/// Controller for managing SVG element selection state.
///
/// This controller is responsible only for state management (selection state).
/// Tap detection and coordinate transformation are handled by separate services.
///
/// Example:
/// ```dart
/// final controller = SvgInteractionController(
///   elements: svgElements,
///   viewBox: svgViewBox,
///   onElementTapped: (event) {
///     print('Tapped: ${event.elementId}');
///   },
/// );
/// ```
class SvgInteractionController extends ChangeNotifier {
  SvgInteractionController({
    required List<SvgElement> elements,
    required SvgViewBox? viewBox,
    this.onElementTapped,
    this.onElementSelected,
    this.onElementDeselected,
    Set<String>? initialSelectedIds,
  })  : _elements = elements,
        _viewBox = viewBox,
        _selectedIds = initialSelectedIds ?? <String>{},
        _elementMap = {for (final element in elements) element.id: element},
        _pathMap = {for (final element in elements) element.id: element.path};

  final List<SvgElement> _elements;
  SvgViewBox? _viewBox;
  final Set<String> _selectedIds;
  final Map<String, SvgElement> _elementMap;
  final Map<String, Path> _pathMap;

  /// Callback fired when an element is tapped.
  final void Function(SvgTapEvent event)? onElementTapped;

  /// Callback fired when an element is selected.
  final void Function(String elementId)? onElementSelected;

  /// Callback fired when an element is deselected.
  final void Function(String elementId)? onElementDeselected;

  /// All SVG elements.
  List<SvgElement> get elements => List.unmodifiable(_elements);

  /// The SVG viewBox.
  SvgViewBox? get viewBox => _viewBox;

  /// Currently selected element IDs.
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);

  /// Map of element IDs to elements.
  Map<String, SvgElement> get elementMap => Map.unmodifiable(_elementMap);

  /// Map of element IDs to paths.
  Map<String, Path> get pathMap => Map.unmodifiable(_pathMap);

  /// Whether an element is selected.
  bool isSelected(String elementId) => _selectedIds.contains(elementId);

  /// Get an element by ID.
  SvgElement? getElementById(String elementId) => _elementMap[elementId];

  /// Select an element.
  void selectElement(String elementId) {
    if (!_elementMap.containsKey(elementId)) return;
    if (_selectedIds.contains(elementId)) return;

    _selectedIds.add(elementId);
    notifyListeners();
    onElementSelected?.call(elementId);
  }

  /// Deselect an element.
  void deselectElement(String elementId) {
    if (!_selectedIds.contains(elementId)) return;

    _selectedIds.remove(elementId);
    notifyListeners();
    onElementDeselected?.call(elementId);
  }

  /// Toggle element selection.
  void toggleElement(String elementId) {
    if (isSelected(elementId)) {
      deselectElement(elementId);
    } else {
      selectElement(elementId);
    }
  }

  /// Select multiple elements.
  void selectElements(Iterable<String> elementIds) {
    bool changed = false;
    for (final id in elementIds) {
      if (_elementMap.containsKey(id) && !_selectedIds.contains(id)) {
        _selectedIds.add(id);
        changed = true;
        onElementSelected?.call(id);
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Deselect multiple elements.
  void deselectElements(Iterable<String> elementIds) {
    bool changed = false;
    for (final id in elementIds) {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        changed = true;
        onElementDeselected?.call(id);
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Clear all selections.
  void clearSelection() {
    if (_selectedIds.isEmpty) return;

    final ids = List<String>.from(_selectedIds);
    _selectedIds.clear();
    notifyListeners();
    for (final id in ids) {
      onElementDeselected?.call(id);
    }
  }

  /// Update the SVG elements and viewBox.
  void updateSvg({
    List<SvgElement>? elements,
    SvgViewBox? viewBox,
  }) {
    bool changed = false;

    if (elements != null) {
      _elements.clear();
      _elements.addAll(elements);
      _elementMap.clear();
      _elementMap.addAll({for (final element in elements) element.id: element});
      _pathMap.clear();
      _pathMap.addAll({for (final element in elements) element.id: element.path});
      changed = true;
    }

    if (viewBox != null && _viewBox != viewBox) {
      _viewBox = viewBox;
      changed = true;
    }

    if (changed) {
      notifyListeners();
    }
  }

  /// Handle a tap event and detect which element was tapped.
  ///
  /// Uses [SvgTapDetector] service for tap detection.
  /// Returns the tapped element ID, or null if no element was tapped.
  String? handleTap({
    required Offset globalPosition,
    required RenderBox viewerRenderBox,
    required RenderBox svgRenderBox,
    required Matrix4 transformation,
  }) {
    if (_viewBox == null) return null;

    final result = SvgTapDetector.detectTappedElement(
      globalPosition: globalPosition,
      viewerRenderBox: viewerRenderBox,
      svgRenderBox: svgRenderBox,
      transformation: transformation,
      viewBox: _viewBox!,
      elementMap: _pathMap,
    );

    if (result != null) {
      final element = _elementMap[result.elementId];
      if (element != null) {
        onElementTapped?.call(SvgTapEvent(
          elementId: result.elementId,
          position: result.position,
          element: element,
        ));
      }
      return result.elementId;
    }

    return null;
  }
}
