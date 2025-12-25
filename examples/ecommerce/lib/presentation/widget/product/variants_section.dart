import 'package:ecommerce/api/models/variants.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/widgets/card.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:ecommerce/presentation/widget/product/variant_selector.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class VariantsSection extends StatelessWidget {
  const VariantsSection({
    super.key,
    required this.productId,
    this.onVariantSelected,
  });

  final String productId;
  final ValueChanged<Variants?>? onVariantSelected;

  @override
  Widget build(BuildContext context) {
    return QueryBuilder(
      queryKey: QueryKeys.productDetail(productId),
      queryFn: () => locator.get<ProductService>().getProductById(productId),
      builder: (context, productState) {
        if (productState.isLoading) {
          return ShimmerLoading(
            isLoading: true,
            child: AppCard(
              children: [
                VariantSelector(
                  variants: const [],
                  onVariantSelected: onVariantSelected,
                ),
              ],
            ),
          );
        }

        final product = productState.data;
        if (product == null) {
          return const SizedBox.shrink();
        }

        final variants = product.variants;

        return ShimmerLoading(
          isLoading: false,
          child: AppCard(
            children: [
              VariantSelector(
                variants: variants,
                onVariantSelected: onVariantSelected,
              ),
            ],
          ),
        );
      },
    );
  }
}
