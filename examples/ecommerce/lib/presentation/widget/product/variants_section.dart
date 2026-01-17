import 'package:ecommerce/api/models/product_detail_response.dart';
import 'package:ecommerce/api/models/variants.dart';
import 'package:ecommerce/presentation/widget/product/variant_selector.dart';
import 'package:ecommerce_ui/ecommerce_ui.dart';
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
          onVariantSelected: onVariantSelected,
          productId: '',
        ),
      );
    }

    if (product == null) {
      return const SizedBox.shrink();
    }

    return ShimmerLoading(
      isLoading: false,
      child: VariantSelector(
        onVariantSelected: onVariantSelected,
        productId: '',
      ),
    );
  }
}
