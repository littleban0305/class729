import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';
import 'app_state.dart';
import 'device_gate.dart';
import 'firebase_config_flag.dart';
import 'firebase_options.dart';
import 'models.dart';
import 'teacher_pages.dart';

bool get isDesktopPlatform => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kFirebaseConfigured) {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    } catch (_) {
      // Cloud sync stays disabled if Firebase can't initialize (e.g. missing config files).
    }
  }
  if (isDesktopPlatform) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1180, 760),
      minimumSize: Size(900, 620),
      center: true,
      title: '729',
      titleBarStyle: TitleBarStyle.hidden,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.maximize();
      await windowManager.focus();
    });
  }

  final state = AppState();
  await state.load();
  runApp(SevenTwentyNineApp(state: state));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppState();
    return SevenTwentyNineApp(state: state);
  }
}

class SevenTwentyNineApp extends StatefulWidget {
  final AppState state;
  const SevenTwentyNineApp({super.key, required this.state});

  @override
  State<SevenTwentyNineApp> createState() => _SevenTwentyNineAppState();
}

class _SevenTwentyNineAppState extends State<SevenTwentyNineApp> {
  late ThemeMode themeMode;

  @override
  void initState() {
    super.initState();
    themeMode = widget.state.darkMode ? ThemeMode.dark : ThemeMode.light;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '729',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Class729Rounded',
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        cardTheme: const CardThemeData(elevation: 0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Class729Rounded',
        colorSchemeSeed: Colors.indigo,
        scaffoldBackgroundColor: const Color(0xFF101217),
        cardTheme: const CardThemeData(elevation: 0),
      ),
      themeMode: themeMode,
      home: DeviceRoleGate(
        state: widget.state,
        onThemeModeChanged: (value) => setState(() => themeMode = value),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final AppState state;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  const MainShell({super.key, required this.state, required this.onThemeModeChanged});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool compact = false;
  bool maximized = true;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      drawer: isMobile ? const _TeacherMobileDrawer() : null,
      body: Stack(
        children: [
          Column(
            children: [
              Builder(
                builder: (barContext) => _WindowBar(
                  title: '後台',
                  maximized: maximized,
                  darkMode: widget.state.darkMode,
                  mobile: isMobile,
                  onOpenMenu: isMobile ? () => Scaffold.of(barContext).openDrawer() : null,
                onToggleDarkMode: () async {
                  final value = !widget.state.darkMode;
                  await widget.state.setDarkMode(value);
                  if (mounted) widget.onThemeModeChanged(value ? ThemeMode.dark : ThemeMode.light);
                },
                onToggleMaximize: () async {
                  if (!isDesktopPlatform) return;
                  if (maximized) {
                    await windowManager.unmaximize();
                  } else {
                    await windowManager.maximize();
                  }
                  if (mounted) setState(() => maximized = !maximized);
                },
                ),
              ),
              Expanded(
                child: AnimatedBuilder(
                  animation: widget.state,
                  builder: (_, __) => AdminPage(state: widget.state),
                ),
              ),
            ],
          ),
          if (!isMobile)
            _SideBar(
              expanded: !compact,
              current: 0,
              labels: const ['後台'],
              icons: const [Icons.settings_outlined],
              onSelect: (_) {},
              onToggle: () => setState(() => compact = !compact),
            ),
        ],
      ),
    );
  }
}

class _TeacherMobileDrawer extends StatelessWidget {
  const _TeacherMobileDrawer();

