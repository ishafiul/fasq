import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/image_viewer/slide.dart';
import 'package:flutter/material.dart';

class Slides extends StatefulWidget {
  const Slides({
    super.key,
    required this.images,
    required this.defaultIndex,
    required this.onIndexChange,
    required this.onTap,
    required this.maxZoom,
    this.imageRender,
  });

  final List<String> images;
  final int defaultIndex;
  final ValueChanged<int>? onIndexChange;
  final VoidCallback? onTap;
  final double maxZoom;
  final Widget Function(String image, {required GlobalKey imageKey, required int index})? imageRender;

  @override
  State<Slides> createState() => _SlidesState();
}

class _SlidesState extends State<Slides> {
  late PageController _pageController;
  late int _currentIndex;
  final ValueNotifier<bool> _dragLockRef = ValueNotifier<bool>(false);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.defaultIndex;
    _pageController = PageController(initialPage: widget.defaultIndex);
  }

  @override
  void didUpdateWidget(Slides oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.defaultIndex != widget.defaultIndex && _currentIndex != widget.defaultIndex) {
      _currentIndex = widget.defaultIndex;
      _pageController.jumpToPage(widget.defaultIndex);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _dragLockRef.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    if (_currentIndex != index) {
      setState(() {
        _currentIndex = index;
      });
      widget.onIndexChange?.call(index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final typography = context.typography;

    return Stack(
      children: [
        ValueListenableBuilder<bool>(
          valueListenable: _dragLockRef,
          builder: (context, isLocked, child) {
            return PageView.builder(
              controller: _pageController,
              physics: isLocked ? const NeverScrollableScrollPhysics() : const PageScrollPhysics(),
              itemCount: widget.images.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                return Slide(
                  image: widget.images[index],
                  maxZoom: widget.maxZoom,
                  onTap: widget.onTap,
                  dragLockRef: _dragLockRef,
                  imageRender: widget.imageRender,
                  index: index,
                  onZoomChange: (zoom) {
                    if (zoom > 1.0) {
                      _dragLockRef.value = true;
                    } else {
                      _dragLockRef.value = false;
                    }
                  },
                );
              },
            );
          },
        ),
        if (widget.images.length > 1)
          Positioned(
            top: 12,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: context.spacing.sm,
                  vertical: context.spacing.xs,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(context.radius.sm),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.images.length}',
                  style: typography.bodySmall.toTextStyle(color: Colors.white),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
