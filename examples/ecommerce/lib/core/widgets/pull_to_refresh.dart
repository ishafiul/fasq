import 'dart:async';
import 'dart:math' as math;

import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/spinner/rotating_dots.dart';
import 'package:flutter/foundation.dart' show clampDouble;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// States of the pull-to-refresh widget.
enum _RefreshState {
  /// Idle state - not pulling.
  idle,

  /// User is pulling but hasn't reached threshold.
  drag,

  /// User has pulled enough to trigger refresh.
  armed,

  /// Refresh is in progress.
  refresh,

  /// Refresh completed successfully.
  done,
}

/// Custom scroll physics that allows overscroll at the top edge
class _RefreshScrollPhysics extends AlwaysScrollableScrollPhysics {
  const _RefreshScrollPhysics({super.parent});

  // Physics constants for progressive friction
  static const double _overscrollNormalizationFactor = 120.0;
  static const double _minFriction = 0.1;
  static const double _maxFriction = 0.52;
  static const double _frictionRange = 0.42;

  @override
  _RefreshScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _RefreshScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    // When overscrolling at top, apply progressive friction
    if (position.pixels < position.minScrollExtent && offset < 0.0) {
      final double overscrollPast = position.minScrollExtent - position.pixels;
      // Apply progressive friction that increases with overscroll
      final double normalizedOverscroll = math.min(overscrollPast / _overscrollNormalizationFactor, 1.0);
      final double friction = _maxFriction - (_frictionRange * normalizedOverscroll);
      return offset * math.max(friction, _minFriction);
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }
}

/// A custom pull-to-refresh widget that wraps scrollable content.
///
/// Usage:
/// ```dart
/// PullToRefresh(
///   onRefresh: () async {
///     await fetchData();
///   },
///   child: ListView.builder(...),
/// )
/// ```
class PullToRefresh extends StatefulWidget {
  const PullToRefresh({
    super.key,
    required this.onRefresh,
    required this.child,
    this.threshold = 50.0,
    this.color,
    this.textColor,
    this.loadingWidget,
    this.idleText = 'Pull to refresh',
    this.readyText = 'Release to refresh immediately',
    this.loadingText = 'Loading',
    this.successText = 'Refresh successful',
    this.successDuration = const Duration(seconds: 1),
  });

  /// Callback that is called when refresh is triggered.
  final Future<void> Function() onRefresh;

  /// The scrollable child widget.
  final Widget child;

  /// The pull distance threshold to trigger refresh. Defaults to 50.0.
  final double threshold;

  /// The indicator color. Defaults to palette.brand.
  final Color? color;

  /// The text color. Defaults to palette.textPrimary.
  final Color? textColor;

  /// Custom loading widget. Defaults to WaveDots.
  final Widget? loadingWidget;

  /// Text shown in idle state.
  final String idleText;

  /// Text shown in ready state.
  final String readyText;

  /// Text shown in loading state.
  final String loadingText;

  /// Text shown in success state.
  final String successText;

  /// Duration to show success message before hiding.
  final Duration successDuration;

  @override
  State<PullToRefresh> createState() => _PullToRefreshState();
}

class _PullToRefreshState extends State<PullToRefresh> with TickerProviderStateMixin {
  _RefreshState _status = _RefreshState.idle;
  double _dragOffset = 0.0;

  late AnimationController _positionController;
  late AnimationController _scaleController;
  late Animation<double> _scaleFactor;
  final ScrollController _scrollController = ScrollController();

  // Smooth animated layout extent for pushing content
  double _layoutExtent = 0.0;

  // Animation duration constants
  static const Duration _positionDuration = Duration(milliseconds: 200);
  static const Duration _scaleDuration = Duration(milliseconds: 300);
  static const Duration _dismissDuration = Duration(milliseconds: 250);

  // Drag and layout constants
  static const double _maxDragMultiplier = 1.5;
  static const double _layoutExtentMultiplier = 1.2;