  @override
  Widget build(BuildContext context) {
    final state = context.findAncestorWidgetOfExactType<MainShell>()?.state;
    if (state == null) return const SizedBox.shrink();
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 20),
              child: Text('729', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            ),
            ListTile(
              selected: true,
              leading: const Icon(Icons.settings_outlined),
              title: const Text('後台', style: TextStyle(fontWeight: FontWeight.w800)),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowBar extends StatelessWidget {
  final String title;
  final bool maximized;
  final bool darkMode;
  final bool mobile;
  final VoidCallback? onOpenMenu;
  final VoidCallback onToggleDarkMode;
  final VoidCallback onToggleMaximize;

  const _WindowBar({
    required this.title,
    required this.maximized,
    required this.darkMode,
    this.mobile = false,
    this.onOpenMenu,
    required this.onToggleDarkMode,
    required this.onToggleMaximize,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (!isDesktopPlatform || maximized) ? null : (_) => windowManager.startDragging(),
      onDoubleTap: isDesktopPlatform ? onToggleMaximize : null,
      child: Container(
        height: 56,
        padding: const EdgeInsets.only(left: 18, right: 8),
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.surface),
        child: Row(
          children: [
            if (mobile) ...[
              IconButton(
                tooltip: '開啟選單',
                onPressed: onOpenMenu,
                icon: const Icon(Icons.menu),
              ),
              const SizedBox(width: 2),
            ],
            const Text('729', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(width: 12),
            Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
            IconButton(
              tooltip: darkMode ? '切換淺色模式' : '切換深色模式',
              onPressed: onToggleDarkMode,
              icon: Icon(darkMode ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
            ),
            if (isDesktopPlatform) ...[
              IconButton(
                tooltip: '最小化',
                onPressed: () => windowManager.minimize(),
                icon: const Icon(Icons.remove),
              ),
              IconButton(
                tooltip: maximized ? '還原' : '最大化',
                onPressed: onToggleMaximize,
                icon: Icon(maximized ? Icons.filter_none : Icons.crop_square),
              ),
              IconButton(
                tooltip: '關閉',
                onPressed: () => windowManager.close(),
                icon: const Icon(Icons.close),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

String _resolveTemplateVariables(String text, AppState state) {
  if (!text.contains('(') && !text.contains('{')) return text;

  final now = state.testNow ?? DateTime.now();
  final weekdayIndex = now.weekday - 1; // 0: 週一 ... 4: 週五
  final currentMinutes = now.hour * 60 + now.minute;

  int parseTime(String time) {
    final parts = time.split(':');
    if (parts.length != 2) return -1;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }

  // 取得當前或下一節課
  ScheduleEntry? currentClass;
  ScheduleEntry? nextClass;

  if (weekdayIndex >= 0 && weekdayIndex < 5) {
    final todayLessons = state.scheduleEntries.where((e) => e.weekday == weekdayIndex).toList()
      ..sort((a, b) => a.lesson.compareTo(b.lesson));

    for (int i = 0; i < todayLessons.length; i++) {
      final entry = todayLessons[i];
      final start = parseTime(entry.startTime);
      final end = parseTime(entry.endTime);
      if (start >= 0 && end >= 0) {
        if (currentMinutes >= start && currentMinutes <= end) {
          currentClass = entry;
          if (i + 1 < todayLessons.length) nextClass = todayLessons[i + 1];
          break;
        } else if (currentMinutes < start) {
          nextClass = entry;
          break;
        }
      }
    }
    // 如果找不到，但今天有課堂，取第一節或後續節次
    if (currentClass == null && nextClass == null && todayLessons.isNotEmpty) {
      if (currentMinutes < (parseTime(todayLessons.first.startTime))) {
        nextClass = todayLessons.first;
      }
    }
  }

  final nextClassName = nextClass?.subject.isNotEmpty == true ? nextClass!.subject : (nextClass != null ? '自習' : '無');
  final currentClassName =
      currentClass?.subject.isNotEmpty == true ? currentClass!.subject : (currentClass != null ? '自習' : '下課休息');
  final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  const weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];
  final weekdayStr = '星期${weekdayNames[now.weekday - 1]}';

  return text
      .replaceAll(RegExp(r'\((?:nextclass|下一節課|下一節)\)', caseSensitive: false), nextClassName)
      .replaceAll(RegExp(r'\{(?:nextclass|下一節課|下一節)\}', caseSensitive: false), nextClassName)
      .replaceAll(RegExp(r'\((?:currentclass|本節課|這一節|目前課堂)\)', caseSensitive: false), currentClassName)
      .replaceAll(RegExp(r'\{(?:currentclass|本節課|這一節|目前課堂)\}', caseSensitive: false), currentClassName)
      .replaceAll(RegExp(r'\((?:time|時間|現在時間)\)', caseSensitive: false), timeStr)
      .replaceAll(RegExp(r'\{(?:time|時間|現在時間)\}', caseSensitive: false), timeStr)
      .replaceAll(RegExp(r'\((?:date|日期|今天日期)\)', caseSensitive: false), dateStr)
      .replaceAll(RegExp(r'\{(?:date|日期|今天日期)\}', caseSensitive: false), dateStr)
      .replaceAll(RegExp(r'\((?:weekday|星期|星期幾)\)', caseSensitive: false), weekdayStr)
      .replaceAll(RegExp(r'\{(?:weekday|星期|星期幾)\}', caseSensitive: false), weekdayStr);
}

class _SideBar extends StatelessWidget {
  final bool expanded;
  final int current;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggle;

  const _SideBar(
      {required this.expanded,
      required this.current,
      required this.labels,
      required this.icons,
      required this.onSelect,
      required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 18,
      bottom: 18,
      child: Material(
        color: const Color(0xFF171A24),
        elevation: 12,
        shadowColor: Colors.black45,
        borderRadius: BorderRadius.circular(expanded ? 18 : 30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: expanded ? 210 : 58,
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: expanded
              ? Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(18, 8, 18, 12),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('729',
                            style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900)),
                      ),
                    ),
                    for (int i = 0; i < icons.length; i++) _navItem(i),
                    IconButton(
                      tooltip: '收合導覽列',
                      onPressed: onToggle,
                      icon: const Icon(Icons.chevron_left, color: Colors.white70),
                    ),
                  ],
                )
              : IconButton(
                  tooltip: '展開導覽列',
                  onPressed: onToggle,
                  icon: const Icon(Icons.menu, color: Colors.white, size: 25),
                ),
        ),
      ),
    );
  }

  Widget _navItem(int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Material(
        color: current == index ? const Color(0xFF30364A) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => onSelect(index),
          child: SizedBox(
            height: 48,
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(icons[index], color: Colors.white70),
                const SizedBox(width: 14),
                Text(labels[index], style: const TextStyle(color: Colors.white, fontSize: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderCanvas extends StatelessWidget {
  final ReminderData item;
  final Map<String, ReminderBlockData> blocks;
  final List<ReminderElementData> elements;
  final bool editable;
  final void Function(String, ReminderBlockData)? onBlockMoved;
  final void Function(ReminderElementData)? onElementChanged;
  final void Function(String)? onElementDeleted;
  final Future<void> Function(String)? onInternalOpen;
  final String? selectedId;
  final AppState? state;

  const _ReminderCanvas({
    required this.item,
    required this.blocks,
    this.elements = const [],
    this.editable = false,
    this.onBlockMoved,
    this.onElementChanged,
    this.onElementDeleted,
    this.onInternalOpen,
    this.selectedId,
    this.state,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1000,
      height: 562,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (elements.isNotEmpty)
            for (final element in elements) _positionedElement(context, element),
          if (elements.isEmpty)
            for (final entry in blocks.entries)
              if (_hasContent(entry.key)) _positionedBlock(context, entry.key, entry.value),
        ],
      ),
    );
  }

  bool _hasContent(String type) {
    if (type == 'content') return item.content.isNotEmpty;
    if (type == 'buttons') return item.buttons.isNotEmpty;
    return true;
  }

  Widget _positionedBlock(BuildContext context, String type, ReminderBlockData block) {
    final child = GestureDetector(
      onPanUpdate: editable
          ? (details) {
              final nextX = (block.x + details.delta.dx).clamp(0, 1000 - block.width).toDouble();
              final nextY = (block.y + details.delta.dy).clamp(0, 562 - block.height).toDouble();
              onBlockMoved?.call(type, block.copyWith(x: nextX, y: nextY));
            }
          : null,
      child: Stack(
        children: [
          Container(
            width: block.width,
            height: block.height,
            padding: const EdgeInsets.all(12),
            decoration: editable
                ? BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
                    border: Border.all(color: Theme.of(context).colorScheme.primary, width: 2),
                    borderRadius: BorderRadius.circular(10),
                  )
                : null,
            child: _blockContent(context, type),
          ),
          if (editable)
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onPanUpdate: (details) {
                  final nextWidth = (block.width + details.delta.dx).clamp(160, 1000 - block.x).toDouble();
                  final nextHeight = (block.height + details.delta.dy).clamp(60, 562 - block.y).toDouble();
                  onBlockMoved?.call(type, block.copyWith(width: nextWidth, height: nextHeight));
                },
                child: const SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(Icons.open_in_full, size: 15),
                ),
              ),
            ),
        ],
      ),
    );
    return Positioned(left: block.x, top: block.y, child: child);
  }

  Widget _positionedElement(BuildContext context, ReminderElementData element) {
    final selected = selectedId == element.id;
    final child = GestureDetector(
      onTap: editable ? () => onElementChanged?.call(element) : null,
      onPanUpdate: editable
          ? (details) {
              final nextX = (element.x + details.delta.dx).clamp(0, 1000 - element.width).toDouble();
              final nextY = (element.y + details.delta.dy).clamp(0, 562 - element.height).toDouble();
              onElementChanged?.call(element.copyWith(x: nextX, y: nextY));
            }
          : null,
      child: Stack(
        children: [
          Container(
            width: element.width,
            height: element.height,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Color(element.backgroundColor),
              border: editable && selected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: _elementContent(context, element),
          ),
          if (editable && selected) ...[
            Positioned(
              right: 0,
              bottom: 0,
              child: GestureDetector(
                onPanUpdate: (details) {
                  final width = (element.width + details.delta.dx).clamp(80, 1000 - element.x).toDouble();
                  final height = (element.height + details.delta.dy).clamp(40, 562 - element.y).toDouble();
                  onElementChanged?.call(element.copyWith(width: width, height: height));
                },
                child: const Icon(Icons.open_in_full, size: 18),
              ),
            ),
            Positioned(
              right: -8,
              top: -8,
              child: IconButton(
                tooltip: '刪除元素',
                onPressed: () => onElementDeleted?.call(element.id),
                icon: const Icon(Icons.close, size: 16),
              ),
            ),
          ],
        ],
      ),
    );
    return Positioned(left: element.x, top: element.y, child: child);
  }

  Widget _elementContent(BuildContext context, ReminderElementData element) {
    if (element.type == 'divider') {
      return Center(child: Divider(thickness: 3, color: Color(element.color)));
    }
    if (element.type == 'image') {
      return element.url.isEmpty
          ? const Center(child: Icon(Icons.image_outlined, size: 50))
          : Image.network(element.url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_outlined, size: 42)));
    }
    final style = TextStyle(
      fontSize: element.fontSize,
      fontWeight: element.bold ? FontWeight.w800 : FontWeight.w400,
      fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
      decoration: element.underline ? TextDecoration.underline : TextDecoration.none,
      color: element.color == 0xff171a24 ? Theme.of(context).colorScheme.onSurface : Color(element.color),
    );
    final displayText = state != null ? _resolveTemplateVariables(element.text, state!) : element.text;
    if (element.type == 'button') {
      return FilledButton(
          onPressed: editable
              ? null
              : () async {
                  if (element.url.startsWith('internal://')) {
                    await onInternalOpen?.call(element.url);
                    return;
                  }
                  final uri = Uri.tryParse(element.url);
                  if (uri != null && uri.hasScheme) await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
          child: Text(displayText, style: style));
    }
    return Align(
        alignment: _textAlignment(element.alignment),
        child: Text(displayText, textAlign: _textAlign(element.alignment), style: style));
  }

  Alignment _textAlignment(String value) {
    if (value == 'center') return Alignment.topCenter;
    if (value == 'right') return Alignment.topRight;
    return Alignment.topLeft;
  }

  TextAlign _textAlign(String value) {
    if (value == 'center') return TextAlign.center;
    if (value == 'right') return TextAlign.right;
    return TextAlign.left;
  }

  Widget _blockContent(BuildContext context, String type) {
    switch (type) {
      case 'title':
        final title = state != null ? _resolveTemplateVariables(item.title, state!) : item.title;
        return Align(
          alignment: Alignment.topLeft,
          child: Text(title,
              style: TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w900,
                  height: 1.05,
                  color: Theme.of(context).colorScheme.onSurface)),
        );
      case 'content':
        final content = state != null ? _resolveTemplateVariables(item.content, state!) : item.content;
        return Align(
          alignment: Alignment.topLeft,
          child: Text(content,
              style: TextStyle(fontSize: 28, height: 1.35, color: Theme.of(context).colorScheme.onSurface)),
        );
      case 'buttons':
        return Align(
          alignment: Alignment.topLeft,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: item.buttons.map((button) {
              final btnText = state != null ? _resolveTemplateVariables(button.text, state!) : button.text;
              return FilledButton.icon(
                onPressed: editable
                    ? null
                    : () async {
                        if (button.url.startsWith('internal://')) {
                          await onInternalOpen?.call(button.url);
                          return;
                        }
                        final uri = Uri.tryParse(button.url);
                        if (uri != null && uri.hasScheme) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                icon: const Icon(Icons.open_in_new, size: 19),
                label: Text(btnText, style: const TextStyle(fontSize: 18)),
              );
            }).toList(),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _ReminderDisplay extends StatefulWidget {
  final AppState state;
  final Future<void> Function(String) onInternalOpen;

  const _ReminderDisplay({required this.state, required this.onInternalOpen});

  @override
  State<_ReminderDisplay> createState() => _ReminderDisplayState();
}

class _ReminderDisplayState extends State<_ReminderDisplay> {
  Timer? rotationTimer;
  int currentIndex = 0;

  @override
  void initState() {
    super.initState();
    rotationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => currentIndex++);
    });
  }

  @override
  void dispose() {
    rotationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.state.reminders.where((reminder) => reminder.isActive).toList();
    final reminders = active.isNotEmpty ? active : widget.state.reminders;
    if (reminders.isEmpty) return const SizedBox.expand();
    final reminder = reminders[currentIndex % reminders.length];
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('提醒', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: _ReminderCanvas(
                    item: reminder,
                    blocks: reminder.blocks,
                    elements: reminder.elements,
                    onInternalOpen: widget.onInternalOpen,
                    state: widget.state,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReminderPage extends StatelessWidget {
  final AppState state;
  final bool manage;
  const ReminderPage({super.key, required this.state, this.manage = false});

  @override
  Widget build(BuildContext context) {
    if (manage) return _buildManagement(context);
    return _ReminderDisplay(
      state: state,
      onInternalOpen: (target) => _openInternalPage(context, target),
    );
    /*
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('提醒', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
              if (manage) ...[
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => _openReminderEditor(context),
                  icon: const Icon(Icons.add),
                  label: const Text('新增提醒'),
                ),
                if (visible.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: '編輯目前提醒',
                    onPressed: () => _openReminderEditor(context, index: state.reminders.indexOf(visible.first)),
                    icon: const Icon(Icons.edit_outlined),
                  ),
                  IconButton(
                    tooltip: '刪除目前提醒',
                    onPressed: () => state.deleteReminder(state.reminders.indexOf(visible.first)),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ],
              ],
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: visible.isEmpty
                ? const SizedBox.shrink()
                : Center(
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: _ReminderCanvas(
                          item: visible.first,
                          blocks: visible.first.blocks,
                          elements: visible.first.elements,
                          onInternalOpen: (target) => _openInternalPage(context, target),
                        ),
                      ),
                    ),
                  ),
          )
        ],
      ),
    );
    */
  }

  Widget _buildManagement(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('提醒管理', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
              const Spacer(),
              FilledButton.icon(
                onPressed: () => _openReminderEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('新增簡報'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: () => _addPresetReminders(),
                icon: const Icon(Icons.auto_awesome),
                label: const Text('加入預設簡報'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: state.reminders.isEmpty
                ? const SizedBox.shrink()
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                      maxCrossAxisExtent: 520,
                      mainAxisExtent: 330,
                      crossAxisSpacing: 18,
                      mainAxisSpacing: 18,
                    ),
                    itemCount: state.reminders.length,
                    itemBuilder: (context, index) {
                      final reminder = state.reminders[index];
                      return Card(
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: () => _openReminderEditor(context, index: index),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: _ReminderCanvas(
                                      item: reminder,
                                      blocks: reminder.blocks,
                                      elements: reminder.elements,
                                      onInternalOpen: (target) => _openInternalPage(context, target),
                                      state: state,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 10, 8, 12),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(reminder.title.isEmpty ? '未命名簡報' : reminder.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                          const SizedBox(height: 4),
                                          Text(_repeatLabel(reminder), style: const TextStyle(color: Colors.black54)),
                                        ],
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: '複製',
                                      onPressed: () => state.duplicateReminder(index),
                                      icon: const Icon(Icons.copy_outlined),
                                    ),
                                    IconButton(
                                      tooltip: '刪除',
                                      onPressed: () => state.deleteReminder(index),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _repeatLabel(ReminderData reminder) {
    switch (reminder.repeatType) {
      case 'daily':
        return '每日 · ${reminder.startTime}-${reminder.endTime}';
      case 'weekly':
        return '每週 · ${reminder.startTime}-${reminder.endTime}';
      case 'specific':
        return '指定日期 · ${reminder.repeatDates.length} 天';
      default:
        return '單次 · ${reminder.date.isEmpty ? '每日' : reminder.date}';
    }
  }

  Future<void> _addPresetReminders() async {
    final presets = [
      _presetReminder('早自習', '早自習時間', '07:30', '08:00'),
      _presetReminder('上課中', '現在是上課時間', '08:00', '08:50'),
      _presetReminder('下課', '下課休息時間', '08:50', '09:00'),
      _presetReminder('午休', '午休時間', '12:00', '13:00'),
      _presetReminder('吃飯時間', '吃飯時間', '12:00', '12:30'),
      _presetReminder('放學', '放學時間', '16:00', '23:59'),
    ];
    for (final preset in presets) {
      if (state.reminders.any((reminder) => reminder.title == preset.title)) continue;
      await state.saveReminder(preset);
    }
  }

  ReminderData _presetReminder(String title, String content, String start, String end) {
    return ReminderData(
      title: title,
      content: content,
      date: '',
      startTime: start,
      endTime: end,
      repeatType: 'daily',
      elements: [
        ReminderElementData(
          id: 'preset-title-${title.hashCode}',
          type: 'text',
          text: title,
          x: 70,
          y: 100,
          width: 860,
          height: 90,
          fontSize: 48,
          bold: true,
        ),
        ReminderElementData(
          id: 'preset-content-${title.hashCode}',
          type: 'text',
          text: content,
          x: 70,
          y: 230,
          width: 860,
          height: 100,
          fontSize: 30,
        ),
      ],
    );
  }

  Future<void> _openInternalPage(BuildContext context, String target) async {
    final Widget page;
    switch (target) {
      case 'internal://seats':
        page = SeatPage(state: state);
        break;
      case 'internal://lottery':
        page = LotteryPage(state: state);
        break;
      case 'internal://diary':
        page = DiaryPage(state: state);
        break;
      case 'internal://schedule':
        page = SchedulePage(state: state, editable: false);
        break;
      default:
        return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        child: SizedBox(
          width: 1050,
          height: 680,
          child: Stack(
            children: [
              Padding(padding: const EdgeInsets.only(top: 12), child: page),
              Positioned(
                left: 8,
                top: 8,
                child: IconButton(
                  tooltip: '返回',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.arrow_back),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openReminderEditor(BuildContext context, {int? index}) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _ReminderEditor(state: state, index: index),
    );
  }

  // Legacy editor retained temporarily for data compatibility; all current entry points use _ReminderEditor.
  // ignore: unused_element
  Future<void> _editReminder(BuildContext context, {int? index}) async {
    final old = index == null ? null : state.reminders[index];
    final title = TextEditingController(text: old?.title ?? '');
    final content = TextEditingController(text: old?.content ?? '');
    final date = TextEditingController(text: old?.date ?? '');
    final start = TextEditingController(text: old?.startTime ?? '08:00');
    final end = TextEditingController(text: old?.endTime ?? '18:00');
    final buttons = List<ActionButtonData>.from(old?.buttons ?? []);
    final layout = List<String>.from(old?.layout ?? const ['title', 'content', 'buttons']);
    final blockLayouts = <String, ReminderBlockData>{
      ...ReminderData.defaultBlockLayouts(),
      ...?old?.blocks,
    };
    final elements = old?.elements.isNotEmpty == true
        ? List<ReminderElementData>.from(old!.elements)
        : <ReminderElementData>[
            ReminderElementData(
                id: 'title',
                type: 'text',
                text: old?.title ?? '',
                x: 70,
                y: 70,
                width: 860,
                height: 90,
                fontSize: 48,
                bold: true),
            ReminderElementData(
                id: 'content',
                type: 'text',
                text: old?.content ?? '',
                x: 70,
                y: 190,
                width: 860,
                height: 150,
                fontSize: 28),
            ...List.generate(
              old?.buttons.length ?? 0,
              (i) => ReminderElementData(
                id: 'button-$i',
                type: 'button',
                text: old!.buttons[i].text,
                url: old.buttons[i].url,
                x: 70 + (i % 3) * 190,
                y: 390 + (i ~/ 3) * 70,
                width: 170,
                height: 52,
                fontSize: 16,
              ),
            ),
          ];
    String? selectedId;
    var newElementIndex = elements.length;

    Offset nextElementPosition() {
      final slot = newElementIndex++;
      return Offset(70 + (slot % 4) * 215, 70 + (slot ~/ 4) * 110);
    }

    void updateElement(String id, ReminderElementData Function(ReminderElementData) change) {
      final position = elements.indexWhere((element) => element.id == id);
      if (position >= 0) elements[position] = change(elements[position]);
    }

    void addElement(String type) {
      final id = '$type-${DateTime.now().microsecondsSinceEpoch}-${elements.length}';
      final position = nextElementPosition();
      final element = switch (type) {
        'text' =>
          ReminderElementData(id: id, type: type, text: '新增文字', x: position.dx, y: position.dy, width: 360, height: 80),
        'button' => ReminderElementData(
            id: id,
            type: type,
            text: '按鈕',
            url: 'https://',
            x: position.dx,
            y: position.dy,
            width: 180,
            height: 56,
            fontSize: 16),
        'divider' => ReminderElementData(id: id, type: type, x: position.dx, y: position.dy, width: 500, height: 40),
        _ =>
          ReminderElementData(id: id, type: 'image', url: '', x: position.dx, y: position.dy, width: 300, height: 180),
      };
      elements.add(element);
      selectedId = id;
    }

    final buttonTextControllers = buttons.map((button) => TextEditingController(text: button.text)).toList();
    final buttonUrlControllers = buttons.map((button) => TextEditingController(text: button.url)).toList();

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(index == null ? '新增提醒' : '編輯提醒'),
          content: SizedBox(
            width: 920,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(
                    width: 860,
                    height: 500,
                    child: _ReminderCanvas(
                      item: ReminderData(
                        title: title.text,
                        content: content.text,
                        date: date.text,
                        startTime: start.text,
                        endTime: end.text,
                        buttons: buttons,
                        elements: elements,
                        blocks: blockLayouts,
                      ),
                      blocks: blockLayouts,
                      editable: true,
                      onBlockMoved: (type, next) => setState(() => blockLayouts[type] = next),
                      selectedId: selectedId,
                      onElementChanged: (next) => setState(() {
                        selectedId = next.id;
                        final position = elements.indexWhere((element) => element.id == next.id);
                        if (position == -1) {
                          elements.add(next);
                        } else {
                          elements[position] = next;
                        }
                      }),
                      onElementDeleted: (id) => setState(() {
                        elements.removeWhere((element) => element.id == id);
                        if (selectedId == id) selectedId = null;
                      }),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilledButton.tonalIcon(
                        onPressed: () => setState(() => addElement('text')),
                        icon: const Icon(Icons.text_fields),
                        label: const Text('文字'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => setState(() => addElement('button')),
                        icon: const Icon(Icons.smart_button_outlined),
                        label: const Text('按鈕'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => setState(() => addElement('divider')),
                        icon: const Icon(Icons.horizontal_rule),
                        label: const Text('分隔線'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: () => setState(() => addElement('image')),
                        icon: const Icon(Icons.image_outlined),
                        label: const Text('圖片'),
                      ),
                    ],
                  ),
                  if (selectedId != null)
                    _ElementInspector(
                      element: elements.firstWhere((element) => element.id == selectedId),
                      onChanged: (next) => setState(() {
                        final position = elements.indexWhere((element) => element.id == next.id);
                        if (position >= 0) elements[position] = next;
                      }),
                    ),
                  const Divider(height: 28),
                  TextField(
                      controller: title,
                      onChanged: (value) => setState(() {
                            updateElement('title', (element) => element.copyWith(text: value));
                          }),
                      decoration: const InputDecoration(labelText: '標題')),
                  TextField(
                      controller: content,
                      maxLines: 4,
                      onChanged: (value) => setState(() {
                            updateElement('content', (element) => element.copyWith(text: value));
                          }),
                      decoration: const InputDecoration(labelText: '內容')),
                  Row(children: [
                    Expanded(
                        child: TextField(
                            controller: date, decoration: const InputDecoration(labelText: '日期（YYYY-MM-DD，可空白）'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: start, decoration: const InputDecoration(labelText: '開始'))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: end, decoration: const InputDecoration(labelText: '結束'))),
                  ]),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() {
                          buttons.add(ActionButtonData(text: '開啟', url: 'https://'));
                          buttonTextControllers.add(TextEditingController(text: '開啟'));
                          buttonUrlControllers.add(TextEditingController(text: 'https://'));
                        });
                      },
                      icon: const Icon(Icons.add_link),
                      label: const Text('新增連結按鈕'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (int i = 0; i < buttons.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: buttonTextControllers[i],
                              decoration: const InputDecoration(labelText: '按鈕文字'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: buttonUrlControllers[i],
                              decoration: const InputDecoration(labelText: '連結'),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                buttonTextControllers.removeAt(i).dispose();
                                buttonUrlControllers.removeAt(i).dispose();
                                buttons.removeAt(i);
                              });
                            },
                            icon: const Icon(Icons.delete_outline),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                final editedButtons = <ActionButtonData>[];
                for (int i = 0; i < buttons.length; i++) {
                  editedButtons.add(
                    ActionButtonData(
                      text: buttonTextControllers[i].text,
                      url: buttonUrlControllers[i].text,
                    ),
                  );
                }
                final error = await state.saveReminder(
                  ReminderData(
                    title: title.text,
                    content: content.text,
                    date: date.text,
                    startTime: start.text,
                    endTime: end.text,
                    buttons: editedButtons,
                    layout: layout,
                    blocks: blockLayouts,
                    elements: elements,
                  ),
                  index: index,
                );
                if (error != null) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                  }
                  return;
                }
                for (final controller in buttonTextControllers) {
                  controller.dispose();
                }
                for (final controller in buttonUrlControllers) {
                  controller.dispose();
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('儲存'),
            )
          ],
        ),
      ),
    );
  }
}

class _ReminderEditor extends StatefulWidget {
  final AppState state;
  final int? index;

  const _ReminderEditor({required this.state, this.index});

  @override
  State<_ReminderEditor> createState() => _ReminderEditorState();
}

class _FastReminderCanvas extends StatefulWidget {
  final ReminderData item;
  final List<ReminderElementData> elements;
  final String? selectedId;
  final ValueChanged<ReminderElementData> onChanged;
  final ValueChanged<String> onDeleted;
  final VoidCallback? onDeselect;
  final AppState? state;

  const _FastReminderCanvas({
    required this.item,
    required this.elements,
    required this.selectedId,
    required this.onChanged,
    required this.onDeleted,
    this.onDeselect,
    this.state,
  });

  @override
  State<_FastReminderCanvas> createState() => _FastReminderCanvasState();
}

class _FastReminderCanvasState extends State<_FastReminderCanvas> {
  final Map<String, ValueNotifier<ReminderElementData>> localElements = {};
  final ValueNotifier<_GuidesData> guidesNotifier = ValueNotifier(const _GuidesData());
  String? draggingId;
  ReminderElementData? dragStartElement;
  Offset dragDistance = Offset.zero;
  ReminderElementData? resizeStartElement;
  Offset resizeDistance = Offset.zero;

  @override
  void initState() {
    super.initState();
    _syncElements();
  }

  @override
  void didUpdateWidget(covariant _FastReminderCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncElements();
  }

  void _syncElements() {
    final incoming = {for (final element in widget.elements) element.id: element};
    for (final id in localElements.keys.toList()) {
      if (!incoming.containsKey(id)) {
        localElements.remove(id)!.dispose();
      }
    }
    for (final entry in incoming.entries) {
      final notifier = localElements[entry.key];
      if (notifier == null) {
        localElements[entry.key] = ValueNotifier(entry.value);
      } else {
        notifier.value = entry.value;
      }
    }
  }

  void _beginDrag(ValueNotifier<ReminderElementData> notifier) {
    draggingId = notifier.value.id;
    dragStartElement = notifier.value;
    dragDistance = Offset.zero;
    guidesNotifier.value = const _GuidesData();
  }

  void _move(ValueNotifier<ReminderElementData> notifier, Offset delta) {
    if (draggingId != notifier.value.id || dragStartElement == null) {
      _beginDrag(notifier);
    }
    dragDistance += delta;
    final start = dragStartElement!;
    final element = notifier.value;
    var x = (start.x + dragDistance.dx).clamp(0, 1000 - element.width).toDouble();
    var y = (start.y + dragDistance.dy).clamp(0, 562.5 - element.height).toDouble();
    double? activeGuideX;
    double? activeGuideY;
    bool isCenterX = false;
    bool isCenterY = false;

    // 畫布基準線（邊緣、正中心）
    final canvasCenterX = _SnapPoint(500 - element.width / 2, 500, isCenter: true);
    final canvasCenterY = _SnapPoint(281.25 - element.height / 2, 281.25, isCenter: true);

    // Canva 邊距／標題區域安全線（左/右 70，上 100，下 70）
    // 元素左邊對齊 margin 左(70)、右邊對齊 margin 右(930)、中心對齊 margin 中心(500)
    // 元素上邊對齊 margin 上(100 - 偏標題位置)、下邊對齊 margin 下(492.5)
    final marginGuideLeft = _SnapPoint(70, 70, isMargin: true);
    final marginGuideRight = _SnapPoint(930 - element.width, 930, isMargin: true);
    final marginGuideTop = _SnapPoint(100, 100, isMargin: true);
    final marginGuideBottom = _SnapPoint(492.5 - element.height, 492.5, isMargin: true);

    final xTargets = <_SnapPoint>[
      _SnapPoint(0, 0),
      marginGuideLeft,
      canvasCenterX,
      marginGuideRight,
      _SnapPoint(1000 - element.width, 1000),
    ];
    final yTargets = <_SnapPoint>[
      _SnapPoint(0, 0),
      marginGuideTop,
      canvasCenterY,
      marginGuideBottom,
      _SnapPoint(562.5 - element.height, 562.5),
    ];

    // 標題對齊基準
    final titleNotifier = localElements['title'];
    if (titleNotifier != null && element.id != 'title') {
      final t = titleNotifier.value;
      xTargets.addAll([
        _SnapPoint(t.x, t.x, isMargin: true),
        _SnapPoint(t.x + t.width / 2 - element.width / 2, t.x + t.width / 2, isCenter: true),
        _SnapPoint(t.x + t.width - element.width, t.x + t.width, isMargin: true),
      ]);
      yTargets.addAll([
        _SnapPoint(t.y, t.y, isMargin: true),
        _SnapPoint(t.y + t.height / 2 - element.height / 2, t.y + t.height / 2, isCenter: true),
        _SnapPoint(t.y + t.height + 16, t.y + t.height + 16, isMargin: true),
        _SnapPoint(t.y + t.height + 24, t.y + t.height + 24, isMargin: true),
        _SnapPoint(t.y + t.height - element.height, t.y + t.height, isMargin: true),
      ]);
    }

    for (final other in localElements.values) {
      if (other.value.id == element.id || other.value.id == 'title') continue;
      final target = other.value;
      xTargets.addAll([
        _SnapPoint(target.x, target.x),
        _SnapPoint(target.x + target.width / 2 - element.width / 2, target.x + target.width / 2, isCenter: true),
        _SnapPoint(target.x + target.width - element.width, target.x + target.width),
      ]);
      yTargets.addAll([
        _SnapPoint(target.y, target.y),
        _SnapPoint(target.y + target.height / 2 - element.height / 2, target.y + target.height / 2, isCenter: true),
        _SnapPoint(target.y + target.height - element.height, target.y + target.height),
      ]);
    }

    final snapX = _nearest(x, xTargets);
    final snapY = _nearest(y, yTargets);
    bool isMarginX = false;
    bool isMarginY = false;
    if (snapX != null) {
      x = snapX.value;
      activeGuideX = snapX.guide;
      isCenterX = snapX.isCenter;
      isMarginX = snapX.isMargin;
    }
    if (snapY != null) {
      y = snapY.value;
      activeGuideY = snapY.guide;
      isCenterY = snapY.isCenter;
      isMarginY = snapY.isMargin;
    }

    notifier.value = element.copyWith(x: x, y: y);
    guidesNotifier.value = _GuidesData(
      x: activeGuideX,
      y: activeGuideY,
      isCenterX: isCenterX,
      isCenterY: isCenterY,
      isMarginX: isMarginX,
      isMarginY: isMarginY,
    );
  }

  void _endDrag(ValueNotifier<ReminderElementData> notifier) {
    widget.onChanged(notifier.value);
    guidesNotifier.value = const _GuidesData();
    draggingId = null;
    dragStartElement = null;
    dragDistance = Offset.zero;
  }

  void _beginResize(ValueNotifier<ReminderElementData> notifier) {
    resizeStartElement = notifier.value;
    resizeDistance = Offset.zero;
  }

  void _resize(ValueNotifier<ReminderElementData> notifier, Offset delta) {
    if (resizeStartElement == null) {
      _beginResize(notifier);
    }
    resizeDistance += delta;
    final start = resizeStartElement!;
    final nextWidth = (start.width + resizeDistance.dx).clamp(60, 1000 - start.x).toDouble();
    final nextHeight = (start.height + resizeDistance.dy).clamp(30, 562.5 - start.y).toDouble();
    notifier.value = start.copyWith(width: nextWidth, height: nextHeight);
  }

  void _endResize(ValueNotifier<ReminderElementData> notifier) {
    widget.onChanged(notifier.value);
    resizeStartElement = null;
    resizeDistance = Offset.zero;
  }

  _SnapPoint? _nearest(double value, List<_SnapPoint> targets) {
    _SnapPoint? best;
    var distance = 10.0;
    for (final target in targets) {
      final difference = (target.value - value).abs();
      if (difference < distance) {
        distance = difference;
        best = target;
      }
    }
    return best;
  }

  @override
  void dispose() {
    guidesNotifier.dispose();
    for (final notifier in localElements.values) {
      notifier.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unselected = localElements.values.where((n) => n.value.id != widget.selectedId).toList();
    final selectedNotifier = widget.selectedId == null ? null : localElements[widget.selectedId];

    return Container(
      width: 1000,
      height: 562.5,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          guidesNotifier.value = const _GuidesData();
          widget.onDeselect?.call();
        },
        child: Stack(
          children: [
            // 先渲染未選取元素（底層）
            for (final notifier in unselected) _fastElement(context, notifier),
            // 選取中的元素置頂渲染（頂層，不被其他元素遮擋）
            if (selectedNotifier != null) _fastElement(context, selectedNotifier),
            // 最頂層：對齊輔助線
            ValueListenableBuilder<_GuidesData>(
              valueListenable: guidesNotifier,
              builder: (_, guides, __) => Stack(
                children: [
                  if (guides.x != null)
                    Positioned(
                      left: guides.x!,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: guides.isCenterX ? 2.5 : (guides.isMarginX ? 2.0 : 1.5),
                        color: guides.isCenterX
                            ? const Color(0xFFFF007A)
                            : (guides.isMarginX ? const Color(0xFF00E5FF) : const Color(0xFF8B5CF6)),
                      ),
                    ),
                  if (guides.y != null)
                    Positioned(
                      top: guides.y!,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: guides.isCenterY ? 2.5 : (guides.isMarginY ? 2.0 : 1.5),
                        color: guides.isCenterY
                            ? const Color(0xFFFF007A)
                            : (guides.isMarginY ? const Color(0xFF00E5FF) : const Color(0xFF8B5CF6)),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fastElement(BuildContext context, ValueNotifier<ReminderElementData> notifier) {
    return ValueListenableBuilder<ReminderElementData>(
      valueListenable: notifier,
      builder: (context, element, _) {
        final selected = widget.selectedId == element.id;
        return Positioned(
          left: element.x,
          top: element.y,
          child: GestureDetector(
            onTap: () {
              guidesNotifier.value = const _GuidesData();
              widget.onChanged(element);
            },
            onPanStart: selected ? (_) => _beginDrag(notifier) : null,
            onPanUpdate: selected ? (details) => _move(notifier, details.delta) : null,
            onPanEnd: selected ? (_) => _endDrag(notifier) : null,
            onPanCancel: selected
                ? () {
                    guidesNotifier.value = const _GuidesData();
                    draggingId = null;
                    dragStartElement = null;
                    dragDistance = Offset.zero;
                  }
                : null,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: element.width,
                  height: element.height,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Color(element.backgroundColor),
                    border: selected
                        ? Border.all(color: const Color(0xFF8B5CF6), width: 2)
                        : Border.all(color: Colors.transparent, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _fastContent(context, element),
                ),
                if (selected)
                  Positioned(
                    right: -6,
                    bottom: -6,
                    child: GestureDetector(
                      onPanStart: (_) => _beginResize(notifier),
                      onPanUpdate: (details) => _resize(notifier, details.delta),
                      onPanEnd: (_) => _endResize(notifier),
                      onPanCancel: () {
                        resizeStartElement = null;
                        resizeDistance = Offset.zero;
                      },
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: const Color(0xFF8B5CF6),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const Icon(Icons.open_in_full, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                if (selected)
                  Positioned(
                    right: -10,
                    top: -10,
                    child: GestureDetector(
                      onTap: () => widget.onDeleted(element.id),
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                        ),
                        child: const Icon(Icons.close, size: 14, color: Colors.white),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _fastContent(BuildContext context, ReminderElementData element) {
    if (element.type == 'divider') return Center(child: Divider(thickness: 3, color: Color(element.color)));
    if (element.type == 'image') {
      return element.url.isEmpty
          ? const Center(child: Icon(Icons.image_outlined, size: 50))
          : Image.network(element.url, fit: BoxFit.cover);
    }
    final style = TextStyle(
      fontSize: element.fontSize,
      fontWeight: element.bold ? FontWeight.w800 : FontWeight.w400,
      fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
      decoration: element.underline ? TextDecoration.underline : TextDecoration.none,
      color: element.color == 0xff171a24 ? Theme.of(context).colorScheme.onSurface : Color(element.color),
    );
    final displayText = widget.state != null ? _resolveTemplateVariables(element.text, widget.state!) : element.text;
    if (element.type == 'button') return FilledButton(onPressed: null, child: Text(displayText, style: style));
    return Align(
        alignment: _fastTextAlignment(element.alignment),
        child: Text(displayText, textAlign: _fastTextAlign(element.alignment), style: style));
  }

  Alignment _fastTextAlignment(String value) {
    if (value == 'center') return Alignment.topCenter;
    if (value == 'right') return Alignment.topRight;
    return Alignment.topLeft;
  }

  TextAlign _fastTextAlign(String value) {
    if (value == 'center') return TextAlign.center;
    if (value == 'right') return TextAlign.right;
    return TextAlign.left;
  }
}

class _SnapPoint {
  final double value;
  final double guide;
  final bool isCenter;
  final bool isMargin;
  _SnapPoint(this.value, this.guide, {this.isCenter = false, this.isMargin = false});
}

class _GuidesData {
  final double? x;
  final double? y;
  final bool isCenterX;
  final bool isCenterY;
  final bool isMarginX;
  final bool isMarginY;

  const _GuidesData({
    this.x,
    this.y,
    this.isCenterX = false,
    this.isCenterY = false,
    this.isMarginX = false,
    this.isMarginY = false,
  });
}

class _ReminderEditorState extends State<_ReminderEditor> {
  late final TextEditingController titleController;
  late final TextEditingController contentController;
  late final TextEditingController dateController;
  late final TextEditingController startController;
  late final TextEditingController endController;
  late final TextEditingController repeatDatesController;
  late List<ReminderElementData> elements;
  late Map<String, ReminderBlockData> blocks;
  String? selectedId;
  int elementSerial = 0;
  late String repeatType;

  ReminderData? get original => widget.index == null ? null : widget.state.reminders[widget.index!];

  @override
  void initState() {
    super.initState();
    final item = original;
    titleController = TextEditingController(text: item?.title ?? '');
    contentController = TextEditingController(text: item?.content ?? '');
    dateController = TextEditingController(text: item?.date ?? '');
    startController = TextEditingController(text: item?.startTime ?? '08:00');
    endController = TextEditingController(text: item?.endTime ?? '18:00');
    repeatType = item?.repeatType ?? 'none';
    repeatDatesController = TextEditingController(text: item?.repeatDates.join(', ') ?? '');
    blocks = {...ReminderData.defaultBlockLayouts(), ...?item?.blocks};
    elements = item?.elements.isNotEmpty == true
        ? item!.elements.map((element) => element.copyWith()).toList()
        : [
            ReminderElementData(
                id: 'title',
                type: 'text',
                text: item?.title ?? '',
                x: 70,
                y: 70,
                width: 860,
                height: 90,
                fontSize: 48,
                bold: true),
            ReminderElementData(
                id: 'content',
                type: 'text',
                text: item?.content ?? '',
                x: 70,
                y: 190,
                width: 860,
                height: 150,
                fontSize: 28),
          ];
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    dateController.dispose();
    startController.dispose();
    endController.dispose();
    repeatDatesController.dispose();
    super.dispose();
  }

  Offset _nextPosition() {
    final slot = elements.length + elementSerial++;
    return Offset(70 + (slot % 4) * 215, 70 + (slot ~/ 4) * 100);
  }

  void _addElement(String type) {
    final id = '$type-${DateTime.now().microsecondsSinceEpoch}-${elementSerial++}';
    final position = _nextPosition();
    final element = switch (type) {
      'text' =>
        ReminderElementData(id: id, type: type, text: '新增文字', x: position.dx, y: position.dy, width: 360, height: 80),
      'button' => ReminderElementData(
          id: id,
          type: type,
          text: '按鈕',
          url: 'https://',
          x: position.dx,
          y: position.dy,
          width: 180,
          height: 56,
          fontSize: 16),
      'divider' => ReminderElementData(id: id, type: type, x: position.dx, y: position.dy, width: 500, height: 40),
      _ => ReminderElementData(id: id, type: 'image', x: position.dx, y: position.dy, width: 300, height: 180),
    };
    setState(() {
      elements.add(element);
      selectedId = id;
    });
  }

  void _replaceElement(ReminderElementData next) {
    final index = elements.indexWhere((element) => element.id == next.id);
    if (index < 0) return;
    setState(() {
      elements[index] = next;
      selectedId = next.id;
    });
  }

  void _moveLayer(String id, int delta) {
    final index = elements.indexWhere((e) => e.id == id);
    if (index < 0) return;
    setState(() {
      final item = elements.removeAt(index);
      if (delta == -999) {
        elements.insert(0, item);
      } else if (delta == 999) {
        elements.add(item);
      } else {
        final target = (index + delta).clamp(0, elements.length);
        elements.insert(target, item);
      }
    });
  }

  Future<void> _save() async {
    final error = await widget.state.saveReminder(
      ReminderData(
        title: titleController.text.trim(),
        content: contentController.text,
        date: dateController.text.trim(),
        startTime: startController.text.trim(),
        endTime: endController.text.trim(),
        repeatType: repeatType,
        repeatDates:
            repeatDatesController.text.split(',').map((date) => date.trim()).where((date) => date.isNotEmpty).toList(),
        blocks: blocks,
        elements: elements,
      ),
      index: widget.index,
    );
    if (!mounted) return;
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final preview = ReminderData(
      title: titleController.text,
      content: contentController.text,
      date: dateController.text,
      startTime: startController.text,
      endTime: endController.text,
      blocks: blocks,
      elements: elements,
    );
    return AlertDialog(
      title: Text(widget.index == null ? '新增提醒' : '編輯提醒'),
      content: SizedBox(
        width: 920,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                width: 860,
                height: 484,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.contain,
                    child: _FastReminderCanvas(
                      item: preview,
                      elements: elements,
                      selectedId: selectedId,
                      state: widget.state,
                      onChanged: _replaceElement,
                      onDeselect: () => setState(() => selectedId = null),
                      onDeleted: (id) => setState(() {
                        elements.removeWhere((element) => element.id == id);
                        selectedId = null;
                      }),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _elementButton('文字', Icons.text_fields, 'text'),
                  _elementButton('按鈕', Icons.smart_button_outlined, 'button'),
                  _elementButton('分隔線', Icons.horizontal_rule, 'divider'),
                  _elementButton('圖片', Icons.image_outlined, 'image'),
                ],
              ),
              if (selectedId != null)
                _ElementInspector(
                  element: elements.firstWhere((element) => element.id == selectedId),
                  onChanged: _replaceElement,
                  onBringToFront: () => _moveLayer(selectedId!, 999),
                  onBringForward: () => _moveLayer(selectedId!, 1),
                  onSendBackward: () => _moveLayer(selectedId!, -1),
                  onSendToBack: () => _moveLayer(selectedId!, -999),
                ),
              const Divider(height: 28),
              TextField(
                controller: titleController,
                onChanged: (value) => setState(() {
                  final index = elements.indexWhere((element) => element.id == 'title');
                  if (index >= 0) elements[index] = elements[index].copyWith(text: value);
                }),
                decoration: const InputDecoration(labelText: '標題'),
              ),
              TextField(
                controller: contentController,
                maxLines: 4,
                onChanged: (value) => setState(() {
                  final index = elements.indexWhere((element) => element.id == 'content');
                  if (index >= 0) elements[index] = elements[index].copyWith(text: value);
                }),
                decoration: const InputDecoration(labelText: '內容'),
              ),
              Row(
                children: [
                  Expanded(
                      child: TextField(controller: dateController, decoration: const InputDecoration(labelText: '日期'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child:
                          TextField(controller: startController, decoration: const InputDecoration(labelText: '開始'))),
                  const SizedBox(width: 12),
                  Expanded(
                      child: TextField(controller: endController, decoration: const InputDecoration(labelText: '結束'))),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: repeatType,
                      decoration: const InputDecoration(labelText: '重複'),
                      items: const [
                        DropdownMenuItem(value: 'none', child: Text('不重複')),
                        DropdownMenuItem(value: 'daily', child: Text('每日')),
                        DropdownMenuItem(value: 'weekly', child: Text('每週')),
                        DropdownMenuItem(value: 'specific', child: Text('指定日期')),
                      ],
                      onChanged: (value) => setState(() => repeatType = value ?? 'none'),
                    ),
                  ),
                  if (repeatType == 'specific') ...[
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: repeatDatesController,
                        decoration: const InputDecoration(labelText: '日期（YYYY-MM-DD，以逗號分隔）'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_outlined), label: const Text('套用並儲存')),
      ],
    );
  }

  Widget _elementButton(String label, IconData icon, String type) {
    return FilledButton.tonalIcon(
      onPressed: () => _addElement(type),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

class _ElementInspector extends StatefulWidget {
  final ReminderElementData element;
  final ValueChanged<ReminderElementData> onChanged;
  final VoidCallback? onBringToFront;
  final VoidCallback? onBringForward;
  final VoidCallback? onSendBackward;
  final VoidCallback? onSendToBack;

  const _ElementInspector({
    required this.element,
    required this.onChanged,
    this.onBringToFront,
    this.onBringForward,
    this.onSendBackward,
    this.onSendToBack,
  });

  @override
  State<_ElementInspector> createState() => _ElementInspectorState();
}

class _ElementInspectorState extends State<_ElementInspector> {
  late final TextEditingController textController;
  late final TextEditingController urlController;

  @override
  void initState() {
    super.initState();
    textController = TextEditingController(text: widget.element.text);
    urlController = TextEditingController(text: widget.element.url);
  }

  @override
  void didUpdateWidget(covariant _ElementInspector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.element.id != widget.element.id) {
      textController.text = widget.element.text;
      urlController.text = widget.element.url;
    }
  }

  @override
  void dispose() {
    textController.dispose();
    urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final element = widget.element;
    final supportsText = element.type == 'text' || element.type == 'button';
    final supportsUrl = element.type == 'button' || element.type == 'image';
    return Card(
      margin: const EdgeInsets.only(top: 14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('元素格式 · ${element.type}', style: Theme.of(context).textTheme.titleSmall),
            if (supportsText) ...[
              TextField(
                controller: textController,
                onChanged: (value) => widget.onChanged(element.copyWith(text: value)),
                decoration: const InputDecoration(labelText: '文字'),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('+ (nextclass)'),
                    tooltip: '插入下一節課變數',
                    onPressed: () {
                      final updated = '${textController.text}(nextclass)';
                      textController.text = updated;
                      widget.onChanged(element.copyWith(text: updated));
                    },
                  ),
                  ActionChip(
                    label: const Text('+ (currentclass)'),
                    tooltip: '插入當前課堂變數',
                    onPressed: () {
                      final updated = '${textController.text}(currentclass)';
                      textController.text = updated;
                      widget.onChanged(element.copyWith(text: updated));
                    },
                  ),
                  ActionChip(
                    label: const Text('+ (time)'),
                    tooltip: '插入目前時間變數',
                    onPressed: () {
                      final updated = '${textController.text}(time)';
                      textController.text = updated;
                      widget.onChanged(element.copyWith(text: updated));
                    },
                  ),
                  ActionChip(
                    label: const Text('+ (date)'),
                    tooltip: '插入今日日期變數',
                    onPressed: () {
                      final updated = '${textController.text}(date)';
                      textController.text = updated;
                      widget.onChanged(element.copyWith(text: updated));
                    },
                  ),
                  ActionChip(
                    label: const Text('+ (weekday)'),
                    tooltip: '插入星期變數',
                    onPressed: () {
                      final updated = '${textController.text}(weekday)';
                      textController.text = updated;
                      widget.onChanged(element.copyWith(text: updated));
                    },
                  ),
                ],
              ),
            ],
            if (supportsUrl)
              TextField(
                controller: urlController,
                onChanged: (value) => widget.onChanged(element.copyWith(url: value)),
                decoration: InputDecoration(labelText: element.type == 'image' ? '圖片網址' : '按鈕連結'),
              ),
            if (element.type == 'button')
              DropdownButtonFormField<String>(
                initialValue: const [
                  'internal://seats',
                  'internal://lottery',
                  'internal://diary',
                  'internal://schedule'
                ].contains(element.url)
                    ? element.url
                    : null,
                decoration: const InputDecoration(labelText: '快速選擇軟體內頁'),
                items: const [
                  DropdownMenuItem(value: 'internal://seats', child: Text('座位表')),
                  DropdownMenuItem(value: 'internal://lottery', child: Text('選號')),
                  DropdownMenuItem(value: 'internal://diary', child: Text('聯絡簿')),
                  DropdownMenuItem(value: 'internal://schedule', child: Text('課表')),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  urlController.text = value;
                  widget.onChanged(element.copyWith(url: value));
                },
              ),
            if (supportsText)
              Row(
                children: [
                  const Text('字級'),
                  Expanded(
                    child: Slider(
                      value: element.fontSize.clamp(10, 96),
                      min: 10,
                      max: 96,
                      divisions: 86,
                      label: element.fontSize.round().toString(),
                      onChanged: (value) => widget.onChanged(element.copyWith(fontSize: value)),
                    ),
                  ),
                  IconButton(
                    tooltip: '粗體',
                    onPressed: () => widget.onChanged(element.copyWith(bold: !element.bold)),
                    icon: Icon(Icons.format_bold, color: element.bold ? Theme.of(context).colorScheme.primary : null),
                  ),
                  IconButton(
                    tooltip: '斜體',
                    onPressed: () => widget.onChanged(element.copyWith(italic: !element.italic)),
                    icon:
                        Icon(Icons.format_italic, color: element.italic ? Theme.of(context).colorScheme.primary : null),
                  ),
                  IconButton(
                    tooltip: '底線',
                    onPressed: () => widget.onChanged(element.copyWith(underline: !element.underline)),
                    icon: Icon(Icons.format_underline,
                        color: element.underline ? Theme.of(context).colorScheme.primary : null),
                  ),
                ],
              ),
            if (supportsText)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'left', icon: Icon(Icons.format_align_left)),
                  ButtonSegment(value: 'center', icon: Icon(Icons.format_align_center)),
                  ButtonSegment(value: 'right', icon: Icon(Icons.format_align_right)),
                ],
                selected: {element.alignment},
                onSelectionChanged: (value) => widget.onChanged(element.copyWith(alignment: value.first)),
              ),
            const SizedBox(height: 8),
            const Text('文字顏色'),
            Wrap(
              spacing: 8,
              children: [
                for (final color in const [0xff171a24, 0xffd32f2f, 0xff1565c0, 0xff2e7d32, 0xfff57c00, 0xffffffff])
                  InkWell(
                    onTap: () => widget.onChanged(element.copyWith(color: color)),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black26),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Text('圖層順序：', style: TextStyle(fontSize: 14)),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: '移至最底層',
                  icon: const Icon(Icons.flip_to_back, size: 18),
                  onPressed: widget.onSendToBack,
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: '下移一層',
                  icon: const Icon(Icons.arrow_downward, size: 18),
                  onPressed: widget.onSendBackward,
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: '上移一層',
                  icon: const Icon(Icons.arrow_upward, size: 18),
                  onPressed: widget.onBringForward,
                ),
                const SizedBox(width: 6),
                IconButton.filledTonal(
                  tooltip: '移至最頂層',
                  icon: const Icon(Icons.flip_to_front, size: 18),
                  onPressed: widget.onBringToFront,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class SeatPage extends StatelessWidget {
  final AppState state;
  const SeatPage({super.key, required this.state});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('座位表', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 1180,
                height: 640,
                child: _SeatRows(state: state, editable: false),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _SeatRows extends StatelessWidget {
  final AppState state;
  final bool editable;
  const _SeatRows({required this.state, required this.editable});

  @override
  Widget build(BuildContext context) {
    final highestRow = state.seats.isEmpty ? 5 : state.seats.map((seat) => seat.row).reduce((a, b) => a > b ? a : b);
    final highestSlot = state.seats.isEmpty ? 4 : state.seats.map((seat) => seat.slot).reduce((a, b) => a > b ? a : b);
    final slotCount = highestSlot < 4 ? 5 : highestSlot + 1;
    return SingleChildScrollView(
      child: Column(
        children: [
          if (editable)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => state.rotateSeats(-1),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('每排向左換位'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => state.rotateSeats(1),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('每排向右換位'),
                  ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF30364A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Center(
              child: Text('講台', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var row = 0; row <= highestRow; row++) _buildSeatColumn(context, row, slotCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeatColumn(BuildContext context, int row, int slotCount) {
    final indexes = [
      for (var i = 0; i < state.seats.length; i++)
        if (state.seats[i].row == row) i
    ]..sort((a, b) => state.seats[a].slot.compareTo(state.seats[b].slot));
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        children: [
          SizedBox(
            width: 150,
            height: slotCount * 108,
            child: Stack(
              children: [
                for (var slot = 0; slot < slotCount; slot++)
                  if (_seatAtSlot(indexes, slot) != null)
                    Positioned(
                      left: 0,
                      top: slot * 108,
                      width: 150,
                      height: 108,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _SeatCard(
                          state: state,
                          index: _seatAtSlot(indexes, slot)!,
                          editable: editable,
                          onEdit: () => _editSeat(context, state, _seatAtSlot(indexes, slot)!, editable),
                        ),
                      ),
                    ),
              ],
            ),
          ),
          if (editable)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: '新增座位',
                  onPressed: () => state.addSeat(row: row),
                  icon: const Icon(Icons.add_box_outlined),
                ),
                IconButton(
                  tooltip: '刪除整排座位',
                  onPressed: () => state.deleteRow(row),
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
        ],
      ),
    );
  }

  int? _seatAtSlot(List<int> indexes, int slot) {
    for (final index in indexes) {
      if (state.seats[index].slot == slot) return index;
    }
    return null;
  }
}

class _SeatCard extends StatelessWidget {
  final AppState state;
  final int index;
  final bool editable;
  final VoidCallback onEdit;

  const _SeatCard({required this.state, required this.index, required this.editable, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    final seat = state.seats[index];
    final card = Card(
      color: _seatColor(context, seat.gender),
      child: InkWell(
        onTap: editable ? onEdit : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(seat.number, style: const TextStyle(fontSize: 18)),
            const Spacer(),
            Text(seat.name.isEmpty ? '空位' : seat.name,
                overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    );
    if (!editable) return card;
    return Draggable<int>(
      data: index,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(width: 150, height: 108, child: Opacity(opacity: 0.78, child: card)),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: card),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (details) => details.data != index,
        onAcceptWithDetails: (details) => state.swapSeats(details.data, index),
        builder: (context, candidates, rejected) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: candidates.isEmpty
              ? null
              : BoxDecoration(
                  border: Border.all(color: Theme.of(context).colorScheme.primary, width: 3),
                  borderRadius: BorderRadius.circular(16),
                ),
          child: card,
        ),
      ),
    );
  }

  Color _seatColor(BuildContext context, String gender) {
    if (gender == '男') {
      return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF164A78) : const Color(0xFFDCEEFF);
    }
    if (gender == '女') {
      return Theme.of(context).brightness == Brightness.dark ? const Color(0xFF7D294B) : const Color(0xFFFFE0EA);
    }
    return Theme.of(context).colorScheme.surfaceContainerHighest;
  }
}

Future<void> _editSeat(BuildContext context, AppState state, int index, bool editable) async {
  final numberController = TextEditingController(text: state.seats[index].number);
  final controller = TextEditingController(text: state.seats[index].name);
  var gender = state.seats[index].gender;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('編輯座位'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: numberController, decoration: const InputDecoration(labelText: '座號')),
            TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: '姓名')),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '', label: Text('未設定')),
                ButtonSegment(value: '男', label: Text('男生')),
                ButtonSegment(value: '女', label: Text('女生')),
              ],
              selected: {gender},
              onSelectionChanged: (value) => setState(() => gender = value.first),
            ),
          ],
        ),
        actions: [
          if (editable)
            TextButton(
              onPressed: () async {
                await state.deleteSeat(index);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('刪除座位'),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              await state.updateSeatDetails(index,
                  number: numberController.text, name: controller.text, gender: gender);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    ),
  );
  numberController.dispose();
  controller.dispose();
}

class LotteryPage extends StatefulWidget {
  final AppState state;
  const LotteryPage({super.key, required this.state});

  @override
  State<LotteryPage> createState() => _LotteryPageState();
}

class _LotteryPageState extends State<LotteryPage> {
  SeatData? selected;
  final random = Random();
  bool drawing = false;

  Future<void> draw() async {
    final candidates = widget.state.seats.where((seat) => seat.name.trim().isNotEmpty).toList();
    if (candidates.isEmpty || drawing) return;
    final winner = candidates[random.nextInt(candidates.length)];
    setState(() => drawing = true);
    const durations = [45, 45, 55, 65, 80, 100, 125, 155, 190, 230];
    for (final milliseconds in durations) {
      if (!mounted) return;
      setState(() => selected = candidates[random.nextInt(candidates.length)]);
      await Future<void>.delayed(Duration(milliseconds: milliseconds));
    }
    if (!mounted) return;
    setState(() {
      selected = winner;
      drawing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('選號機器', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800))),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: selected == null
                  ? const Text('從班上隨機抽出一位同學', style: TextStyle(fontSize: 24))
                  : Card(
                      color: selected!.gender == '男'
                          ? const Color(0xFFDCEEFF)
                          : selected!.gender == '女'
                              ? const Color(0xFFFFE0EA)
                              : null,
                      child: Padding(
                        padding: const EdgeInsets.all(44),
                        child: Column(mainAxisSize: MainAxisSize.min, children: [
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 70),
                            child: Text(selected!.number,
                                key: ValueKey(selected!.number), style: const TextStyle(fontSize: 28)),
                          ),
                          const SizedBox(height: 10),
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 70),
                            child: Text(selected!.name,
                                key: ValueKey(selected!.name),
                                style: const TextStyle(fontSize: 52, fontWeight: FontWeight.w900)),
                          ),
                        ]),
                      ),
                    ),
            ),
          ),
          FilledButton.icon(
              onPressed: drawing ? null : draw, icon: const Icon(Icons.casino), label: Text(drawing ? '抽選中' : '開始抽選')),
        ],
      ),
    );
  }
}

class DiaryPage extends StatefulWidget {
  final AppState state;
  final bool editable;
  const DiaryPage({super.key, required this.state, this.editable = true});
  @override
  State<DiaryPage> createState() => _DiaryPageState();
}

class _DiaryPageState extends State<DiaryPage> {
  late DateTime selectedDate;
  final tags = const ['一般', '作業', '考試', '活動', '通知'];

  @override
  void initState() {
    super.initState();
    selectedDate = DateTime.now();
  }

  String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final key = dateKey(selectedDate);
    final entries = widget.state.diaryEntries.where((entry) => entry.date == key).toList();
    return Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 720 ? 12 : 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('聯絡簿', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
            IconButton(
                onPressed: () => setState(() => selectedDate = selectedDate.subtract(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_left)),
            Text(key, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            IconButton(
                onPressed: () => setState(() => selectedDate = selectedDate.add(const Duration(days: 1))),
                icon: const Icon(Icons.chevron_right)),
            if (widget.editable)
              FilledButton.icon(onPressed: () => _addEntry(key), icon: const Icon(Icons.add), label: const Text('新增')),
          ],
        ),
        const SizedBox(height: 18),
        Expanded(
            child: ListView.separated(
          itemCount: entries.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, index) => Card(
              child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(children: [
                    Chip(label: Text(entries[index].tag)),
                    const SizedBox(width: 14),
                    Expanded(child: Text(entries[index].content, style: const TextStyle(fontSize: 20))),
                    if (widget.editable) ...[
                      IconButton(onPressed: () => _editEntry(entries[index]), icon: const Icon(Icons.edit_outlined)),
                      IconButton(
                          onPressed: () async {
                            widget.state.diaryEntries.remove(entries[index]);
                            await widget.state.saveDiaryEntries(widget.state.diaryEntries);
                          },
                          icon: const Icon(Icons.delete_outline)),
                    ],
                  ]))),
        )),
      ]),
    );
  }

  Future<void> _addEntry(String date) async {
    final entry = await _entryDialog(DiaryEntry(date: date, tag: tags.first, content: ''));
    if (entry != null) await widget.state.saveDiaryEntries([...widget.state.diaryEntries, entry]);
  }

  Future<void> _editEntry(DiaryEntry old) async {
    final entry = await _entryDialog(old);
    if (entry == null) return;
    final index = widget.state.diaryEntries.indexOf(old);
    final copy = [...widget.state.diaryEntries]..[index] = entry;
    await widget.state.saveDiaryEntries(copy);
  }

  Future<DiaryEntry?> _entryDialog(DiaryEntry initial) async {
    final controller = TextEditingController(text: initial.content);
    final tagController = TextEditingController(text: tags.contains(initial.tag) ? '' : initial.tag);
    var tag = tags.contains(initial.tag) ? initial.tag : '自訂';
    final tagOptions = [...tags, '自訂'];
    final result = await showDialog<DiaryEntry>(
        context: context,
        builder: (context) => StatefulBuilder(
            builder: (context, setState) => AlertDialog(
                  title: const Text('聯絡簿內容'),
                  content: Column(mainAxisSize: MainAxisSize.min, children: [
                    TextField(controller: controller, maxLines: 5, decoration: const InputDecoration(labelText: '內容')),
                    DropdownButtonFormField<String>(
                        initialValue: tag,
                        items: tagOptions.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                        onChanged: (value) {
                          if (value != null) setState(() => tag = value);
                        },
                        decoration: const InputDecoration(labelText: '標籤')),
                    if (tag == '自訂')
                      TextField(controller: tagController, decoration: const InputDecoration(labelText: '自訂標籤文字')),
                  ]),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                    FilledButton(
                        onPressed: () => Navigator.pop(
                            context,
                            DiaryEntry(
                                date: initial.date,
                                tag: tag == '自訂' && tagController.text.trim().isNotEmpty
                                    ? tagController.text.trim()
                                    : tag,
                                content: controller.text)),
                        child: const Text('儲存'))
                  ],
                )));
    controller.dispose();
    tagController.dispose();
    return result;
  }
}

class SchedulePage extends StatefulWidget {
  final AppState state;
  final bool editable;
  const SchedulePage({super.key, required this.state, this.editable = false});
  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final days = const ['週一', '週二', '週三', '週四', '週五'];

  @override
  Widget build(BuildContext context) {
    final maxLesson = widget.state.scheduleEntries.isEmpty
        ? 6
        : widget.state.scheduleEntries.map((e) => e.lesson).reduce((a, b) => a > b ? a : b) + 1;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('課表', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const Spacer(),
          if (widget.editable) ...[
            OutlinedButton.icon(
                onPressed: maxLesson == 0 ? null : () => _removeLesson(maxLesson - 1),
                icon: const Icon(Icons.remove),
                label: const Text('減少一節')),
            const SizedBox(width: 8),
            FilledButton.icon(
                onPressed: () => _addLesson(maxLesson), icon: const Icon(Icons.add), label: const Text('增加一節'))
          ]
        ]),
        const SizedBox(height: 16),
        Expanded(child: LayoutBuilder(builder: (context, constraints) {
          const contentWidth = 5 * 178.0 + 105.0 + 4 * 34.0 + 80.0;
          final contentHeight = 58.0 + maxLesson * 82.0;
          return Center(
            child: FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: contentWidth,
                height: contentHeight,
                child: DataTable(
                  horizontalMargin: 20,
                  columnSpacing: 34,
                  headingRowHeight: 58.0,
                  dataRowMinHeight: 82.0,
                  dataRowMaxHeight: 82.0,
                  columns: [
                    const DataColumn(label: Text('節次', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                    for (var day = 0; day < days.length; day++)
                      DataColumn(label: widget.editable ? _scheduleHeader(day) : Text(days[day]))
                  ],
                  rows: [
                    for (var lesson = 0; lesson < maxLesson; lesson++)
                      DataRow(cells: [
                        DataCell(_lessonLabel(lesson)),
                        for (var day = 0; day < 5; day++) DataCell(_scheduleCell(day, lesson))
                      ])
                  ],
                ),
              ),
            ),
          );
        }))
      ]),
    );
  }

  Widget _scheduleCell(int day, int lesson) {
    final matches = widget.state.scheduleEntries.where((e) => e.weekday == day && e.lesson == lesson).toList();
    final entry = matches.isEmpty ? null : matches.first;
    return InkWell(
        onTap: widget.editable ? () => _editSubject(day, lesson, entry) : null,
        child: SizedBox(
            width: 178,
            height: 76,
            child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: entry == null
                    ? const Center(child: Icon(Icons.add_circle_outline))
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text(entry.subject.isEmpty ? '未命名' : entry.subject,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                            if (entry.teacher.isNotEmpty)
                              Text(entry.teacher,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, color: Colors.black54)),
                          ]))));
  }

  Widget _lessonLabel(int lesson) {
    final entries = widget.state.scheduleEntries.where((entry) => entry.lesson == lesson).toList();
    final entry = entries.isEmpty
        ? null
        : entries.firstWhere((item) => item.startTime.isNotEmpty || item.endTime.isNotEmpty,
            orElse: () => entries.first);
    final time = entry == null || (entry.startTime.isEmpty && entry.endTime.isEmpty)
        ? '--:--~--:--'
        : '${entry.startTime.isEmpty ? '--:--' : entry.startTime}~${entry.endTime.isEmpty ? '--:--' : entry.endTime}';
    return InkWell(
      onTap: widget.editable ? () => _editLesson(0, lesson, entry) : null,
      child: SizedBox(
        width: 105,
        height: 68,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('${lesson + 1}',
                textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            Text(time, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14), maxLines: 1),
          ],
        ),
      ),
    );
  }

  Widget _scheduleHeader(int day) {
    final count = widget.state.scheduleEntries.where((entry) => entry.weekday == day).length;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Text(days[day]),
      IconButton(
          tooltip: '增加${days[day]}課堂', onPressed: () => _addDayLesson(day), icon: const Icon(Icons.add, size: 16)),
      IconButton(
          tooltip: '減少${days[day]}課堂',
          onPressed: count == 0 ? null : () => _removeDayLesson(day),
          icon: const Icon(Icons.remove, size: 16)),
    ]);
  }

  Future<void> _addDayLesson(int day) async {
    final lessons =
        widget.state.scheduleEntries.where((entry) => entry.weekday == day).map((entry) => entry.lesson).toList();
    final next = lessons.isEmpty ? 0 : lessons.reduce((a, b) => a > b ? a : b) + 1;
    final list = [
      ...widget.state.scheduleEntries,
      ScheduleEntry(weekday: day, lesson: next, subject: '', startTime: '08:00', endTime: '08:50')
    ];
    await widget.state.saveScheduleEntries(list);
  }

  Future<void> _removeDayLesson(int day) async {
    final entries = widget.state.scheduleEntries.where((entry) => entry.weekday == day).toList();
    if (entries.isEmpty) return;
    final last = entries.map((entry) => entry.lesson).reduce((a, b) => a > b ? a : b);
    final list = [...widget.state.scheduleEntries]
      ..removeWhere((entry) => entry.weekday == day && entry.lesson == last);
    await widget.state.saveScheduleEntries(list);
  }

  Future<void> _addLesson(int lesson) async {
    final list = [...widget.state.scheduleEntries];
    for (var day = 0; day < 5; day++) {
      list.add(ScheduleEntry(weekday: day, lesson: lesson, subject: '', startTime: '08:00', endTime: '08:50'));
    }
    await widget.state.saveScheduleEntries(list);
  }

  Future<void> _removeLesson(int lesson) async {
    final list = [...widget.state.scheduleEntries]..removeWhere((entry) => entry.lesson == lesson);
    await widget.state.saveScheduleEntries(list);
  }

  Future<void> _editSubject(int day, int lesson, ScheduleEntry? old) async {
    final subject = TextEditingController(text: old?.subject ?? '');
    final teacher = TextEditingController(text: old?.teacher ?? '');
    final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              title: Text('${days[day]} 第 ${lesson + 1} 節'),
              content: Column(mainAxisSize: MainAxisSize.min, children: [
                TextField(controller: subject, autofocus: true, decoration: const InputDecoration(labelText: '科目')),
                TextField(controller: teacher, decoration: const InputDecoration(labelText: '老師名稱')),
              ]),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('儲存')),
              ],
            ));
    if (result == true) {
      final list = [...widget.state.scheduleEntries];
      final index = list.indexWhere((entry) => entry.weekday == day && entry.lesson == lesson);
      if (index >= 0) {
        final current = list[index];
        list[index] = ScheduleEntry(
          weekday: day,
          lesson: lesson,
          subject: subject.text,
          teacher: teacher.text,
          startTime: current.startTime,
          endTime: current.endTime,
        );
      } else {
        list.add(ScheduleEntry(
            weekday: day,
            lesson: lesson,
            subject: subject.text,
            teacher: teacher.text,
            startTime: '08:00',
            endTime: '08:50'));
      }
      await widget.state.saveScheduleEntries(list);
    }
    subject.dispose();
    teacher.dispose();
  }

  Future<void> _editLesson(int day, int lesson, ScheduleEntry? old) async {
    final subject = TextEditingController(text: old?.subject ?? '');
    final teacher = TextEditingController(text: old?.teacher ?? '');
    final start = TextEditingController(text: old?.startTime ?? '08:00');
    final end = TextEditingController(text: old?.endTime ?? '08:50');
    final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: Text('${days[day]} 第 ${lesson + 1} 節'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(controller: subject, decoration: const InputDecoration(labelText: '科目')),
                  TextField(controller: teacher, decoration: const InputDecoration(labelText: '老師名稱')),
                  Row(children: [
                    Expanded(
                        child: TextField(controller: start, decoration: const InputDecoration(labelText: '開始（??:??）'))),
                    const SizedBox(width: 10),
                    Expanded(
                        child: TextField(controller: end, decoration: const InputDecoration(labelText: '結束（??:??）')))
                  ])
                ]),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('儲存'))
                ]));
    if (result == true) {
      final list = [...widget.state.scheduleEntries];
      list.removeWhere((e) => e.weekday == day && e.lesson == lesson);
      list.add(ScheduleEntry(
          weekday: day,
          lesson: lesson,
          subject: subject.text,
          teacher: teacher.text,
          startTime: start.text,
          endTime: end.text));
      for (var weekday = 0; weekday < 5; weekday++) {
        final index = list.indexWhere((e) => e.weekday == weekday && e.lesson == lesson);
        if (index >= 0) {
          list[index] = ScheduleEntry(
            weekday: weekday,
            lesson: lesson,
            subject: list[index].subject,
            teacher: list[index].teacher,
            startTime: start.text,
            endTime: end.text,
          );
        }
      }
      await widget.state.saveScheduleEntries(list);
    }
    subject.dispose();
    teacher.dispose();
    start.dispose();
    end.dispose();
  }
}

