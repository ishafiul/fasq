import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/widgets/no_data.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:ecommerce/core/widgets/tag.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class ProductInfoSection extends StatelessWidget {
  const ProductInfoSection({
    super.key,
    required this.id,
  });

  final String id;

  @override
  Widget build(BuildContext context) {
    return QueryBuilder(
      queryKey: QueryKeys.productDetail(id),
      queryFn: () => locator.get<ProductService>().getProductById(id),
      builder: (context, productState) {
        if (productState.hasError) {
          return const Center(
            child: NoData(message: 'Failed to load product details'),
          );
        }
        final basePrice = double.parse(productState.data?.basePrice ?? '0');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShimmerLoading(
              height: 20,
              isLoading: productState.isLoading,
              child: Text(
                productState.data?.name ?? '',
                style: context.typography.bodyMedium
                    .toTextStyle(
                      color: productState.isLoading ? Colors.transparent : context.palette.textPrimary,
                    )
                    .copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            SizedBox(height: context.spacing.xs),
            ShimmerLoading(
              height: 20,
              isLoading: productState.isLoading,
              child: Container(
                color: productState.isLoading ? Colors.transparent : null,
                child: Text(
                  basePrice > 0 ? '\$${basePrice.toStringAsFixed(2)}' : '\$0.00',
                  style: context.typography.titleMedium
                      .toTextStyle(
                        color: productState.isLoading ? Colors.transparent : context.palette.textPrimary,
                      )
                      .copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ),
            SizedBox(
              height: context.spacing.sm,
            ),
            ShimmerLoading(
              isLoading: productState.isLoading,
              child: Wrap(
                spacing: context.spacing.xs,
                runSpacing: context.spacing.xs,
                children:
                    (productState.isLoading || productState.data?.tags == null || productState.data!.tags!.isEmpty)
                        ? [
                            const Tag(
                              color: TagColor.primary,
                              child: Text('TAG'),
                            ),
                            const Tag(
                              color: TagColor.primary,
                              child: Text('TAG'),
                            ),
                          ]
                        : productState.data!.tags!.map((tag) {
                            return Tag(
                              color: TagColor.primary,
                              child: Text(tag.toUpperCase()),
                            );
                          }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}