  @override
  void initState() {
    super.initState();
    _positionController = AnimationController(vsync: this, duration: _positionDuration);
    _scaleController = AnimationController(vsync: this, duration: _scaleDuration);
    _scaleFactor = _scaleController.drive(CurveTween(curve: Curves.easeOut));

    _positionController.addListener(_updateLayoutExtent);
    _scaleController.addListener(_updateLayoutExtent);
  }

  /// Updates the layout extent based on current animation state.
  ///
  /// This method is called whenever the position or scale controllers change,
  /// ensuring smooth animation of the refresh indicator. The layout extent
  /// determines how much space the indicator takes, pushing content down.
  void _updateLayoutExtent() {
    if (!mounted) return;
    setState(() {
      // Don't recalculate when idle - layout extent should stay at 0
      if (_status == _RefreshState.idle) {
        _layoutExtent = 0.0;
        return;
      }

      // Calculate layout extent based on animation and state
      if (_isRefreshActive) {
        // During refresh/done: scale down smoothly during dismissal
        _layoutExtent = widget.threshold * (1.0 - _scaleFactor.value);
      } else if (_isDragActive) {
        // During drag: smoothly interpolate based on position controller
        _layoutExtent = _positionController.value * widget.threshold;
      }
    });
  }

  /// Returns true if the user is actively dragging (drag or armed state).
  bool get _isDragActive => _status == _RefreshState.drag || _status == _RefreshState.armed;

  /// Returns true if refresh is active or completed (refresh or done state).
  bool get _isRefreshActive => _status == _RefreshState.refresh || _status == _RefreshState.done;

  /// Resets all state variables to idle state.
  ///
  /// Should be called after animations complete to ensure clean state reset.
  void _resetStateToIdle() {
    setState(() {
      _status = _RefreshState.idle;
      _layoutExtent = 0.0;
      _dragOffset = 0.0;
    });
  }

