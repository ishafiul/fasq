import 'package:ecommerce/core/widgets/list_item.dart';
import 'package:flutter/material.dart';

class CollapsePanel {
  final String key;
  final Widget title;
  final Widget child;
  final bool disabled;
  final bool forceRender;
  final bool destroyOnClose;
  final Widget? arrowIcon;
  final VoidCallback? onClick;

  CollapsePanel({
    required this.key,
    required this.title,
    required this.child,
    this.disabled = false,
    this.forceRender = false,
    this.destroyOnClose = false,
    this.arrowIcon,
    this.onClick,
  });
}

class Collapse extends StatefulWidget {
  final List<CollapsePanel> items;
  final List<String>? activeKey;
  final List<String>? defaultActiveKey;
  final bool accordion;
  final ValueChanged<List<String>>? onChange;
  final Widget? arrowIcon;

  const Collapse({
    super.key,
    required this.items,
    this.activeKey,
    this.defaultActiveKey,
    this.accordion = false,
    this.onChange,
    this.arrowIcon,
  });

  @override
  State<Collapse> createState() => _CollapseState();
}

class _CollapseState extends State<Collapse> {
  late List<String> _activeKeys;

  @override
  void initState() {
    super.initState();
    _activeKeys = widget.activeKey ?? widget.defaultActiveKey ?? [];
  }

  @override
  void didUpdateWidget(Collapse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activeKey != null) {
      _activeKeys = widget.activeKey!;
    }
  }

  void _handleChange(String key) {
    final active = _activeKeys.contains(key);
    List<String> nextActiveKeys;

    if (widget.accordion) {
      nextActiveKeys = active ? [] : [key];
    } else {
      if (active) {
        nextActiveKeys = List.of(_activeKeys)..remove(key);
      } else {
        nextActiveKeys = List.of(_activeKeys)..add(key);
      }
    }

    if (widget.activeKey == null) {
      setState(() {
        _activeKeys = nextActiveKeys;
      });
    }

    widget.onChange?.call(nextActiveKeys);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: widget.items.map((panel) {
        final active = _activeKeys.contains(panel.key);
        return _CollapseItem(
          panel: panel,
          active: active,
          onToggle: () {
            if (!panel.disabled) {
              _handleChange(panel.key);
              panel.onClick?.call();
            }
          },
          arrowIcon: widget.arrowIcon,
        );
      }).toList(),
    );
  }
}

class _CollapseItem extends StatefulWidget {
  final CollapsePanel panel;
  final bool active;
  final VoidCallback onToggle;
  final Widget? arrowIcon;

  const _CollapseItem({
    required this.panel,
    required this.active,
    required this.onToggle,
    this.arrowIcon,
  });

  @override
  State<_CollapseItem> createState() => _CollapseItemState();
}

class _CollapseItemState extends State<_CollapseItem> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _heightFactor;
  late Animation<double> _iconTurns;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _heightFactor = _controller.drive(CurveTween(curve: Curves.ease));
    _iconTurns = _controller.drive(
      Tween<double>(begin: 0.0, end: -0.5).chain(
        CurveTween(curve: Curves.ease),
      ),
    );

    if (widget.active) {
      _controller.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(_CollapseItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final arrow =
        widget.panel.arrowIcon ?? widget.arrowIcon ?? const Icon(Icons.keyboard_arrow_down, size: 16); // Default arrow

    // Wrap arrow with rotation
    final rotatedArrow = RotationTransition(
      turns: _iconTurns,
      child: arrow,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ListItem(
          title: widget.panel.title,
          onClick: widget.onToggle,
          disabled: widget.panel.disabled,
          arrowIcon: rotatedArrow,
        ),
        AnimatedBuilder(
          animation: _controller.view,
          builder: (context, child) {
            final closed = !widget.active && _controller.status == AnimationStatus.dismissed;
            if (closed && widget.panel.destroyOnClose) {
              return const SizedBox.shrink();
            }

            return ClipRect(
              child: Align(
                heightFactor: _heightFactor.value,
                alignment: Alignment.topCenter,
                child: child,
              ),
            );
          },
          child: ListItem(
            child: widget.panel.child,
          ),
        ),
      ],
    );
  }
}
