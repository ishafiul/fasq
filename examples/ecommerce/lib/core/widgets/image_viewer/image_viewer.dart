import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/mask.dart';
import 'package:ecommerce/core/widgets/svg_icon.dart';
import 'package:ecommerce/core/widgets/swiper.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:flutter/material.dart';

class ImageViewerProps {
  const ImageViewerProps({
    this.image,
    this.images,
    this.defaultIndex = 0,
    this.onIndexChange,
    this.onClose,
    this.afterClose,
    this.imageRender,
  }) : assert(
          image != null || images != null,
          'Either image or images must be provided',
        );

  final String? image;
  final List<String>? images;
  final int defaultIndex;
  final ValueChanged<int>? onIndexChange;
  final VoidCallback? onClose;
  final VoidCallback? afterClose;
  final Widget Function(String image, {required ImageProvider imageProvider, required int index})? imageRender;
}

class MultiImageViewerProps {
  const MultiImageViewerProps({
    required this.images,
    this.defaultIndex = 0,
    this.onIndexChange,
    this.onClose,
    this.afterClose,
    this.imageRender,
  });

  final List<String> images;
  final int defaultIndex;
  final ValueChanged<int>? onIndexChange;
  final VoidCallback? onClose;
  final VoidCallback? afterClose;
  final Widget Function(String image, {required ImageProvider imageProvider, required int index})? imageRender;
}

class ImageViewer extends StatefulWidget {
  const ImageViewer({
    super.key,
    required this.props,
    this.visible = true,
  });

  final ImageViewerProps props;
  final bool visible;

  @override
  State<ImageViewer> createState() => _ImageViewerState();
}