  @override
  void dispose() {
    _positionController
      ..removeListener(_updateLayoutExtent)
      ..dispose();
    _scaleController
      ..removeListener(_updateLayoutExtent)
      ..dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Determines if pull-to-refresh should start based on scroll notification.
  ///
  /// Follows Flutter's RefreshIndicator pattern: checks for drag start/update
  /// notifications, downward scroll direction, and that we're at the top.
  bool _shouldStart(ScrollNotification notification) {
    // Follow Flutter's RefreshIndicator pattern exactly
    final bool result = ((notification is ScrollStartNotification && notification.dragDetails != null) ||
            (notification is ScrollUpdateNotification && notification.dragDetails != null)) &&
        notification.metrics.axisDirection == AxisDirection.down &&
        notification.metrics.extentBefore == 0.0 &&
        _status == _RefreshState.idle &&
        _start();

    return result;
  }

  /// Initializes drag state and resets animation controllers.
  ///
  /// Returns false if already in a non-idle state, preventing duplicate starts.
  bool _start() {
    if (_status != _RefreshState.idle) {
      return false;
    }
    _dragOffset = 0.0;
    _positionController.value = 0.0;
    _scaleController.value = 0.0;
    _layoutExtent = 0.0;
    return true;
  }

  /// Checks drag offset and updates state accordingly.
  ///
  /// Calculates the position factor based on drag distance and updates
  /// the animation controller. Also handles state transitions between
  /// drag and armed states based on threshold crossing.
  void _checkDragOffset(double containerExtent) {
    assert(_status == _RefreshState.drag || _status == _RefreshState.armed);

    // Calculate position factor based on drag offset
    // Use threshold as the reference for full extension
    final double targetValue = clampDouble(_dragOffset / widget.threshold, 0.0, _maxDragMultiplier);

    // Smoothly update position controller
    _positionController.value = targetValue;

    // Update layout extent for smooth content push
    _layoutExtent = math.min(_dragOffset, widget.threshold * _layoutExtentMultiplier);

    // Check if we should arm the refresh
    if (_status == _RefreshState.drag && _dragOffset >= widget.threshold) {
      setState(() {
        _status = _RefreshState.armed;
      });
    } else if (_status == _RefreshState.armed && _dragOffset < widget.threshold) {
      // Disarm if user pulls back above threshold
      setState(() {
        _status = _RefreshState.drag;
      });
    }
  }

  /// Handles drag progress updates from scroll notifications.
  ///
  /// Updates the drag offset based on scroll delta and checks if state
  /// transitions are needed (drag to armed or vice versa).
  void _handleDragProgress(double delta, double viewportDimension) {
    _dragOffset = math.max(0.0, _dragOffset - delta);
    _checkDragOffset(viewportDimension);
  }

  /// Dismisses the refresh indicator by animating back to idle state.
  ///
  /// Only dismisses if not in refresh/done state. Animates position controller
  /// back to zero before resetting state to ensure smooth transition.
  Future<void> _dismiss() async {
    if (_isRefreshActive) return;

    // Smoothly animate back to zero before resetting state
    await _positionController.animateTo(0.0, duration: _dismissDuration, curve: Curves.easeOutCubic);

    if (mounted && !_isRefreshActive) {
      _resetStateToIdle();
    }
  }

  /// Shows the refresh indicator and triggers the refresh callback.
  ///
  /// Transitions from armed to refresh state, animates to loading position,
  /// then calls the onRefresh callback. Handles errors gracefully by still
  /// transitioning to done state.
  Future<void> _show() async {
    assert(_status == _RefreshState.armed);
    _scaleController.value = 0.0;
    setState(() {
      _status = _RefreshState.refresh;
      _layoutExtent = widget.threshold;
    });

    // Animate to loading position
    await _positionController.animateTo(1.0, duration: _positionDuration, curve: Curves.easeOutCubic);

    if (!mounted || _status != _RefreshState.refresh) return;

    // Execute refresh callback with error handling
    try {
      await widget.onRefresh();
    } catch (error) {
      // Log error but still show success state
      // In production, you might want to show an error state instead
      debugPrint('PullToRefresh: Error during refresh: $error');
    } finally {
      // Always transition to done state, even on error
      if (mounted && _status == _RefreshState.refresh) {
        setState(() {
          _status = _RefreshState.done;
        });
        await _dismissAfterSuccess();
      }
    }
  }

  /// Dismisses the refresh indicator after successful refresh.
  ///
  /// Waits for success duration, then animates scale out for smooth dismissal,
  /// scrolls back to top if needed, and resets all state to idle.
  Future<void> _dismissAfterSuccess() async {
    await Future.delayed(widget.successDuration);
    if (!mounted) return;

    // Animate scale out for smooth dismissal - listener already added in initState
    await _scaleController.animateTo(1.0, duration: _scaleDuration, curve: Curves.easeOutCubic);
    if (!mounted) return;

    // Animate scroll back to top if needed
    if (_scrollController.hasClients && _scrollController.offset < 0) {
      await _scrollController.animateTo(0.0, duration: _positionDuration, curve: Curves.easeOut);
    }
    if (!mounted) return;

    _resetStateToIdle();

    // Now safe to reset animation controllers
    _positionController.value = 0.0;
    _scaleController.value = 0.0;
  }

  /// Handles scroll notifications to manage pull-to-refresh state.
  ///
  /// Processes different notification types:
  /// - ScrollStart/Update: Initiates drag or updates progress
  /// - Overscroll: Updates drag progress during overscroll
  /// - ScrollEnd: Triggers refresh or dismiss based on state
  bool _handleScrollNotification(ScrollNotification notification) {
    if (_shouldStart(notification)) {
      setState(() {
        _status = _RefreshState.drag;
      });
      return false;
    }

    if (_status == _RefreshState.idle) {
      return false;
    }

    if (notification.metrics.axisDirection != AxisDirection.down && _isDragActive) {
      unawaited(_dismiss());
      return false;
    }

    if (notification is ScrollUpdateNotification && _isDragActive) {
      _handleDragProgress(notification.scrollDelta ?? 0.0, notification.metrics.viewportDimension);
    } else if (notification is OverscrollNotification && _isDragActive) {
      _handleDragProgress(notification.overscroll, notification.metrics.viewportDimension);
    } else if (notification is ScrollEndNotification) {
      unawaited(_handleScrollEnd());
    }

    return false;
  }

  /// Handles scroll end notification by triggering appropriate action.
  ///
  /// If armed (past threshold), triggers refresh. If still dragging (below threshold),
  /// dismisses the indicator. Other states require no action.
  Future<void> _handleScrollEnd() async {
    switch (_status) {
      case _RefreshState.armed:
        await _show();
      case _RefreshState.drag:
        await _dismiss();
      case _RefreshState.refresh:
      case _RefreshState.done:
      case _RefreshState.idle:
        break;
    }
  }

  /// Handles overscroll indicator notifications to prevent default glow effect.
  ///
  /// Disallows the default overscroll indicator when actively dragging
  /// to provide a cleaner visual experience.
  bool _handleIndicatorNotification(OverscrollIndicatorNotification notification) {
    if (notification.depth != 0 || !notification.leading) {
      return false;
    }
    if (_isDragActive) {
      notification.disallowIndicator();
      return true;
    }
    return false;
  }

  /// Builds the indicator content widget with current state and configuration.
  Widget _buildIndicatorContent() {
    return _PullToRefreshIndicator(
      status: _status,
      dragOffset: _dragOffset,
      threshold: widget.threshold,
      scaleFactor: _scaleFactor.value,
      color: widget.color,
      textColor: widget.textColor,
      loadingWidget: widget.loadingWidget,
      idleText: widget.idleText,
      readyText: widget.readyText,
      loadingText: widget.loadingText,
      successText: widget.successText,
    );
  }

  /// Builds the indicator sliver that manages layout and animation.
  ///
  /// The sliver is always present in the tree but has zero size when idle,
  /// preventing layout jumps when the indicator appears/disappears.
  Widget _buildIndicatorSliver() {
    final bool isActive = _status != _RefreshState.idle;
    return _SliverRefreshIndicator(
      refreshIndicatorExtent: widget.threshold,
      hasLayoutExtent: _isRefreshActive,
      layoutExtent: _layoutExtent,
      isActive: isActive,
      child: isActive ? _buildIndicatorContent() : const SizedBox.shrink(),
    );
  }

  /// Builds the list of slivers for the CustomScrollView.
  ///
  /// Always includes the indicator sliver first, followed by the converted child.
  /// Handles different widget types:
  /// - ListView: Converts to SliverList with padding
  /// - CustomScrollView: Extracts existing slivers
  /// - Other widgets: Wraps in SliverToBoxAdapter
  List<Widget> _buildSlivers() {
    final List<Widget> slivers = [_buildIndicatorSliver()];

    // Convert child to slivers based on type
    if (widget.child is ListView) {
      final listView = widget.child as ListView;
      slivers.add(_ListViewToSliverAdapter(listView: listView));
    } else if (widget.child is CustomScrollView) {
      final customScrollView = widget.child as CustomScrollView;
      slivers.addAll(customScrollView.slivers);
    } else {
      slivers.add(SliverToBoxAdapter(child: widget.child));
    }

    return slivers;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _handleScrollNotification,
      child: NotificationListener<OverscrollIndicatorNotification>(
        onNotification: _handleIndicatorNotification,
        child: CustomScrollView(
          controller: _scrollController,
          physics: const _RefreshScrollPhysics(),
          slivers: _buildSlivers(),
        ),
      ),
    );
  }
}

