import 'package:ecommerce/api/models/product_detail_response.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/services/vendor_service.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:ecommerce/presentation/widget/vendor/vendor_info_card.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class VendorSection extends StatelessWidget {
  const VendorSection({
    super.key,
    required this.productId,
  });

  final String productId;

  @override
  Widget build(BuildContext context) {
    return QueryBuilder<ProductDetailResponse>(
      queryKey: QueryKeys.productDetail(productId),
      queryFn: () => locator.get<ProductService>().getProductById(productId),
      builder: (context, productState) {
        if (productState.isLoading || !productState.isSuccess) {
          return const SizedBox.shrink();
        }

        final product = productState.data;
        if (product == null) {
          return const SizedBox.shrink();
        }

        final vendorId = product.vendorId;
        if (vendorId.isEmpty) {
          return const SizedBox.shrink();
        }

        return QueryBuilder(
          queryKey: QueryKeys.vendor(vendorId),
          queryFn: () => locator.get<VendorService>().getVendorById(vendorId),
          options: QueryOptions(
            enabled: productState.isSuccess && vendorId.isNotEmpty,
          ),
          builder: (context, vendorState) {
            if (vendorState.isLoading) {
              return const SizedBox.shrink();
            }

            if (vendorState.hasError || vendorState.data == null) {
              return const SizedBox.shrink();
            }

            return ShimmerLoading(
              isLoading: vendorState.isLoading,
              child: VendorInfoCard(vendor: vendorState.data!),
            );
          },
        );
      },
    );
  }
}
