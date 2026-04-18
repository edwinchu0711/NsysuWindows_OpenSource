import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// A modern "Liquid Glass" style single-select dropdown.
class GlassSingleSelectDropdown extends StatefulWidget {
  final String label;
  final List<String> items;
  final String value;
  final Function(String?)? onChanged;
  final Map<String, String>? displayMap;

  const GlassSingleSelectDropdown({
    Key? key,
    required this.label,
    required this.items,
    required this.value,
    this.onChanged,
    this.displayMap,
  }) : super(key: key);

  @override
  State<GlassSingleSelectDropdown> createState() => _GlassSingleSelectDropdownState();
}

class _GlassSingleSelectDropdownState extends State<GlassSingleSelectDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;

  void _toggleDropdown() {
    if (widget.onChanged == null) return;
    if (_isOpen) {
      _closeDropdown();
    } else {
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
      setState(() => _isOpen = true);
    }
  }

  void _closeDropdown() {
    FocusManager.instance.primaryFocus?.unfocus();
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _isOpen = false);
  }

  OverlayEntry _createOverlayEntry() {
    final RenderBox renderBox = context.findRenderObject() as RenderBox;
    final size = renderBox.size;
    final colorScheme = Theme.of(context).colorScheme;

    return OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closeDropdown,
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 4),
              child: Material(
                color: Colors.transparent,
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 200),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutBack,
                  builder: (context, val, child) {
                    return Transform.scale(
                      scale: 0.95 + 0.05 * val,
                      alignment: Alignment.topCenter,
                      child: Opacity(
                        opacity: val.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: size.width < 140 ? 140 : size.width,
                    constraints: const BoxConstraints(maxHeight: 250),
                    decoration: BoxDecoration(
                      color: colorScheme.headerBackground,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: colorScheme.borderColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: widget.items.map((item) {
                          final isSelected = item == widget.value;
                          final label = widget.displayMap != null
                              ? (widget.displayMap![item] ?? item)
                              : item;
                          return HoverableSingleSelectOption(
                            label: label,
                            isSelected: isSelected,
                            colorScheme: colorScheme,
                            onTap: () {
                              if (widget.onChanged != null) {
                                widget.onChanged!(item);
                              }
                              _closeDropdown();
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final displayValue = widget.displayMap != null
        ? (widget.displayMap![widget.value] ?? widget.value)
        : widget.value;

    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4, left: 2),
              child: Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.subtitleText,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          InkWell(
            onTap: widget.onChanged == null ? null : _toggleDropdown,
            borderRadius: BorderRadius.circular(10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: colorScheme.secondaryCardBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: colorScheme.borderColor, width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      displayValue,
                      style: TextStyle(
                        fontSize: 14,
                        color: widget.onChanged == null
                            ? colorScheme.subtitleText
                            : colorScheme.primaryText,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 20,
                    color: colorScheme.subtitleText,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class HoverableSingleSelectOption extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const HoverableSingleSelectOption({
    Key? key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  }) : super(key: key);

  @override
  State<HoverableSingleSelectOption> createState() =>
      _HoverableSingleSelectOptionState();
}

class _HoverableSingleSelectOptionState
    extends State<HoverableSingleSelectOption> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final cs = widget.colorScheme;
    final isSelected = widget.isSelected;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.accentBlue.withValues(alpha: 0.15)
                : (_isHovering
                      ? cs.accentBlue.withValues(alpha: 0.08)
                      : Colors.transparent),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? cs.accentBlue.withValues(alpha: 0.4)
                  : (_isHovering
                        ? cs.accentBlue.withValues(alpha: 0.25)
                        : Colors.transparent),
            ),
            boxShadow: _isHovering && !isSelected
                ? [
                    BoxShadow(
                      color: cs.accentBlue.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: isSelected || _isHovering
                        ? cs.primaryText
                        : cs.subtitleText,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isSelected)
                Icon(Icons.check_rounded, size: 18, color: cs.accentBlue),
            ],
          ),
        ),
      ),
    );
  }
}
