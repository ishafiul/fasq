import 'package:ecommerce/core/widgets/image_viewer/image_viewer.dart';
import 'package:flutter/material.dart';

class ImageViewerShowHandler {
  ImageViewerShowHandler({
    required this.close,
  });

  final VoidCallback close;
}

final Set<ImageViewerShowHandler> _handlerSet = <ImageViewerShowHandler>{};

ImageViewerShowHandler showImageViewer(
  BuildContext context,
  ImageViewerProps props,
) {
  clearImageViewer();

  bool visible = true;
  OverlayEntry? overlayEntry;

  void close() {
    debugPrint('[ImageViewer] close() called, visible: $visible');
    if (!visible) {
      debugPrint('[ImageViewer] Already closed, returning');
      return;
    }
    visible = false;
    debugPrint('[ImageViewer] Setting visible to false, marking overlay for rebuild');
    overlayEntry?.markNeedsBuild();
    Future.delayed(const Duration(milliseconds: 100), () {
      debugPrint('[ImageViewer] Removing overlay entry after delay');
      overlayEntry?.remove();
      _handlerSet.removeWhere((handler) => handler.close == close);
      props.afterClose?.call();
    });
  }

  final handler = ImageViewerShowHandler(close: close);

  overlayEntry = OverlayEntry(
    maintainState: true,
    builder: (overlayContext) {
      debugPrint('[ImageViewer] Overlay builder called, visible: $visible');
      return BackButtonListener(
        onBackButtonPressed: () async {
          debugPrint('[ImageViewer] BackButtonListener onBackButtonPressed called, visible: $visible');
          if (visible) {
            debugPrint('[ImageViewer] Calling close() from BackButtonListener');
            close();
            return true;
          }
          return false;
        },
        child: PopScope(
          canPop: !visible,
          onPopInvoked: (didPop) {
            debugPrint('[ImageViewer] PopScope onPopInvoked called, didPop: $didPop, visible: $visible');
            if (!didPop && visible) {
              debugPrint('[ImageViewer] Calling close() from PopScope');
              close();
            } else {
              debugPrint('[ImageViewer] PopScope: didPop=$didPop, visible=$visible, not closing');
            }
          },
          child: Positioned.fill(
            child: ImageViewer(
              props: ImageViewerProps(
                image: props.image,
                maxZoom: props.maxZoom,
                visible: visible,
                onClose: () {
                  debugPrint('[ImageViewer] onClose callback called from ImageViewer');
                  close();
                },
                afterClose: () {
                  debugPrint('[ImageViewer] afterClose callback called');
                  _handlerSet.remove(handler);
                  props.afterClose?.call();
                },
                renderFooter: props.renderFooter,
                imageRender: props.imageRender,
                mask: props.mask,
              ),
            ),
          ),
        ),
      );
    },
  );

  Overlay.of(context).insert(overlayEntry);
  _handlerSet.add(handler);

  return handler;
}

ImageViewerShowHandler showMultiImageViewer(
  BuildContext context,
  MultiImageViewerProps props,
) {
  clearImageViewer();

  bool visible = true;
  OverlayEntry? overlayEntry;

  void close() {
    debugPrint('[MultiImageViewer] close() called, visible: $visible');
    if (!visible) {
      debugPrint('[MultiImageViewer] Already closed, returning');
      return;
    }
    visible = false;
    debugPrint('[MultiImageViewer] Setting visible to false, marking overlay for rebuild');
    overlayEntry?.markNeedsBuild();
    Future.delayed(const Duration(milliseconds: 100), () {
      debugPrint('[MultiImageViewer] Removing overlay entry after delay');
      overlayEntry?.remove();
      _handlerSet.removeWhere((handler) => handler.close == close);
      props.afterClose?.call();
    });
  }

  final handler = ImageViewerShowHandler(close: close);

  overlayEntry = OverlayEntry(
    maintainState: true,
    builder: (overlayContext) {
      debugPrint('[MultiImageViewer] Overlay builder called, visible: $visible');
      return BackButtonListener(
        onBackButtonPressed: () async {
          debugPrint('[MultiImageViewer] BackButtonListener onBackButtonPressed called, visible: $visible');
          if (visible) {
            debugPrint('[MultiImageViewer] Calling close() from BackButtonListener');
            close();
            return true;
          }
          return false;
        },
        child: PopScope(
          canPop: !visible,
          onPopInvoked: (didPop) {
            debugPrint('[MultiImageViewer] PopScope onPopInvoked called, didPop: $didPop, visible: $visible');
            if (!didPop && visible) {
              debugPrint('[MultiImageViewer] Calling close() from PopScope');
              close();
            } else {
              debugPrint('[MultiImageViewer] PopScope: didPop=$didPop, visible=$visible, not closing');
            }
          },
          child: Positioned.fill(
            child: MultiImageViewer(
              props: MultiImageViewerProps(
                images: props.images,
                defaultIndex: props.defaultIndex,
                onIndexChange: props.onIndexChange,
                maxZoom: props.maxZoom,
                visible: visible,
                onClose: () {
                  debugPrint('[MultiImageViewer] onClose callback called from MultiImageViewer');
                  close();
                },
                afterClose: () {
                  debugPrint('[MultiImageViewer] afterClose callback called');
                  _handlerSet.remove(handler);
                  props.afterClose?.call();
                },
                renderFooter: props.renderFooter,
                imageRender: props.imageRender,
                mask: props.mask,
              ),
            ),
          ),
        ),
      );
    },
  );

  Overlay.of(context).insert(overlayEntry);
  _handlerSet.add(handler);

  return handler;
}

void clearImageViewer() {
  for (final handler in _handlerSet) {
    handler.close();
  }
  _handlerSet.clear();
}