/// Adapter to convert ListView to SliverList
class _ListViewToSliverAdapter extends StatelessWidget {
  const _ListViewToSliverAdapter({required this.listView});

  final ListView listView;

  @override
  Widget build(BuildContext context) {
    final padding = listView.padding ?? EdgeInsets.zero;
    return SliverPadding(padding: padding, sliver: SliverList(delegate: listView.childrenDelegate));
  }
}

/// Custom sliver that displays the refresh indicator
class _SliverRefreshIndicator extends SingleChildRenderObjectWidget {
  const _SliverRefreshIndicator({
    required this.refreshIndicatorExtent,
    required this.hasLayoutExtent,
    required this.layoutExtent,
    required this.isActive,
    super.child,
  });

  final double refreshIndicatorExtent;
  final bool hasLayoutExtent;
  final double layoutExtent;
  final bool isActive;

  @override
  _RenderSliverRefreshIndicator createRenderObject(BuildContext context) {
    return _RenderSliverRefreshIndicator(
      refreshIndicatorExtent: refreshIndicatorExtent,
      hasLayoutExtent: hasLayoutExtent,
      layoutExtent: layoutExtent,
      isActive: isActive,
    );
  }

  @override
  void updateRenderObject(BuildContext context, _RenderSliverRefreshIndicator renderObject) {
    renderObject
      ..refreshIndicatorExtent = refreshIndicatorExtent
      ..hasLayoutExtent = hasLayoutExtent
      ..layoutExtent = layoutExtent
      ..isActive = isActive;
  }
}

