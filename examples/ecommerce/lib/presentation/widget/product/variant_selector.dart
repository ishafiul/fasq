import 'package:ecommerce/api/models/options.dart';
import 'package:ecommerce/api/models/product_detail_response.dart';
import 'package:ecommerce/api/models/variants.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce_ui/ecommerce_ui.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class VariantSelector extends StatefulWidget {
  const VariantSelector({
    super.key,
    required this.productId,
    this.onVariantSelected,
  });

  final String productId;
  final ValueChanged<Variants?>? onVariantSelected;

  @override
  State<VariantSelector> createState() => _VariantSelectorState();
}

class _VariantSelectorState extends State<VariantSelector> {
  final Map<String, String> _selectedOptions = {};
  Variants? _selectedVariant;
  List<Variants>? _previousVariants;

  void _initializeSelection(List<Variants> variants) {
    if (variants.isEmpty) {
      if (_selectedVariant != null) {
        _selectedVariant = null;
        widget.onVariantSelected?.call(null);
      }
      return;
    }

    if (_previousVariants != null && _previousVariants!.length == variants.length) {
      final previousIds = _previousVariants!.map((v) => v.id).toSet();
      final currentIds = variants.map((v) => v.id).toSet();
      if (previousIds == currentIds) {
        return;
      }
    }

    _previousVariants = variants;

    final optionTypes = _getOptionTypes(variants);
    bool needsUpdate = false;

    for (final optionType in optionTypes) {
      final options = _getOptionsForType(variants, optionType);
      if (options.isNotEmpty && _selectedOptions[optionType] == null) {
        _selectedOptions[optionType] = options.first.optionValue;
        needsUpdate = true;
      }
    }

    if (needsUpdate || _selectedVariant == null) {
      _updateSelectedVariant(variants);
    }
  }

  List<String> _getOptionTypes(List<Variants> variants) {
    final optionTypes = <String>{};
    for (final variant in variants) {
      for (final option in variant.options) {
        optionTypes.add(option.optionType);
      }
    }
    return optionTypes.toList()..sort();
  }

  List<Options> _getOptionsForType(List<Variants> variants, String optionType) {
    final optionValues = <String>{};
    final options = <Options>[];

    for (final variant in variants) {
      for (final option in variant.options) {
        if (option.optionType == optionType && !optionValues.contains(option.optionValue)) {
          optionValues.add(option.optionValue);
          options.add(option);
        }
      }
    }

    return options;
  }

  void _onOptionChanged(List<Variants> variants, String optionType, String optionValue) {
    setState(() {
      _selectedOptions[optionType] = optionValue;
      _updateSelectedVariant(variants);
    });
  }

  void _updateSelectedVariant(List<Variants> variants) {
    Variants? matchingVariant;

    for (final variant in variants) {
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
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          widget.onVariantSelected?.call(_selectedVariant);
        }
      });
    }
  }

  bool _isVariantAvailable(Variants variant) {
    return variant.inventoryQuantity > 0;
  }

  Variants? _findVariantWithOption(List<Variants> variants, String optionType, String optionValue) {
    for (final variant in variants) {
      final hasOption = variant.options.any(
        (option) => option.optionType == optionType && option.optionValue == optionValue,
      );
      if (hasOption) {
        return variant;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: QueryBuilder<ProductDetailResponse>(
        queryKey: QueryKeys.productDetail(widget.productId),
        queryFn: () => locator.get<ProductService>().getProductById(widget.productId),
        builder: (context, productState) {
          if (productState.hasError) {
            return const SizedBox.shrink();
          }

          final variants = productState.data?.variants ?? [];
          final isLoading = productState.isLoading;

          if (variants.isEmpty && !isLoading) {
            return const SizedBox.shrink();
          }

          if (variants.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _initializeSelection(variants);
              }
            });
          }

          final optionTypes = _getOptionTypes(variants);
          if (optionTypes.isEmpty && !isLoading) {
            return const SizedBox.shrink();
          }

          return _VariantSelectorContent(
            variants: variants,
            selectedOptions: _selectedOptions,
            selectedVariant: _selectedVariant,
            optionTypes: optionTypes,
            isLoading: isLoading,
            onOptionChanged: (optionType, optionValue) => _onOptionChanged(variants, optionType, optionValue),
            findVariantWithOption: (optionType, optionValue) =>
                _findVariantWithOption(variants, optionType, optionValue),
            isVariantAvailable: _isVariantAvailable,
          );
        },
      ),
    );
  }
}

