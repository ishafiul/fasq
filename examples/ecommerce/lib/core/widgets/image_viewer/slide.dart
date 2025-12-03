import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:flutter/material.dart';

class Slide extends StatefulWidget {
  const Slide({
    super.key,
    required this.image,
    required this.maxZoom,
    this.onTap,
    this.onZoomChange,
    this.dragLockRef,
    this.imageRender,
    this.index,
  });

  final String image;
  final double maxZoom;
  final VoidCallback? onTap;
  final ValueChanged<double>? onZoomChange;
  final ValueNotifier<bool>? dragLockRef;
  final Widget Function(String image, {required GlobalKey imageKey, required int index})? imageRender;
  final int? index;

  @override
  State<Slide> createState() => _SlideState();
}

class _SlideState extends State<Slide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Matrix4 _matrix = Matrix4.identity();

  double _scale = 1.0;
  double _targetScale = 1.0;
  Offset _translation = Offset.zero;
  Offset _targetTranslation = Offset.zero;
  Offset _lastPanPosition = Offset.zero;
  Size? _imageSize;
  Size? _viewportSize;
  bool _isPinching = false;
  bool _isPanning = false;
  Timer? _tapTimer;
  Offset? _lastTapPosition;
  double _initialPinchScale = 1.0;
  Offset _initialPinchTranslation = Offset.zero;
  Offset _initialPinchFocalPoint = Offset.zero;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );

    _controller.addListener(_updateMatrix);
  }

  @override
  void dispose() {
    _tapTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _updateMatrix() {
    if (!mounted) return;
    final t = _controller.value;
    final currentScale = _scale + (_targetScale - _scale) * t;
    final currentTranslation = Offset.lerp(_translation, _targetTranslation, t) ?? _targetTranslation;
    setState(() {
      _matrix = Matrix4.identity()
        ..translate(currentTranslation.dx, currentTranslation.dy)
        ..scale(currentScale);
    });
  }

  double _getNextZoomLevel(double currentZoom) {
    final maxZoom = widget.maxZoom;

    if (currentZoom < 1.5) {
      return math.min(2.0, maxZoom);
    }
    if (currentZoom < 2.5 && maxZoom >= 3.0) {
      return 3.0;
    }
    return 1.0;
  }

  double _clampZoom(double zoom) {
    final maxZoom = widget.maxZoom;
    return zoom.clamp(1.0, maxZoom);
  }

  void _applyZoom(double newScale, Offset focalPoint, {bool animate = true}) {
    if (_imageSize == null || _viewportSize == null) return;

    final clampedScale = _clampZoom(newScale);
    final scaleChange = clampedScale / _scale;

    final viewportCenter = Offset(_viewportSize!.width / 2, _viewportSize!.height / 2);

    final focalPointInImage = focalPoint - viewportCenter;
    final currentImagePoint = focalPointInImage - _translation;

    final newTranslation = _translation - (currentImagePoint * (scaleChange - 1));

    _targetScale = clampedScale;
    _targetTranslation = newTranslation;
    _constrainTranslation();

    if (animate && !_isPinching) {
      _scale = _targetScale;
      _translation = _targetTranslation;
      _updateMatrix();
      _controller.forward(from: 0.0);
    } else {
      _scale = _targetScale;
      _translation = _targetTranslation;
      _updateMatrix();
      _controller.value = 1.0;
    }

    widget.onZoomChange?.call(_scale);
    if (_scale > 1.0) {
      widget.dragLockRef?.value = true;
    } else {
      widget.dragLockRef?.value = false;
    }
  }

  void _constrainTranslation() {
    if (_imageSize == null || _viewportSize == null) return;

    final scaledWidth = _imageSize!.width * _targetScale;
    final scaledHeight = _imageSize!.height * _targetScale;

    final maxX = math.max(0.0, (scaledWidth - _viewportSize!.width) / 2);
    final maxY = math.max(0.0, (scaledHeight - _viewportSize!.height) / 2);

    if (scaledWidth <= _viewportSize!.width) {
      _targetTranslation = Offset(0, _targetTranslation.dy);
    } else {
      _targetTranslation = Offset(
        _targetTranslation.dx.clamp(-maxX, maxX),
        _targetTranslation.dy,
      );
    }

    if (scaledHeight <= _viewportSize!.height) {
      _targetTranslation = Offset(_targetTranslation.dx, 0);
    } else {
      _targetTranslation = Offset(
        _targetTranslation.dx,
        _targetTranslation.dy.clamp(-maxY, maxY),
      );
    }
  }

  void _handleDoubleTap() {
    if (_isPinching || _isPanning) return;

    _tapTimer?.cancel();
    _tapTimer = null;

    final viewportSize = _viewportSize;
    if (viewportSize == null) return;

    final focalPoint = _lastTapPosition ?? Offset(viewportSize.width / 2, viewportSize.height / 2);
    final nextZoom = _getNextZoomLevel(_scale);
    _applyZoom(nextZoom, focalPoint);
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _tapTimer?.cancel();
    _tapTimer = null;

    if (details.pointerCount == 2) {
      _isPinching = true;
      _initialPinchScale = _scale;
      _initialPinchTranslation = _translation;
      _initialPinchFocalPoint = details.localFocalPoint;
      _lastPanPosition = details.localFocalPoint;
    } else if (details.pointerCount == 1 && _scale > 1.0) {
      _isPanning = true;
      _lastPanPosition = details.localFocalPoint;
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount == 2 && _isPinching) {
      final newScale = _initialPinchScale * details.scale;
      final clampedScale = _clampZoom(newScale);
      final scaleChange = clampedScale / _initialPinchScale;

      if (_viewportSize == null || _imageSize == null) return;

      final viewportCenter = Offset(_viewportSize!.width / 2, _viewportSize!.height / 2);
      final currentFocalPoint = details.localFocalPoint;
      final initialFocalPointInViewport = _initialPinchFocalPoint - viewportCenter;
      final currentFocalPointInViewport = currentFocalPoint - viewportCenter;

      final pointInImageSpace = initialFocalPointInViewport - _initialPinchTranslation;
      final scaledPointInImageSpace = pointInImageSpace * scaleChange;
      final newTranslation = currentFocalPointInViewport - scaledPointInImageSpace;

      _targetScale = clampedScale;
      _targetTranslation = newTranslation;
      _constrainTranslation();

      _scale = _targetScale;
      _translation = _targetTranslation;
      _controller.value = 1.0;
      _updateMatrix();

      widget.onZoomChange?.call(_scale);
      if (_scale > 1.0) {
        widget.dragLockRef?.value = true;
      } else {
        widget.dragLockRef?.value = false;
      }
    } else if (details.pointerCount == 1 && _scale > 1.0) {
      _isPanning = true;
      final delta = details.localFocalPoint - _lastPanPosition;
      _targetTranslation = _translation + delta;
      _translation = _targetTranslation;
      _lastPanPosition = details.localFocalPoint;
      _constrainTranslation();
      _targetTranslation = _translation;
      _controller.value = 1.0;
      setState(() {
        _matrix = Matrix4.identity()
          ..translate(_translation.dx, _translation.dy)
          ..scale(_scale);
      });
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _isPinching = false;
    _isPanning = false;
    _scale = _targetScale;
    _translation = _targetTranslation;
    _constrainTranslation();
    _targetTranslation = _translation;
    _controller.forward(from: 0.0);
  }

  void _handleTapDown(TapDownDetails details) {
    if (!_isPinching && !_isPanning) {
      _lastTapPosition = details.localPosition;
    }
  }

  void _handleTap() {
    if (_isPinching || _isPanning || _scale > 1.0) {
      debugPrint('[Slide] Tap ignored: isPinching=$_isPinching, isPanning=$_isPanning, scale=$_scale');
      return;
    }

    _tapTimer?.cancel();
    _tapTimer = Timer(const Duration(milliseconds: 250), () {
      if (!_isPinching && !_isPanning && _scale <= 1.0) {
        debugPrint('[Slide] Single tap confirmed, calling onTap');
        widget.onTap?.call();
      } else {
        debugPrint('[Slide] Single tap cancelled: isPinching=$_isPinching, isPanning=$_isPanning, scale=$_scale');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;

    return LayoutBuilder(
      builder: (context, constraints) {
        _viewportSize = Size(constraints.maxWidth, constraints.maxHeight);

        return GestureDetector(
          onTapDown: _handleTapDown,
          onTap: _handleTap,
          onDoubleTap: _handleDoubleTap,
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onScaleEnd: _handleScaleEnd,
          behavior: HitTestBehavior.opaque,
          child: Center(
            child: Transform(
              transform: _matrix,
              alignment: Alignment.center,
              child: _buildImage(palette, spacing),
            ),
          ),
        );
      },
    );
  }

  Widget _buildImage(AppPalette palette, Spacing spacing) {
    final imageKey = GlobalKey();

    void updateImageSize() {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final renderObject = imageKey.currentContext?.findRenderObject();
        if (renderObject is RenderBox) {
          final size = renderObject.size;
          if (size.width > 0 && size.height > 0 && _imageSize != size) {
            setState(() {
              _imageSize = size;
            });
          }
        }
      });
    }

    if (widget.imageRender != null) {
      final customWidget = widget.imageRender!(
        widget.image,
        imageKey: imageKey,
        index: widget.index ?? 0,
      );
      updateImageSize();
      return customWidget;
    }

    return CachedNetworkImage(
      imageUrl: widget.image,
      fit: BoxFit.contain,
      placeholder: (context, url) => Center(
        child: CircularProgressSpinner(
          color: palette.brand,
          size: 24,
          strokeWidth: 2,
        ),
      ),
      errorWidget: (context, url, error) => ColoredBox(
        color: palette.surface,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: palette.weak,
            size: spacing.lg,
          ),
        ),
      ),
      imageBuilder: (context, imageProvider) {
        return Image(
          key: imageKey,
          image: imageProvider,
          fit: BoxFit.contain,
          frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
            if (frame != null) {
              updateImageSize();
            }
            return child;
          },
        );
      },
    );
  }
}
