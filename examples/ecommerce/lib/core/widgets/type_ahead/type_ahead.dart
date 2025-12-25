import 'dart:async';

import 'package:ecommerce/core/colors.dart';
import 'package:ecommerce/core/const.dart';
import 'package:ecommerce/core/widgets/spinner/circular_progress.dart';
import 'package:ecommerce/core/widgets/type_ahead/type_ahead_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

export 'type_ahead_controller.dart';

/// Direction for the suggestions box.
enum SuggestionsDirection {
  /// Show suggestions above the input.
  up,

  /// Show suggestions below the input.
  down,

  /// Automatically determine based on available space.
  auto,
}

/// Builder for the text input field.
typedef TypeAheadFieldBuilder = Widget Function(
  BuildContext context,
  TextEditingController controller,
  FocusNode focusNode,
);

/// Builder for rendering a single suggestion item.
typedef TypeAheadItemBuilder<T> = Widget Function(
  BuildContext context,
  T item,
);

/// Builder for custom suggestions list layout.
typedef TypeAheadListBuilder = Widget Function(
  BuildContext context,
  List<Widget> children,
);

/// Builder for error state widget.
typedef TypeAheadErrorBuilder = Widget Function(
  BuildContext context,
  Object error,
);

/// A type-safe typeahead (autocomplete) widget.
///
/// Features:
/// - Generic type parameter for suggestions
/// - Debounced suggestions callback
/// - Loading, error, and empty states
/// - Customizable suggestion item rendering
/// - Keyboard navigation support
/// - Overlay suggestions box with auto-positioning
///
/// Usage:
/// ```dart
/// TypeAhead<Product>(
///   suggestionsCallback: (pattern) async {
///     return await productService.search(pattern);
///   },
///   itemBuilder: (context, product) {
///     return ListTile(
///       title: Text(product.name),
///       subtitle: Text(product.price.toString()),
///     );
///   },
///   onSelected: (product) {
///     Navigator.push(context, ProductDetailRoute(product: product));
///   },
///   placeholder: 'Search products...',
/// )
/// ```
class TypeAhead<T> extends StatefulWidget {
  const TypeAhead({
    super.key,
    required this.suggestionsCallback,
    required this.itemBuilder,
    required this.onSelected,
    this.builder,
    this.listBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.minCharsForSuggestions = 0,
    this.hideOnEmpty = true,
    this.hideOnLoading = false,
    this.hideOnError = false,
    this.direction = SuggestionsDirection.auto,
    this.controller,
    this.placeholder,
    this.autoFlipDirection = true,
    this.suggestionsBoxMaxHeight = 300,
    this.suggestionsBoxDecoration,
    this.keepSuggestionsOnSelect = false,
    this.retainOnLoading = true,
    this.showMask = true,
    this.maskColor,
    this.maskOpacity = 0,
  });

  /// Async function to fetch suggestions based on search pattern.
  final Future<List<T>> Function(String pattern) suggestionsCallback;

  /// Builder for each suggestion item.
  final TypeAheadItemBuilder<T> itemBuilder;

  /// Called when a suggestion is selected.
  final void Function(T item) onSelected;

  /// Optional custom builder for the input field.
  final TypeAheadFieldBuilder? builder;

  /// Optional custom builder for the suggestions list layout.
  final TypeAheadListBuilder? listBuilder;

  /// Optional loading widget. Defaults to a spinner.
  final WidgetBuilder? loadingBuilder;

  /// Optional error widget builder.
  final TypeAheadErrorBuilder? errorBuilder;

  /// Optional empty state widget.
  final WidgetBuilder? emptyBuilder;

  /// Duration to debounce input before triggering suggestions callback.
  final Duration debounceDuration;

  /// Minimum characters required before triggering suggestions.
  final int minCharsForSuggestions;

  /// Hide suggestions box when there are no results.
  final bool hideOnEmpty;

  /// Hide suggestions box while loading.
  final bool hideOnLoading;

  /// Hide suggestions box on error.
  final bool hideOnError;

  /// Direction to show the suggestions box.
  final SuggestionsDirection direction;

  /// Optional controller for programmatic control.
  final TypeAheadController<T>? controller;

  /// Placeholder text for the input field.
  final String? placeholder;

  /// Whether to automatically flip direction if not enough space.
  final bool autoFlipDirection;

  /// Maximum height of the suggestions box.
  final double suggestionsBoxMaxHeight;

  /// Custom decoration for the suggestions box.
  final BoxDecoration? suggestionsBoxDecoration;

