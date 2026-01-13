import 'package:ecommerce/api/models/product_detail_response.dart';
import 'package:ecommerce/api/models/variants.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:ecommerce/presentation/widget/product/variant_selector.dart';
import 'package:flutter/material.dart';

class VariantsSection extends StatelessWidget {
  const VariantsSection({
    super.key,
    required this.product,
    this.isLoading = false,
    this.onVariantSelected,
  });

  final ProductDetailResponse? product;
  final bool isLoading;
  final ValueChanged<Variants?>? onVariantSelected;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return ShimmerLoading(
        isLoading: true,
        child: VariantSelector(
          variants: const [],
          onVariantSelected: onVariantSelected,
        ),
      );
    }

    if (product == null) {
      return const SizedBox.shrink();
    }

    final variants = product!.variants;

    return ShimmerLoading(
      isLoading: false,
      child: VariantSelector(
        variants: variants,
        onVariantSelected: onVariantSelected,
      ),
    );
  }
}
