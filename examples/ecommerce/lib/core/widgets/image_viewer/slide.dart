import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';

class _Bounds {
  const _Bounds({
    required this.position,
    required this.min,
    required this.max,
  });

  final double position;
  final double min;
  final double max;
}

class ImageViewerSlide extends StatefulWidget {
  const ImageViewerSlide({
    super.key,
    required this.image,
    this.maxZoom,
    this.onTap,
    this.onZoomChange,
    this.dragLockRef,
    this.imageRender,
    this.index,
  });

  final String image;
  final double? maxZoom;
  final VoidCallback? onTap;
  final ValueChanged<double>? onZoomChange;
  final ValueNotifier<bool>? dragLockRef;
  final Widget Function(String image, {required ImageProvider imageProvider, required int index})? imageRender;
  final int? index;

  @override
  State<ImageViewerSlide> createState() => _ImageViewerSlideState();
}

class _ImageViewerSlideState extends State<ImageViewerSlide> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Matrix4> _matrixAnimation;
  Matrix4 _targetMatrix = Matrix4.identity();
  Matrix4 _currentMatrix = Matrix4.identity();
  final GlobalKey _controlKey = GlobalKey();
  final GlobalKey _imageKey = GlobalKey();
  Size? _controlSize;
  Size? _imageSize;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _matrixAnimation = Matrix4Tween(begin: Matrix4.identity(), end: Matrix4.identity()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.value = 1.0;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _updateSizes() {
    final controlBox = _controlKey.currentContext?.findRenderObject() as RenderBox?;
    final imageBox = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (controlBox != null && imageBox != null) {
      if (mounted) {
        setState(() {
          _controlSize = controlBox.size;
          _imageSize = imageBox.size;
        });
      }
    }
  }

  double _getScaleX(Matrix4 matrix) {
    return math.sqrt(matrix.entry(0, 0) * matrix.entry(0, 0) + matrix.entry(1, 0) * matrix.entry(1, 0));
  }

  double _getTranslateX(Matrix4 matrix) {
    return matrix.entry(0, 3);
  }

  double _getTranslateY(Matrix4 matrix) {
    return matrix.entry(1, 3);
  }

  Matrix4 _createMatrix() {
    return Matrix4.identity();
  }

  Matrix4 _translate(Matrix4 matrix, double x, double y) {
    final result = Matrix4.copy(matrix);
    result.translate(x, y);
    return result;
  }

  Matrix4 _scale(Matrix4 matrix, double scale) {
    final result = Matrix4.copy(matrix);
    result.scale(scale);
    return result;
  }

  Offset _apply(Matrix4 matrix, double x, double y) {
    final w = matrix.entry(3, 0) * x + matrix.entry(3, 1) * y + matrix.entry(3, 3);
    if (w == 0) return Offset(x, y);
    final resultX = (matrix.entry(0, 0) * x + matrix.entry(0, 1) * y + matrix.entry(0, 3)) / w;
    final resultY = (matrix.entry(1, 0) * x + matrix.entry(1, 1) * y + matrix.entry(1, 3)) / w;
    return Offset(resultX, resultY);
  }

  _Bounds _getMinAndMaxX(Matrix4 nextMatrix) {
    if (_controlSize == null || _imageSize == null) {
      return _Bounds(position: 0, min: 0, max: 0);
    }

    final controlLeft = -_controlSize!.width / 2;
    final imgLeft = -_imageSize!.width / 2;
    final zoom = _getScaleX(nextMatrix);
    final scaledImgWidth = zoom * _imageSize!.width;
    final minX = controlLeft - (scaledImgWidth - _controlSize!.width);
    final maxX = controlLeft;

    final point = _apply(nextMatrix, imgLeft, -_imageSize!.height / 2);
    final x = point.dx;

    return _Bounds(position: x, min: minX, max: maxX);
  }

  _Bounds _getMinAndMaxY(Matrix4 nextMatrix) {
    if (_controlSize == null || _imageSize == null) {
      return _Bounds(position: 0, min: 0, max: 0);
    }

    final controlTop = -_controlSize!.height / 2;
    final imgTop = -_imageSize!.height / 2;
    final zoom = _getScaleX(nextMatrix);
    final scaledImgHeight = zoom * _imageSize!.height;
    final minY = controlTop - (scaledImgHeight - _controlSize!.height);
    final maxY = controlTop;

    final point = _apply(nextMatrix, -_imageSize!.width / 2, imgTop);
    final y = point.dy;

    return _Bounds(position: y, min: minY, max: maxY);
  }

  double _bound(double value, double min, double max) {
    return clampDouble(value, min, max);
  }

  double _rubberbandIfOutOfBounds(double value, double min, double max, double factor) {
    if (value < min) {
      final overscroll = min - value;
      return min - overscroll / (1 + overscroll / factor);
    }
    if (value > max) {
      final overscroll = value - max;
      return max + overscroll / (1 + overscroll / factor);
    }
    return value;
  }

  Matrix4 _boundMatrix(Matrix4 nextMatrix, String type, {bool last = false}) {
    if (_controlSize == null || _imageSize == null) return nextMatrix;

    final zoom = _getScaleX(nextMatrix);
    final scaledImgWidth = zoom * _imageSize!.width;
    final scaledImgHeight = zoom * _imageSize!.height;

    final xBounds = _getMinAndMaxX(nextMatrix);
    final yBounds = _getMinAndMaxY(nextMatrix);

    if (type == 'translate') {
      double boundedX = xBounds.position;
      double boundedY = yBounds.position;

      if (scaledImgWidth > _controlSize!.width) {
        boundedX = last
            ? _bound(xBounds.position, xBounds.min, xBounds.max)
            : _rubberbandIfOutOfBounds(xBounds.position, xBounds.min, xBounds.max, zoom * 50);
      } else {
        boundedX = -scaledImgWidth / 2;
      }

      if (scaledImgHeight > _controlSize!.height) {
        boundedY = last
            ? _bound(yBounds.position, yBounds.min, yBounds.max)
            : _rubberbandIfOutOfBounds(yBounds.position, yBounds.min, yBounds.max, zoom * 50);
      } else {
        boundedY = -scaledImgHeight / 2;
      }

      final currentX = _getTranslateX(nextMatrix);
      final currentY = _getTranslateY(nextMatrix);
      return _translate(nextMatrix, boundedX - currentX, boundedY - currentY);
    }

    if (type == 'scale' && last) {
      final xBounds = _getMinAndMaxX(nextMatrix);
      final yBounds = _getMinAndMaxY(nextMatrix);
      final boundedX = scaledImgWidth > _controlSize!.width
          ? _bound(xBounds.position, xBounds.min, xBounds.max)
          : -scaledImgWidth / 2;
      final boundedY = scaledImgHeight > _controlSize!.height
          ? _bound(yBounds.position, yBounds.min, yBounds.max)
          : -scaledImgHeight / 2;

      final currentX = _getTranslateX(nextMatrix);
      final currentY = _getTranslateY(nextMatrix);
      return _translate(nextMatrix, boundedX - currentX, boundedY - currentY);
    }

    return nextMatrix;
  }

  void _updateMatrix(Matrix4 newMatrix, {bool immediate = false}) {
    setState(() {
      _targetMatrix = newMatrix;
      if (immediate) {
        _currentMatrix = newMatrix;
      }
    });
    if (immediate) {
      _matrixAnimation = Matrix4Tween(begin: _currentMatrix, end: _targetMatrix).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.value = 1.0;
    } else {
      _matrixAnimation = Matrix4Tween(begin: _currentMatrix, end: _targetMatrix).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _currentMatrix = _matrixAnimation.value;
      _controller.value = 0.0;
      _controller.forward().then((_) {
        if (mounted) {
          setState(() {
            _currentMatrix = _targetMatrix;
          });
        }
      });
    }
  }

  double _initialScale = 1.0;
  double _initialZoom = 1.0;

  void _handleScaleStart(ScaleStartDetails details) {
    if (details.pointerCount != 2) return;
    _controller.stop();
    _currentMatrix = _matrixAnimation.value;
    _initialScale = 1.0;
    _initialZoom = _getScaleX(_currentMatrix);
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount != 2) return;
    _controller.stop();
    _currentMatrix = _matrixAnimation.value;

    final currentZoom = _getScaleX(_currentMatrix);
    final scaleChange = details.scale / _initialScale;

    if (scaleChange <= 0) return;

    double mergedMaxZoom;
    if (widget.maxZoom == null) {
      mergedMaxZoom = _controlSize != null && _imageSize != null
          ? math.max(_controlSize!.height / _imageSize!.height, _controlSize!.width / _imageSize!.width)
          : 1.0;
    } else {
      mergedMaxZoom = widget.maxZoom!;
    }

    final nextZoom = _initialZoom * scaleChange;
    final clampedZoom = _bound(nextZoom, 1.0, mergedMaxZoom);

    widget.onZoomChange?.call(clampedZoom);

    if (clampedZoom <= 1.0) {
      _updateMatrix(_createMatrix(), immediate: true);
      if (widget.dragLockRef != null) {
        widget.dragLockRef!.value = false;
      }
      return;
    }

    if (_controlSize == null) return;

    final focalPoint = details.focalPoint;
    final originOffsetX = focalPoint.dx - _controlSize!.width / 2;
    final originOffsetY = focalPoint.dy - _controlSize!.height / 2;

    var nextMatrix = _translate(_currentMatrix, -originOffsetX, -originOffsetY);
    nextMatrix = _scale(nextMatrix, clampedZoom / currentZoom);
    nextMatrix = _translate(nextMatrix, originOffsetX, originOffsetY);
    nextMatrix = _boundMatrix(nextMatrix, 'scale', last: false);

    _updateMatrix(nextMatrix, immediate: true);

    if (widget.dragLockRef != null) {
      widget.dragLockRef!.value = true;
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    final currentZoom = _getScaleX(_currentMatrix);
    double mergedMaxZoom;
    if (widget.maxZoom == null) {
      mergedMaxZoom = _controlSize != null && _imageSize != null
          ? math.max(_controlSize!.height / _imageSize!.height, _controlSize!.width / _imageSize!.width)
          : 1.0;
    } else {
      mergedMaxZoom = widget.maxZoom!;
    }

    final clampedZoom = _bound(currentZoom, 1.0, mergedMaxZoom);
    widget.onZoomChange?.call(clampedZoom);

    if (clampedZoom <= 1.0) {
      _updateMatrix(_createMatrix());
      if (widget.dragLockRef != null) {
        widget.dragLockRef!.value = false;
      }
    } else {
      final boundedMatrix = _boundMatrix(_currentMatrix, 'scale', last: true);
      _updateMatrix(boundedMatrix);
    }
  }

  void _handleTap() {
    final currentZoom = _getScaleX(_currentMatrix);
    if (currentZoom > 1.0) {
      _updateMatrix(_createMatrix());
      if (widget.dragLockRef != null) {
        widget.dragLockRef!.value = false;
      }
      widget.onZoomChange?.call(1.0);
    } else {
      widget.onTap?.call();
    }
  }

  ImageProvider _getImageProvider() {
    if (widget.image.startsWith('http://') || widget.image.startsWith('https://')) {
      return CachedNetworkImageProvider(widget.image);
    }
    return AssetImage(widget.image);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;

    return LayoutBuilder(
      builder: (context, constraints) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _updateSizes();
        });

        return GestureDetector(
          onTap: _handleTap,
          onScaleStart: _handleScaleStart,
          onScaleUpdate: _handleScaleUpdate,
          onScaleEnd: _handleScaleEnd,
          child: Container(
            key: _controlKey,
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            color: Colors.transparent,
            child: Center(
              child: AnimatedBuilder(
                animation: _matrixAnimation,
                builder: (context, child) {
                  return Transform(
                    transform: _matrixAnimation.value,
                    alignment: Alignment.center,
                    child: widget.imageRender != null
                        ? widget.imageRender!(
                            widget.image,
                            imageProvider: _getImageProvider(),
                            index: widget.index ?? 0,
                          )
                        : Image(
                            key: _imageKey,
                            image: _getImageProvider(),
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 200,
                                height: 200,
                                color: palette.surface,
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: palette.weak,
                                  size: spacing.lg,
                                ),
                              );
                            },
                          ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
