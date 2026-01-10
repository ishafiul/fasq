/// Service for applying styles to SVG strings based on element selection state.
class SvgStyleApplier {
  SvgStyleApplier._();

  /// Applies fill colors to SVG elements based on their selection state.
  ///
  /// [svgString] - Original SVG string
  /// [selectedIds] - Set of selected element IDs
  /// [allIds] - Set of all element IDs that should be styled
  /// [className] - CSS class name to match
  /// [selectedFillColor] - Fill color for selected elements
  /// [unselectedFillColor] - Fill color for unselected elements
  ///
  /// Returns the modified SVG string with updated fill colors.
  static String applySelectionStyles({
    required String svgString,
    required Set<String> selectedIds,
    required Iterable<String> allIds,
    required String className,
    required String selectedFillColor,
    required String unselectedFillColor,
  }) {
    String modified = svgString;

    for (final id in selectedIds) {
      modified = modified.replaceAll(
        'id="$id" class="$className" fill="$unselectedFillColor"',
        'id="$id" class="$className" fill="$selectedFillColor"',
      );
    }

    for (final id in allIds) {
      if (!selectedIds.contains(id)) {
        modified = modified.replaceAll(
          'id="$id" class="$className" fill="$selectedFillColor"',
          'id="$id" class="$className" fill="$unselectedFillColor"',
        );
      }
    }

    return modified;
  }
}
