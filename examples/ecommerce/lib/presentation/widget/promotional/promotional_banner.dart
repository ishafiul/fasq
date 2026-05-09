import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/api/models/promotional_content_response.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/promotional_service.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

int _toMemCacheDimension(BuildContext context, double logicalSize) {
  final safeLogicalSize = logicalSize.isFinite && logicalSize > 0 ? logicalSize : 1;
  final physicalSize = (safeLogicalSize * MediaQuery.devicePixelRatioOf(context)).round();
  return physicalSize > 0 ? physicalSize : 1;
}

/// A carousel banner widget for displaying promotional content.
class PromotionalBanner extends StatelessWidget {
  const PromotionalBanner({super.key, this.onBannerTap});

  final ValueChanged<PromotionalContentResponse?>? onBannerTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final radius = context.radius;

    return QueryBuilder<List<PromotionalContentResponse>>(
      queryKey: QueryKeys.currentOffers,
      queryFnWithToken: (token) => locator.get<PromotionalService>().getCurrentOffers(),
      builder: (context, state) {
        if (state.hasError) {
          debugPrint('PromotionalBanner: Error - ${state.error}');
          return const SizedBox.shrink();
        }

        final offers = state.data ?? [];
        debugPrint(
          'PromotionalBanner: Status=${state.status}, DataLength=${offers.length}, IsLoading=${state.isLoading}, IsFetching=${state.isFetching}, IsStale=${state.isStale}, DataUpdatedAt=${state.dataUpdatedAt}',
        );
        final isLoading = state.isLoading;

        if (!isLoading && offers.isEmpty) {
          return const SizedBox.shrink();
        }

        // Show at least one banner when loading
        final itemCount = isLoading ? 1 : offers.length;

        return SizedBox(
          height: 200,
          child: PageView.builder(
            itemCount: itemCount,
            itemBuilder: (context, index) {
              // Create mock offer data when loading
              final offer = isLoading ? null : offers[index];

              return ShimmerLoading(
                isLoading: isLoading,
                loadingChild: _BannerSkeleton(palette: palette, spacing: spacing, radius: radius),
                child: _BannerItem(
                  offer: offer,
                  onTap: isLoading ? () {} : () => onBannerTap?.call(offer),
                  palette: palette,
                  spacing: spacing,
                  typography: typography,
                  radius: radius,
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _BannerSkeleton extends StatelessWidget {
  const _BannerSkeleton({required this.palette, required this.spacing, required this.radius});

  final AppPalette palette;
  final Spacing spacing;
  final RadiusScale radius;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm),
      child: ClipRRect(
        borderRadius: radius.all(radius.lg),
        child: ColoredBox(
          color: palette.weak.withValues(alpha: 0.25),
          child: Padding(
            padding: EdgeInsets.all(spacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FractionallySizedBox(
                  widthFactor: 0.65,
                  child: Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: palette.weak.withValues(alpha: 0.55),
                      borderRadius: radius.all(radius.sm),
                    ),
                  ),
                ),
                SizedBox(height: spacing.xs),
                FractionallySizedBox(
                  widthFactor: 0.5,
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: palette.weak.withValues(alpha: 0.45),
                      borderRadius: radius.all(radius.xs),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BannerItem extends StatelessWidget {
  const _BannerItem({
    required this.offer,
    required this.onTap,
    required this.palette,
    required this.spacing,
    required this.typography,
    required this.radius,
  });

  final PromotionalContentResponse? offer;
  final VoidCallback onTap;
  final AppPalette palette;
  final Spacing spacing;
  final TypographyScale typography;
  final RadiusScale radius;

  @override
  Widget build(BuildContext context) {
    // When loading, use empty strings for shimmer effect
    final title = offer?.title;
    final description = offer?.description;
    final imageUrl = offer?.imageUrl;
    final bannerLogicalWidth = (MediaQuery.sizeOf(context).width - (spacing.sm * 2)).clamp(1.0, double.infinity);
    final memCacheWidth = _toMemCacheDimension(context, bannerLogicalWidth);
    final memCacheHeight = _toMemCacheDimension(context, 200);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: spacing.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: radius.all(radius.lg),
        child: ClipRRect(
          borderRadius: radius.all(radius.lg),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Background Image
              if (imageUrl != null && imageUrl.isNotEmpty)
                CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: memCacheWidth,
                  memCacheHeight: memCacheHeight,
                  placeholder: (context, url) => ColoredBox(
                    color: palette.weak,
                    child: Center(child: CircularProgressIndicator(color: palette.brand)),
                  ),
                  errorWidget: (context, url, error) => ColoredBox(
                    color: palette.brand.withValues(alpha: 0.1),
                    child: Icon(Icons.image_not_supported, color: palette.textSecondary, size: spacing.xl),
                  ),
                )
              else
                Container(decoration: BoxDecoration(gradient: palette.gradientBrand)),
              // Gradient Overlay
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.black.withValues(alpha: 0.3), Colors.black.withValues(alpha: 0.1)],
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Text(
                      title ?? '',
                      style: typography.titleMedium
                          .toTextStyle(color: Colors.white)
                          .copyWith(fontWeight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: spacing.xs),
                    Text(
                      description ?? '',
                      style: typography.bodySmall.toTextStyle(color: Colors.white.withValues(alpha: 0.9)),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
