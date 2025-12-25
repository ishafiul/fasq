import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/image_viewer/slide.dart';
import 'package:ecommerce/core/widgets/image_viewer/slides.dart';
import 'package:ecommerce/core/widgets/svg_icon.dart';
import 'package:ecommerce/gen/assets.gen.dart';
import 'package:flutter/material.dart';

class _FastMask extends StatefulWidget {
  const _FastMask({
    required this.visible,
    this.onMaskClick,
    this.afterClose,
    this.child,
  });

  final bool visible;
  final VoidCallback? onMaskClick;
  final VoidCallback? afterClose;
  final Widget? child;

  @override
  State<_FastMask> createState() => _FastMaskState();
}

class _FastMaskState extends State<_FastMask> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  bool _active = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );

    _opacityAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );

    _controller.addStatusListener(_handleAnimationStatus);

    if (widget.visible) {
      _active = true;
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_FastMask oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.visible != oldWidget.visible) {
      if (widget.visible) {
        _active = true;
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (!mounted) return;

    if (status == AnimationStatus.reverse && _controller.value == 0) {
      setState(() {
        _active = false;
      });
      widget.afterClose?.call();
    }
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  Color _getBackgroundColor() {
    return Colors.black;
  }

  double _getOpacity() {
    return 0.75;
  }

  @override
  Widget build(BuildContext context) {
    if (!_active) {
      return const SizedBox.shrink();
    }

    final backgroundColor = _getBackgroundColor();
    final opacity = _getOpacity();
    final effectiveOpacity = _opacityAnimation.value * opacity;
    final screenSize = MediaQuery.of(context).size;

    return IgnorePointer(
      ignoring: !widget.visible,
      child: Material(
        type: MaterialType.transparency,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              right: 0,
              bottom: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: widget.onMaskClick,
                child: Container(
                  width: screenSize.width,
                  height: screenSize.height,
                  color: backgroundColor.withValues(alpha: effectiveOpacity),
                ),
              ),
            ),
            if (widget.child != null)
              Positioned.fill(
                child: IgnorePointer(
                  ignoring: false,
                  child: widget.child!,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class ImageViewerProps {
  const ImageViewerProps({
    required this.image,
    this.maxZoom = 3.0,
    this.visible = true,
    this.onClose,
    this.afterClose,
    this.renderFooter,
    this.imageRender,
    this.mask,
  });

  final String image;
  final double maxZoom;
  final bool visible;
  final VoidCallback? onClose;
  final VoidCallback? afterClose;
  final Widget Function(String image)? renderFooter;
  final Widget Function(String image, {required GlobalKey imageKey, required int index})? imageRender;
  final MaskProps? mask;
}

class MaskProps {
  const MaskProps({
    this.onClick,
  });

  final void Function()? onClick;
}

class ImageViewer extends StatelessWidget {
  const ImageViewer({
    super.key,
    required this.props,
  });

  final ImageViewerProps props;

  @override
  Widget build(BuildContext context) {
    debugPrint('[ImageViewer] build() called, visible: ${props.visible}');
    return _FastMask(
      visible: props.visible,
      onMaskClick: () {
        debugPrint('[ImageViewer] Mask clicked, calling onClose');
        (props.mask?.onClick ?? props.onClose)?.call();
      },
      afterClose: props.afterClose,
      child: Stack(
        children: [
          Positioned.fill(
            child: Slide(
              image: props.image,
              maxZoom: props.maxZoom,
              imageRender: props.imageRender != null
                  ? (image, {required imageKey, required index}) {
                      return props.imageRender!(image, imageKey: imageKey, index: index);
                    }
                  : null,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: _CloseButton(
              onTap: props.onClose,
            ),
          ),
          if (props.renderFooter != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: props.renderFooter!(props.image),
              ),
            ),
        ],
      ),
    );
  }
}

class MultiImageViewerProps {
  const MultiImageViewerProps({
    required this.images,
    this.defaultIndex = 0,
    this.onIndexChange,
    this.maxZoom = 3.0,
    this.visible = true,
    this.onClose,
    this.afterClose,
    this.renderFooter,
    this.imageRender,
    this.mask,
  });

  final List<String> images;
  final int defaultIndex;
  final ValueChanged<int>? onIndexChange;
  final double maxZoom;
  final bool visible;
  final VoidCallback? onClose;
  final VoidCallback? afterClose;
  final Widget Function(String image, int index)? renderFooter;
  final Widget Function(String image, {required GlobalKey imageKey, required int index})? imageRender;
  final MaskProps? mask;
}

class MultiImageViewer extends StatefulWidget {
  const MultiImageViewer({
    super.key,
    required this.props,
  });

  final MultiImageViewerProps props;

  @override
  State<MultiImageViewer> createState() => _MultiImageViewerState();
}

class _MultiImageViewerState extends State<MultiImageViewer> {
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.props.defaultIndex;
  }

  void _onIndexChange(int index) {
    setState(() {
      _currentIndex = index;
    });
    widget.props.onIndexChange?.call(index);
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('[MultiImageViewer] build() called, visible: ${widget.props.visible}');
    return _FastMask(
      visible: widget.props.visible,
      onMaskClick: () {
        debugPrint('[MultiImageViewer] Mask clicked, calling onClose');
        (widget.props.mask?.onClick ?? widget.props.onClose)?.call();
      },
      afterClose: widget.props.afterClose,
      child: Stack(
        children: [
          Positioned.fill(
            child: Slides(
              images: widget.props.images,
              defaultIndex: widget.props.defaultIndex,
              onIndexChange: _onIndexChange,
              onTap: null,
              maxZoom: widget.props.maxZoom,
              imageRender: widget.props.imageRender,
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: _CloseButton(
              onTap: widget.props.onClose,
            ),
          ),
          if (widget.props.renderFooter != null && widget.props.images.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                child: widget.props.renderFooter!(
                  widget.props.images[_currentIndex],
                  _currentIndex,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({
    required this.onTap,
  });

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final spacing = context.spacing;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(spacing.xs),
        child: Container(
          padding: EdgeInsets.all(spacing.xs),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(spacing.xs),
          ),
          child: SvgIcon(
            svg: Assets.icons.filled.closeCircle,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