/// Render object for the refresh indicator sliver
class _RenderSliverRefreshIndicator extends RenderSliverSingleBoxAdapter {
  _RenderSliverRefreshIndicator({
    required double refreshIndicatorExtent,
    required bool hasLayoutExtent,
    required double layoutExtent,
    required bool isActive,
  })  : _refreshIndicatorExtent = refreshIndicatorExtent,
        _hasLayoutExtent = hasLayoutExtent,
        _layoutExtent = layoutExtent,
        _isActive = isActive;

  double _refreshIndicatorExtent;
  bool _hasLayoutExtent;
  double _layoutExtent;
  bool _isActive;

  double get refreshIndicatorExtent => _refreshIndicatorExtent;
  set refreshIndicatorExtent(double value) {
    if (_refreshIndicatorExtent == value) return;
    _refreshIndicatorExtent = value;
    markNeedsLayout();
  }

  bool get hasLayoutExtent => _hasLayoutExtent;
  set hasLayoutExtent(bool value) {
    if (_hasLayoutExtent == value) return;
    _hasLayoutExtent = value;
    markNeedsLayout();
  }

  double get layoutExtent => _layoutExtent;
  set layoutExtent(double value) {
    if (_layoutExtent == value) return;
    _layoutExtent = value;
    markNeedsLayout();
  }

  bool get isActive => _isActive;
  set isActive(bool value) {
    if (_isActive == value) return;
    _isActive = value;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    final SliverConstraints constraints = this.constraints;

    // When not active, use zero geometry but still participate in layout
    if (!_isActive && _layoutExtent <= 0.0) {
      geometry = SliverGeometry.zero;
      return;
    }

    // Use the pre-calculated layout extent for smooth animation
    final double effectiveLayoutExtent = _layoutExtent;

    // Layout the child with the current extent
    if (child != null) {
      final double childHeight = math.max(effectiveLayoutExtent, _refreshIndicatorExtent);
      child!.layout(constraints.asBoxConstraints(maxExtent: childHeight), parentUsesSize: true);
    }

    // Paint extent matches layout extent for pushing content
    final double paintExtent = math.min(effectiveLayoutExtent, constraints.remainingPaintExtent);

    // Scroll extent only during refresh/done states
    final double scrollExtent = _hasLayoutExtent ? effectiveLayoutExtent : 0.0;

    geometry = SliverGeometry(
      scrollExtent: scrollExtent,
      paintExtent: paintExtent,
      maxPaintExtent: math.max(effectiveLayoutExtent, _refreshIndicatorExtent),
      layoutExtent: paintExtent, // Content pushed down by this amount
    );
  }
}