class _ImageViewerState extends State<ImageViewer> {
  final Map<int, TransformationController> _transformationControllers = <int, TransformationController>{};
  final Map<int, double> _zoomLevels = <int, double>{};
  int _currentIndex = 0;
  final ValueNotifier<bool> _isZoomedNotifier = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    final images = widget.props.images ?? (widget.props.image != null ? [widget.props.image!] : <String>[]);
    _currentIndex = widget.props.defaultIndex.clamp(0, images.length - 1);
    for (int i = 0; i < images.length; i++) {
      _transformationControllers[i] = TransformationController();
    }
  }

  @override
  void dispose() {
    for (final controller in _transformationControllers.values) {
      controller.dispose();
    }
    _isZoomedNotifier.dispose();
    super.dispose();
  }

  void _handleClose() {
    widget.props.onClose?.call();
  }

  TransformationController _getController(int index) {
    if (!_transformationControllers.containsKey(index)) {
      _transformationControllers[index] = TransformationController();
    }
    return _transformationControllers[index]!;
  }

  double _getZoomLevel(int index) {
    return _zoomLevels[index] ?? 1.0;
  }

  void _handleDoubleTap(int index) {
    if (index != _currentIndex) return;

    final controller = _getController(index);
    final currentScale = controller.value.getMaxScaleOnAxis();
    final isCurrentlyZoomed = (currentScale - 1.0).abs() > 0.1;

    setState(() {
      if (isCurrentlyZoomed) {
        _zoomLevels[index] = 1.0;
        controller.value = Matrix4.identity();
        _isZoomedNotifier.value = false;
      } else {
        _zoomLevels[index] = 2.0;
        final screenSize = MediaQuery.of(context).size;
        final focalPoint = Offset(screenSize.width / 2, screenSize.height / 2);
        final matrix = Matrix4.identity()
          ..translate(focalPoint.dx, focalPoint.dy)
          ..scale(2.0)
          ..translate(-focalPoint.dx, -focalPoint.dy);
        controller.value = matrix;
        _isZoomedNotifier.value = true;
      }
    });
  }

  Widget _buildImageWidget(String imageUrl, int index, BuildContext context) {
    Widget imageWidget;
    if (widget.props.imageRender != null) {
      final imageProvider = _getImageProvider(imageUrl);
      imageWidget = widget.props.imageRender!(imageUrl, imageProvider: imageProvider, index: index);
    } else {
      imageWidget = _buildDefaultImage(imageUrl, context);
    }

    final controller = _getController(index);
    final isCurrent = index == _currentIndex;
    final zoomLevel = _getZoomLevel(index);
    final currentScale = controller.value.getMaxScaleOnAxis();
    final isZoomed = zoomLevel == 2.0 || currentScale > 1.0;

    if (isCurrent) {
      _isZoomedNotifier.value = isZoomed;
    }

    if (isZoomed) {
      return LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: GestureDetector(
              onDoubleTap: () => _handleDoubleTap(index),
              behavior: HitTestBehavior.translucent,
              child: InteractiveViewer(
                transformationController: controller,
                minScale: 1.0,
                maxScale: 2.0,
                panEnabled: isCurrent,
                scaleEnabled: false,
                clipBehavior: Clip.hardEdge,
                boundaryMargin: EdgeInsets.zero,
                constrained: true,
                child: imageWidget,
              ),
            ),
          );
        },
      );
    }

    return GestureDetector(
      onDoubleTap: () => _handleDoubleTap(index),
      behavior: HitTestBehavior.deferToChild,
      child: imageWidget,
    );
  }

  ImageProvider _getImageProvider(String imageUrl) {
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return CachedNetworkImageProvider(imageUrl);
    }
    return AssetImage(imageUrl);
  }

  Widget _buildDefaultImage(String imageUrl, BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;

    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return CachedNetworkImage(
        imageUrl: imageUrl,
        fit: BoxFit.contain,
        errorWidget: (context, url, error) {
          return Container(
            color: palette.surface,
            child: Center(
              child: Icon(
                Icons.image_not_supported_outlined,
                color: palette.weak,
                size: spacing.xxl,
              ),
            ),
          );
        },
        placeholder: (context, url) {
          return Container(
            color: palette.surface,
            child: Center(
              child: CircularProgressIndicator(
                color: palette.brand,
              ),
            ),
          );
        },
      );
    }

    return Image.asset(
      imageUrl,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: palette.surface,
          child: Center(
            child: Icon(
              Icons.image_not_supported_outlined,
              color: palette.weak,
              size: spacing.xxl,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;
    final images = widget.props.images ?? (widget.props.image != null ? [widget.props.image!] : <String>[]);
    final isMultiple = images.length > 1;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) {
        if (!didPop) {
          _handleClose();
        }
      },
      child: Mask(
        visible: widget.visible,
        onMaskClick: _handleClose,
        afterClose: widget.props.afterClose,
        opacity: MaskOpacity.thick,
        disableBodyScroll: false,
        destroyOnClose: true,
        child: Stack(
          children: [
            Positioned.fill(
              child: Center(
                child: isMultiple
                    ? ValueListenableBuilder<bool>(
                        valueListenable: _isZoomedNotifier,
                        builder: (context, isZoomed, child) {
                          if (isZoomed) {
                            return _buildImageWidget(images[_currentIndex], _currentIndex, context);
                          }
                          return Swiper(
                            defaultIndex: widget.props.defaultIndex,
                            allowTouchMove: true,
                            onIndexChange: (index) {
                              setState(() {
                                _currentIndex = index;
                                final controller = _getController(index);
                                final scale = controller.value.getMaxScaleOnAxis();
                                _isZoomedNotifier.value = scale > 1.0;
                              });
                              widget.props.onIndexChange?.call(index);
                            },
                            children: images.asMap().entries.map((entry) {
                              return SwiperItem(
                                child: _buildImageWidget(entry.value, entry.key, context),
                              );
                            }).toList(),
                            showIndicator: true,
                            slideSize: 100.0,
                            trackOffset: 0.0,
                          );
                        },
                      )
                    : images.isNotEmpty
                        ? _buildImageWidget(images[0], 0, context)
                        : const SizedBox.shrink(),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: SafeArea(
                child: Padding(
                  padding: EdgeInsets.all(spacing.md),
                  child: _CloseButton(onClose: _handleClose),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImageViewerHandler {
  ImageViewerHandler(this._overlayEntry);

  final OverlayEntry _overlayEntry;

  void close() {
    _overlayEntry.remove();
  }
}

final Set<ImageViewerHandler> _handlerSet = <ImageViewerHandler>{};

ImageViewerHandler showImageViewer(BuildContext context, ImageViewerProps props) {
  clearImageViewer();
  late ImageViewerHandler handler;
  late OverlayEntry overlayEntry;

  void close() {
    overlayEntry.remove();
    _handlerSet.remove(handler);
    props.afterClose?.call();
  }

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: ImageViewer(
        props: ImageViewerProps(
          image: props.image,
          images: props.images,
          defaultIndex: props.defaultIndex,
          onIndexChange: props.onIndexChange,
          onClose: close,
          afterClose: props.afterClose,
          imageRender: props.imageRender,
        ),
        visible: true,
      ),
    ),
  );
  handler = ImageViewerHandler(overlayEntry);
  _handlerSet.add(handler);
  Overlay.of(context).insert(overlayEntry);
  return handler;
}

ImageViewerHandler showMultiImageViewer(BuildContext context, MultiImageViewerProps props) {
  clearImageViewer();
  late ImageViewerHandler handler;
  late OverlayEntry overlayEntry;

  void close() {
    overlayEntry.remove();
    _handlerSet.remove(handler);
    props.afterClose?.call();
  }

  overlayEntry = OverlayEntry(
    builder: (context) => Positioned.fill(
      child: ImageViewer(
        props: ImageViewerProps(
          images: props.images,
          defaultIndex: props.defaultIndex,
          onIndexChange: props.onIndexChange,
          onClose: close,
          afterClose: props.afterClose,
          imageRender: props.imageRender,
        ),
        visible: true,
      ),
    ),
  );
  handler = ImageViewerHandler(overlayEntry);
  _handlerSet.add(handler);
  Overlay.of(context).insert(overlayEntry);
  return handler;
}

void clearImageViewer() {
  for (final handler in _handlerSet) {
    handler.close();
  }
  _handlerSet.clear();
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({
    this.onClose,
  });

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onClose,
      child: Container(
        decoration: BoxDecoration(
          color: palette.background.withValues(alpha: 0.7),
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(4),
        child: SvgIcon(
          svg: Assets.icons.filled.closeSquare,
          size: 32,
          color: palette.textPrimary,
          semanticLabel: 'Close image viewer',
        ),
      ),
    );
  }
}
