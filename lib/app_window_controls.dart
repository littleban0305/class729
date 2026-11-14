import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'main.dart' show AppIcon, AppIcons;

bool get supportsDesktopWindowControls => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// 黏在右上角的視窗按鈕（最小化／最大化／關閉），樣式比照 Windows。
class AppWindowControls extends StatefulWidget {
  const AppWindowControls({super.key});

  @override
  State<AppWindowControls> createState() => _AppWindowControlsState();
}

class _AppWindowControlsState extends State<AppWindowControls> {
  bool _maximized = true;

  Future<void> _toggleMaximize() async {
    if (_maximized) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
    if (mounted) setState(() => _maximized = !_maximized);
  }

  @override
  Widget build(BuildContext context) {
    if (!supportsDesktopWindowControls) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _CaptionButton(tooltip: '最小化', icon: AppIcons.minus, onTap: windowManager.minimize),
        _CaptionButton(
          tooltip: _maximized ? '還原視窗' : '最大化',
          icon: _maximized ? AppIcons.restore : AppIcons.expand,
          onTap: _toggleMaximize,
        ),
        _CaptionButton(tooltip: '關閉軟體', icon: AppIcons.close, onTap: windowManager.close, danger: true),
      ],
    );
  }
}

class _CaptionButton extends StatefulWidget {
  final String tooltip;
  final String icon;
  final double iconSize;
  final VoidCallback onTap;
  final bool danger;
  const _CaptionButton({
    required this.tooltip,
    required this.icon,
    required this.onTap,
    this.iconSize = AppIcons.topBarSize,
    this.danger = false,
  });

  @override
  State<_CaptionButton> createState() => _CaptionButtonState();
}

class _CaptionButtonState extends State<_CaptionButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = !_hover
        ? Colors.transparent
        : (widget.danger ? const Color(0xFFE81123) : scheme.onSurface.withValues(alpha: 0.08));
    final fg = _hover && widget.danger ? Colors.white : scheme.onSurface;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 600),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Container(
            width: 56,
            height: 60,
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 100),
              width: 46,
              height: 44,
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: AppIcon(widget.icon, size: widget.iconSize, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