/// Internal widget that displays the pull-to-refresh indicator.
class _PullToRefreshIndicator extends StatelessWidget {
  const _PullToRefreshIndicator({
    required this.status,
    required this.dragOffset,
    required this.threshold,
    required this.scaleFactor,
    this.color,
    this.textColor,
    this.loadingWidget,
    required this.idleText,
    required this.readyText,
    required this.loadingText,
    required this.successText,
  });

  // Animation constants for opacity and scale calculations
  static const double _scaleDownFactor = 0.2;
  static const double _opacityBoostFactor = 1.5;
  static const double _minScale = 0.9;
  static const double _scaleRange = 0.1;
  static const double _maxOpacity = 1.0;
  static const double _minOpacity = 0.0;

  // Animation durations
  static const Duration _opacityAnimationDuration = Duration(milliseconds: 100);
  static const Duration _scaleAnimationDuration = Duration(milliseconds: 150);

  final _RefreshState status;
  final double dragOffset;
  final double threshold;
  final double scaleFactor;
  final Color? color;
  final Color? textColor;
  final Widget? loadingWidget;
  final String idleText;
  final String readyText;
  final String loadingText;
  final String successText;

  String get _stateText {
    switch (status) {
      case _RefreshState.idle:
        return '';
      case _RefreshState.drag:
        return idleText;
      case _RefreshState.armed:
        return readyText;
      case _RefreshState.refresh:
        return loadingText;
      case _RefreshState.done:
        return successText;
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;
    final typography = context.typography;
    final textColorResolved = textColor ?? palette.textPrimary;
    final iconColor = color ?? palette.brand;

    // Don't render anything in idle state
    if (status == _RefreshState.idle) {
      return const SizedBox.shrink();
    }

    // Calculate opacity and scale based on state
    final double finalOpacity;
    final double finalScale;

    if (status == _RefreshState.refresh || status == _RefreshState.done) {
      // During refresh and done states, always show at full opacity
      // Apply scale factor only during dismissal (done state with scaleFactor > 0)
      finalOpacity = _maxOpacity * (1.0 - scaleFactor);
      finalScale = 1.0 - (scaleFactor * _scaleDownFactor);
    } else {
      // During drag and armed states, fade in smoothly
      // Start at 0 and reach full opacity as user drags
      final double progress = dragOffset > 0 ? math.min(dragOffset / threshold, 1.0) : 0.0;
      finalOpacity = clampDouble(progress * _opacityBoostFactor, _minOpacity, _maxOpacity);
      finalScale = _minScale + (progress * _scaleRange);
    }

    final textStyle = typography.labelSmall.toTextStyle(color: textColorResolved);
    return AnimatedOpacity(
      opacity: finalOpacity,
      duration: _opacityAnimationDuration,
      child: AnimatedScale(
        scale: finalScale,
        duration: _scaleAnimationDuration,
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: spacing.sm),
          decoration: BoxDecoration(
            color: palette.surface,
            boxShadow: [
              BoxShadow(color: palette.border.withValues(alpha: 0.15), blurRadius: 4, offset: const Offset(0, 2)),
            ],
          ),
          child: _buildIndicatorChild(textStyle, iconColor, spacing),
        ),
      ),
    );
  }

  Widget _buildIndicatorChild(TextStyle textStyle, Color iconColor, Spacing spacing) {
    if (status == _RefreshState.refresh) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(_stateText, style: textStyle, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis),
          SizedBox(width: spacing.xs),
          loadingWidget ?? WaveDots(color: iconColor, size: spacing.md),
        ],
      );
    }

    return Text(_stateText, style: textStyle, textAlign: TextAlign.center, overflow: TextOverflow.ellipsis);
  }
}
