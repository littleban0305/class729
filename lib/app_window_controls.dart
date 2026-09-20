import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

bool get supportsDesktopWindowControls => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// A single window-control surface shared by every desktop route.
class AppWindowControls extends StatefulWidget {
  const AppWindowControls({
    super.key,
  });

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
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: '最小化',
              onPressed: windowManager.minimize,
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              tooltip: _maximized ? '還原視窗' : '最大化',
              onPressed: _toggleMaximize,
              icon: Icon(_maximized ? Icons.filter_none : Icons.crop_square),
            ),
            IconButton(
              tooltip: '關閉軟體',
              onPressed: windowManager.close,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
