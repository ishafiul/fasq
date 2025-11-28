import 'package:ecommerce/api/models/options.dart';
import 'package:ecommerce/api/models/variants.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/segmented.dart';
import 'package:flutter/material.dart';

class VariantSelector extends StatefulWidget {
  const VariantSelector({
    super.key,
    required this.variants,
    this.onVariantSelected,
  });

  final List<Variants> variants;
  final ValueChanged<Variants?>? onVariantSelected;

  @override
  State<VariantSelector> createState() => _VariantSelectorState();
}

class _VariantSelectorState extends State<VariantSelector> {
  final Map<String, String> _selectedOptions = {};
  Variants? _selectedVariant;

  @override
  void initState() {
    super.initState();
    _initializeSelection();
  }

  void _initializeSelection() {
    if (widget.variants.isEmpty) return;

    final optionTypes = _getOptionTypes();
    for (final optionType in optionTypes) {
      final options = _getOptionsForType(optionType);
      if (options.isNotEmpty && _selectedOptions[optionType] == null) {
        _selectedOptions[optionType] = options.first.optionValue;
      }
    }

    _updateSelectedVariant();
  }

  List<String> _getOptionTypes() {
    final optionTypes = <String>{};
    for (final variant in widget.variants) {
      for (final option in variant.options) {
        optionTypes.add(option.optionType);
      }
    }
    return optionTypes.toList()..sort();
  }

  List<Options> _getOptionsForType(String optionType) {
    final optionValues = <String>{};
    final options = <Options>[];

    for (final variant in widget.variants) {
      for (final option in variant.options) {
        if (option.optionType == optionType && !optionValues.contains(option.optionValue)) {
          optionValues.add(option.optionValue);
          options.add(option);
        }
      }
    }

    return options;
  }

  void _onOptionChanged(String optionType, String optionValue) {
    setState(() {
      _selectedOptions[optionType] = optionValue;
      _updateSelectedVariant();
    });
  }

  void _updateSelectedVariant() {
    Variants? matchingVariant;

    for (final variant in widget.variants) {
      bool matches = true;
      for (final entry in _selectedOptions.entries) {
        final optionType = entry.key;
        final optionValue = entry.value;

        final hasMatchingOption = variant.options.any(
          (option) => option.optionType == optionType && option.optionValue == optionValue,
        );

        if (!hasMatchingOption) {
          matches = false;
          break;
        }
      }

      if (matches) {
        matchingVariant = variant;
        break;
      }
    }

    if (_selectedVariant?.id != matchingVariant?.id) {
      _selectedVariant = matchingVariant;
      widget.onVariantSelected?.call(_selectedVariant);
    }
  }

  bool _isVariantAvailable(Variants variant) {
    return variant.inventoryQuantity > 0;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    if (widget.variants.isEmpty) {
      return const SizedBox.shrink();
    }

    final optionTypes = _getOptionTypes();
    if (optionTypes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final optionType in optionTypes) ...[
          SizedBox(height: spacing.md),
          Text(
            optionType,
            style: typography.labelMedium.toTextStyle(color: palette.textPrimary),
          ),
          SizedBox(height: spacing.xs),
          _buildOptionSelector(optionType),
        ],
        if (_selectedVariant != null) ...[
          SizedBox(height: spacing.md),
          _buildVariantInfo(),
        ],
      ],
    );
  }

  Widget _buildOptionSelector(String optionType) {
    final options = _getOptionsForType(optionType);
    final selectedValue = _selectedOptions[optionType] ?? '';

    final availableOptions = <String>[];
    final unavailableOptions = <String>[];

    for (final option in options) {
      final variant = _findVariantWithOption(optionType, option.optionValue);
      if (variant != null && _isVariantAvailable(variant)) {
        availableOptions.add(option.optionValue);
      } else {
        unavailableOptions.add(option.optionValue);
      }
    }

    final segmentedOptions = <SegmentedOption<String>>[];

    for (final optionValue in availableOptions) {
      segmentedOptions.add(
        SegmentedOption<String>(
          value: optionValue,
          child: Text(optionValue),
        ),
      );
    }

    for (final optionValue in unavailableOptions) {
      segmentedOptions.add(
        SegmentedOption<String>(
          value: optionValue,
          child: Text(optionValue),
          disabled: true,
        ),
      );
    }

    if (segmentedOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Segmented<String>(
      value: selectedValue,
      onValueChanged: (value) => _onOptionChanged(optionType, value),
      options: segmentedOptions,
    );
  }

  Variants? _findVariantWithOption(String optionType, String optionValue) {
    for (final variant in widget.variants) {
      final hasOption = variant.options.any(
        (option) => option.optionType == optionType && option.optionValue == optionValue,
      );
      if (hasOption) {
        return variant;
      }
    }
    return null;
  }

  Widget _buildVariantInfo() {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    if (_selectedVariant == null) return const SizedBox.shrink();

    final variant = _selectedVariant!;
    final price = double.tryParse(variant.price) ?? 0;
    final compareAtPrice = variant.compareAtPrice != null && variant.compareAtPrice!.isNotEmpty
        ? double.tryParse(variant.compareAtPrice!)
        : null;
    final hasDiscount = compareAtPrice != null && compareAtPrice > price;
    final isInStock = _isVariantAvailable(variant);

    return Container(
      padding: EdgeInsets.all(spacing.md),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variant.name,
                      style: typography.titleSmall.toTextStyle(color: palette.textPrimary),
                    ),
                    SizedBox(height: spacing.xs / 2),
                    Row(
                      children: [
                        Text(
                          '\$${price.toStringAsFixed(2)}',
                          style: typography.titleSmall.toTextStyle(color: palette.textPrimary).copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                        if (hasDiscount) ...[
                          SizedBox(width: spacing.xs),
                          Text(
                            '\$${compareAtPrice.toStringAsFixed(2)}',
                            style: typography.bodySmall.toTextStyle(color: palette.textSecondary).copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  decorationColor: palette.textSecondary,
                                ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isInStock)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xs / 2),
                  decoration: BoxDecoration(
                    color: palette.success.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'In Stock',
                    style: typography.labelSmall.toTextStyle(color: palette.success),
                  ),
                )
              else
                Container(
                  padding: EdgeInsets.symmetric(horizontal: spacing.xs, vertical: spacing.xs / 2),
                  decoration: BoxDecoration(
                    color: palette.danger.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Out of Stock',
                    style: typography.labelSmall.toTextStyle(color: palette.danger),
                  ),
                ),
            ],
          ),
          if (variant.inventoryQuantity > 0 && variant.inventoryQuantity <= variant.lowStockThreshold.toDouble()) ...[
            SizedBox(height: spacing.xs),
            Text(
              'Only ${variant.inventoryQuantity.toInt()} left in stock',
              style: typography.labelSmall.toTextStyle(color: palette.warning),
            ),
          ],
        ],
      ),
    );
  }
}
