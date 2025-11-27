import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/get_it.dart';
import 'package:ecommerce/core/query_keys.dart';
import 'package:ecommerce/core/services/promotional_service.dart';
import 'package:ecommerce/core/widgets/shimmer/shimmer_loading.dart';
import 'package:fasq/fasq.dart';
import 'package:flutter/material.dart';

/// A carousel banner widget for displaying promotional content.
class PromotionalBanner extends StatelessWidget {
  const PromotionalBanner({super.key, this.onBannerTap});

  final ValueChanged<dynamic>? onBannerTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final radius = context.radius;

    return QueryBuilder<List<dynamic>>(
      queryKey: QueryKeys.currentOffers,
      queryFn: () => locator.get<PromotionalService>().getCurrentOffers(),
      builder: (context, state) {
        if (state.hasError) {
          return const SizedBox.shrink();
        }

        final offers = state.data ?? [];
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
              final offer = isLoading ? <String, dynamic>{} : offers[index];

              return ShimmerLoading(
                isLoading: isLoading,
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

class _BannerItem extends StatelessWidget {
  const _BannerItem({
    required this.offer,
    required this.onTap,
    required this.palette,
    required this.spacing,
    required this.typography,
    required this.radius,
  });

  final dynamic offer;
  final VoidCallback onTap;
  final AppPalette palette;
  final Spacing spacing;
  final TypographyScale typography;
  final RadiusScale radius;

  @override
  Widget build(BuildContext context) {
    // When loading, use empty strings for shimmer effect
    final title = _getStringValue(offer, 'title') ?? '';
    final description = _getStringValue(offer, 'description');
    final imageUrl = _getStringValue(offer, 'imageUrl');

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
                  placeholder: (context, url) => Container(
                    color: palette.weak,
                    child: Center(child: CircularProgressIndicator(color: palette.brand)),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: palette.brand.withOpacity(0.1),
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
                    colors: [Colors.black.withOpacity(0.3), Colors.black.withOpacity(0.1)],
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
                    if (title.isNotEmpty)
                      Text(
                        title,
                        style: typography.titleLarge.toTextStyle(color: Colors.white),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      // Placeholder for shimmer when loading
                      Container(
                        height: 24,
                        width: 200,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.3),
                          borderRadius: radius.all(radius.xs),
                        ),
                      ),
                    if (description != null && description.isNotEmpty) ...[
                      SizedBox(height: spacing.xs),
                      Text(
                        description,
                        style: typography.bodySmall.toTextStyle(color: Colors.white.withOpacity(0.9)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ] else if (title.isEmpty) ...[
                      // Show description placeholder when loading
                      SizedBox(height: spacing.xs),
                      Container(
                        height: 16,
                        width: 150,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: radius.all(radius.xs),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _getStringValue(dynamic obj, String key) {
    if (obj is Map) {
      return obj[key]?.toString();
    }
    return null;
  }
}
