import 'package:ecommerce/core/widgets/number_stepper/number_stepper_controller.dart';
import 'package:flutter/material.dart';

class DirectionMenu extends StatelessWidget {
  const DirectionMenu({
    super.key,
    required this.onSelected,
  });

  final ValueChanged<NumberStepperExpandDirection> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<NumberStepperExpandDirection>(
      padding: EdgeInsets.zero,
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: NumberStepperExpandDirection.left,
          child: Text('left'),
        ),
        PopupMenuItem(
          value: NumberStepperExpandDirection.right,
          child: Text('right'),
        ),
        PopupMenuItem(
          value: NumberStepperExpandDirection.top,
          child: Text('top'),
        ),
        PopupMenuItem(
          value: NumberStepperExpandDirection.bottom,
          child: Text('bottom'),
        ),
        PopupMenuItem(
          value: NumberStepperExpandDirection.centerHorizontal,
          child: Text('centerHorizontal'),
        ),
        PopupMenuItem(
          value: NumberStepperExpandDirection.centerVertical,
          child: Text('centerVertical'),
        ),
      ],
      child: const SizedBox(
        width: 24,
        height: 24,
        child: Icon(Icons.tune, size: 18),
      ),
    );
  }
}
