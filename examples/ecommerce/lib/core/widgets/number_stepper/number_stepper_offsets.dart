import 'package:flutter/material.dart';
import 'package:ecommerce/core/widgets/number_stepper/number_stepper_controller.dart';

class NumberStepperOffsetCalculator {
  NumberStepperOffsetCalculator({
    required this.direction,
    required this.gap,
  });

  final NumberStepperExpandDirection direction;
  final double gap;

  ({Offset minus, Offset number, Offset plus}) computeOffsets({
    required double t,
    required double numberW,
    required double numberH,
    required Size minusSize,
    required Size plusSize,
  }) {
    final minusW = minusSize.width > 0 ? minusSize.width : 32.0;
    final minusH = minusSize.height > 0 ? minusSize.height : 32.0;
    final plusW = plusSize.width > 0 ? plusSize.width : 32.0;
    final plusH = plusSize.height > 0 ? plusSize.height : 32.0;

    return switch (direction) {
      NumberStepperExpandDirection.left => (
          plus: Offset.zero,
          number: Offset(-(plusW / 2 + gap + numberW / 2) * t, 0),
          minus: Offset(-(plusW / 2 + gap + numberW + gap + minusW / 2) * t, 0),
        ),
      NumberStepperExpandDirection.right => (
          minus: Offset.zero,
          number: Offset((minusW / 2 + gap + numberW / 2) * t, 0),
          plus: Offset((minusW / 2 + gap + numberW + gap + plusW / 2) * t, 0),
        ),
      NumberStepperExpandDirection.top => (
          minus: Offset.zero,
          number: Offset(0, -(minusH / 2 + gap + numberH / 2) * t),
          plus: Offset(0, -(minusH / 2 + gap + numberH + gap + plusH / 2) * t),
        ),
      NumberStepperExpandDirection.bottom => (
          plus: Offset.zero,
          number: Offset(0, (plusH / 2 + gap + numberH / 2) * t),
          minus: Offset(0, (plusH / 2 + gap + numberH + gap + minusH / 2) * t),
        ),
      NumberStepperExpandDirection.centerHorizontal => (
          minus: Offset(-(numberW / 2 + gap + minusW / 2) * t, 0),
          number: Offset.zero,
          plus: Offset((numberW / 2 + gap + plusW / 2) * t, 0),
        ),
      NumberStepperExpandDirection.centerVertical => (
          plus: Offset(0, -(numberH / 2 + gap + plusH / 2) * t),
          number: Offset.zero,
          minus: Offset(0, (numberH / 2 + gap + minusH / 2) * t),
        ),
    };
  }
}
