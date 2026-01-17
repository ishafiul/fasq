import 'package:ecommerce_ui/src/widgets/number_stepper/components/compact.dart';
import 'package:flutter/material.dart';

/// Calculates the position of the popover menu based on direction.
/// Follows Single Responsibility Principle - only handles positioning.
class PopoverPositionCalculator {
  const PopoverPositionCalculator._();

  /// Calculates the RelativeRect for the popover menu.
  static RelativeRect calculate({
    required Offset anchorOffset,
    required Size anchorSize,
    required PopoverDirection direction,
  }) {
    return switch (direction) {
      PopoverDirection.bottom => RelativeRect.fromLTRB(
          anchorOffset.dx,
          anchorOffset.dy - 7,
          anchorOffset.dx,
          anchorOffset.dx - 80,
        ),
      PopoverDirection.top => RelativeRect.fromLTRB(
          anchorOffset.dx,
          anchorOffset.dy - 90,
          anchorOffset.dx,
          anchorOffset.dx,
        ),
      PopoverDirection.left => RelativeRect.fromLTRB(
          anchorOffset.dx - 80,
          anchorOffset.dy - 7,
          anchorOffset.dx,
          anchorOffset.dy,
        ),
      PopoverDirection.right => RelativeRect.fromLTRB(
          anchorOffset.dx,
          anchorOffset.dy - 7,
          anchorOffset.dx,
          anchorOffset.dy,
        ),
    };
  }
}