class _EditableListPage extends StatefulWidget {
  final String title;
  final List<String> items;
  final Future<void> Function(List<String>) save;
  final String hint;
  const _EditableListPage({required this.title, required this.items, required this.save, required this.hint});
  @override
  State<_EditableListPage> createState() => _EditableListPageState();
}

class _EditableListPageState extends State<_EditableListPage> {
  late List<TextEditingController> controllers;
  @override
  void initState() {
    super.initState();
    controllers = <TextEditingController>[
      for (final item in widget.items) TextEditingController(text: item),
    ];
  }

  @override
  void dispose() {
    for (final c in controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    await widget.save(controllers.map((e) => e.text).toList());
  }

  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(widget.title, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const Spacer(),
          FilledButton.icon(
              onPressed: () => setState(() => controllers.add(TextEditingController())),
              icon: const Icon(Icons.add),
              label: const Text('新增'))
        ]),
        const SizedBox(height: 18),
        Expanded(
            child: ListView.builder(
                itemCount: controllers.length,
                itemBuilder: (_, i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      Expanded(
                          child: TextField(
                              controller: controllers[i], decoration: InputDecoration(hintText: widget.hint))),
                      IconButton(
                          onPressed: () {
                            setState(() {
                              controllers[i].dispose();
                              controllers.removeAt(i);
                            });
                          },
                          icon: const Icon(Icons.delete_outline))
                    ])))),
        Align(alignment: Alignment.centerRight, child: FilledButton(onPressed: save, child: const Text('儲存')))
      ]));
}

