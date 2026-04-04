import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import '../theme/app_theme.dart';

class CustomTitleBar extends StatefulWidget {
  final String title;
  final bool showTitle;

  const CustomTitleBar({Key? key, this.title = "NSYSU", this.showTitle = true})
    : super(key: key);

  @override
  State<CustomTitleBar> createState() => _CustomTitleBarState();
}

class _CustomTitleBarState extends State<CustomTitleBar> with WindowListener {
  bool _isMaximized = false;

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _checkMaximized();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  Future<void> _checkMaximized() async {
    bool isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() {
        _isMaximized = isMaximized;
      });
    }
  }

  @override
  void onWindowMaximize() {
    setState(() => _isMaximized = true);
  }

  @override
  void onWindowUnmaximize() {
    setState(() => _isMaximized = false);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      height: 32, // 標準 Windows 標題列高度
      color: colorScheme.pageBackground, // 自動與背景融合
      child: Row(
        children: [
          // 標題區域（可拖動）
          Expanded(
            child: DragToMoveArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                alignment: Alignment.centerLeft,
                child: widget.showTitle
                    ? Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.subtitleText,
                          letterSpacing: 0.5,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),

          // 視窗控制項
          Row(
            children: [
              _WindowControlBtn(
                icon: Icons.remove, // 使用 remove 作為最小化符號，位置較適中
                iconSize: 20,
                onPressed: () => windowManager.minimize(),
                hoverColor: colorScheme.subtleBackground,
              ),
              _WindowControlBtn(
                icon: _isMaximized ? null : Icons.crop_square,
                customIcon: _isMaximized
                    ? SizedBox(
                        width: 11,
                        height: 11,
                        child: Stack(
                          children: [
                            // 後方的方框
                            Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                width: 8.5,
                                height: 8.5,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(1.5),
                                  border: Border.all(
                                    color: colorScheme.primaryText.withOpacity(0.7),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                            // 前方的方框
                            Positioned(
                              bottom: 0,
                              left: 0,
                              child: Container(
                                width: 8.5,
                                height: 8.5,
                                decoration: BoxDecoration(
                                  color: colorScheme.pageBackground,
                                  borderRadius: BorderRadius.circular(1.5),
                                  border: Border.all(
                                    color: colorScheme.primaryText.withOpacity(0.7),
                                    width: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : null,
                iconSize: 14,
                onPressed: () async {
                  if (_isMaximized) {
                    windowManager.unmaximize();
                  } else {
                    windowManager.maximize();
                  }
                },
                hoverColor: colorScheme.subtleBackground,
              ),
              _WindowControlBtn(
                icon: Icons.close,
                onPressed: () => windowManager.close(),
                hoverColor: Colors.red.withOpacity(0.8),
                hoverIconColor: Colors.white,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WindowControlBtn extends StatefulWidget {
  final IconData? icon;
  final Widget? customIcon;
  final double iconSize;
  final VoidCallback onPressed;
  final Color hoverColor;
  final Color? hoverIconColor;

  const _WindowControlBtn({
    this.icon,
    this.customIcon,
    required this.onPressed,
    required this.hoverColor,
    this.iconSize = 16,
    this.hoverIconColor,
  });

  @override
  State<_WindowControlBtn> createState() => _WindowControlBtnState();
}

class _WindowControlBtnState extends State<_WindowControlBtn> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: Container(
          width: 46, // Windows 標準按鈕寬度
          height: 32,
          color: _isHovering ? widget.hoverColor : Colors.transparent,
          child: Center(
            child: widget.customIcon ??
                (widget.icon != null
                    ? Icon(
                        widget.icon,
                        size: widget.iconSize,
                        color: _isHovering && widget.hoverIconColor != null
                            ? widget.hoverIconColor
                            : colorScheme.primaryText.withOpacity(0.7),
                      )
                    : const SizedBox.shrink()),
          ),
        ),
      ),
    );
  }
}
