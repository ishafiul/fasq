import 'dart:async';

import 'package:ecommerce/core/colors.dart';
import 'package:flutter/material.dart';

/// An option for the [Segmented] widget.
///
/// The [value] can be any type [T], making the segmented control fully generic.
/// The [child] widget will be displayed in the segmented item and will receive
/// color styling based on selection state.
///
/// Example:
/// ```dart
/// SegmentedOption<String>(
///   value: "option1",
///   child: Text("Option 1"),
/// )
/// ```
class SegmentedOption<T> {
  const SegmentedOption({
    required this.value,
    required this.child,
    this.disabled = false,
  });

  /// The value associated with this option.
  /// Must be unique within the list of options.
  final T value;

  /// The widget to display for this option.
  ///
  /// This widget will receive color styling based on selection state:
  /// - Material [Icon] widgets will use [IconTheme] for coloring
  /// - [Text] widgets will use [DefaultTextStyle] for coloring
  /// - Widgets with explicit colors (e.g., `Container(color: Colors.red)`)
  ///   will preserve their colors and not be overridden
  /// - **SVG icons** need to be wrapped in [ColorFiltered] to respect the active color:
  ///   ```dart
  ///   SegmentedOption(
  ///     value: "option1",
  ///     child: ColorFiltered(
  ///       colorFilter: ColorFilter.mode(
  ///         Colors.blue, // This will be overridden by selection state
  ///         BlendMode.srcIn,
  ///       ),
  ///       child: SvgIcon(svg: Assets.icons.filled.home),
  ///     ),
  ///   )
  ///   ```
  final Widget child;

  /// Whether this option is disabled.
  /// Disabled options cannot be selected and will appear grayed out.
  final bool disabled;
}

/// A segmented control widget with an animated sliding thumb indicator.
///
/// This widget displays a list of options in a horizontal row with a sliding
/// background indicator that animates between selections. The widget is fully
/// generic, accepting any type [T] for option values.
///
/// **Color Styling:**
/// - Selected items use [activeColor] (or `palette.textPrimary` if not provided)
/// - Unselected items use `palette.textSecondary`
/// - Disabled items use `palette.weak`
/// - Colors are applied via [IconTheme] for Material icons and [DefaultTextStyle] for text
/// - Widgets with explicit colors (e.g., `Container(color: Colors.red)`) preserve
///   their colors and are not overridden
/// - **For SVG icons**: Wrap them in [ColorFiltered] to respect the active color:
///   ```dart
///   SegmentedOption(
///     value: "option1",
///     child: ColorFiltered(
///       colorFilter: ColorFilter.mode(
///         Colors.blue, // Will be overridden by selection state
///         BlendMode.srcIn,
///       ),
///       child: SvgIcon(svg: Assets.icons.filled.home),
///     ),
///   )
///   ```
///
/// **Animation:**
/// The thumb indicator animates smoothly between selections using a 300ms
/// cubic-bezier transition (0.645, 0.045, 0.355, 1.0).
///
/// Example with String values:
/// ```dart
/// Segmented<String>(
///   value: selectedValue,
///   onValueChanged: (value) => setState(() => selectedValue = value),
///   options: [
///     SegmentedOption(value: "option1", child: Text("Option 1")),
///     SegmentedOption(value: "option2", child: Text("Option 2")),
///   ],
/// )
/// ```
///
/// Example with custom active color and icons:
/// ```dart
/// Segmented<int>(
///   activeColor: Colors.blue,
///   block: true,
///   options: [
///     SegmentedOption(
///       value: 1,
///       child: Row(
///         mainAxisSize: MainAxisSize.min,
///         children: [
///           Icon(Icons.home),
///           SizedBox(width: 4),
///           Text("Home"),
///         ],
///       ),
///     ),
///   ],
/// )
/// ```
class Segmented<T> extends StatefulWidget {
  const Segmented({
    super.key,
    required this.options,
    this.value,
    this.onValueChanged,
    this.block = false,
    this.activeColor,
  });

  /// The list of options to display.
  /// Each option must have a unique [SegmentedOption.value].
  final List<SegmentedOption<T>> options;

  /// The currently selected value.
  /// Must match one of the [SegmentedOption.value] in [options].
  final T? value;

  /// Callback fired when a new option is selected.
  /// The callback receives the [SegmentedOption.value] of the selected option.
  final ValueChanged<T>? onValueChanged;

  /// Whether the segmented control should expand to fill available width.
  /// When `true`, the widget will take `double.infinity` width.
  /// When `false`, the widget will size itself based on content.
  final bool block;