class AdminPage extends StatelessWidget {
  final AppState state;
  const AdminPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 720;
    return DefaultTabController(
      length: 7,
      child: Column(
        children: [
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              labelPadding: EdgeInsets.symmetric(horizontal: mobile ? 12 : 16),
              tabs: const [
                Tab(icon: Icon(Icons.notifications_none), text: '提醒管理'),
                Tab(icon: Icon(Icons.grid_view), text: '座位管理'),
                Tab(icon: Icon(Icons.calendar_month_outlined), text: '課表管理'),
                Tab(icon: Icon(Icons.import_export), text: '資料'),
                Tab(icon: Icon(Icons.timer_outlined), text: '測試'),
                Tab(icon: Icon(Icons.groups_outlined), text: '班級管理'),
                Tab(icon: Icon(Icons.cloud_outlined), text: '雲端與裝置'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: [
                ReminderPage(state: state, manage: true),
                _SeatAdminPage(state: state),
                SchedulePage(state: state, editable: true),
                _DataTransferPage(state: state),
                _ReminderTestPage(state: state),
                TeacherManagementPage(state: state),
                CloudDevicePage(state: state),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeatAdminPage extends StatelessWidget {
  final AppState state;
  const _SeatAdminPage({required this.state});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('座位配置', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
              const Spacer(),
              FilledButton.icon(
                onPressed: state.addRow,
                icon: const Icon(Icons.view_column_outlined),
                label: const Text('新增一排'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: _SeatRows(state: state, editable: true)),
        ],
      ),
    );
  }
}

class _DataTransferPage extends StatelessWidget {
  final AppState state;
  const _DataTransferPage({required this.state});

  static const dataTypes = [
    XTypeGroup(label: '729 資料', extensions: ['json'])
  ];

  Future<void> _export(BuildContext context) async {
    final pathController = TextEditingController(text: '729-資料備份.json');
    final path = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('匯出資料'),
          content: TextField(controller: pathController, decoration: const InputDecoration(labelText: '檔案路徑')),
          actions: [
            TextButton(
              onPressed: () async {
                final location = await getSaveLocation(
                  suggestedName: '729-資料備份.json',
                  acceptedTypeGroups: dataTypes,
                  confirmButtonText: '選擇',
                );
                if (location != null) setState(() => pathController.text = location.path);
              },
              child: const Text('選擇儲存位置'),
            ),
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, pathController.text.trim()), child: const Text('匯出')),
          ],
        ),
      ),
    );
    pathController.dispose();
    if (path == null) return;
    final fileName = path.split(RegExp(r'[\\/]')).last;
    if (fileName.isEmpty || !fileName.toLowerCase().endsWith('.json') || RegExp(r'[<>:"|?*]').hasMatch(fileName)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('檔名格式錯誤，請使用合法的 .json 檔名')));
      }
      return;
    }
    try {
      await state.exportToFile(path);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('資料已匯出')));
      }
    } on FileSystemException {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('匯出失敗')));
      }
    }
  }

  Future<void> _import(BuildContext context) async {
    final pathController = TextEditingController();
    final path = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('匯入資料'),
          content: TextField(controller: pathController, decoration: const InputDecoration(labelText: '檔案路徑')),
          actions: [
            TextButton(
              onPressed: () async {
                final file = await openFile(confirmButtonText: '選擇');
                if (file != null) setState(() => pathController.text = file.path);
              },
              child: const Text('選擇檔案'),
            ),
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            FilledButton(
                onPressed: () => Navigator.pop(dialogContext, pathController.text.trim()), child: const Text('下一步')),
          ],
        ),
      ),
    );
    pathController.dispose();
    if (path == null) return;
    if (!context.mounted) return;
    final fileName = path.split(RegExp(r'[\\/]')).last;
    if (fileName.isEmpty || !fileName.toLowerCase().endsWith('.json')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('只能匯入 .json 資料檔')));
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('匯入資料'),
        content: const Text('匯入會取代目前的提醒、座位、課表、聯絡簿與班級管理資料。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('繼續匯入')),
        ],
      ),
    );
    if (confirmed != true) return;
    final error = await state.importFromFile(path);
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? '資料已匯入')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('資料', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                  onPressed: () => _export(context), icon: const Icon(Icons.download), label: const Text('匯出資料')),
              OutlinedButton.icon(
                  onPressed: () => _import(context), icon: const Icon(Icons.upload), label: const Text('匯入資料')),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReminderTestPage extends StatefulWidget {
  final AppState state;
  const _ReminderTestPage({required this.state});

  @override
  State<_ReminderTestPage> createState() => _ReminderTestPageState();
}

