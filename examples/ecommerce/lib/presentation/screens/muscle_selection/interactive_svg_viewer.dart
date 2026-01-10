import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/presentation/screens/muscle_selection/services/svg_loader.dart' as svg_loader;
import 'package:ecommerce/presentation/screens/muscle_selection/services/svg_parser.dart';
import 'package:ecommerce/presentation/screens/muscle_selection/services/svg_style_applier.dart';
import 'package:ecommerce/presentation/screens/muscle_selection/svg_interaction_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A reusable widget for displaying and interacting with SVG diagrams.
///
/// This widget handles SVG loading, parsing, rendering, and tap interactions.
/// It automatically creates and manages the [SvgInteractionController] internally,
/// or accepts an existing controller. The controller is exposed via [onControllerReady]
/// callback when it's initialized.
///
/// Example:
/// ```dart
/// InteractiveSvgViewer(
///   svgPath: 'assets/images/muscle_diagram.svg',
///   filter: const SvgGroupFilter.byClass('muscle'),
///   selectedFillColor: '#00FF88',
///   unselectedFillColor: '#3A3A3A',
///   onControllerReady: (controller) {
///     // Use controller to manage selections
///   },
/// )
/// ```
class InteractiveSvgViewer extends StatefulWidget {
  const InteractiveSvgViewer({
    super.key,
    this.controller,
    required this.svgPath,
    this.filter,
    this.selectedFillColor = '#00FF88',
    this.unselectedFillColor = '#3A3A3A',
    this.className = 'muscle',
    this.minScale = 0.5,
    this.maxScale = 3.0,
    this.onTap,
    this.onControllerReady,
  });

  /// Optional controller. If not provided, the widget will create one internally.
  final SvgInteractionController? controller;

  /// Path to the SVG asset file.
  final String svgPath;

  /// Filter for parsing SVG groups. If not provided, all groups with IDs will be parsed.
  final SvgGroupFilter? filter;

  /// Fill color for selected elements.
  final String selectedFillColor;

  /// Fill color for unselected elements.
  final String unselectedFillColor;

  /// CSS class name to filter elements (used for styling).
  final String className;

  /// Minimum zoom scale for InteractiveViewer.
  final double minScale;

  /// Maximum zoom scale for InteractiveViewer.
  final double maxScale;

  /// Optional callback when an element is tapped (called after controller handles the tap).
  final void Function(String? elementId)? onTap;

  /// Callback fired when the controller is ready (only when controller is created internally).
  final void Function(SvgInteractionController controller)? onControllerReady;

  @override
  State<InteractiveSvgViewer> createState() => _InteractiveSvgViewerState();
}

class _InteractiveSvgViewerState extends State<InteractiveSvgViewer> {
  final TransformationController _transformationController = TransformationController();
  SvgInteractionController? _internalController;
  String? _svgString;
  final GlobalKey _svgKey = GlobalKey();
  final GlobalKey _viewerKey = GlobalKey();
  bool _isInitialized = false;

  SvgInteractionController? get _controller => widget.controller ?? _internalController;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  @override
  void didUpdateWidget(InteractiveSvgViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
    }
    if (oldWidget.svgPath != widget.svgPath || oldWidget.filter != widget.filter) {
      _initialize();
    }
  }

  @override
  void dispose() {
    widget.controller?.removeListener(_onControllerChanged);
    _internalController?.removeListener(_onControllerChanged);
    _internalController?.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _initialize() async {
    if (widget.controller != null) {
      widget.controller!.addListener(_onControllerChanged);
      await _loadSvgString();
      return;
    }

    if (_isInitialized) return;
    _isInitialized = true;

    final result = await svg_loader.SvgLoader.loadAndParse(
      context: context,
      svgPath: widget.svgPath,
      filter: widget.filter,
    );

    if (!mounted || result == null) return;

    final controller = SvgInteractionController(
      elements: result.elements,
      viewBox: result.viewBox,
    );
    controller.addListener(_onControllerChanged);

    setState(() {
      _svgString = result.svgString;
      _internalController = controller;
    });

    widget.onControllerReady?.call(controller);
  }

  Future<void> _loadSvgString() async {
    final svgString = await svg_loader.SvgLoader.loadString(
      context: context,
      svgPath: widget.svgPath,
    );

    if (mounted && svgString != null) {
      setState(() {
        _svgString = svgString;
      });
    }
  }

  String _applyElementStyles(String svgString) {
    final controller = _controller;
    if (controller == null) return svgString;

    return SvgStyleApplier.applySelectionStyles(
      svgString: svgString,
      selectedIds: controller.selectedIds,
      allIds: controller.elementMap.keys,
      className: widget.className,
      selectedFillColor: widget.selectedFillColor,
      unselectedFillColor: widget.unselectedFillColor,
    );
  }

  void _handleTap(TapDownDetails details) {
    final controller = _controller;
    if (controller == null) return;

    final viewerRenderBox = _viewerKey.currentContext?.findRenderObject() as RenderBox?;
    final svgRenderBox = _svgKey.currentContext?.findRenderObject() as RenderBox?;
    if (viewerRenderBox == null || svgRenderBox == null) return;

    final tappedElementId = controller.handleTap(
      globalPosition: details.globalPosition,
      viewerRenderBox: viewerRenderBox,
      svgRenderBox: svgRenderBox,
      transformation: _transformationController.value,
    );

    widget.onTap?.call(tappedElementId);
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null || _svgString == null) {
      final palette = context.palette;
      return Center(
        child: CircularProgressSpinner(
          color: palette.brand,
          size: 48,
        ),
      );
    }

    return InteractiveViewer(
      key: _viewerKey,
      transformationController: _transformationController,
      minScale: widget.minScale,
      maxScale: widget.maxScale,
      child: GestureDetector(
        onTapDown: _handleTap,
        child: SvgPicture.string(
          _applyElementStyles(_svgString!),
          key: _svgKey,
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
