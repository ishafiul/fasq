import 'package:flutter/material.dart';

class NumberStepperConfig {
  const NumberStepperConfig({
    this.iconSize = 18.0,
    this.inputHeight = 40.0,
    this.borderRadiusFactor = 0.5,
    this.spacingFactor = 0.5,
    this.animationDuration = const Duration(milliseconds: 200),
    this.collapseThreshold = 0.1,
    this.expandThreshold = 0.05,
  });

  final double iconSize;
  final double inputHeight;
  final double borderRadiusFactor;
  final double spacingFactor;
  final Duration animationDuration;
  final double collapseThreshold;
  final double expandThreshold;

  double calculateInputHeight(double baseSpacing) {
    return inputHeight - (baseSpacing - 2);
  }

  EdgeInsets calculateInputPadding(double baseSpacing) {
    return EdgeInsets.symmetric(
      horizontal: baseSpacing,
      vertical: baseSpacing - 2,
    );
  }

  double calculateBorderRadius(double baseRadius) {
    return baseRadius * borderRadiusFactor;
  }

  double calculateGap(double baseSpacing) {
    return baseSpacing * spacingFactor;
  }
}
