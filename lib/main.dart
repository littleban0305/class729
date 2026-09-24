import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'app_window_controls.dart';
import 'app_state.dart';
import 'app_update_service.dart';
import 'device_gate.dart';
import 'firebase_config_flag.dart';
import 'firebase_options.dart';
import 'models.dart';
import 'teacher_pages.dart';
import 'services/auth_service.dart';

bool get isDesktopPlatform => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kFirebaseConfigured) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      firebaseRuntimeReady = true;
      firebaseRuntimeError = null;
    } catch (error) {
      firebaseRuntimeReady = false;
      firebaseRuntimeError = error.toString();
      debugPrint('Firebase 初始化失敗：$error');
    }
  }

  if (kFirebaseConfigured && firebaseRuntimeReady) {
    try {
      await AuthService.ensureAnonymouslyAuthenticated();
    } catch (error) {
      debugPrint('Firebase 匿名登入啟動失敗：$error');
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
  static const String _updateCheckUrl =
      'https://raw.githubusercontent.com/littleban0305/class729-updater/main/version.json';

  late ThemeMode themeMode;

  @override
  void initState() {
    super.initState();
    themeMode = widget.state.darkMode ? ThemeMode.dark : ThemeMode.light;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      const AppUpdateService().checkForUpdate(
        context,
        versionUrl: _updateCheckUrl,
      );
    });
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
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFF171A24)),
          bodyMedium: TextStyle(color: Color(0xFF30323A)),
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F6FA),
        cardTheme: const CardThemeData(elevation: 0),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        fontFamily: 'Class729Rounded',
        colorSchemeSeed: Colors.indigo,
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Color(0xFFF1F3F8)),
          bodyMedium: TextStyle(color: Color(0xFFD9DDE7)),
        ),
        scaffoldBackgroundColor: const Color(0xFF101217),
        cardTheme: const CardThemeData(elevation: 0),
      ),
      themeMode: themeMode,
      home: AnimatedBuilder(
        animation: widget.state,
        builder: (context, _) => Stack(
          children: [
            DeviceRoleGate(
              state: widget.state,
              onThemeModeChanged: (value) => setState(() => themeMode = value),
            ),
            const Positioned(
              top: 10,
              right: 10,
              child: AppWindowControls(),
            ),
          ],
        ),
      ),
    );
  }
}