  /// Whether to keep suggestions visible after selection.
  final bool keepSuggestionsOnSelect;

  /// Whether to retain previous suggestions while loading new ones.
  final bool retainOnLoading;

  /// Whether to show a semi-transparent mask behind the suggestions.
  final bool showMask;

  /// Custom mask background color. Defaults to black.
  final Color? maskColor;

  /// Mask opacity value (0.0 to 1.0). Defaults to 0.35.
  final double maskOpacity;

  @override
  State<TypeAhead<T>> createState() => _TypeAheadState<T>();
}

class _TypeAheadState<T> extends State<TypeAhead<T>> {
  late TextEditingController _textController;
  late FocusNode _focusNode;
  late TypeAheadController<T> _controller;
  Timer? _debounceTimer;
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  int _selectedIndex = -1;
  bool _isControllerOwned = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();

    _controller = widget.controller ?? TypeAheadController<T>();
    _isControllerOwned = widget.controller == null;

    _controller.onRefresh = _refreshSuggestions;
    _focusNode.addListener(_onFocusChange);
    _textController.addListener(_onTextChange);
  }

  @override
  void didUpdateWidget(covariant TypeAhead<T> oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.controller != oldWidget.controller) {
      if (_isControllerOwned) {
        _controller.dispose();
      }
      _controller = widget.controller ?? TypeAheadController<T>();
      _isControllerOwned = widget.controller == null;
      _controller.onRefresh = _refreshSuggestions;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _hideOverlay();
    _focusNode.removeListener(_onFocusChange);
    _textController.removeListener(_onTextChange);
    _textController.dispose();
    _focusNode.dispose();
    if (_isControllerOwned) {
      _controller.dispose();
    }
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      // Only show overlay and fetch suggestions if there's enough text
      if (_textController.text.length >= widget.minCharsForSuggestions) {
        _showOverlay();
        unawaited(_fetchSuggestions(_textController.text));
      }
    } else {
      // Delay to allow tap on suggestion to register
      unawaited(
        Future<void>.delayed(const Duration(milliseconds: 200), () {
          if (mounted && !_focusNode.hasFocus) {
            _hideOverlay();
          }
        }),
      );
    }
  }

  void _onTextChange() {
    final text = _textController.text;
    _selectedIndex = -1;

    if (text.length < widget.minCharsForSuggestions) {
      _controller.clear();
      _hideOverlay();
      return;
    }

    // Show overlay when user types enough characters
    _showOverlay();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      if (mounted) {
        unawaited(_fetchSuggestions(text));
      }
    });
  }

  void _refreshSuggestions() {
    unawaited(_fetchSuggestions(_textController.text));
  }

  Future<void> _fetchSuggestions(String pattern) async {
    if (!widget.retainOnLoading) {
      _controller.clear();
    }
    _controller.setLoading(true);
    _updateOverlay();

    try {
      final suggestions = await widget.suggestionsCallback(pattern);
      if (!mounted) return;

      _controller.setSuggestions(suggestions);
      _controller.setLoading(false);

      if (suggestions.isNotEmpty || !widget.hideOnEmpty) {
        _showOverlay();
      } else {
        _hideOverlay();
      }
      _updateOverlay();
    } on Exception catch (e) {
      if (!mounted) return;
      _controller.setError(e);
      _controller.setLoading(false);
      if (!widget.hideOnError) {
        _updateOverlay();
      } else {
        _hideOverlay();
      }
    }
  }

  void _showOverlay() {
    if (_overlayEntry != null) return;

    // Get dimensions and position of the input field
    final renderBox = context.findRenderObject();
    double width = double.infinity;
    double inputTopOffset = 0;
    double inputHeight = 0;

    if (renderBox is RenderBox) {
      width = renderBox.size.width;
      // Calculate global position for mask positioning
      final position = renderBox.localToGlobal(Offset.zero);
      inputTopOffset = position.dy;
      inputHeight = renderBox.size.height;
    }

    _overlayEntry = OverlayEntry(
      builder: (context) => _SuggestionsOverlay<T>(
        layerLink: _layerLink,
        controller: _controller,
        itemBuilder: widget.itemBuilder,
        listBuilder: widget.listBuilder,
        loadingBuilder: widget.loadingBuilder,
        errorBuilder: widget.errorBuilder,
        emptyBuilder: widget.emptyBuilder,
        direction: widget.direction,
        autoFlipDirection: widget.autoFlipDirection,
        maxHeight: widget.suggestionsBoxMaxHeight,
        decoration: widget.suggestionsBoxDecoration,
        selectedIndex: _selectedIndex,
        hideOnEmpty: widget.hideOnEmpty,
        hideOnLoading: widget.hideOnLoading,
        hideOnError: widget.hideOnError,
        onItemSelected: _onItemSelected,
        onMaskTap: _hideOverlay,
        showMask: widget.showMask,
        maskColor: widget.maskColor ?? Colors.black,
        maskOpacity: widget.maskOpacity,
        suggestionsWidth: width,
        inputTopOffset: inputTopOffset,
        inputHeight: inputHeight,
        inputWidth: width,
        inputLeftOffset: renderBox is RenderBox ? renderBox.localToGlobal(Offset.zero).dx : 0,
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    _controller.open();
  }

  void _hideOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    _controller.close();
  }

  void _updateOverlay() {
    _overlayEntry?.markNeedsBuild();
  }

  void _onItemSelected(T item) {
    widget.onSelected(item);
    if (!widget.keepSuggestionsOnSelect) {
      _hideOverlay();
      _focusNode.unfocus();
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (!_controller.isOpen) return;

    final suggestions = _controller.suggestions;
    if (suggestions.isEmpty) return;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() {
        _selectedIndex = (_selectedIndex + 1) % suggestions.length;
      });
      _updateOverlay();
    } else if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() {
        _selectedIndex = _selectedIndex <= 0 ? suggestions.length - 1 : _selectedIndex - 1;
      });
      _updateOverlay();
    } else if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_selectedIndex >= 0 && _selectedIndex < suggestions.length) {
        _onItemSelected(suggestions[_selectedIndex]);
      }
    } else if (event.logicalKey == LogicalKeyboardKey.escape) {
      _hideOverlay();
      _focusNode.unfocus();
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: _handleKeyEvent,
        child: widget.builder?.call(
              context,
              _textController,
              _focusNode,
            ) ??
            _DefaultInputField(
              controller: _textController,
              focusNode: _focusNode,
              placeholder: widget.placeholder,
            ),
      ),
    );
  }
}

