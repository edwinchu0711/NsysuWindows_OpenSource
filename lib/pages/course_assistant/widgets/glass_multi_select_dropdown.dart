import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

class GlassMultiSelectDropdown extends StatefulWidget {
  final String label;
  final Set<String> values;
  final Map<String, String> options;
  final Function(Set<String>) onChanged;

  const GlassMultiSelectDropdown({
    super.key,
    required this.label,
    required this.values,
    required this.options,
    required this.onChanged,
  });

  @override
  State<GlassMultiSelectDropdown> createState() =>
      _GlassMultiSelectDropdownState();
}

class _GlassMultiSelectDropdownState extends State<GlassMultiSelectDropdown> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  bool _isOpen = false;
  late Set<String> _tempSet;

  void _toggleDropdown() {
    if (_isOpen) {
      _closeDropdown(true);
    } else {
      _tempSet = Set.from(widget.values);
      _overlayEntry = _createOverlayEntry();
      Overlay.of(context).insert(_overlayEntry!);
      setState(() => _isOpen = true);
    }
  }

  void _closeDropdown([bool save = false]) {
    if (save) {
      widget.onChanged(Set.from(_tempSet));
    }
    // 解決 Windows 平台在移除 Overlay 時可能發生的焦點/鍵盤狀態斷言錯誤
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
                onTap: () => _closeDropdown(true),
              ),
            ),
            CompositedTransformFollower(
              link: _layerLink,
              showWhenUnlinked: false,
              offset: Offset(0, size.height + 8),
              child: Material(
                color: Colors.transparent,
                child: StatefulBuilder(
                  builder: (context, setInnerState) {
                    return TweenAnimationBuilder<double>(
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
                        width: size.width < 180 ? 180 : size.width,
                        constraints: const BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          color: colorScheme.headerBackground,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: colorScheme.borderColor.withValues(
                              alpha: 0.5,
                            ),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Flexible(
                              child: SingleChildScrollView(
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: widget.options.entries.map((e) {
                                    final isSelected = _tempSet.contains(e.key);
                                    return HoverableMultiSelectOption(
                                      label: e.value,
                                      isSelected: isSelected,
                                      colorScheme: colorScheme,
                                      onTap: () {
                                        setInnerState(() {
                                          if (isSelected) {
                                            _tempSet.remove(e.key);
                                          } else {
                                            _tempSet.add(e.key);
                                          }
                                          // Save immediately upon ticking for real-time feel
                                          widget.onChanged(Set.from(_tempSet));
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
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
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
          ),
          const SizedBox(height: 2),
          InkWell(
            onTap: _toggleDropdown,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 38,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: colorScheme.borderColor, width: 0.5),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      widget.values.isEmpty
                          ? "全部"
                          : widget.values
                              .map((e) {
                                final label = widget.options[e] ?? e;
                                // 如果標籤包含括號時間，在欄位顯示時僅保留前半部 (例如 "A (07:00)" -> "A")
                                return label.contains(' (')
                                    ? label.split(' (')[0]
                                    : label;
                              })
                              .join(', '),
                      style: TextStyle(
                        fontSize: 13,
                        color: colorScheme.primaryText,
                        fontWeight: FontWeight.w500,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Icon(
                    _isOpen
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    size: 18,
                    color: colorScheme.accentBlue,
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

class HoverableMultiSelectOption extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ColorScheme colorScheme;

  const HoverableMultiSelectOption({
    super.key,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  State<HoverableMultiSelectOption> createState() =>
      _HoverableMultiSelectOptionState();
}

class _HoverableMultiSelectOptionState
    extends State<HoverableMultiSelectOption> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isSelected
                ? cs.accentBlue.withValues(alpha: 0.1)
                : (_isHovering
                    ? cs.accentBlue.withValues(alpha: 0.05)
                    : Colors.transparent),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? cs.accentBlue.withValues(alpha: 0.3)
                  : (_isHovering
                      ? cs.accentBlue.withValues(alpha: 0.2)
                      : Colors.transparent),
            ),
            boxShadow: _isHovering && !isSelected
                ? [
                    BoxShadow(
                      color: cs.accentBlue.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                isSelected
                    ? Icons.check_box_rounded
                    : Icons.check_box_outline_blank_rounded,
                size: 18,
                color: isSelected
                    ? cs.accentBlue
                    : (_isHovering
                        ? cs.accentBlue.withValues(alpha: 0.6)
                        : cs.subtitleText),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.label,
                  style: TextStyle(
                    color: isSelected || _isHovering
                        ? cs.primaryText
                        : cs.subtitleText,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