  /// Custom color for the active/selected item.
  ///
  /// If not provided, uses `palette.textPrimary` as the default active color.
  /// This color is applied to:
  /// - Material [Icon] widgets via [IconTheme]
  /// - [Text] widgets via [DefaultTextStyle]
  /// - Does not override explicit colors in child widgets
  final Color? activeColor;

  @override
  State<Segmented<T>> createState() => _SegmentedState<T>();
}

class _SegmentedState<T> extends State<Segmented<T>> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  int? _selectedIndex;
  int? _previousIndex;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: const Cubic(0.645, 0.045, 0.355, 1.0),
    );
    _selectedIndex = _findIndex(widget.value);
    _previousIndex = _selectedIndex;
    if (_selectedIndex != null) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(covariant Segmented<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final newIndex = _findIndex(widget.value);
      if (newIndex != _selectedIndex) {
        _previousIndex = _selectedIndex;
        _selectedIndex = newIndex;
        unawaited(_controller.forward(from: 0.0));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _findIndex(T? value) {
    if (value == null) return null;
    for (int i = 0; i < widget.options.length; i++) {
      if (widget.options[i].value == value) {
        return i;
      }
    }
    return null;
  }

  Future<void> _handleSelection(T value) async {
    final newIndex = _findIndex(value);
    if (newIndex == null || newIndex == _selectedIndex) return;

    setState(() {
      _previousIndex = _selectedIndex;
      _selectedIndex = newIndex;
    });
    await _controller.forward(from: 0.0);
    widget.onValueChanged?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const containerPadding = 2.0;
    const borderRadius = 2.0;

    return Container(
      width: widget.block ? double.infinity : null,
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      padding: const EdgeInsets.all(containerPadding),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.maxWidth;
          final itemWidth = availableWidth / widget.options.length;

          return Stack(
            children: [
              if (_selectedIndex != null)
                _ThumbIndicator(
                  selectedIndex: _selectedIndex!,
                  previousIndex: _previousIndex,
                  itemWidth: itemWidth,
                  itemCount: widget.options.length,
                  animation: _animation,
                ),
              Row(
                mainAxisSize: widget.block ? MainAxisSize.max : MainAxisSize.min,
                children: List.generate(widget.options.length, (index) {
                  final option = widget.options[index];
                  final isSelected = _selectedIndex == index;
                  final isFirst = index == 0;
                  final isLast = index == widget.options.length - 1;

                  return Expanded(
                    child: _SegmentedItem<T>(
                      option: option,
                      isSelected: isSelected,
                      isFirst: isFirst,
                      isLast: isLast,
                      activeColor: widget.activeColor,
                      onTap: option.disabled ? null : () => _handleSelection(option.value),
                    ),
                  );
                }),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThumbIndicator extends StatelessWidget {
  const _ThumbIndicator({
    required this.selectedIndex,
    this.previousIndex,
    required this.itemWidth,
    required this.itemCount,
    required this.animation,
  });

  final int selectedIndex;
  final int? previousIndex;
  final double itemWidth;
  final int itemCount;
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const containerPadding = 2.0;
    const borderRadius = 2.0;
    const thumbPadding = 4.0;

    final thumbWidth = itemWidth - containerPadding * 2;
    final targetLeft = selectedIndex * itemWidth + containerPadding;
    final startLeft = previousIndex != null ? previousIndex! * itemWidth + containerPadding : targetLeft;

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        final thumbLeft = previousIndex != null ? (startLeft + (targetLeft - startLeft) * animation.value) : targetLeft;

        return Positioned(
          left: thumbLeft,
          top: thumbPadding,
          bottom: thumbPadding,
          width: thumbWidth,
          child: Container(
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(borderRadius),
            ),
          ),
        );
      },
    );
  }
}

class _SegmentedItem<T> extends StatelessWidget {
  const _SegmentedItem({
    required this.option,
    required this.isSelected,
    required this.isFirst,
    required this.isLast,
    this.activeColor,
    this.onTap,
  });

  final SegmentedOption<T> option;
  final bool isSelected;
  final bool isFirst;
  final bool isLast;
  final Color? activeColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    const horizontalPadding = 11.0;
    const verticalPadding = 4.0;

    final widgetColor = option.disabled
        ? palette.weak
        : isSelected
            ? (activeColor ?? palette.textPrimary)
            : palette.textSecondary;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        child: IconTheme(
          data: IconThemeData(color: widgetColor),
          child: DefaultTextStyle(
            style: TextStyle(color: widgetColor),
            child: option.child,
          ),
        ),
      ),
    );
  }
}