/// Default input field when no custom builder is provided.
class _DefaultInputField extends StatelessWidget {
  const _DefaultInputField({
    required this.controller,
    required this.focusNode,
    this.placeholder,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? placeholder;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final typography = context.typography;
    final radius = context.radius;
    final spacing = context.spacing;

    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: typography.bodyMedium.toTextStyle(color: palette.textPrimary),
      decoration: InputDecoration(
        hintText: placeholder,
        hintStyle: typography.bodyMedium.toTextStyle(color: palette.weak),
        filled: true,
        fillColor: palette.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.sm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius.sm),
          borderSide: BorderSide(color: palette.brand),
        ),
        contentPadding: EdgeInsets.symmetric(
          horizontal: spacing.sm,
          vertical: spacing.xs,
        ),
      ),
    );
  }
}

/// Overlay widget for displaying suggestions.
class _SuggestionsOverlay<T> extends StatelessWidget {
  const _SuggestionsOverlay({
    required this.layerLink,
    required this.controller,
    required this.itemBuilder,
    required this.onItemSelected,
    required this.selectedIndex,
    required this.hideOnEmpty,
    required this.hideOnLoading,
    required this.hideOnError,
    required this.onMaskTap,
    required this.showMask,
    required this.maskColor,
    required this.maskOpacity,
    required this.suggestionsWidth,
    required this.inputTopOffset,
    required this.inputHeight,
    required this.inputWidth,
    required this.inputLeftOffset,
    this.listBuilder,
    this.loadingBuilder,
    this.errorBuilder,
    this.emptyBuilder,
    this.direction = SuggestionsDirection.auto,
    this.autoFlipDirection = true,
    this.maxHeight = 300,
    this.decoration,
  });

  final LayerLink layerLink;
  final TypeAheadController<T> controller;
  final TypeAheadItemBuilder<T> itemBuilder;
  final TypeAheadListBuilder? listBuilder;
  final WidgetBuilder? loadingBuilder;
  final TypeAheadErrorBuilder? errorBuilder;
  final WidgetBuilder? emptyBuilder;
  final SuggestionsDirection direction;
  final bool autoFlipDirection;
  final double maxHeight;
  final BoxDecoration? decoration;
  final int selectedIndex;
  final bool hideOnEmpty;
  final bool hideOnLoading;
  final bool hideOnError;
  final void Function(T item) onItemSelected;
  final VoidCallback onMaskTap;
  final bool showMask;
  final Color maskColor;
  final double maskOpacity;
  final double suggestionsWidth;
  final double inputTopOffset;
  final double inputHeight;
  final double inputWidth;
  final double inputLeftOffset;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        // Determine if we should hide the overlay
        if (controller.isLoading && hideOnLoading) {
          return const SizedBox.shrink();
        }
        if (controller.hasError && hideOnError) {
          return const SizedBox.shrink();
        }
        if (!controller.hasSuggestions && !controller.isLoading && !controller.hasError && hideOnEmpty) {
          return const SizedBox.shrink();
        }