class _VariantSelectorContent extends StatelessWidget {
  const _VariantSelectorContent({
    required this.variants,
    required this.selectedOptions,
    required this.selectedVariant,
    required this.optionTypes,
    required this.isLoading,
    required this.onOptionChanged,
    required this.findVariantWithOption,
    required this.isVariantAvailable,
  });

  final List<Variants> variants;
  final Map<String, String> selectedOptions;
  final Variants? selectedVariant;
  final List<String> optionTypes;
  final bool isLoading;
  final void Function(String, String) onOptionChanged;
  final Variants? Function(String, String) findVariantWithOption;
  final bool Function(Variants) isVariantAvailable;

  List<Options> _getOptionsForType(String optionType) {
    final optionValues = <String>{};
    final options = <Options>[];

    for (final variant in variants) {
      for (final option in variant.options) {
        if (option.optionType == optionType && !optionValues.contains(option.optionValue)) {
          optionValues.add(option.optionValue);
          options.add(option);
        }
      }
    }

    return options;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final optionType in optionTypes) ...[
          if (optionTypes.indexOf(optionType) > 0) SizedBox(height: spacing.sm),
          ShimmerLoading.text(
            isLoading: isLoading,
            child: Text(
              optionType,
              style: typography.bodyMedium
                  .toTextStyle(
                    color: palette.textPrimary,
                  )
                  .copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          SizedBox(height: spacing.xs),
          _OptionSelector(
            optionType: optionType,
            options: _getOptionsForType(optionType),
            selectedValue: selectedOptions[optionType] ?? '',
            isLoading: isLoading,
            onValueChanged: (value) => onOptionChanged(optionType, value),
            findVariantWithOption: findVariantWithOption,
            isVariantAvailable: isVariantAvailable,
          ),
        ],
        SizedBox(height: spacing.sm),
        _VariantInfo(
          variant: selectedVariant,
          isLoading: isLoading,
        ),
      ],
    );
  }
}

class _OptionSelector extends StatelessWidget {
  const _OptionSelector({
    required this.optionType,
    required this.options,
    required this.selectedValue,
    required this.isLoading,
    required this.onValueChanged,
    required this.findVariantWithOption,
    required this.isVariantAvailable,
  });

  final String optionType;
  final List<Options> options;
  final String selectedValue;
  final bool isLoading;
  final void Function(String) onValueChanged;
  final Variants? Function(String, String) findVariantWithOption;
  final bool Function(Variants) isVariantAvailable;

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    final availableOptions = <String>[];
    final unavailableOptions = <String>[];

    for (final option in options) {
      final variant = findVariantWithOption(optionType, option.optionValue);
      if (variant != null && isVariantAvailable(variant)) {
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
          child: Text(
            optionValue,
            style: typography.bodyMedium.toTextStyle(),
          ),
        ),
      );
    }

    for (final optionValue in unavailableOptions) {
      segmentedOptions.add(
        SegmentedOption<String>(
          value: optionValue,
          child: Text(
            optionValue,
            style: typography.bodyMedium.toTextStyle(),
          ),
          disabled: true,
        ),
      );
    }

    if (segmentedOptions.isEmpty && !isLoading) {
      return const SizedBox.shrink();
    }

    return ShimmerLoading(
      isLoading: isLoading,
      child: Segmented<String>(
        value: selectedValue,
        onValueChanged: isLoading ? null : onValueChanged,
        options: segmentedOptions,
        block: true,
      ),
    );
  }
}