class MainShell extends StatefulWidget {
  final AppState state;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  const MainShell({
    super.key,
    required this.state,
    required this.onThemeModeChanged,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool compact = false;
  int page = 0;

  static const _labels = [
    '提醒管理',
    '座位管理',
    '課表管理',
    '簽到',
    '登記紀錄',
    '班級照片',
    '資訊與設定',
    '提醒測試',
  ];
  static const _icons = [
    Icons.notifications_none,
    Icons.grid_view,
    Icons.calendar_month_outlined,
    Icons.how_to_reg_outlined,
    Icons.assignment_outlined,
    Icons.photo_library_outlined,
    Icons.info_outline,
    Icons.timer_outlined,
  ];

  void _selectPage(int value) => setState(() => page = value);

  Future<void> _exitTeacher() async {
    await AuthService().signOut();
    await widget.state.setDeviceRole('');
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      drawer: isMobile
          ? TeacherMobileDrawer(
              labels: _labels,
              icons: _icons,
              current: page,
              onSelect: _selectPage,
              extraItems: [
                ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  title: const Text('退出'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _exitTeacher();
                  },
                ),
              ],
            )
          : null,
      body: isMobile
          ? SafeArea(
              top: true,
              bottom: false,
              child: Stack(
                children: [
                  Column(
                    children: [
                      Builder(
                        builder: (barContext) => WindowBar(
                          title: '後台',
                          mobile: isMobile,
                          onOpenMenu: () => Scaffold.of(barContext).openDrawer(),
                        ),
                      ),
                      Expanded(
                        child: AnimatedBuilder(
                          animation: widget.state,
                          builder: (_, __) => KeyedSubtree(
                            key: ValueKey<int>(page),
                            child: AdminPage(
                              state: widget.state,
                              page: page,
                              onThemeModeChanged: widget.onThemeModeChanged,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            )
          : Stack(
              children: [
                Column(
                  children: [
                    const WindowBar(title: '後台'),
                    Expanded(
                      child: AnimatedBuilder(
                        animation: widget.state,
                        builder: (_, __) => AdminPage(
                          state: widget.state,
                          page: page,
                          onThemeModeChanged: widget.onThemeModeChanged,
                        ),
                      ),
                    ),
                  ],
                ),
                SideBar(
                  expanded: !compact,
                  current: page,
                  labels: _labels,
                  icons: _icons,
                  onSelect: _selectPage,
                  onToggle: () => setState(() => compact = !compact),
                  onExit: _exitTeacher,
                ),
              ],
            ),
    );
  }
}

class TeacherMobileDrawer extends StatelessWidget {
  final List<String> labels;
  final List<IconData> icons;
  final int current;
  final ValueChanged<int> onSelect;
  final List<Widget>? extraItems;

  const TeacherMobileDrawer({
    super.key,
    required this.labels,
    required this.icons,
    required this.current,
    required this.onSelect,
    this.extraItems,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 10, 12, 20),
              child: Text(
                '729',
                style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900),
              ),
            ),
            for (var i = 0; i < labels.length; i++)
              ListTile(
                selected: current == i,
                leading: Icon(icons[i]),
                title: Text(
                  labels[i],
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                onTap: () {
                  onSelect(i);
                  Navigator.pop(context);
                },
              ),
            if (extraItems != null) ...[
              const Divider(),
              ...extraItems!,
            ],
          ],
        ),
      ),
    );
  }
}

class WindowBar extends StatelessWidget {
  final String title;
  final bool mobile;
  final VoidCallback? onOpenMenu;
  final List<Widget>? actions;

  const WindowBar({
    super.key,
    required this.title,
    this.mobile = false,
    this.onOpenMenu,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: isDesktopPlatform ? (_) => windowManager.startDragging() : null,
      child: Container(
        height: mobile ? 64 : 56,
        padding: EdgeInsets.only(
          left: 18,
          right: isDesktopPlatform ? 120 : 72,
          top: mobile ? 8 : 0,
        ),
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
            const Text(
              '729',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (actions != null) ...actions!,
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
      .replaceAll(
        RegExp(r'\((?:nextclass|下一節課|下一節)\)', caseSensitive: false),
        nextClassName,
      )
      .replaceAll(
        RegExp(r'\{(?:nextclass|下一節課|下一節)\}', caseSensitive: false),
        nextClassName,
      )
      .replaceAll(
        RegExp(r'\((?:currentclass|本節課|這一節|目前課堂)\)', caseSensitive: false),
        currentClassName,
      )
      .replaceAll(
        RegExp(r'\{(?:currentclass|本節課|這一節|目前課堂)\}', caseSensitive: false),
        currentClassName,
      )
      .replaceAll(
        RegExp(r'\((?:time|時間|現在時間)\)', caseSensitive: false),
        timeStr,
      )
      .replaceAll(
        RegExp(r'\{(?:time|時間|現在時間)\}', caseSensitive: false),
        timeStr,
      )
      .replaceAll(
        RegExp(r'\((?:date|日期|今天日期)\)', caseSensitive: false),
        dateStr,
      )
      .replaceAll(
        RegExp(r'\{(?:date|日期|今天日期)\}', caseSensitive: false),
        dateStr,
      )
      .replaceAll(
        RegExp(r'\((?:weekday|星期|星期幾)\)', caseSensitive: false),
        weekdayStr,
      )
      .replaceAll(
        RegExp(r'\{(?:weekday|星期|星期幾)\}', caseSensitive: false),
        weekdayStr,
      );
}

class SideBar extends StatelessWidget {
  final bool expanded;
  final int current;
  final List<String> labels;
  final List<IconData> icons;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggle;
  final VoidCallback? onExit;

  const SideBar({
    super.key,
    required this.expanded,
    required this.current,
    required this.labels,
    required this.icons,
    required this.onSelect,
    required this.onToggle,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height - 36;
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
          constraints: BoxConstraints(maxHeight: maxHeight),
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: expanded
              ? SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(18, 8, 18, 12),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '729',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                      for (int i = 0; i < icons.length; i++) _navItem(i),
                      if (onExit != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: onExit,
                              child: const SizedBox(
                                height: 48,
                                child: Row(
                                  children: [
                                    SizedBox(width: 14),
                                    Icon(Icons.logout_outlined, color: Colors.white70),
                                    SizedBox(width: 12),
                                    Text(
                                      '退出',
                                      style: TextStyle(color: Colors.white, fontSize: 16),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      IconButton(
                        tooltip: '收合導覽列',
                        onPressed: onToggle,
                        icon: const Icon(
                          Icons.chevron_left,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '展開導覽列',
                      onPressed: onToggle,
                      icon: const Icon(Icons.menu, color: Colors.white, size: 25),
                    ),
                  ],
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
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    labels[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ),
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
  final bool immersive;

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
    this.immersive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1000,
      height: 562,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: immersive ? BorderRadius.zero : BorderRadius.circular(18),
        border: immersive ? null : Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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

  Widget _positionedBlock(
    BuildContext context,
    String type,
    ReminderBlockData block,
  ) {
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
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
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
                  onBlockMoved?.call(
                    type,
                    block.copyWith(width: nextWidth, height: nextHeight),
                  );
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
      child: Transform.rotate(
        angle: element.rotation * pi / 180,
        alignment: Alignment.center,
        child: Stack(
          children: [
            Container(
              width: element.width,
              height: element.height,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Color(element.backgroundColor),
                border: editable && selected
                    ? Border.all(
                        color: Theme.of(context).colorScheme.primary,
                        width: 2,
                      )
                    : null,
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
                    onElementChanged?.call(
                      element.copyWith(width: width, height: height),
                    );
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
      ),
    );
    return Positioned(left: element.x, top: element.y, child: child);
  }

  Widget _elementContent(BuildContext context, ReminderElementData element) {
    if (element.type == 'divider') {
      return Center(child: Divider(thickness: 3, color: Color(element.color)));
    }
    if (element.type == 'image') {
      if (element.url.isEmpty) {
        return const Center(child: Icon(Icons.image_outlined, size: 50));
      }
      final localFile = File(element.url);
      if (localFile.existsSync()) {
        return Image.file(
          localFile,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 42),
          ),
        );
      }
      final uri = Uri.tryParse(element.url);
      if (uri != null && uri.hasScheme) {
        return Image.network(
          element.url,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(
            child: Icon(Icons.broken_image_outlined, size: 42),
          ),
        );
      }
      return const Center(child: Icon(Icons.broken_image_outlined, size: 42));
    }
    final theme = Theme.of(context);
    final rawColor = Color(element.color);
    final defaultColor = element.color == 0xff171a24;
    final darkOnTransparent = theme.brightness == Brightness.dark &&
        element.backgroundColor == 0x00000000 &&
        rawColor.computeLuminance() < 0.25;
    final textColor = defaultColor || darkOnTransparent ? theme.colorScheme.onSurface : rawColor;
    final style = TextStyle(
      fontSize: element.fontSize,
      fontWeight: element.bold ? FontWeight.w800 : FontWeight.w400,
      fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
      decoration: element.underline ? TextDecoration.underline : TextDecoration.none,
      color: textColor,
    );
    final displayText = state != null ? _resolveTemplateVariables(element.text, state!) : element.text;
    if (element.type == 'button') {
      return FilledButton.tonal(
        style: FilledButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
        ),
        onPressed: editable
            ? null
            : () async {
                if (element.url.startsWith('internal://')) {
                  await onInternalOpen?.call(element.url);
                  return;
                }
                final uri = Uri.tryParse(element.url);
                if (uri != null && uri.hasScheme) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                }
              },
        child: Text(displayText, style: style),
      );
    }
    return Align(
      alignment: _textAlignment(element.alignment),
      child: Text(
        displayText,
        textAlign: _textAlign(element.alignment),
        style: style,
      ),
    );
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
          child: Text(
            title,
            style: TextStyle(
              fontSize: 48,
              fontWeight: FontWeight.w900,
              height: 1.05,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      case 'content':
        final content = state != null ? _resolveTemplateVariables(item.content, state!) : item.content;
        return Align(
          alignment: Alignment.topLeft,
          child: Text(
            content,
            style: TextStyle(
              fontSize: 28,
              height: 1.35,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        );
      case 'buttons':
        return Align(
          alignment: Alignment.topLeft,
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: item.buttons.map((button) {
              final btnText = state != null ? _resolveTemplateVariables(button.text, state!) : button.text;
              return FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                  foregroundColor: Theme.of(context).colorScheme.onSurface,
                ),
                onPressed: editable
                    ? null
                    : () async {
                        if (button.url.startsWith('internal://')) {
                          await onInternalOpen?.call(button.url);
                          return;
                        }
                        final uri = Uri.tryParse(button.url);
                        if (uri != null && uri.hasScheme) {
                          await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          );
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
  bool minimized = false;

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
    final active = widget.state.reminders.where((reminder) => reminder.isActiveAt(widget.state.reminderNow)).toList();
    final reminders = active.isNotEmpty ? active : widget.state.reminders;
    if (reminders.isEmpty) return const SizedBox.expand();
    final reminder = reminders[currentIndex % reminders.length];
    final canvas = _ReminderCanvas(
      item: reminder,
      blocks: reminder.blocks,
      elements: reminder.elements,
      onInternalOpen: (target) async {
        if (target == 'internal://minimize') {
          if (mounted) setState(() => minimized = !minimized);
          return;
        }
        await widget.onInternalOpen(target);
      },
      state: widget.state,
    );
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '提醒',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: minimized
                      ? Align(
                          alignment: Alignment.bottomRight,
                          child: SizedBox(width: 380, height: 214, child: canvas),
                        )
                      : canvas,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ReminderPresentation extends StatefulWidget {
  final AppState state;
  const ReminderPresentation({super.key, required this.state});

  @override
  State<ReminderPresentation> createState() => _ReminderPresentationState();
}

class _ReminderPresentationState extends State<ReminderPresentation> {
  Timer? _timer;
  int _index = 0;
  bool minimized = false;
  ReminderData? _lastAutoEvaluationReminder;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (mounted) setState(() => _index++);
    });
  }

  void _triggerAutoEvaluationIfNeeded(BuildContext context, ReminderData reminder) {
    if (_lastAutoEvaluationReminder == reminder) return;
    if (!reminder.shouldAutoEvaluateAt(widget.state.reminderNow)) return;
    if (reminder.hasEvaluationForDate(widget.state.reminderNow)) return;

    _lastAutoEvaluationReminder = reminder;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !context.mounted) return;
      unawaited(_showAutoEvaluationDialog(context, reminder));
    });
  }

  Future<void> _showAutoEvaluationDialog(BuildContext context, ReminderData reminder) async {
    final result = await showDialog<LessonEvaluationRecord?>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (dialogContext) => _LessonEvaluationDialog(reminder: reminder),
    );

    if (!context.mounted) return;
    if (result == null) {
      _lastAutoEvaluationReminder = reminder;
      return;
    }

    final index = widget.state.reminders.indexOf(reminder);
    if (index >= 0) {
      reminder.evaluations.add(result);
      await widget.state.saveReminder(reminder, index: index);
      if (mounted) setState(() {});
    }
    _lastAutoEvaluationReminder = reminder;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _openInternal(BuildContext context, String target) async {
    if (target == 'internal://minimize') {
      if (mounted) setState(() => minimized = !minimized);
      return;
    }
    if (target == 'internal://registration') {
      await _showRegistrationDialog(context, widget.state);
      return;
    }
    Widget? page;
    switch (target) {
      case 'internal://lottery':
        page = LotteryPage(state: widget.state);
        break;
      case 'internal://seats':
        page = SeatPage(state: widget.state);
        break;
      case 'internal://diary':
        page = DiaryPage(state: widget.state, editable: true);
        break;
      case 'internal://schedule':
        page = SchedulePage(state: widget.state, editable: false);
        break;
    }
    if (page == null || !context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black54,
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: SizedBox(
            width: size.width < 720 ? size.width - 24 : 1100,
            height: size.height < 760 ? size.height - 24 : 700,
            child: Stack(
              children: [
                Padding(padding: const EdgeInsets.only(top: 8), child: page!),
                Positioned(
                  right: 8,
                  top: 8,
                  child: IconButton(
                    tooltip: '關閉',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.state.reminderNow;
    if (now.hour * 60 + now.minute < AppState.attendanceCutoffMinutes) {
      return BigScreenAttendancePage(state: widget.state);
    }
    final active = widget.state.reminders.where((e) => e.isActiveAt(widget.state.reminderNow)).toList();
    final reminders = active.isNotEmpty ? active : widget.state.reminders;
    if (reminders.isEmpty) {
      return ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: const Center(
          child: Text('目前沒有提醒', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
        ),
      );
    }

    final reminder = reminders[_index % reminders.length];
    _triggerAutoEvaluationIfNeeded(context, reminder);
    final canvas = _ReminderCanvas(
      item: reminder,
      blocks: reminder.blocks,
      elements: reminder.elements,
      onInternalOpen: (target) => _openInternal(context, target),
      state: widget.state,
      immersive: true,
    );
    return ColoredBox(
      color: Theme.of(context).colorScheme.surface,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final height = constraints.maxHeight;
          final slideHeight = width * 9 / 16;
          final fittedHeight = slideHeight <= height ? slideHeight : height;
          final fittedWidth = fittedHeight * 16 / 9;
          return Center(
            child: SizedBox(
              width: fittedWidth,
              height: fittedHeight,
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: 1000,
                  height: 562,
                  child: minimized
                      ? Align(
                          alignment: Alignment.bottomRight,
                          child: SizedBox(width: 380, height: 214, child: canvas),
                        )
                      : canvas,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _LessonEvaluationDialog extends StatefulWidget {
  final ReminderData reminder;
  const _LessonEvaluationDialog({required this.reminder});

  @override
  State<_LessonEvaluationDialog> createState() => _LessonEvaluationDialogState();
}

class _LessonEvaluationDialogState extends State<_LessonEvaluationDialog> {
  int _score = 4;
  final TextEditingController _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.all(18),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '課堂表現評價',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                widget.reminder.title.isEmpty ? '本堂課' : widget.reminder.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 18),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final value = index + 1;
                  final active = value <= _score;
                  return IconButton(
                    onPressed: () => setState(() => _score = value),
                    icon: Icon(
                      active ? Icons.favorite : Icons.favorite_border,
                      size: 34,
                      color: active ? Colors.pink : Colors.grey,
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _noteController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: '備註',
                  hintText: '例如：整體秩序良好、同學專注度高',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: () {
                      final record = LessonEvaluationRecord(
                        id: 'eval-${DateTime.now().microsecondsSinceEpoch}',
                        score: _score,
                        note: _noteController.text.trim(),
                        createdAt: DateTime.now(),
                        lessonType: widget.reminder.lessonType,
                      );
                      Navigator.pop(context, record);
                    },
                    icon: const Icon(Icons.check),
                    label: const Text('送出'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showRegistrationDialog(BuildContext context, AppState state) async {
  await showDialog<void>(
    context: context,
    barrierColor: Colors.black54,
    builder: (dialogContext) {
      final size = MediaQuery.sizeOf(dialogContext);
      return Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: SizedBox(
          width: size.width < 720 ? size.width - 24 : 900,
          height: size.height < 760 ? size.height - 24 : 660,
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: BigScreenRegistrationPage(state: state),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  tooltip: '關閉',
                  onPressed: () => Navigator.pop(dialogContext),
                  icon: const Icon(Icons.close),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
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
  }

  Widget _buildManagement(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        MediaQuery.sizeOf(context).width < 720 ? 14 : 24,
        16,
        MediaQuery.sizeOf(context).width < 720 ? 14 : 24,
        24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '提醒管理',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              FilledButton.icon(
                onPressed: () => _openReminderEditor(context),
                icon: const Icon(Icons.add),
                label: const Text('新增簡報'),
              ),
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
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  10,
                                  8,
                                  12,
                                ),
                                child: Wrap(
                                  alignment: WrapAlignment.spaceBetween,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  runSpacing: 4,
                                  children: [
                                    SizedBox(
                                      width: MediaQuery.sizeOf(context).width < 720 ? 180 : 300,
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            reminder.title.isEmpty ? '未命名簡報' : reminder.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _repeatLabel(reminder),
                                            style: const TextStyle(
                                              color: Colors.black54,
                                            ),
                                          ),
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
    final labels = reminder.timeRanges.map((range) {
      final repeat = switch (range.repeatType) {
        'daily' => '每日',
        'weekly' => '每週 ${range.weekdays.map((day) => '一二三四五'[day - 1]).join('、')}',
        'specific' => '指定 ${range.dates.length} 天',
        _ => '不重複',
      };
      return '${range.startTime}-${range.endTime} $repeat';
    });
    return labels.join('、');
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
      if (state.reminders.any((reminder) => reminder.title == preset.title)) {
        continue;
      }
      await state.saveReminder(preset);
    }
  }

  ReminderData _presetReminder(
    String title,
    String content,
    String start,
    String end,
  ) {
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
    if (target == 'internal://registration') {
      await _showRegistrationDialog(context, state);
      return;
    }
    if (target == 'internal://minimize') return;
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
      builder: (dialogContext) {
        final size = MediaQuery.sizeOf(dialogContext);
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          child: SizedBox(
            width: size.width < 720 ? size.width - 24 : 1050,
            height: size.height < 760 ? size.height - 24 : 680,
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
        );
      },
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
    final layout = List<String>.from(
      old?.layout ?? const ['title', 'content', 'buttons'],
    );
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
              bold: true,
            ),
            ReminderElementData(
              id: 'content',
              type: 'text',
              text: old?.content ?? '',
              x: 70,
              y: 190,
              width: 860,
              height: 150,
              fontSize: 28,
            ),
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

    void updateElement(
      String id,
      ReminderElementData Function(ReminderElementData) change,
    ) {
      final position = elements.indexWhere((element) => element.id == id);
      if (position >= 0) elements[position] = change(elements[position]);
    }

    void addElement(String type) {
      final id = '$type-${DateTime.now().microsecondsSinceEpoch}-${elements.length}';
      final position = nextElementPosition();
      final element = switch (type) {
        'text' => ReminderElementData(
            id: id,
            type: type,
            text: '新增文字',
            x: position.dx,
            y: position.dy,
            width: 360,
            height: 80,
          ),
        'button' => ReminderElementData(
            id: id,
            type: type,
            text: '按鈕',
            url: 'https://',
            x: position.dx,
            y: position.dy,
            width: 180,
            height: 56,
            fontSize: 16,
          ),
        'divider' => ReminderElementData(
            id: id,
            type: type,
            x: position.dx,
            y: position.dy,
            width: 500,
            height: 40,
          ),
        _ => ReminderElementData(
            id: id,
            type: 'image',
            url: '',
            x: position.dx,
            y: position.dy,
            width: 300,
            height: 180,
          ),
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
                        final position = elements.indexWhere(
                          (element) => element.id == next.id,
                        );
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
                      element: elements.firstWhere(
                        (element) => element.id == selectedId,
                      ),
                      onChanged: (next) => setState(() {
                        final position = elements.indexWhere(
                          (element) => element.id == next.id,
                        );
                        if (position >= 0) elements[position] = next;
                      }),
                    ),
                  const Divider(height: 28),
                  TextField(
                    controller: title,
                    onChanged: (value) => setState(() {
                      updateElement(
                        'title',
                        (element) => element.copyWith(text: value),
                      );
                    }),
                    decoration: const InputDecoration(labelText: '標題'),
                  ),
                  TextField(
                    controller: content,
                    maxLines: 4,
                    onChanged: (value) => setState(() {
                      updateElement(
                        'content',
                        (element) => element.copyWith(text: value),
                      );
                    }),
                    decoration: const InputDecoration(labelText: '內容'),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: date,
                          decoration: const InputDecoration(
                            labelText: '日期（YYYY-MM-DD，可空白）',
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: start,
                          decoration: const InputDecoration(labelText: '開始'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: end,
                          decoration: const InputDecoration(labelText: '結束'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() {
                          buttons.add(
                            ActionButtonData(text: '開啟', url: 'https://'),
                          );
                          buttonTextControllers.add(
                            TextEditingController(text: '開啟'),
                          );
                          buttonUrlControllers.add(
                            TextEditingController(text: 'https://'),
                          );
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
                              decoration: const InputDecoration(
                                labelText: '按鈕文字',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: buttonUrlControllers[i],
                              decoration: const InputDecoration(
                                labelText: '連結',
                              ),
                            ),
                          ),
                          PopupMenuButton<String>(
                            tooltip: '快速選擇軟體內頁',
                            icon: const Icon(Icons.dashboard_customize_outlined),
                            onSelected: (value) {
                              setState(() => buttonUrlControllers[i].text = value);
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'internal://minimize', child: Text('最小化')),
                              PopupMenuItem(value: 'internal://registration', child: Text('登記')),
                              PopupMenuItem(value: 'internal://seats', child: Text('座位表')),
                              PopupMenuItem(value: 'internal://lottery', child: Text('選號')),
                              PopupMenuItem(value: 'internal://diary', child: Text('聯絡簿')),
                              PopupMenuItem(value: 'internal://schedule', child: Text('課表')),
                            ],
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
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
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
            ),
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
  final ValueNotifier<_GuidesData> guidesNotifier = ValueNotifier(
    const _GuidesData(),
  );
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
    final incoming = {
      for (final element in widget.elements) element.id: element,
    };
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
    final canvasCenterX = _SnapPoint(
      500 - element.width / 2,
      500,
      isCenter: true,
    );
    final canvasCenterY = _SnapPoint(
      281.25 - element.height / 2,
      281.25,
      isCenter: true,
    );

    // Canva 邊距／標題區域安全線（左/右 70，上 100，下 70）
    // 元素左邊對齊 margin 左(70)、右邊對齊 margin 右(930)、中心對齊 margin 中心(500)
    // 元素上邊對齊 margin 上(100 - 偏標題位置)、下邊對齊 margin 下(492.5)
    final marginGuideLeft = _SnapPoint(70, 70, isMargin: true);
    final marginGuideRight = _SnapPoint(
      930 - element.width,
      930,
      isMargin: true,
    );
    final marginGuideTop = _SnapPoint(100, 100, isMargin: true);
    final marginGuideBottom = _SnapPoint(
      492.5 - element.height,
      492.5,
      isMargin: true,
    );

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
        _SnapPoint(
          t.x + t.width / 2 - element.width / 2,
          t.x + t.width / 2,
          isCenter: true,
        ),
        _SnapPoint(
          t.x + t.width - element.width,
          t.x + t.width,
          isMargin: true,
        ),
      ]);
      yTargets.addAll([
        _SnapPoint(t.y, t.y, isMargin: true),
        _SnapPoint(
          t.y + t.height / 2 - element.height / 2,
          t.y + t.height / 2,
          isCenter: true,
        ),
        _SnapPoint(t.y + t.height + 16, t.y + t.height + 16, isMargin: true),
        _SnapPoint(t.y + t.height + 24, t.y + t.height + 24, isMargin: true),
        _SnapPoint(
          t.y + t.height - element.height,
          t.y + t.height,
          isMargin: true,
        ),
      ]);
    }

    for (final other in localElements.values) {
      if (other.value.id == element.id || other.value.id == 'title') continue;
      final target = other.value;
      xTargets.addAll([
        _SnapPoint(target.x, target.x),
        _SnapPoint(
          target.x + target.width / 2 - element.width / 2,
          target.x + target.width / 2,
          isCenter: true,
        ),
        _SnapPoint(
          target.x + target.width - element.width,
          target.x + target.width,
        ),
      ]);
      yTargets.addAll([
        _SnapPoint(target.y, target.y),
        _SnapPoint(
          target.y + target.height / 2 - element.height / 2,
          target.y + target.height / 2,
          isCenter: true,
        ),
        _SnapPoint(
          target.y + target.height - element.height,
          target.y + target.height,
        ),
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

  Widget _fastElement(
    BuildContext context,
    ValueNotifier<ReminderElementData> notifier,
  ) {
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
            child: Transform.rotate(
              angle: element.rotation * pi / 180,
              alignment: Alignment.center,
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
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.open_in_full,
                            size: 14,
                            color: Colors.white,
                          ),
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
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: const Icon(
                            Icons.close,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fastContent(BuildContext context, ReminderElementData element) {
    if (element.type == 'divider') {
      return Center(child: Divider(thickness: 3, color: Color(element.color)));
    }
    if (element.type == 'image') {
      if (element.url.isEmpty) {
        return const Center(child: Icon(Icons.image_outlined, size: 50));
      }
      final localFile = File(element.url);
      if (localFile.existsSync()) {
        return Image.file(localFile, fit: BoxFit.cover);
      }
      final uri = Uri.tryParse(element.url);
      if (uri != null && uri.hasScheme) {
        return Image.network(element.url, fit: BoxFit.cover);
      }
      return const Center(child: Icon(Icons.broken_image_outlined, size: 42));
    }
    final style = TextStyle(
      fontSize: element.fontSize,
      fontWeight: element.bold ? FontWeight.w800 : FontWeight.w400,
      fontStyle: element.italic ? FontStyle.italic : FontStyle.normal,
      decoration: element.underline ? TextDecoration.underline : TextDecoration.none,
      color: element.color == 0xff171a24 ? Theme.of(context).colorScheme.onSurface : Color(element.color),
    );
    final displayText = widget.state != null ? _resolveTemplateVariables(element.text, widget.state!) : element.text;
    if (element.type == 'button') {
      return FilledButton(
        onPressed: null,
        child: Text(displayText, style: style),
      );
    }
    return Align(
      alignment: _fastTextAlignment(element.alignment),
      child: Text(
        displayText,
        textAlign: _fastTextAlign(element.alignment),
        style: style,
      ),
    );
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
  _SnapPoint(
    this.value,
    this.guide, {
    this.isCenter = false,
    this.isMargin = false,
  });
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

class _ReminderTimeRangeControllers {
  final TextEditingController start;
  final TextEditingController end;
  final TextEditingController dates;
  String repeatType;
  Set<int> weekdays;

  _ReminderTimeRangeControllers({
    required String startTime,
    required String endTime,
    this.repeatType = 'none',
    Iterable<int> weekdays = const [],
    Iterable<String> dates = const [],
  })  : start = TextEditingController(text: startTime),
        end = TextEditingController(text: endTime),
        dates = TextEditingController(text: dates.join(', ')),
        weekdays = weekdays.toSet();

  void dispose() {
    start.dispose();
    end.dispose();
    dates.dispose();
  }
}

class _ReminderEditorState extends State<_ReminderEditor> {
  late final TextEditingController titleController;
  late final TextEditingController contentController;
  late List<_ReminderTimeRangeControllers> timeRangeControllers;
  late List<ReminderElementData> elements;
  late Map<String, ReminderBlockData> blocks;
  late String lessonType;
  late bool autoEvaluationEnabled;
  String? selectedId;
  int elementSerial = 0;

  ReminderData? get original => widget.index == null ? null : widget.state.reminders[widget.index!];

  @override
  void initState() {
    super.initState();
    final item = original;
    titleController = TextEditingController(text: item?.title ?? '');
    contentController = TextEditingController(text: item?.content ?? '');
    lessonType = item?.lessonType ?? 'other';
    autoEvaluationEnabled = item?.autoEvaluationEnabled ?? false;
    final timeRanges = item?.timeRanges ??
        [
          ReminderTimeRange(startTime: item?.startTime ?? '08:00', endTime: item?.endTime ?? '18:00'),
        ];
    timeRangeControllers = timeRanges
        .map((range) => _ReminderTimeRangeControllers(
              startTime: range.startTime,
              endTime: range.endTime,
              repeatType: range.repeatType,
              weekdays: range.weekdays,
              dates: range.dates,
            ))
        .toList();
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
              bold: true,
            ),
            ReminderElementData(
              id: 'content',
              type: 'text',
              text: item?.content ?? '',
              x: 70,
              y: 190,
              width: 860,
              height: 150,
              fontSize: 28,
            ),
          ];
  }

  @override
  void dispose() {
    titleController.dispose();
    contentController.dispose();
    for (final range in timeRangeControllers) {
      range.dispose();
    }
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
      'text' => ReminderElementData(
          id: id,
          type: type,
          text: '新增文字',
          x: position.dx,
          y: position.dy,
          width: 360,
          height: 80,
        ),
      'button' => ReminderElementData(
          id: id,
          type: type,
          text: '按鈕',
          url: 'https://',
          x: position.dx,
          y: position.dy,
          width: 180,
          height: 56,
          fontSize: 16,
        ),
      'divider' => ReminderElementData(
          id: id,
          type: type,
          x: position.dx,
          y: position.dy,
          width: 500,
          height: 40,
        ),
      _ => ReminderElementData(
          id: id,
          type: 'image',
          x: position.dx,
          y: position.dy,
          width: 300,
          height: 180,
        ),
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
    try {
      final timeRanges = timeRangeControllers
          .map((range) => ReminderTimeRange(
                startTime: range.start.text.trim(),
                endTime: range.end.text.trim(),
                repeatType: range.repeatType,
                weekdays: range.weekdays.toList()..sort(),
                dates: range.dates.text.split(',').map((date) => date.trim()).where((date) => date.isNotEmpty).toList(),
              ))
          .toList();
      final item = ReminderData(
        title: titleController.text.trim(),
        content: contentController.text,
        date: '',
        startTime: timeRanges.first.startTime,
        endTime: timeRanges.first.endTime,
        lessonType: lessonType,
        autoEvaluationEnabled: lessonType == 'class' && autoEvaluationEnabled,
        evaluations: original?.evaluations
                .map((evaluation) => LessonEvaluationRecord(
                      id: evaluation.id,
                      score: evaluation.score,
                      note: evaluation.note,
                      createdAt: DateTime.tryParse(evaluation.createdAt),
                      lessonType: evaluation.lessonType,
                    ))
                .toList() ??
            [],
        timeRanges: timeRanges,
        repeatType: 'none',
        repeatDates: const [],
        blocks: {
          for (final entry in blocks.entries) entry.key: entry.value.copyWith(),
        },
        elements: elements.map((element) => element.copyWith()).toList(),
      );
      final error = await widget.state.saveReminder(item, index: widget.index);
      if (!mounted) return;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
        return;
      }
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('儲存失敗：$error')));
    }
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _addDate(int index) async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: DateTime.now(),
      helpText: '選擇提醒日期',
    );
    if (picked == null || !mounted) return;
    final range = timeRangeControllers[index];
    final dates = range.dates.text.split(',').map((date) => date.trim()).where((date) => date.isNotEmpty).toSet();
    dates.add(_dateKey(picked));
    final sorted = dates.toList()..sort();
    setState(() => range.dates.text = sorted.join(', '));
  }

  Widget _repeatSettings(int index) {
    final range = timeRangeControllers[index];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          initialValue: range.repeatType,
          decoration: const InputDecoration(labelText: '重複方式'),
          items: const [
            DropdownMenuItem(value: 'none', child: Text('不重複')),
            DropdownMenuItem(value: 'daily', child: Text('每日')),
            DropdownMenuItem(value: 'weekly', child: Text('每週')),
            DropdownMenuItem(value: 'specific', child: Text('指定日期')),
          ],
          onChanged: (value) => setState(() {
            range.repeatType = value ?? 'none';
            if (range.repeatType != 'weekly') range.weekdays.clear();
            if (range.repeatType != 'specific') range.dates.clear();
          }),
        ),
        if (range.repeatType == 'weekly') ...[
          const SizedBox(height: 8),
          const Text('星期幾'),
          Wrap(
            spacing: 6,
            children: [
              for (final day in [1, 2, 3, 4, 5])
                FilterChip(
                  label: Text('週${['一', '二', '三', '四', '五'][day - 1]}'),
                  selected: range.weekdays.contains(day),
                  onSelected: (selected) => setState(() {
                    if (selected) {
                      range.weekdays.add(day);
                    } else {
                      range.weekdays.remove(day);
                    }
                  }),
                ),
            ],
          ),
        ],
        if (range.repeatType == 'specific') ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _addDate(index),
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('從日曆選日期'),
              ),
              if (range.dates.text.isNotEmpty) Text(range.dates.text, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    final preview = ReminderData(
      title: titleController.text,
      content: contentController.text,
      date: '',
      startTime: timeRangeControllers.first.start.text,
      endTime: timeRangeControllers.first.end.text,
      lessonType: lessonType,
      autoEvaluationEnabled: lessonType == 'class' && autoEvaluationEnabled,
      timeRanges: timeRangeControllers
          .map((range) => ReminderTimeRange(
                startTime: range.start.text,
                endTime: range.end.text,
                repeatType: range.repeatType,
                weekdays: range.weekdays.toList()..sort(),
                dates: range.dates.text.split(',').map((date) => date.trim()).where((date) => date.isNotEmpty).toList(),
              ))
          .toList(),
      blocks: blocks,
      elements: elements,
    );
    return AlertDialog(
      title: Text(widget.index == null ? '新增提醒' : '編輯提醒'),
      content: SizedBox(
        width: compact ? MediaQuery.sizeOf(context).width - 64 : 920,
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: compact ? 220 : 484,
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
                  element: elements.firstWhere(
                    (element) => element.id == selectedId,
                  ),
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
                  final index = elements.indexWhere(
                    (element) => element.id == 'title',
                  );
                  if (index >= 0) {
                    elements[index] = elements[index].copyWith(text: value);
                  }
                }),
                decoration: const InputDecoration(labelText: '標題'),
              ),
              TextField(
                controller: contentController,
                maxLines: 4,
                onChanged: (value) => setState(() {
                  final index = elements.indexWhere(
                    (element) => element.id == 'content',
                  );
                  if (index >= 0) {
                    elements[index] = elements[index].copyWith(text: value);
                  }
                }),
                decoration: const InputDecoration(labelText: '內容'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: lessonType,
                decoration: const InputDecoration(labelText: '簡報類型'),
                items: const [
                  DropdownMenuItem(value: 'class', child: Text('上課')),
                  DropdownMenuItem(value: 'break', child: Text('下課')),
                  DropdownMenuItem(value: 'other', child: Text('其他')),
                ],
                onChanged: (value) => setState(() {
                  lessonType = value ?? 'other';
                  if (lessonType != 'class') {
                    autoEvaluationEnabled = false;
                  }
                }),
              ),
              const SizedBox(height: 8),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('到時間自動叫出評分'),
                subtitle: const Text('只有「上課」簡報會啟用課堂評分'),
                value: lessonType == 'class' && autoEvaluationEnabled,
                onChanged: lessonType == 'class' ? (value) => setState(() => autoEvaluationEnabled = value) : null,
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('套用時間（可設定多段）', style: Theme.of(context).textTheme.titleSmall),
              ),
              for (var index = 0; index < timeRangeControllers.length; index++)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: timeRangeControllers[index].start,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(labelText: '第 ${index + 1} 段開始'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: timeRangeControllers[index].end,
                              onChanged: (_) => setState(() {}),
                              decoration: InputDecoration(labelText: '第 ${index + 1} 段結束'),
                            ),
                          ),
                          if (timeRangeControllers.length > 1)
                            IconButton(
                              tooltip: '移除時段',
                              onPressed: () => setState(() => timeRangeControllers.removeAt(index).dispose()),
                              icon: const Icon(Icons.delete_outline),
                            ),
                        ],
                      ),
                      _repeatSettings(index),
                    ],
                  ),
                ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => setState(() {
                    timeRangeControllers.add(
                      _ReminderTimeRangeControllers(startTime: '08:00', endTime: '09:00'),
                    );
                  }),
                  icon: const Icon(Icons.add),
                  label: const Text('新增套用時段'),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save_outlined),
          label: const Text('套用並儲存'),
        ),
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

  Future<void> _pickImageForElement() async {
    const group = XTypeGroup(label: '圖片', extensions: ['jpg', 'jpeg', 'png', 'webp']);
    final file = await openFile(acceptedTypeGroups: [group], confirmButtonText: '選擇圖片');
    if (file == null || !mounted) return;

    final appDir = await getApplicationSupportDirectory();
    final imageDir = Directory('${appDir.path}${Platform.pathSeparator}reminder_images');
    await imageDir.create(recursive: true);

    final extension = file.name.contains('.') ? file.name.substring(file.name.lastIndexOf('.')) : '.png';
    final fileName = '${DateTime.now().microsecondsSinceEpoch}$extension';
    final storedPath = '${imageDir.path}${Platform.pathSeparator}$fileName';
    await File(file.path).copy(storedPath);

    urlController.text = storedPath;
    widget.onChanged(widget.element.copyWith(url: storedPath));
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
            Text(
              '元素格式 · ${element.type}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (supportsText) ...[
              TextField(
                controller: textController,
                minLines: 2,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textInputAction: TextInputAction.newline,
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
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Text('旋轉'),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Slider(
                        value: ((element.rotation % 360) + 360) % 360,
                        min: 0,
                        max: 360,
                        divisions: 36,
                        label: '${element.rotation.round()}°',
                        onChanged: (value) => widget.onChanged(element.copyWith(rotation: value)),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () =>
                          widget.onChanged(element.copyWith(rotation: (element.rotation - 15).clamp(-360, 360))),
                      icon: const Icon(Icons.rotate_left),
                      label: const Text('-15°'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () =>
                          widget.onChanged(element.copyWith(rotation: (element.rotation + 15).clamp(-360, 360))),
                      icon: const Icon(Icons.rotate_right),
                      label: const Text('+15°'),
                    ),
                  ],
                ),
              ],
            ),
            if (supportsUrl)
              element.type == 'image'
                  ? Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: urlController,
                            onChanged: (value) => widget.onChanged(element.copyWith(url: value)),
                            decoration: const InputDecoration(labelText: '圖片路徑／網址'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: '上傳圖片',
                          onPressed: _pickImageForElement,
                          icon: const Icon(Icons.upload_file_outlined),
                        ),
                      ],
                    )
                  : TextField(
                      controller: urlController,
                      onChanged: (value) => widget.onChanged(element.copyWith(url: value)),
                      decoration: InputDecoration(
                        labelText: element.type == 'image' ? '圖片網址' : '按鈕連結',
                      ),
                    ),
            if (element.type == 'button')
              DropdownButtonFormField<String>(
                initialValue: const [
                  'internal://seats',
                  'internal://lottery',
                  'internal://diary',
                  'internal://schedule',
                  'internal://minimize',
                  'internal://registration',
                ].contains(element.url)
                    ? element.url
                    : null,
                decoration: const InputDecoration(labelText: '快速選擇軟體內頁'),
                items: const [
                  DropdownMenuItem(
                    value: 'internal://seats',
                    child: Text('座位表'),
                  ),
                  DropdownMenuItem(
                    value: 'internal://lottery',
                    child: Text('選號'),
                  ),
                  DropdownMenuItem(
                    value: 'internal://diary',
                    child: Text('聯絡簿'),
                  ),
                  DropdownMenuItem(
                    value: 'internal://schedule',
                    child: Text('課表'),
                  ),
                  DropdownMenuItem(
                    value: 'internal://minimize',
                    child: Text('最小化'),
                  ),
                  DropdownMenuItem(
                    value: 'internal://registration',
                    child: Text('登記'),
                  ),
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
                    icon: Icon(
                      Icons.format_bold,
                      color: element.bold ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  IconButton(
                    tooltip: '斜體',
                    onPressed: () => widget.onChanged(
                      element.copyWith(italic: !element.italic),
                    ),
                    icon: Icon(
                      Icons.format_italic,
                      color: element.italic ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                  IconButton(
                    tooltip: '底線',
                    onPressed: () => widget.onChanged(
                      element.copyWith(underline: !element.underline),
                    ),
                    icon: Icon(
                      Icons.format_underline,
                      color: element.underline ? Theme.of(context).colorScheme.primary : null,
                    ),
                  ),
                ],
              ),
            if (supportsText)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Text('旋轉'),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Slider(
                          value: (element.rotation % 360 + 360) % 360,
                          min: 0,
                          max: 360,
                          divisions: 36,
                          label: '${element.rotation.round()}°',
                          onChanged: (value) => widget.onChanged(element.copyWith(rotation: value)),
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () =>
                            widget.onChanged(element.copyWith(rotation: (element.rotation - 15).clamp(-360, 360))),
                        icon: const Icon(Icons.rotate_left),
                        label: const Text('-15°'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () =>
                            widget.onChanged(element.copyWith(rotation: (element.rotation + 15).clamp(-360, 360))),
                        icon: const Icon(Icons.rotate_right),
                        label: const Text('+15°'),
                      ),
                    ],
                  ),
                ],
              ),
            if (supportsText)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'left',
                    icon: Icon(Icons.format_align_left),
                  ),
                  ButtonSegment(
                    value: 'center',
                    icon: Icon(Icons.format_align_center),
                  ),
                  ButtonSegment(
                    value: 'right',
                    icon: Icon(Icons.format_align_right),
                  ),
                ],
                selected: {element.alignment},
                onSelectionChanged: (value) => widget.onChanged(element.copyWith(alignment: value.first)),
              ),
            const SizedBox(height: 8),
            const Text('文字顏色'),
            Wrap(
              spacing: 8,
              children: [
                for (final color in const [
                  0xff171a24,
                  0xffd32f2f,
                  0xff1565c0,
                  0xff2e7d32,
                  0xfff57c00,
                  0xffffffff,
                ])
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '座位表',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => FittedBox(
                fit: BoxFit.contain,
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: 1180,
                  height: 640,
                  child: _SeatRows(
                    state: state,
                    editable: false,
                    draggable: state.deviceRole != 'bigscreen',
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

class _SeatRows extends StatelessWidget {
  final AppState state;
  final bool editable;
  final bool draggable;
  const _SeatRows({required this.state, required this.editable, this.draggable = false});

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
                    label: const Text('每排桌子向左挪'),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => state.rotateSeats(1),
                    icon: const Icon(Icons.arrow_forward),
                    label: const Text('每排桌子向右挪'),
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
              child: Text(
                '講台',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
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
        if (state.seats[i].row == row) i,
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
                  Positioned(
                    left: 0,
                    top: slot * 108,
                    width: 150,
                    height: 108,
                    child: _buildSlot(context, state, row, slot, indexes, editable, draggable),
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

  Widget _buildSlot(
      BuildContext context, AppState state, int row, int slot, List<int> indexes, bool editable, bool draggable) {
    final index = _seatAtSlot(indexes, slot);
    if (index != null) {
      final seatCard = _SeatCard(
        state: state,
        index: index,
        editable: editable,
        draggable: draggable,
        onEdit: () => _editSeat(context, state, index, editable),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: draggable
            ? DragTarget<int>(
                onWillAcceptWithDetails: (details) => details.data != index,
                onAcceptWithDetails: (details) {
                  if (details.data != index) state.swapSeats(details.data, index);
                },
                hitTestBehavior: HitTestBehavior.opaque,
                builder: (context, candidates, rejected) => AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  decoration: candidates.isEmpty
                      ? null
                      : BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                  child: seatCard,
                ),
              )
            : seatCard,
      );
    }
    if (!draggable) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: DragTarget<int>(
        onWillAcceptWithDetails: (_) => true,
        onAcceptWithDetails: (details) => state.moveSeatTo(details.data, row: row, slot: slot),
        builder: (context, candidates, rejected) => AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          decoration: BoxDecoration(
            border: Border.all(
              color: candidates.isEmpty
                  ? Theme.of(context).colorScheme.outlineVariant
                  : Theme.of(context).colorScheme.primary,
              width: candidates.isEmpty ? 1 : 3,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Center(child: Icon(Icons.add, color: Colors.black26)),
        ),
      ),
    );
  }
}

class _SeatCard extends StatelessWidget {
  final AppState state;
  final int index;
  final bool editable;
  final bool draggable;
  final VoidCallback onEdit;

  const _SeatCard({
    required this.state,
    required this.index,
    required this.editable,
    required this.draggable,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final seat = state.seats[index];
    Widget buildCard() {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: draggable ? null : (editable ? onEdit : () => _showSeatProfile(context, state, index, seat)),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 108,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  _seatColor(context, seat.gender).withValues(alpha: 0.96),
                  _seatColor(context, seat.gender).withValues(alpha: 0.84),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.8),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  seat.number,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      seat.name.isEmpty ? '空位' : seat.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final card = buildCard();
    if (!draggable) return card;
    return Draggable<int>(
      data: index,
      feedback: Material(
        color: Colors.transparent,
        child: SizedBox(
          width: 150,
          height: 108,
          child: Opacity(opacity: 0.78, child: buildCard()),
        ),
      ),
      childWhenDragging: Opacity(opacity: 0.3, child: buildCard()),
      child: card,
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

Future<void> _editSeat(
  BuildContext context,
  AppState state,
  int index,
  bool editable,
) async {
  final numberController = TextEditingController(
    text: state.seats[index].number,
  );
  final controller = TextEditingController(text: state.seats[index].name);
  var gender = state.seats[index].gender;
  final labelController = TextEditingController(text: state.seats[index].label);
  final noteController = TextEditingController(text: state.seats[index].note);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('編輯座位'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: numberController,
              decoration: const InputDecoration(labelText: '座號'),
            ),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: '姓名'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: '同學標籤／職位',
                hintText: '例如：資訊股長',
              ),
            ),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '備註',
                hintText: '可填寫同學備註',
              ),
            ),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              await state.updateSeatDetails(
                index,
                number: numberController.text,
                name: controller.text,
                gender: gender,
                label: labelController.text.trim(),
                note: noteController.text.trim(),
              );
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
  noteController.dispose();
}

Future<void> _showSeatProfile(BuildContext context, AppState state, int index, SeatData seat) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setDialogState) {
        Future<void> changeScore(int delta) async {
          final saveFuture = state.adjustSeatScore(index, delta);
          if (dialogContext.mounted) setDialogState(() {});
          await saveFuture;
        }

        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.dashboard_customize_outlined),
              const SizedBox(width: 10),
              Expanded(child: Text(seat.name.isEmpty ? '空位' : seat.name)),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _profilePanelCard(
                    context,
                    width: 248,
                    icon: Icons.badge_outlined,
                    title: '座位資訊',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          seat.name.isEmpty ? '空位' : seat.name,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 6),
                        Text('座號 ${seat.number}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  _profilePanelCard(
                    context,
                    width: 248,
                    icon: Icons.stars_outlined,
                    title: '目前積分',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${seat.score}', style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            FilledButton.icon(
                              onPressed: () => changeScore(1),
                              icon: const Icon(Icons.add, size: 18),
                              label: const Text('+1'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => changeScore(-1),
                              icon: const Icon(Icons.remove, size: 18),
                              label: const Text('-1'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => changeScore(5),
                              icon: const Icon(Icons.exposure_plus_1_outlined, size: 18),
                              label: const Text('+5'),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => changeScore(-5),
                              icon: const Icon(Icons.exposure_neg_1_outlined, size: 18),
                              label: const Text('-5'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _profilePanelCard(
                    context,
                    width: 248,
                    icon: Icons.label_outline,
                    title: '標籤／職務',
                    child: Text(seat.label.isEmpty ? '尚未設定' : seat.label),
                  ),
                  _profilePanelCard(
                    context,
                    width: 248,
                    icon: Icons.notes_outlined,
                    title: '備註',
                    child: Text(seat.note.isEmpty ? '沒有備註' : seat.note),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('關閉')),
          ],
        );
      },
    ),
  );
}

Widget _profilePanelCard(
  BuildContext context, {
  required double width,
  required IconData icon,
  required String title,
  required Widget child,
}) {
  return SizedBox(
    width: width,
    child: Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 19),
                const SizedBox(width: 7),
                Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              ],
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    ),
  );
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
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final darkMode = Theme.of(context).brightness == Brightness.dark;
    final resultTextColor = darkMode ? Colors.white : Colors.black87;
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '選號機器',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: selected == null
                  ? const Text('從班上隨機抽出一位同學', style: TextStyle(fontSize: 22))
                  : Card(
                      color: selected!.gender == '男'
                          ? (darkMode ? const Color(0xFF164A78) : const Color(0xFFDCEEFF))
                          : selected!.gender == '女'
                              ? (darkMode ? const Color(0xFF7D294B) : const Color(0xFFFFE0EA))
                              : null,
                      child: Padding(
                        padding: EdgeInsets.all(isMobile ? 24 : 44),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 70),
                              child: Text(
                                selected!.number,
                                key: ValueKey(selected!.number),
                                style: TextStyle(fontSize: 24, color: resultTextColor),
                              ),
                            ),
                            const SizedBox(height: 10),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 70),
                                child: Text(
                                  selected!.name,
                                  key: ValueKey(selected!.name),
                                  style: TextStyle(
                                    fontSize: 48,
                                    fontWeight: FontWeight.w900,
                                    color: resultTextColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ),
          ),
          FilledButton.icon(
            onPressed: drawing ? null : draw,
            icon: const Icon(Icons.casino),
            label: Text(drawing ? '抽選中' : '開始抽選'),
          ),
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
  List<String> _subjectTags(AppState state) {
    final subjects = state.scheduleEntries.map((e) => e.subject.trim()).where((e) => e.isNotEmpty).toSet().toList();
    const defaults = ['國文', '數學', '英文', '自然', '社會', '健體', '藝術', '綜合'];
    for (final item in defaults) {
      if (subjects.length < 5 && !subjects.contains(item)) subjects.add(item);
    }
    return subjects;
  }

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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '聯絡簿',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
              ),
              IconButton(
                onPressed: () => setState(
                  () => selectedDate = selectedDate.subtract(
                    const Duration(days: 1),
                  ),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                key,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              IconButton(
                onPressed: () => setState(
                  () => selectedDate = selectedDate.add(const Duration(days: 1)),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
              if (widget.editable)
                FilledButton.icon(
                  onPressed: () => _addEntry(key),
                  icon: const Icon(Icons.add),
                  label: const Text('新增'),
                ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView.separated(
              itemCount: entries.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) => Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
                  child: Row(
                    children: [
                      Chip(label: Text(entries[index].tag)),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          entries[index].content,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                        ),
                      ),
                      if (widget.editable) ...[
                        IconButton(
                          onPressed: () => _editEntry(entries[index]),
                          icon: const Icon(Icons.edit_outlined),
                        ),
                        IconButton(
                          onPressed: () async {
                            widget.state.diaryEntries.remove(entries[index]);
                            await widget.state.saveDiaryEntries(
                              widget.state.diaryEntries,
                            );
                          },
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addEntry(String date) async {
    final tags = _subjectTags(widget.state);
    final entry = await _entryDialog(
      DiaryEntry(date: date, tag: tags.first, content: ''),
    );
    if (entry != null) {
      await widget.state.saveDiaryEntries([
        ...widget.state.diaryEntries,
        entry,
      ]);
    }
  }

  Future<void> _editEntry(DiaryEntry old) async {
    final entry = await _entryDialog(old);
    if (entry == null) {
      return;
    }
    final index = widget.state.diaryEntries.indexOf(old);
    final copy = [...widget.state.diaryEntries]..[index] = entry;
    await widget.state.saveDiaryEntries(copy);
  }

  Future<DiaryEntry?> _entryDialog(DiaryEntry initial) async {
    final controller = TextEditingController(text: initial.content);
    final tags = _subjectTags(widget.state);
    final legacyTag = initial.tag.trim();
    final tagOptions = [
      ...tags,
      if (legacyTag.isNotEmpty && !tags.contains(legacyTag)) legacyTag,
    ];
    var tag = legacyTag.isNotEmpty && tagOptions.contains(legacyTag) ? legacyTag : tags.first;
    final result = await showDialog<DiaryEntry>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('聯絡簿內容'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                maxLines: 5,
                decoration: const InputDecoration(labelText: '內容'),
              ),
              DropdownButtonFormField<String>(
                initialValue: tag,
                items: tagOptions.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                onChanged: (value) {
                  if (value != null) setState(() => tag = value);
                },
                decoration: const InputDecoration(labelText: '科目'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                DiaryEntry(
                  date: initial.date,
                  tag: tag,
                  content: controller.text,
                ),
              ),
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 700;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    '課表',
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
                  ),
                  if (widget.editable) ...[
                    OutlinedButton.icon(
                      onPressed: maxLesson == 0 ? null : () => _removeLesson(maxLesson - 1),
                      icon: const Icon(Icons.remove),
                      label: Text(compact ? '減少' : '減少一節'),
                    ),
                    FilledButton.icon(
                      onPressed: () => _addLesson(maxLesson),
                      icon: const Icon(Icons.add),
                      label: Text(compact ? '增加' : '增加一節'),
                    ),
                  ],
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
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
                          const DataColumn(
                            label: Text(
                              '節次',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          for (var day = 0; day < days.length; day++)
                            DataColumn(
                              label: widget.editable ? _scheduleHeader(day) : Text(days[day]),
                            ),
                        ],
                        rows: [
                          for (var lesson = 0; lesson < maxLesson; lesson++)
                            DataRow(
                              cells: [
                                DataCell(_lessonLabel(lesson)),
                                for (var day = 0; day < 5; day++) DataCell(_scheduleCell(day, lesson)),
                              ],
                            ),
                        ],
                      ),
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
                    Text(
                      entry.subject.isEmpty ? '未命名' : entry.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (entry.teacher.isNotEmpty)
                      Text(
                        entry.teacher,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _lessonLabel(int lesson) {
    final entries = widget.state.scheduleEntries.where((entry) => entry.lesson == lesson).toList();
    final entry = entries.isEmpty
        ? null
        : entries.firstWhere(
            (item) => item.startTime.isNotEmpty || item.endTime.isNotEmpty,
            orElse: () => entries.first,
          );
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
            Text(
              '${lesson + 1}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            Text(
              time,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduleHeader(int day) {
    final count = widget.state.scheduleEntries.where((entry) => entry.weekday == day).length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(days[day]),
        IconButton(
          tooltip: '增加${days[day]}課堂',
          onPressed: () => _addDayLesson(day),
          icon: const Icon(Icons.add, size: 16),
        ),
        IconButton(
          tooltip: '減少${days[day]}課堂',
          onPressed: count == 0 ? null : () => _removeDayLesson(day),
          icon: const Icon(Icons.remove, size: 16),
        ),
      ],
    );
  }

  Future<void> _addDayLesson(int day) async {
    final lessons =
        widget.state.scheduleEntries.where((entry) => entry.weekday == day).map((entry) => entry.lesson).toList();
    final next = lessons.isEmpty ? 0 : lessons.reduce((a, b) => a > b ? a : b) + 1;
    final list = [
      ...widget.state.scheduleEntries,
      ScheduleEntry(
        weekday: day,
        lesson: next,
        subject: '',
        startTime: '08:00',
        endTime: '08:50',
      ),
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
      list.add(
        ScheduleEntry(
          weekday: day,
          lesson: lesson,
          subject: '',
          startTime: '08:00',
          endTime: '08:50',
        ),
      );
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subject,
              autofocus: true,
              decoration: const InputDecoration(labelText: '科目'),
            ),
            TextField(
              controller: teacher,
              decoration: const InputDecoration(labelText: '老師名稱'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    if (result == true) {
      final list = [...widget.state.scheduleEntries];
      final index = list.indexWhere(
        (entry) => entry.weekday == day && entry.lesson == lesson,
      );
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
        list.add(
          ScheduleEntry(
            weekday: day,
            lesson: lesson,
            subject: subject.text,
            teacher: teacher.text,
            startTime: '08:00',
            endTime: '08:50',
          ),
        );
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
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: subject,
              decoration: const InputDecoration(labelText: '科目'),
            ),
            TextField(
              controller: teacher,
              decoration: const InputDecoration(labelText: '老師名稱'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: start,
                    decoration: const InputDecoration(labelText: '開始（??:??）'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: end,
                    decoration: const InputDecoration(labelText: '結束（??:??）'),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    if (result == true) {
      final list = [...widget.state.scheduleEntries];
      list.removeWhere((e) => e.weekday == day && e.lesson == lesson);
      list.add(
        ScheduleEntry(
          weekday: day,
          lesson: lesson,
          subject: subject.text,
          teacher: teacher.text,
          startTime: start.text,
          endTime: end.text,
        ),
      );
      for (var weekday = 0; weekday < 5; weekday++) {
        final index = list.indexWhere(
          (e) => e.weekday == weekday && e.lesson == lesson,
        );
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
  const _EditableListPage({
    required this.title,
    required this.items,
    required this.save,
    required this.hint,
  });
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: () => setState(() => controllers.add(TextEditingController())),
                  icon: const Icon(Icons.add),
                  label: const Text('新增'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.builder(
                itemCount: controllers.length,
                itemBuilder: (_, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: controllers[i],
                          decoration: InputDecoration(hintText: widget.hint),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            controllers[i].dispose();
                            controllers.removeAt(i);
                          });
                        },
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton(onPressed: save, child: const Text('儲存')),
            ),
          ],
        ),
      );
}

class AdminPage extends StatelessWidget {
  final AppState state;
  final int page;
  final ValueChanged<ThemeMode>? onThemeModeChanged;
  const AdminPage({
    super.key,
    required this.state,
    required this.page,
    this.onThemeModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return switch (page) {
      0 => ReminderPage(state: state, manage: true),
      1 => _SeatAdminPage(state: state),
      2 => SchedulePage(state: state, editable: true),
      3 => AttendancePage(state: state),
      4 => RegistrationRecordsPage(state: state),
      5 => ClassPhotosPage(state: state),
      6 => _AppInfoSettingsPage(
          state: state,
          onThemeModeChanged: onThemeModeChanged,
        ),
      _ => _ReminderTestPage(state: state),
    };
  }
}

class _AppInfoSettingsPage extends StatefulWidget {
  final AppState state;
  final ValueChanged<ThemeMode>? onThemeModeChanged;

  const _AppInfoSettingsPage({
    required this.state,
    this.onThemeModeChanged,
  });

  @override
  State<_AppInfoSettingsPage> createState() => _AppInfoSettingsPageState();
}

class _AppInfoSettingsPageState extends State<_AppInfoSettingsPage> {
  final _classIdController = TextEditingController();
  final _auth = AuthService();
  String _version = '讀取中...';

  @override
  void initState() {
    super.initState();
    _classIdController.text = widget.state.classId;
    _loadVersion();
  }

  @override
  void dispose() {
    _classIdController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = packageInfo.version);
  }

  Future<void> _saveClassId() async {
    await widget.state.setClassId(_classIdController.text.trim());
    await widget.state.setDeviceRole(widget.state.deviceRole);
    widget.state.cloudSyncEnabled = kFirebaseConfigured && firebaseRuntimeReady;
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('班級代碼已儲存')),
    );
  }

  Future<void> _changePassword() async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();
    String? error;
    final changed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('更改登入密碼'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '目前密碼'),
                ),
                TextField(
                  controller: newController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '新密碼'),
                ),
                TextField(
                  controller: confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: '確認新密碼'),
                ),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () async {
                if (newController.text != confirmController.text) {
                  setDialogState(() => error = '兩次輸入的新密碼不一致');
                  return;
                }
                final result = await _auth.changePassword(
                  currentController.text,
                  newController.text,
                );
                if (result != null) {
                  setDialogState(() => error = result);
                  return;
                }
                if (dialogContext.mounted) Navigator.pop(dialogContext, true);
              },
              child: const Text('儲存密碼'),
            ),
          ],
        ),
      ),
    );
    currentController.dispose();
    newController.dispose();
    confirmController.dispose();
    if (changed == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('登入密碼已更新')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, compact ? 24 : 32),
      children: [
        const Text(
          '資訊與設定',
          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    const Text('軟體資訊', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                  ],
                ),
                const SizedBox(height: 18),
                _InfoRow(label: '版本', value: _version),
                const SizedBox(height: 10),
                const _InfoRow(label: '製作人', value: '張以樂'),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('深色模式'),
                  subtitle: const Text('切換淺色與深色模式'),
                  value: widget.state.darkMode,
                  onChanged: (value) async {
                    await widget.state.setDarkMode(value);
                    widget.onThemeModeChanged?.call(value ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('班級與帳號', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 16),
                TextField(
                  controller: _classIdController,
                  decoration: const InputDecoration(
                    labelText: '班級代碼（大屏裝置需輸入相同代碼）',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 14),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saveClassId,
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('儲存班級代碼'),
                  ),
                ),
                const SizedBox(height: 18),
                OutlinedButton.icon(
                  onPressed: _changePassword,
                  icon: const Icon(Icons.password_outlined),
                  label: const Text('更改密碼'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        _DataTransferPage(state: widget.state),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text('$label：', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
      ],
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
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                '座位配置',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
              ),
              FilledButton.icon(
                onPressed: state.addRow,
                icon: const Icon(Icons.view_column_outlined),
                label: const Text('新增一排'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(child: _SeatRows(state: state, editable: true, draggable: true)),
        ],
      ),
    );
  }
}

class _DataTransferPage extends StatelessWidget {
  final AppState state;
  const _DataTransferPage({required this.state});

  static const dataTypes = [
    XTypeGroup(label: '729 資料', extensions: ['json']),
  ];

  Future<void> _export(BuildContext context) async {
    final pathController = TextEditingController(text: '729-資料備份.json');
    final path = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('匯出資料'),
          content: TextField(
            controller: pathController,
            decoration: const InputDecoration(labelText: '檔案路徑'),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final location = await getSaveLocation(
                  suggestedName: '729-資料備份.json',
                  acceptedTypeGroups: dataTypes,
                  confirmButtonText: '選擇',
                );
                if (location != null) {
                  setState(() => pathController.text = location.path);
                }
              },
              child: const Text('選擇儲存位置'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, pathController.text.trim()),
              child: const Text('匯出'),
            ),
          ],
        ),
      ),
    );
    pathController.dispose();
    if (path == null) return;
    final fileName = path.split(RegExp(r'[\\/]')).last;
    if (fileName.isEmpty || !fileName.toLowerCase().endsWith('.json') || RegExp(r'[<>:"|?*]').hasMatch(fileName)) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('檔名格式錯誤，請使用合法的 .json 檔名')));
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
          content: TextField(
            controller: pathController,
            decoration: const InputDecoration(labelText: '檔案路徑'),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                final file = await openFile(confirmButtonText: '選擇');
                if (file != null) {
                  setState(() => pathController.text = file.path);
                }
              },
              child: const Text('選擇檔案'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, pathController.text.trim()),
              child: const Text('下一步'),
            ),
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
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('繼續匯入'),
          ),
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
          const Text(
            '資料',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 22),
          Wrap(
            spacing: 12,
            children: [
              FilledButton.icon(
                onPressed: () => _export(context),
                icon: const Icon(Icons.download),
                label: const Text('匯出資料'),
              ),
              OutlinedButton.icon(
                onPressed: () => _import(context),
                icon: const Icon(Icons.upload),
                label: const Text('匯入資料'),
              ),
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
    await widget.state.setTestNow(
      DateTime(date.year, date.month, date.day, hour, minute),
    );
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
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final previewReminders = testNow == null
        ? <ReminderData>[]
        : widget.state.reminders.where((reminder) => reminder.isActiveAt(testNow)).toList();
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: ListView(
        children: [
          const Text(
            '提醒測試',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 22),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;
              final fieldWidth = narrow ? constraints.maxWidth : (constraints.maxWidth - 14) / 2;
              return Wrap(
                spacing: 14,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: '假日期（YYYY-MM-DD）',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: fieldWidth,
                    child: TextField(
                      controller: timeController,
                      decoration: const InputDecoration(labelText: '假時間（HH:MM）'),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: _apply,
                icon: const Icon(Icons.play_arrow),
                label: const Text('套用測試時間'),
              ),
              OutlinedButton.icon(
                onPressed: _clear,
                icon: const Icon(Icons.restore),
                label: const Text('恢復系統時間'),
              ),
            ],
          ),
          if (testNow != null) ...[
            const SizedBox(height: 16),
            Text(
              '目前測試時間：${_dateKey(testNow)} ${timeController.text}',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: isMobile ? 300 : 440,
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
                                  child: Text(
                                    reminder.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
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
