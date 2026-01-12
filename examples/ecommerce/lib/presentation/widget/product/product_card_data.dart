import 'package:ecommerce/api/models/product_response.dart';

class ProductCardData {
  const ProductCardData({
    required this.productId,
    required this.productName,
    required this.imageUrl,
    required this.tags,
    required this.originalPrice,
    required this.discountedPrice,
    required this.hasDiscount,
    required this.discountPercentage,
  });

  final String productId;
  final String productName;
  final String? imageUrl;
  final List<String> tags;
  final double originalPrice;
  final double discountedPrice;
  final bool hasDiscount;
  final double? discountPercentage;

  factory ProductCardData.fromProduct(
    ProductResponse? product, {
    double? discountPercentage,
  }) {
    final productId = product?.id ?? '';
    final productName = product?.name ?? '';
    final basePrice = product?.basePrice ?? '0';
    final tags = product?.tags ?? [];

    final imageUrl = product?.images.isNotEmpty == true ? product?.images.first.url : null;

    final hasDiscount = discountPercentage != null && discountPercentage > 0;
    final originalPrice = double.tryParse(basePrice) ?? 0;
    final discountedPrice = hasDiscount ? originalPrice * (1 - discountPercentage / 100) : originalPrice;

    return ProductCardData(
      productId: productId,
      productName: productName,
      imageUrl: imageUrl,
      tags: tags,
      originalPrice: originalPrice,
      discountedPrice: discountedPrice,
      hasDiscount: hasDiscount,
      discountPercentage: discountPercentage,
    );
  }

  bool get hasValidId => productId.isNotEmpty;

  String get formattedOriginalPrice => '\$${originalPrice.toStringAsFixed(2)}';

  String get formattedDiscountedPrice => '\$${discountedPrice.toStringAsFixed(2)}';

  String get formattedDiscountPercentage {
    final discount = discountPercentage;
    if (discount == null) return '';
    return '-${discount.toInt()}%';
  }
}
