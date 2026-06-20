import 'package:flutter/material.dart';

class HoverIconButton extends StatefulWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final Color? color;
  final double iconSize;
  final double padding;
  final Color? hoverColor;

  const HoverIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.color,
    this.iconSize = 20,
    this.padding = 8,
    this.hoverColor,
  });

  @override
  State<HoverIconButton> createState() => _HoverIconButtonState();
}

class _HoverIconButtonState extends State<HoverIconButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = colorScheme.brightness == Brightness.dark;
    
    final defaultHoverColor = isDark
        ? Colors.white.withValues(alpha: 0.1)
        : Colors.black.withValues(alpha: 0.06);

    Widget button = MouseRegion(
      cursor: widget.onPressed != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTap: widget.onPressed,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.all(widget.padding),
          decoration: BoxDecoration(
            color: _isHovered && widget.onPressed != null
                ? (widget.hoverColor ?? defaultHoverColor)
                : Colors.transparent,
            shape: BoxShape.circle,
          ),
          child: IconTheme(
            data: IconThemeData(
              color: widget.color ?? (widget.onPressed != null
                  ? colorScheme.onSurface
                  : colorScheme.onSurface.withValues(alpha: 0.4)),
              size: widget.iconSize,
            ),
            child: widget.icon,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      button = Tooltip(
        message: widget.tooltip!,
        child: button,
      );
    }

    return button;
  }
}
