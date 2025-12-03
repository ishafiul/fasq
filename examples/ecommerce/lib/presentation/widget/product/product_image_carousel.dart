import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/api/models/images2.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/product_service.dart';
import 'package:ecommerce/core/widgets/image_viewer/image_viewer.dart';
import 'package:ecommerce/core/widgets/image_viewer/image_viewer_show.dart';
import 'package:ecommerce/core/widgets/no_data.dart';
import 'package:ecommerce/core/widgets/page_indicator.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/core/widgets/swiper.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

class ProductImageCarousel extends StatefulWidget {
  const ProductImageCarousel({
    super.key,
    required this.id,
  });

  final String id;

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  final SwiperRef _swiperRef = SwiperRef();
  int _currentIndex = 0;

  void _onIndexChange(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onThumbnailTap(int index) {
    _swiperRef.swipeTo(index);
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final palette = context.palette;

    return QueryBuilder(
      queryKey: QueryKeys.productDetail(widget.id),
      queryFn: () => locator.get<ProductService>().getProductById(widget.id),
      builder: (context, productState) {
        if (productState.isLoading) {
          return const Text("lolading");
        }
        if (productState.hasError || productState.data == null) {
          return const Center(
            child: NoData(message: 'Failed to load product details'),
          );
        }
        final sortedImages = List<Images2>.from(productState.data!.images)
          ..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

        return Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                const aspectRatio = 0.75; // 4:3 aspect ratio (less height)
                final height = width * aspectRatio;

                if (sortedImages.isEmpty) {
                  return Container(
                    width: width,
                    height: height,
                    color: palette.surface,
                    child: Center(
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: palette.weak,
                        size: spacing.xxl,
                      ),
                    ),
                  );
                }

                return GestureDetector(
                  onTap: () {
                    showMultiImageViewer(
                      context,
                      MultiImageViewerProps(
                        images: sortedImages.map((img) => img.url).toList(),
                        defaultIndex: _currentIndex,
                      ),
                    );
                  },
                  child: SizedBox(
                    width: width,
                    height: height,
                    child: Swiper(
                      ref: _swiperRef,
                      defaultIndex: _currentIndex,
                      onIndexChange: _onIndexChange,
                      showIndicator: sortedImages.length > 1,
                      indicatorProps: const SwiperIndicatorProps(
                        color: PageIndicatorColor.primary,
                        position: SwiperIndicatorPosition.center,
                      ),
                      children: sortedImages
                          .map((image) => SwiperItem(
                                child: CachedNetworkImage(
                                  imageUrl: image.url,
                                  fit: BoxFit.contain,
                                  placeholder: (context, url) => ColoredBox(
                                    color: palette.surface,
                                    child: Center(
                                      child: CircularProgressSpinner(color: palette.brand, size: 24, strokeWidth: 2),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => ColoredBox(
                                    color: palette.surface,
                                    child: Icon(
                                      Icons.image_not_supported_outlined,
                                      color: palette.weak,
                                      size: spacing.lg,
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                  ),
                );
              },
            ),
            if (sortedImages.length > 1) ...[
              SizedBox(height: spacing.sm),
              SizedBox(
                height: 60,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: spacing.sm),
                  child: Row(
                    children: sortedImages.asMap().entries.map((entry) {
                      final index = entry.key;
                      final image = entry.value;
                      final isSelected = index == _currentIndex;
                      return GestureDetector(
                        onTap: () => _onThumbnailTap(index),
                        child: Container(
                          width: 60,
                          height: 60,
                          margin: EdgeInsets.only(right: index < sortedImages.length - 1 ? spacing.xs : 0),
                          decoration: BoxDecoration(
                            borderRadius: radius.all(radius.sm),
                            border: Border.all(
                              color: isSelected ? palette.brand : palette.border,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: radius.all(radius.sm),
                            child: _ThumbnailImage(imageUrl: image.url),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ThumbnailImage extends StatelessWidget {
  const _ThumbnailImage({
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      placeholder: (context, url) => ColoredBox(
        color: palette.surface,
        child: Center(
          child: CircularProgressSpinner(color: palette.brand, size: 16, strokeWidth: 2),
        ),
      ),
      errorWidget: (context, url, error) => ColoredBox(
        color: palette.surface,
        child: Icon(
          Icons.image_not_supported_outlined,
          color: palette.weak,
          size: spacing.sm,
        ),
      ),
    );
  }
}
