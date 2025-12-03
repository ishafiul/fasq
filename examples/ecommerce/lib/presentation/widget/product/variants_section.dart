import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:ecommerce/presentation/widget/product/variant_selector.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class VariantsSection extends StatelessWidget {
  const VariantsSection({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final typography = context.typography;
    final palette = context.palette;

    return QueryBuilder(
      queryKey: QueryKeys.productDetail(productId),
      queryFn: () => locator.get<ProductService>().getProductById(productId),
      builder: (context, productState) {
        if (productState.data == null) {
          return Text("data");
        }
        return ShimmerLoading(
          isLoading: productState.isLoading,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Variants',
                style: typography.titleSmall.toTextStyle(color: palette.textPrimary),
              ),
              SizedBox(height: spacing.sm),
              ShimmerLoading(
                isLoading: productState.isLoading,
                child: VariantSelector(
                  variants: productState.data!.variants,
                  onVariantSelected: (variant) {
                    // Handle variant selection
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