        final suggestionsBox = CompositedTransformFollower(
          link: layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 48),
          child: SizedBox(
            width: suggestionsWidth,
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(8),
              child: _buildContent(context),
            ),
          ),
        );

        if (!showMask) {
          return Positioned(
            width: suggestionsWidth,
            child: suggestionsBox,
          );
        }

        // Return full screen mask + suggestions box
        // Mask covers entire screen, but ignores taps within input bounds
        final inputRect = Rect.fromLTWH(
          inputLeftOffset,
          inputTopOffset,
          inputWidth,
          inputHeight,
        );

        return Stack(
          children: [
            // Full screen mask that ignores taps on input area
            Positioned.fill(
              child: GestureDetector(
                onTapDown: (details) {
                  // If tap is within input bounds, ignore it
                  if (inputRect.contains(details.globalPosition)) {
                    return;
                  }
                  // Otherwise, unfocus and close overlay
                  FocusScope.of(context).unfocus();
                  onMaskTap();
                },
                behavior: HitTestBehavior.opaque,
                child: ColoredBox(
                  color: maskColor.withValues(alpha: maskOpacity),
                ),
              ),
            ),
            // Suggestions box on top
            Positioned(
              width: suggestionsWidth,
              child: suggestionsBox,
            ),
          ],
        );
      },
    );
  }

  Widget _buildContent(BuildContext context) {
    final palette = context.palette;
    final spacing = context.spacing;

    final effectiveDecoration = decoration ??
        BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: palette.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Get the width from the render box of the target
        final renderBox = layerLink.leader?.owner;
        final width = renderBox is RenderBox ? renderBox.size.width : 280.0;

        return Container(
          width: width,
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: effectiveDecoration,
          child: _buildContentChild(context, palette, spacing),
        );
      },
    );
  }

  Widget _buildContentChild(
    BuildContext context,
    AppPalette palette,
    Spacing spacing,
  ) {
    // Loading state
    if (controller.isLoading && !controller.hasSuggestions) {
      return loadingBuilder?.call(context) ??
          Padding(
            padding: EdgeInsets.all(spacing.sm),
            child: const Center(
              child: CircularProgressSpinner(size: 24),
            ),
          );
    }

    // Error state
    if (controller.hasError) {
      final error = controller.error;
      if (error == null) return const SizedBox.shrink();

      return errorBuilder?.call(context, error) ??
          Padding(
            padding: EdgeInsets.all(spacing.sm),
            child: Text(
              'Error loading suggestions',
              style: TextStyle(color: palette.danger),
            ),
          );
    }

    // Empty state
    if (!controller.hasSuggestions) {
      return emptyBuilder?.call(context) ??
          Padding(
            padding: EdgeInsets.all(spacing.sm),
            child: Text(
              'No results found',
              style: TextStyle(color: palette.textSecondary),
            ),
          );
    }

    // Build suggestion items
    final items = <Widget>[];
    for (var i = 0; i < controller.suggestions.length; i++) {
      final suggestion = controller.suggestions[i];
      final isSelected = i == selectedIndex;

      items.add(
        _SuggestionItem<T>(
          item: suggestion,
          isSelected: isSelected,
          itemBuilder: itemBuilder,
          onTap: () => onItemSelected(suggestion),
        ),
      );
    }

    // Use custom list builder or default ListView
    if (listBuilder != null) {
      return listBuilder!.call(context, items);
    }

    return ListView(
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      children: items,
    );
  }
}

/// Individual suggestion item wrapper.
class _SuggestionItem<T> extends StatelessWidget {
  const _SuggestionItem({
    required this.item,
    required this.isSelected,
    required this.itemBuilder,
    required this.onTap,
  });

  final T item;
  final bool isSelected;
  final TypeAheadItemBuilder<T> itemBuilder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: isSelected ? palette.surface : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: itemBuilder(context, item),
      ),
    );
  }
}