class _VariantInfo extends StatelessWidget {
  const _VariantInfo({
    required this.variant,
    required this.isLoading,
  });

  final Variants? variant;
  final bool isLoading;

  bool _isVariantAvailable(Variants variant) {
    return variant.inventoryQuantity > 0;
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    if (variant == null) {
      return ShimmerLoading(
        isLoading: isLoading,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(
            horizontal: spacing.sm,
            vertical: spacing.xs,
          ),
          decoration: BoxDecoration(
            color: palette.surface,
            borderRadius: BorderRadius.circular(context.radius.sm),
            border: Border.all(color: palette.border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline_rounded,
                color: palette.textSecondary,
                size: 16,
              ),
              SizedBox(width: spacing.xs),
              Text(
                'Variant not available',
                style: typography.bodySmall.toTextStyle(color: palette.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final currentVariant = variant!;
    final price = double.tryParse(currentVariant.price) ?? 0;
    final compareAtPrice = currentVariant.compareAtPrice != null && currentVariant.compareAtPrice!.isNotEmpty
        ? double.tryParse(currentVariant.compareAtPrice!)
        : null;
    final hasDiscount = compareAtPrice != null && compareAtPrice > price;
    final isInStock = _isVariantAvailable(currentVariant);

    return ShimmerLoading(
      isLoading: isLoading,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs,
        ),
        decoration: BoxDecoration(
          color: palette.surface,
          borderRadius: BorderRadius.circular(context.radius.sm),
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
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShimmerLoading.text(
                        isLoading: isLoading,
                        child: Text(
                          currentVariant.name,
                          style: typography.bodyMedium
                              .toTextStyle(
                                color: palette.textPrimary,
                              )
                              .copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      SizedBox(height: spacing.xs / 2),
                      Row(
                        children: [
                          ShimmerLoading.text(
                            isLoading: isLoading,
                            child: Text(
                              '\$${price.toStringAsFixed(2)}',
                              style: typography.titleMedium
                                  .toTextStyle(
                                    color: palette.brand,
                                  )
                                  .copyWith(
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                          if (hasDiscount) ...[
                            SizedBox(width: spacing.xs),
                            ShimmerLoading.text(
                              isLoading: isLoading,
                              child: Text(
                                '\$${compareAtPrice.toStringAsFixed(2)}',
                                style: typography.bodySmall
                                    .toTextStyle(
                                      color: palette.textSecondary,
                                    )
                                    .copyWith(
                                      decoration: TextDecoration.lineThrough,
                                      decorationColor: palette.textSecondary,
                                    ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: spacing.xs),
                ShimmerLoading(
                  isLoading: isLoading,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.xs,
                      vertical: spacing.xs / 2,
                    ),
                    decoration: BoxDecoration(
                      color: isInStock ? palette.success.withValues(alpha: 0.1) : palette.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(context.radius.xs),
                    ),
                    child: Text(
                      isInStock ? 'In Stock' : 'Out of Stock',
                      style: typography.labelSmall
                          .toTextStyle(
                            color: isInStock ? palette.success : palette.danger,
                          )
                          .copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            if (currentVariant.inventoryQuantity > 0 &&
                currentVariant.inventoryQuantity <= currentVariant.lowStockThreshold.toDouble()) ...[
              SizedBox(height: spacing.xs),
              ShimmerLoading(
                isLoading: isLoading,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: spacing.xs,
                    vertical: spacing.xs / 2,
                  ),
                  decoration: BoxDecoration(
                    color: palette.warning.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(context.radius.xs),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        size: 14,
                        color: palette.warning,
                      ),
                      SizedBox(width: spacing.xs / 2),
                      Text(
                        'Only ${currentVariant.inventoryQuantity.toInt()} left',
                        style: typography.labelSmall
                            .toTextStyle(
                              color: palette.warning,
                            )
                            .copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