class _ReminderTestPageState extends State<_ReminderTestPage> {
  late final TextEditingController dateController;
  late final TextEditingController timeController;

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  @override
  void initState() {
    super.initState();
    final value = widget.state.testNow ?? DateTime.now();
    dateController = TextEditingController(text: _dateKey(value));
    timeController = TextEditingController(
      text: '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}',
    );
  }

  @override
  void dispose() {
    dateController.dispose();
    timeController.dispose();
    super.dispose();
  }

  Future<void> _apply() async {
    final date = DateTime.tryParse(dateController.text.trim());
    final parts = timeController.text.trim().split(':');
    final hour = parts.length == 2 ? int.tryParse(parts[0]) : null;
    final minute = parts.length == 2 ? int.tryParse(parts[1]) : null;
    if (date == null || hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('測試日期或時間格式錯誤')));
      return;
    }
    await widget.state.setTestNow(DateTime(date.year, date.month, date.day, hour, minute));
  }

  Future<void> _clear() async {
    await widget.state.setTestNow(null);
    final now = DateTime.now();
    dateController.text = _dateKey(now);
    timeController.text = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final testNow = widget.state.testNow;
    final previewReminders = testNow == null
        ? <ReminderData>[]
        : widget.state.reminders.where((reminder) => reminder.isActiveAt(testNow)).toList();
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('提醒測試', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800)),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                  child: TextField(
                      controller: dateController, decoration: const InputDecoration(labelText: '假日期（YYYY-MM-DD）'))),
              const SizedBox(width: 14),
              Expanded(
                  child: TextField(
                      controller: timeController, decoration: const InputDecoration(labelText: '假時間（HH:MM）'))),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              FilledButton.icon(onPressed: _apply, icon: const Icon(Icons.play_arrow), label: const Text('套用測試時間')),
              const SizedBox(width: 10),
              OutlinedButton.icon(onPressed: _clear, icon: const Icon(Icons.restore), label: const Text('恢復系統時間')),
            ],
          ),
          if (testNow != null) ...[
            const SizedBox(height: 16),
            Text('目前測試時間：${_dateKey(testNow)} ${timeController.text}',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            Expanded(
              child: previewReminders.isEmpty
                  ? const Center(child: Text('這個時間沒有符合的提醒'))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 520,
                        mainAxisExtent: 300,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                      ),
                      itemCount: previewReminders.length,
                      itemBuilder: (context, index) {
                        final reminder = previewReminders[index];
                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              Expanded(
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.contain,
                                    child: _ReminderCanvas(
                                      item: reminder,
                                      blocks: reminder.blocks,
                                      elements: reminder.elements,
                                      state: widget.state,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(10),
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(reminder.title, style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
