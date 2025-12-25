import 'package:ecommerce/api/models/product_detail_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class ProductDetailsTab extends StatelessWidget {
  const ProductDetailsTab({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return QueryBuilder(
      queryKey: QueryKeys.productDetail(productId),
      queryFn: () => locator.get<ProductService>().getProductById(productId),
      builder: (context, productState) {
        return CustomScrollView(
          slivers: [
            SliverPadding(
              padding: EdgeInsets.all(spacing.sm),
              sliver: SliverToBoxAdapter(
                child: Column(
                  children: [
                    SizedBox(height: spacing.md),
                    _ProductDescriptionSection(
                      product: productState.data,
                      isLoading: productState.isLoading,
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _ProductDescriptionSection extends StatelessWidget {
  const _ProductDescriptionSection({
    this.product,
    required this.isLoading,
  });

  final ProductDetailResponse? product;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;

    if (!isLoading && (product?.description == null || product!.description!.isEmpty)) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Description',
          style: typography.titleSmall.toTextStyle(color: palette.textPrimary),
        ),
        SizedBox(height: spacing.sm),
        ShimmerLoading(
          isLoading: isLoading,
          child: Text(
            product?.description ?? '',
            style: typography.bodyMedium.toTextStyle(
              color: palette.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}
