import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/api/models/images2.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:flutter/material.dart';

class ProductImageCarousel extends StatefulWidget {
  const ProductImageCarousel({
    super.key,
    required this.images,
  });

  final List<Images2> images;

  @override
  State<ProductImageCarousel> createState() => _ProductImageCarouselState();
}

class _ProductImageCarouselState extends State<ProductImageCarousel> {
  final PageController _pageController = PageController();
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _onThumbnailTap(int index) {
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final radius = context.radius;
    final palette = context.palette;

    if (widget.images.isEmpty) {
      return _ImagePlaceholder();
    }

    final sortedImages = List<Images2>.from(widget.images)..sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    return Column(
      children: [
        SizedBox(
          height: 400,
          child: PageView.builder(
            controller: _pageController,
            onPageChanged: _onPageChanged,
            itemCount: sortedImages.length,
            itemBuilder: (context, index) {
              final image = sortedImages[index];
              return _ImageItem(imageUrl: image.url);
            },
          ),
        ),
        if (sortedImages.length > 1) ...[
          SizedBox(height: spacing.sm),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: sortedImages.length,
              itemBuilder: (context, index) {
                final image = sortedImages[index];
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
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _ImageItem extends StatelessWidget {
  const _ImageItem({
    required this.imageUrl,
  });

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;

    return CachedNetworkImage(
      imageUrl: imageUrl,
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

class _ImagePlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;

    return Container(
      height: 400,
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
}


