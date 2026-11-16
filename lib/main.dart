import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:window_manager/window_manager.dart';

import 'app_window_controls.dart';
import 'app_state.dart';
import 'app_update_service.dart';
import 'windows_updater.dart';
import 'device_gate.dart';
import 'firebase_config_flag.dart';
import 'firebase_options.dart';
import 'models.dart';
import 'teacher_pages.dart';
import 'ui_tweaks.dart';
import 'services/auth_service.dart';

bool get isDesktopPlatform => !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

/// 729 設計規則：顏色、圓角、字級統一在這裡管理。
/// 729 配色（Happy Hues）：
/// 背景 #fffffe、標題 #272343、內文 #2d334a、按鈕 #ffd803、
/// 次要 #e3f6f5、第三 #bae8e8、框線 #272343。
/// 想換強調色，只要改 [accent] 和 [accentDark]。
class AppTokens {
  AppTokens._();

  static const Color accent = Color(0xFFFFD803);
  static const Color accentDark = Color(0xFFFFD803);
  static const Color ink = Color(0xFF272343);

  /// 超細框線：黑色給可以點的東西，灰色給容器
  static const double hairline = 1;
  static BorderSide strokeDark(BuildContext context) =>
      BorderSide(color: Theme.of(context).colorScheme.outline, width: hairline);
  static BorderSide strokeLight(BuildContext context) =>
      BorderSide(color: Theme.of(context).colorScheme.outlineVariant, width: hairline);

  // 座位：男生淺藍、女生淺粉
  static Color seatBoy(bool isDark) => isDark ? const Color(0xFF233A5E) : const Color(0xFFDCEBFF);
  static Color seatGirl(bool isDark) => isDark ? const Color(0xFF5A2843) : const Color(0xFFFFE1EC);

  static const double radiusCard = 16;
  static const double radiusControl = 10;

  // 字級只用這五級：時鐘 / 大數字 / 標題 / 內文 / 說明
  static const double fontClock = 56;
  static const double fontNumber = 32;
  static const double fontTitle = 20;
  static const double fontBody = 15;
  static const double fontCaption = 13;

  static Color pageBackground(bool isDark) => isDark ? const Color(0xFF16152B) : const Color(0xFFFFFFFE);
}

ThemeData _buildAppTheme(Brightness brightness) {
  final isDark = brightness == Brightness.dark;
  final accent = isDark ? AppTokens.accentDark : AppTokens.accent;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppTokens.accent,
    brightness: brightness,
  ).copyWith(
    primary: accent,
    onPrimary: AppTokens.ink,
    primaryContainer: isDark ? const Color(0xFF4A4220) : const Color(0xFFFFF3B0),
    onPrimaryContainer: isDark ? const Color(0xFFFFF3B0) : AppTokens.ink,
    secondary: isDark ? const Color(0xFFBAE8E8) : const Color(0xFF2D334A),
    onSecondary: isDark ? AppTokens.ink : const Color(0xFFFFFFFE),
    secondaryContainer: isDark ? const Color(0xFF24233F) : const Color(0xFFE3F6F5),
    onSecondaryContainer: isDark ? const Color(0xFFFFFFFE) : AppTokens.ink,
    tertiary: isDark ? const Color(0xFFBAE8E8) : const Color(0xFF2D334A),
    onTertiary: isDark ? AppTokens.ink : const Color(0xFFFFFFFE),
    tertiaryContainer: isDark ? const Color(0xFF2C2B4A) : const Color(0xFFBAE8E8),
    onTertiaryContainer: isDark ? const Color(0xFFFFFFFE) : AppTokens.ink,
    error: isDark ? const Color(0xFFF2B8B5) : const Color(0xFFB3261E),
    errorContainer: isDark ? const Color(0xFF8C1D18) : const Color(0xFFF9DEDC),
    onErrorContainer: isDark ? const Color(0xFFF9DEDC) : const Color(0xFF410E0B),
    surface: AppTokens.pageBackground(isDark),
    onSurface: isDark ? const Color(0xFFFFFFFE) : AppTokens.ink,
    onSurfaceVariant: isDark ? const Color(0xFFB9BCCB) : const Color(0xFF5A5F75),
    surfaceContainerLowest: isDark ? const Color(0xFF1F1D38) : const Color(0xFFFFFFFE),
    surfaceContainerLow: isDark ? const Color(0xFF1B1A33) : const Color(0xFFF1FAFA),
    surfaceContainer: isDark ? const Color(0xFF24233F) : const Color(0xFFE3F6F5),
    surfaceContainerHigh: isDark ? const Color(0xFF2C2B4A) : const Color(0xFFD0EFEE),
    surfaceContainerHighest: isDark ? const Color(0xFF353456) : const Color(0xFFBAE8E8),
    // 黑色細框（可點的東西）／灰色細框（容器）
    outline: isDark ? const Color(0xFFFFFFFE) : AppTokens.ink,
    outlineVariant: isDark ? const Color(0xFF3A3958) : const Color(0xFFD5DADF),
  );

  const controlShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppTokens.radiusControl)),
  );
  const controlPadding = EdgeInsets.symmetric(horizontal: 16, vertical: 12);
  const controlText = TextStyle(fontSize: AppTokens.fontBody);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    fontFamily: 'Class729Rounded',
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      foregroundColor: scheme.onSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    textTheme: TextTheme(
      headlineMedium: TextStyle(fontSize: AppTokens.fontNumber, color: scheme.onSurface),
      titleLarge: TextStyle(fontSize: AppTokens.fontTitle, color: scheme.onSurface),
      titleMedium: TextStyle(fontSize: 17, color: scheme.onSurface),
      bodyLarge: TextStyle(fontSize: AppTokens.fontBody, color: scheme.onSurface),
      bodyMedium: TextStyle(fontSize: AppTokens.fontBody, color: scheme.onSurface),
      bodySmall: TextStyle(fontSize: AppTokens.fontCaption, color: scheme.onSurfaceVariant),
      labelLarge: const TextStyle(fontSize: AppTokens.fontBody),
      labelMedium: TextStyle(fontSize: AppTokens.fontCaption, color: scheme.onSurfaceVariant),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, thickness: 1, space: 1),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusCard),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      selectedColor: scheme.primaryContainer,
      labelStyle: TextStyle(fontSize: AppTokens.fontCaption, color: scheme.onSurface),
      side: BorderSide(color: scheme.outlineVariant),
      shape: const StadiumBorder(),
      elevation: 0,
      pressElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppTokens.radiusControl),
        borderSide: BorderSide(color: scheme.outline, width: 1.5),
      ),
    ),
    // 主要動作：唯一用強調色填滿的按鈕
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
        elevation: 0,
        shape: controlShape,
        padding: controlPadding,
        textStyle: controlText,
      ),
    ),
    // 次要動作：白底細框
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.surfaceContainerLowest,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        shadowColor: Colors.transparent,
        side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
        shape: controlShape,
        padding: controlPadding,
        textStyle: controlText,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
        shape: controlShape,
        padding: controlPadding,
        textStyle: controlText,
      ),
    ),
    segmentedButtonTheme: SegmentedButtonThemeData(
      style: ButtonStyle(
        shape: const WidgetStatePropertyAll(controlShape),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
        backgroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.primaryContainer : scheme.surfaceContainerLowest,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? scheme.onPrimaryContainer : scheme.onSurface,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: scheme.onSurface, shape: controlShape, elevation: 0),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: scheme.onSurfaceVariant),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusCard)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusControl)),
    ),
  );
}

/// 正式版（preview.bat）看不到錯誤訊息，所以把錯誤寫進 exe 旁邊的 729_error_log.txt
void _logError(Object error, StackTrace? stack) {
  if (kIsWeb) return;
  try {
    final dir = File(Platform.resolvedExecutable).parent.path;
    File('$dir${Platform.pathSeparator}729_error_log.txt').writeAsStringSync(
      '==== ${DateTime.now()} ====\n$error\n$stack\n\n',
      mode: FileMode.append,
    );
  } catch (_) {}
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    _logError(details.exception, details.stack);
  };
  WidgetsBinding.instance.platformDispatcher.onError = (error, stack) {
    _logError(error, stack);
    return true;
  };
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
    // 螢幕縮放（125%、150%）時，第一次放大有時會失敗，視窗會比螢幕大、上面跑出畫面外。
    // 等一下再確認一次，沒放大就再放大；還是不行就把視窗縮到螢幕裡並置中。
    Future<void>.delayed(const Duration(milliseconds: 600), () async {
      try {
        if (!await windowManager.isMaximized()) await windowManager.maximize();
        await Future<void>.delayed(const Duration(milliseconds: 300));
        if (!await windowManager.isMaximized()) {
          await windowManager.setSize(const Size(1100, 640));
          await windowManager.center();
        }
      } catch (_) {}
    });
  }

  final state = AppState();
  try {
    await state.load();
  } catch (error, stack) {
    // 讀取資料失敗也要能開起來，錯誤記在 729_error_log.txt
    _logError(error, stack);
  }
  runApp(SevenTwentyNineApp(state: state));
  // 準備 exe 旁邊的「頭像」資料夾（第一次會自動建立並放入目前的頭像和設定）
  unawaited(ExternalAvatars.init());
  // 按 F5：重新讀「頭像」資料夾的圖片和「頭像設定.txt」，改完位置馬上看效果
  HardwareKeyboard.instance.addHandler((event) {
    if (event is KeyDownEvent && event.logicalKey == LogicalKeyboardKey.f5) {
      ExternalAvatars.reload().then((msg) {
        windowsUpdateStatus.value = msg;
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (windowsUpdateStatus.value == msg) windowsUpdateStatus.value = null;
        });
      });
      return true;
    }
    return false;
  });
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

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb && Platform.isWindows) {
        // Windows：打開時自動檢查 GitHub Releases，有新版就自動下載、更新、重開
        checkWindowsUpdate();
      } else {
        const AppUpdateService().checkForUpdate(
          context,
          versionUrl: _updateCheckUrl,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final themeMode = widget.state.darkMode ? ThemeMode.dark : ThemeMode.light;
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: '729',
          theme: _buildAppTheme(Brightness.light),
          darkTheme: _buildAppTheme(Brightness.dark),
          themeMode: themeMode,
          builder: (_, child) => Stack(
            fit: StackFit.expand,
            children: [
              _AppBackdrop(
                brightness: themeMode == ThemeMode.dark ? Brightness.dark : Brightness.light,
              ),
              if (child != null) child,
              // 自動更新的進度條
              ValueListenableBuilder<String?>(
                valueListenable: windowsUpdateStatus,
                builder: (context, msg, _) => msg == null
                    ? const SizedBox.shrink()
                    : Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: Material(
                            color: AppTokens.accent,
                            shape: const StadiumBorder(side: BorderSide(color: AppTokens.ink, width: 1)),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: Text(msg,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTokens.ink)),
                            ),
                          ),
                        ),
                      ),
              ),
            ],
          ),
          home: DeviceRoleGate(state: widget.state),
        );
      },
    );
  }
}

class _AppBackdrop extends StatelessWidget {
  final Brightness brightness;

  const _AppBackdrop({required this.brightness});

  @override
  Widget build(BuildContext context) {
    final isDark = brightness == Brightness.dark;

    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(color: AppTokens.pageBackground(isDark)),
      ),
    );
  }
}

Future<bool> showPinEntryDialog(BuildContext context, AppState state) async {
  final pinLength = state.bigScreenExitPinLength;
  if (pinLength == null || pinLength < 4 || pinLength > 8) return false;
  return await showDialog<bool>(
        context: context,
        builder: (_) => _PinEntryDialog(state: state, pinLength: pinLength),
      ) ??
      false;
}

/// 管理者 PIN 碼：進入大屏蓋章頁前輸入。還沒設定幹部 PIN 碼時直接通過。
Future<bool> showOfficerPinDialog(BuildContext context, AppState state) async {
  final pinLength = state.officerPinLength;
  if (pinLength == null || pinLength < 4 || pinLength > 8) return true;
  return await showDialog<bool>(
        context: context,
        builder: (_) => _PinEntryDialog(
          state: state,
          pinLength: pinLength,
          title: '請輸入管理者PIN碼',
          verify: state.verifyOfficerPin,
        ),
      ) ??
      false;
}

/// 打開蓋章頁（大屏用，要先過管理者 PIN 碼）
Future<void> openStampWithOfficerPin(BuildContext context, AppState state) async {
  if (!await showOfficerPinDialog(context, state) || !context.mounted) return;
  await showPageDialog(context, '蓋章', StampPage(state: state));
}

Future<void> showSettingsWindow(
  BuildContext context,
  AppState state,
) async {
  if (!await showPinEntryDialog(context, state) || !context.mounted) return;
  await showSettingsWindowAfterPin(context, state);
}

Future<void> showSettingsWindowAfterPin(
  BuildContext context,
  AppState state,
) async {
  if (!context.mounted) return;
  final size = MediaQuery.sizeOf(context);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: min(900.0, size.width - 32),
        height: min(820.0, size.height - 32),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 12, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '資訊與設定',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    tooltip: '關閉',
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: _AppInfoSettingsPage(
                state: state,
                showTitle: false,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PinEntryDialog extends StatefulWidget {
  final AppState state;
  final int pinLength;
  final String title;
  final bool Function(String)? verify;

  const _PinEntryDialog({required this.state, required this.pinLength, this.title = '請輸入PIN碼', this.verify});

  @override
  State<_PinEntryDialog> createState() => _PinEntryDialogState();
}

class _PinEntryDialogState extends State<_PinEntryDialog> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {});
    if (value.length != widget.pinLength) return;
    if ((widget.verify ?? widget.state.verifyBigScreenExitPin)(value)) {
      Navigator.of(context).pop(true);
    } else {
      _controller.clear();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Dialog(
      child: SizedBox(
        width: 380,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: _focusNode.requestFocus,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < widget.pinLength; i++)
                      Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.symmetric(horizontal: 5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i < _controller.text.length ? scheme.primary : Colors.transparent,
                          border: Border.all(color: scheme.outline, width: 1.5),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 2,
                child: Opacity(
                  opacity: 0.01,
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    autofocus: true,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    maxLength: widget.pinLength,
                    style: const TextStyle(fontSize: 1, color: Colors.transparent),
                    cursorColor: Colors.transparent,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      isCollapsed: true,
                    ),
                    onChanged: _onChanged,
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

class MainShell extends StatefulWidget {
  final AppState state;
  const MainShell({
    super.key,
    required this.state,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool compact = false;
  late int page;

  @override
  void initState() {
    super.initState();
    page = 0;
  }

  // 教師後台 5 大頁；每頁裡面再用分頁標籤切換（見 AdminPage）
  // 教師後台 6 大頁：總覽／學生／蓋章／課程／大屏／測試（每頁裡面最多 4 個分頁，見 AdminPage）
  static const _labels = ['總覽', '學生', '蓋章', '課程', '大屏', '測試'];
  static const List<Object> _icons = [
    AppIcons.dashboard,
    Icons.groups_outlined,
    AppIcons.clipboardPen,
    AppIcons.calendar,
    Icons.tv_outlined,
    Icons.science_outlined,
  ];

  static const _groups = [
    NavGroup('後台', [0, 1, 2, 3, 4, 5]),
  ];

  /// 頂端列的頁面順序（每日 → 班級 → 設定）
  static final List<int> _navOrder = [for (final g in _groups) ...g.pages];

  void _selectPage(int value) => setState(() => page = value);

  Future<void> _openSettings() async {
    await showSettingsWindow(
      context,
      widget.state,
    );
  }

  Future<void> _exitTeacher() async {
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
              groups: _groups,
              current: page,
              onSelect: _selectPage,
              extraItems: [
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: const Text('資訊與設定'),
                  onTap: () {
                    Navigator.pop(context);
                    _openSettings();
                  },
                ),
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
                  Positioned.fill(
                    top: 10,
                    child: AnimatedBuilder(
                      animation: widget.state,
                      builder: (_, __) => KeyedSubtree(
                        key: ValueKey<int>(page),
                        child: AdminPage(
                          state: widget.state,
                          page: page,
                        ),
                      ),
                    ),
                  ),
                  AutoHideBar(
                    child: Builder(
                      builder: (barContext) => WindowBar(
                        title: '後台',
                        mobile: isMobile,
                        onOpenMenu: () => Scaffold.of(barContext).openDrawer(),
                        onOpenSettings: _openSettings,
                      ),
                    ),
                  ),
                ],
              ),
            )
          // 跟大屏首頁同一套外觀：頂端白色圓角長條＋淺青背景＋白色大圓角面板
          : ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainer,
              child: Stack(
                children: [
                  Positioned.fill(
                    top: 10,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(40, 70, 40, 32),
                      child: AnimatedBuilder(
                        animation: widget.state,
                        builder: (_, __) => KeyedSubtree(
                          key: ValueKey<int>(page),
                          child: AdminPage(
                            state: widget.state,
                            page: page,
                          ),
                        ),
                      ),
                    ),
                  ),
                  AutoHideBar(
                    child: BigScreenTopBar(
                      icons: [for (final i in _navOrder) _icons[i]],
                      labels: [for (final i in _navOrder) _labels[i]],
                      current: _navOrder.indexOf(page),
                      onSelect: (i) => _selectPage(_navOrder[i]),
                      onBack: _exitTeacher,
                      backTooltip: '退出教師後台',
                      showLabels: false,
                      showWindowControls: true,
                      onOpenSettings: _openSettings,
                      notificationButton: NotificationBell(state: widget.state, target: 'teacher'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class TeacherMobileDrawer extends StatelessWidget {
  final List<String> labels;
  final List<Object> icons;
  final List<NavGroup> groups;
  final int current;
  final ValueChanged<int> onSelect;
  final List<Widget>? extraItems;

  const TeacherMobileDrawer({
    super.key,
    required this.labels,
    required this.icons,
    required this.groups,
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
              padding: EdgeInsets.fromLTRB(16, 10, 12, 12),
              child: Align(alignment: Alignment.centerLeft, child: AppLogo(height: 26)),
            ),
            for (final group in groups) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                child: Text(
                  group.title,
                  style: TextStyle(
                    fontSize: AppTokens.fontCaption,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              for (final i in group.pages)
                if (i < labels.length)
                  ListTile(
                    selected: current == i,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppTokens.radiusControl),
                    ),
                    leading: navIcon(icons[i], size: 22, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    title: Text(labels[i], style: const TextStyle(fontSize: AppTokens.fontBody)),
                    onTap: () {
                      onSelect(i);
                      Navigator.pop(context);
                    },
                  ),
            ],
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

/// 自訂圖示（assets/icon，黑色線條、透明背景，會依主題自動上色）。
class AppIcons {
  AppIcons._();

  /// 頂端列所有圖示（返回、功能、視窗按鈕）共用的尺寸
  static const double topBarSize = 26;

  static const _dir = 'assets/icon';
  static const dashboard = '$_dir/layout-dashboard.png';
  static const clipboardPen = '$_dir/clipboard-pen.png';
  static const dice = '$_dir/dice-5.png';
  static const bell = '$_dir/bell.png';
  static const grid = '$_dir/layout-grid.png';
  static const calendar = '$_dir/calendar-days.png';
  static const book = '$_dir/book-open-text.png';
  static const chevronLeft = '$_dir/chevron-left.png';
  static const minus = '$_dir/minus.png';
  static const expand = '$_dir/expand.png';
  static const restore = '$_dir/minimize-2.png';
  static const close = '$_dir/x.png';
}

class AppIcon extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;
  const AppIcon(this.asset, {super.key, this.size = 24, this.color});

  @override
  Widget build(BuildContext context) => Image.asset(
        asset,
        width: size,
        height: size,
        color: color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.medium,
      );
}

/// 導覽用圖示：可以是 Material 的 IconData，也可以是 AppIcons 的圖檔路徑。
Widget navIcon(Object icon, {double size = 20, Color? color}) =>
    icon is String ? AppIcon(icon, size: size, color: color) : Icon(icon as IconData, size: size, color: color);

/// Logo：展開時顯示「★729」，收合時只顯示星星圓標。顏色會跟著主題變。
class AppLogo extends StatelessWidget {
  final bool compact;
  final double height;
  const AppLogo({super.key, this.compact = false, this.height = 26});

  @override
  Widget build(BuildContext context) => Image.asset(
        compact ? 'assets/logo_mark.png' : 'assets/logo_wordmark.png',
        height: height,
        color: Theme.of(context).colorScheme.onSurface,
        colorBlendMode: BlendMode.srcIn,
        filterQuality: FilterQuality.medium,
      );
}

/// 桌面版外框：左側導覽列 + 右側頂端列與圓角內容面板。
class DesktopFrame extends StatelessWidget {
  final Widget sidebar;
  final String title;
  final Widget child;
  final VoidCallback onOpenSettings;
  const DesktopFrame(
      {super.key, required this.sidebar, required this.title, required this.child, required this.onOpenSettings});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: scheme.surfaceContainer,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          sidebar,
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        top: 10,
                        child: Container(
                          margin: const EdgeInsets.only(right: 16, bottom: 16),
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(36),
                            border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
                          ),
                          child: child,
                        ),
                      ),
                      AutoHideBar(
                        child: WindowBar(
                          title: title,
                          onOpenSettings: onOpenSettings,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WindowBar extends StatelessWidget {
  final String title;
  final bool mobile;
  final VoidCallback? onOpenMenu;
  final VoidCallback onOpenSettings;
  final List<Widget>? actions;

  const WindowBar({
    super.key,
    required this.title,
    this.mobile = false,
    this.onOpenMenu,
    required this.onOpenSettings,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onPanStart: isDesktopPlatform ? (_) => windowManager.startDragging() : null,
      child: Container(
        height: 60,
        padding: EdgeInsets.only(
          left: mobile ? 8 : 12,
          right: isDesktopPlatform ? 184 : 16,
        ),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          border: Border.all(
            color: scheme.outlineVariant,
            width: AppTokens.hairline,
          ),
        ),
        child: Row(
          children: [
            if (mobile) ...[
              IconButton(
                tooltip: '開啟選單',
                onPressed: onOpenMenu,
                icon: const Icon(Icons.menu),
              ),
              const SizedBox(width: 4),
              const AppLogo(height: 22),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: AppTokens.fontBody,
                  fontWeight: mobile ? FontWeight.normal : FontWeight.w700,
                  color: mobile ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
            ),
            IconButton(
              tooltip: '資訊與設定',
              onPressed: onOpenSettings,
              icon: const Icon(Icons.settings_outlined),
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

/// 側欄分組：標題 + 這組包含的頁面索引。
class NavGroup {
  final String title;
  final List<int> pages;
  const NavGroup(this.title, this.pages);
}

class SideBar extends StatelessWidget {
  final bool expanded;
  final int current;
  final List<String> labels;
  final List<Object> icons;
  final List<NavGroup> groups;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggle;
  final VoidCallback? onExit;

  const SideBar({
    super.key,
    required this.expanded,
    required this.current,
    required this.labels,
    required this.icons,
    required this.groups,
    required this.onSelect,
    required this.onToggle,
    this.onExit,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      width: expanded ? 232 : 72,
      child: ClipRect(
        // 動畫途中內容先用最終寬度排版，避免出現溢位警告
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: expanded ? 232 : 72,
          maxWidth: expanded ? 232 : 72,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 60,
                child: expanded
                    ? Row(
                        children: [
                          const SizedBox(width: 20),
                          const Flexible(child: AppLogo(height: 26)),
                          const Spacer(),
                          IconButton(
                            tooltip: '收合導覽列',
                            onPressed: onToggle,
                            icon: Icon(Icons.keyboard_double_arrow_left, size: 20, color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(width: 8),
                        ],
                      )
                    : Center(
                        child: Tooltip(
                          message: '展開導覽列',
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: onToggle,
                            child: const Padding(
                              padding: EdgeInsets.all(8),
                              child: AppLogo(compact: true, height: 28),
                            ),
                          ),
                        ),
                      ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  children: [
                    for (final group in groups) ...[
                      if (expanded)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
                          child: Text(
                            group.title,
                            maxLines: 1,
                            overflow: TextOverflow.clip,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: AppTokens.fontCaption),
                          ),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                          child: Divider(color: scheme.outlineVariant),
                        ),
                      for (final index in group.pages)
                        if (index < labels.length)
                          _navTile(
                            context,
                            icon: icons[index],
                            label: labels[index],
                            selected: current == index,
                            onTap: () => onSelect(index),
                          ),
                    ],
                  ],
                ),
              ),
              if (onExit != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  decoration: BoxDecoration(border: Border(top: BorderSide(color: scheme.outlineVariant))),
                  child: _navTile(
                    context,
                    icon: Icons.logout_outlined,
                    label: '退出',
                    selected: false,
                    onTap: onExit!,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required Object icon,
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final iconWidget = navIcon(icon, size: 20, color: selected ? scheme.onSurface : scheme.onSurfaceVariant);
    final tile = Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected ? scheme.surfaceContainerLowest : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTokens.radiusControl),
          side: BorderSide(color: selected ? scheme.outline : Colors.transparent, width: AppTokens.hairline),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.radiusControl),
          onTap: onTap,
          child: SizedBox(
            height: 42,
            child: expanded
                ? Row(
                    children: [
                      const SizedBox(width: 10),
                      iconWidget,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                            fontSize: AppTokens.fontBody,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(child: iconWidget),
          ),
        ),
      ),
    );
    return expanded ? tile : Tooltip(message: label, child: tile);
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
  if (!await showOfficerPinDialog(context, state) || !context.mounted) return;
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
                child: StampPage(state: state),
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
                style: TextStyle(fontSize: AppTokens.fontTitle, fontWeight: FontWeight.w800),
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
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.outline,
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
                            ? Theme.of(context).colorScheme.onSurface
                            : Theme.of(context).colorScheme.outline,
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
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2)
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
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: Icon(
                            Icons.open_in_full,
                            size: 14,
                            color: Theme.of(context).colorScheme.onPrimary,
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
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            shape: BoxShape.circle,
                            border: Border.all(color: Theme.of(context).colorScheme.surface, width: 2),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: Theme.of(context).colorScheme.onSurface,
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
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
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
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
            ),
            child: Center(
              child: Text(
                '講台',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
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
    final baseColor = _seatColor(context, seat.gender);
    Widget buildCard() {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: draggable ? null : (editable ? onEdit : () => _showSeatProfile(context, state, index, seat)),
          mouseCursor: draggable ? SystemMouseCursors.grab : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 108,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: baseColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Theme.of(context).colorScheme.outline, width: AppTokens.hairline),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (gender == '男') return AppTokens.seatBoy(isDark);
    if (gender == '女') return AppTokens.seatGirl(isDark);
    return Theme.of(context).colorScheme.surfaceContainer;
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
        content: SizedBox(
          width: 420,
          child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            TextField(
              controller: numberController,
              decoration: const InputDecoration(labelText: '座號'),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: controller,
              autofocus: true,
              decoration: const InputDecoration(labelText: '姓名'),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: labelController,
              decoration: const InputDecoration(
                labelText: '同學標籤／職位',
                hintText: '例如：資訊股長',
              ),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: noteController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: '備註',
                hintText: '可填寫同學備註',
              ),
            ),
            const SizedBox(height: 22),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '', label: Text('未設定')),
                ButtonSegment(value: '男', label: Text('男生')),
                ButtonSegment(value: '女', label: Text('女生')),
              ],
              selected: {gender},
              onSelectionChanged: (value) => setState(() => gender = value.first),
            ),
            const SizedBox(height: 6),
          ],
        ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
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
  // 等視窗關閉動畫跑完再釋放，不然關閉時輸入框還在用會出錯
  Future<void>.delayed(const Duration(milliseconds: 600), () {
    numberController.dispose();
    controller.dispose();
    labelController.dispose();
    noteController.dispose();
  });
}

Future<void> _showSeatProfile(BuildContext context, AppState state, int index, SeatData seat) {
  return showDialog<void>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(24),
      child: _StudentCard(state: state, index: index),
    ),
  );
}

/// 同學卡片：名牌、章數（主角）、蓋章動畫、備註。
class _StudentCard extends StatefulWidget {
  final AppState state;
  final int index;
  const _StudentCard({required this.state, required this.index});

  @override
  State<_StudentCard> createState() => _StudentCardState();
}

class _StudentCardState extends State<_StudentCard> with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  int _lastDelta = 1;
  Set<String> _avatarAssets = {};

  @override
  void initState() {
    super.initState();
    _loadAvatarAssets();
  }

  Future<void> _loadAvatarAssets() async {
    final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
    if (!mounted) return;
    setState(() {
      _avatarAssets = manifest.listAssets().where((asset) => asset.startsWith('assets/avatars/')).toSet();
    });
  }

  String? _avatarForSeat(String seatNumber) {
    for (final extension in ['png', 'jpg', 'jpeg', 'webp', 'gif']) {
      final asset = 'assets/avatars/$seatNumber.$extension';
      if (_avatarAssets.contains(asset)) return asset;
    }
    return null;
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  /// 章數小卡：上面小字、下面大數字，置中；結算章用淡黃底當主角
  Widget _stampFigure(ColorScheme scheme, String label, int value, {bool primary = false}) => Container(
        height: 104,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: primary ? scheme.primaryContainer : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            Text('$value',
                style: TextStyle(fontSize: 44, height: 1, fontWeight: FontWeight.w900, color: scheme.onSurface)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final state = widget.state;
        if (widget.index >= state.seats.length) return const SizedBox.shrink();
        final seat = state.seats[widget.index];
        final scheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final headerColor = seat.gender == '男'
            ? AppTokens.seatBoy(isDark)
            : seat.gender == '女'
                ? AppTokens.seatGirl(isDark)
                : scheme.surfaceContainer;
        final roles = seat.label.split(RegExp(r'[、,，/\s]+')).map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
        final hasName = seat.name.trim().isNotEmpty;
        final hairline = BorderSide(color: scheme.outline, width: AppTokens.hairline);

        Widget section(String title, Widget child) => Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 8),
                  child,
                ],
              ),
            );

        final card = ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(28),
              border: Border.fromBorderSide(hairline),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. 名牌
                  Container(
                    color: headerColor,
                    padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLowest,
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(hairline),
                          ),
                          child: Text(seat.number.isEmpty ? '—' : seat.number,
                              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(hasName ? seat.name : '空位',
                                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                              if (roles.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    for (final r in roles)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: scheme.surfaceContainerLowest,
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.fromBorderSide(hairline),
                                        ),
                                        child: Text(r, style: TextStyle(fontSize: 13, color: scheme.onSurface)),
                                      ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // 印章「咚」地蓋在關閉按鈕左邊（不佔版面）
                        SizedBox(
                          width: 0,
                          height: 64,
                          child: OverflowBox(
                            minWidth: 0,
                            maxWidth: 88,
                            maxHeight: 88,
                            alignment: Alignment.centerRight,
                            child: IgnorePointer(
                              child: AnimatedBuilder(
                                animation: _anim,
                                builder: (_, __) {
                                  final v = _anim.value;
                                  if (v == 0 || v == 1) return const SizedBox(width: 88, height: 88);
                                  final drop = Curves.easeOutBack.transform((v / 0.35).clamp(0.0, 1.0));
                                  final fade = v < 0.7 ? 1.0 : (1 - (v - 0.7) / 0.3).clamp(0.0, 1.0);
                                  final color = _lastDelta > 0 ? const Color(0xFFD7263D) : scheme.onSurfaceVariant;
                                  return Opacity(
                                    opacity: fade,
                                    child: Transform.scale(
                                      scale: 2.2 - 1.2 * drop,
                                      child: Transform.rotate(
                                        angle: -0.2,
                                        child: Container(
                                          width: 88,
                                          height: 88,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            border: Border.all(color: color, width: 4),
                                          ),
                                          child: Text(_lastDelta > 0 ? '+1' : '−1',
                                              style:
                                                  TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: color)),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: '關閉',
                          onPressed: () => Navigator.pop(context),
                          icon: AppIcon(AppIcons.close, size: 22, color: scheme.onSurface),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // 2. 章數＋3. 蓋章動畫
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: AnimatedBuilder(
                                animation: _anim,
                                builder: (_, child) {
                                  final v = _anim.value;
                                  final bump =
                                      v < 0.3 ? 1 + (v / 0.3) * 0.18 : 1.18 - ((v - 0.3) / 0.7).clamp(0.0, 1.0) * 0.18;
                                  final shake = _lastDelta < 0 && v < 0.5 ? sin(v * 40) * 6 * (1 - v * 2) : 0.0;
                                  return Transform.translate(
                                    offset: Offset(shake, 0),
                                    child: Transform.scale(scale: _lastDelta > 0 ? bump : 1, child: child),
                                  );
                                },
                                child: _stampFigure(scheme, '結算章', seat.score, primary: true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(child: _stampFigure(scheme, '兌換章', seat.score)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (seat.note.trim().isNotEmpty) section('備註', Text(seat.note, style: const TextStyle(fontSize: 15))),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        );
        // 有頭像的同學：貼在卡片左上角，稍微超出卡片
        // exe 旁邊「頭像」資料夾裡的圖片和「頭像設定.txt」優先；沒有才用打包在 app 裡的（lib/ui_tweaks.dart）
        return ValueListenableBuilder<int>(
          valueListenable: ExternalAvatars.version,
          builder: (context, _, __) {
            final file = ExternalAvatars.fileFor(seat.number);
            final asset = file == null ? _avatarForSeat(seat.number) : null;
            if (file == null && asset == null) return card;
            final tweak = ExternalAvatars.tweakFor(seat.number);
            return Stack(
              clipBehavior: Clip.none,
              children: [
                card,
                Positioned(
                  left: tweak.left,
                  top: tweak.top,
                  width: tweak.width,
                  height: tweak.height,
                  child: IgnorePointer(
                    child: file != null
                        ? Image.file(file, fit: BoxFit.contain)
                        : Image.asset(asset!, fit: BoxFit.contain),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

class LotteryPage extends StatefulWidget {
  final AppState state;
  const LotteryPage({super.key, required this.state});

  @override
  State<LotteryPage> createState() => _LotteryPageState();
}

class _LotteryPageState extends State<LotteryPage> {
  final random = Random();
  int count = 1;
  PickMode mode = PickMode.normal;
  SeatData? center;
  List<SeatData> results = [];
  bool drawing = false;

  List<SeatData> get _candidates => widget.state.seats.where((seat) => seat.name.trim().isNotEmpty).toList();

  Future<void> draw() async {
    final candidates = _candidates;
    if (candidates.isEmpty || drawing) return;
    final seats = widget.state.seats;
    final centerSeat = candidates[random.nextInt(candidates.length)];
    final special = [
      for (final i in specialPickTargets(seats, seats.indexOf(centerSeat), mode))
        if (seats[i].name.trim().isNotEmpty) seats[i],
    ];
    final n = mode == PickMode.normal
        ? (count < candidates.length ? count : candidates.length)
        : (special.isEmpty ? 1 : special.length);
    final winners = mode == PickMode.normal ? ([...candidates]..shuffle(random)).take(n).toList() : special;
    setState(() {
      drawing = true;
      center = null;
    });
    const durations = [45, 45, 55, 65, 80, 100, 125, 155, 190, 230];
    for (final milliseconds in durations) {
      if (!mounted) return;
      setState(() => results = ([...candidates]..shuffle(random)).take(n).toList());
      await Future<void>.delayed(Duration(milliseconds: milliseconds));
    }
    if (!mounted) return;
    setState(() {
      results = winners;
      center = mode == PickMode.normal ? null : centerSeat;
      drawing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final darkMode = Theme.of(context).brightness == Brightness.dark;
    final resultTextColor = darkMode ? Colors.white : Colors.black87;
    final maxCount = _candidates.isEmpty ? 1 : _candidates.length;
    Widget resultCard(SeatData s) => Card(
          color: s.gender == '男'
              ? AppTokens.seatBoy(darkMode)
              : s.gender == '女'
                  ? AppTokens.seatGirl(darkMode)
                  : null,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: isMobile ? 20 : 36, vertical: isMobile ? 18 : 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(s.number, style: TextStyle(fontSize: 24, color: resultTextColor)),
                const SizedBox(height: 6),
                Text(s.name, style: TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: resultTextColor)),
              ],
            ),
          ),
        );
    return Padding(
      padding: EdgeInsets.all(isMobile ? 12 : 24),
      child: Column(
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('選號機器', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: results.isEmpty
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('要抽幾個人', style: TextStyle(fontSize: 22)),
                        const SizedBox(height: 12),
                        PickCountSelector(
                          value: mode == PickMode.normal ? count : mode.fixedCount,
                          max: maxCount,
                          onChanged: mode == PickMode.normal ? (v) => setState(() => count = v) : null,
                        ),
                        const SizedBox(height: 14),
                        PickModeSelector(value: mode, onChanged: (m) => setState(() => mode = m)),
                      ],
                    )
                  : SingleChildScrollView(
                      child: Column(
                        children: [
                          if (center != null)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: Text(
                                '${mode.label}・中心是 ${center!.number} ${center!.name}（他本人不算）',
                                style: const TextStyle(fontSize: 20),
                              ),
                            ),
                          Wrap(
                            spacing: 16,
                            runSpacing: 16,
                            alignment: WrapAlignment.center,
                            children: [for (final s in results) resultCard(s)],
                          ),
                        ],
                      ),
                    ),
            ),
          ),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (results.isNotEmpty) ...[
                PickCountSelector(
                  value: mode == PickMode.normal ? count : mode.fixedCount,
                  max: maxCount,
                  compact: true,
                  onChanged: drawing || mode != PickMode.normal ? null : (v) => setState(() => count = v),
                ),
                PickModeSelector(value: mode, onChanged: drawing ? null : (m) => setState(() => mode = m)),
              ],
              FilledButton.icon(
                onPressed: drawing ? null : draw,
                icon: const Icon(Icons.casino),
                label: Text(drawing ? '抽選中' : '開始抽選'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 特殊抽法：抽中的人是中心點，他自己不算，跟他有關的人被選到
enum PickMode {
  normal('一般', 0),
  cross('大十字', 9),
  nine('九宮格', 8),
  canyon('大峽谷', 10);

  final String label;
  final int fixedCount;
  const PickMode(this.label, this.fixedCount);
}

/// 依特殊抽法算出被選到的座位索引（不含中心點）。座位超出邊界時繞到對面。
List<int> specialPickTargets(List<SeatData> seats, int center, PickMode mode) {
  if (seats.isEmpty || center < 0 || center >= seats.length || mode == PickMode.normal) return [];
  final cols = seats.map((s) => s.row).reduce(max) + 1;
  final rows = seats.map((s) => s.slot).reduce(max) + 1;
  final c = seats[center];
  int? at(int col, int slot) {
    final cc = ((col % cols) + cols) % cols;
    final ss = ((slot % rows) + rows) % rows;
    for (var i = 0; i < seats.length; i++) {
      if (seats[i].row == cc && seats[i].slot == ss) return i;
    }
    return null;
  }

  final out = <int?>{};
  switch (mode) {
    case PickMode.cross:
      for (var col = 0; col < cols; col++) {
        out.add(at(col, c.slot));
      }
      for (var s = 0; s < rows; s++) {
        out.add(at(c.row, s));
      }
    case PickMode.nine:
      for (var dc = -1; dc <= 1; dc++) {
        for (var ds = -1; ds <= 1; ds++) {
          out.add(at(c.row + dc, c.slot + ds));
        }
      }
    case PickMode.canyon:
      for (var s = 0; s < rows; s++) {
        out.add(at(c.row - 1, s));
        out.add(at(c.row + 1, s));
      }
    case PickMode.normal:
      break;
  }
  out.remove(center);
  return out.whereType<int>().toList();
}

/// 特殊抽法選擇列（放在選人數下面）
class PickModeSelector extends StatelessWidget {
  final PickMode value;
  final ValueChanged<PickMode>? onChanged;
  const PickModeSelector({super.key, required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final m in PickMode.values)
          ChoiceChip(
            label: Text(m.label, style: const TextStyle(fontSize: 16)),
            selected: value == m,
            showCheckmark: false,
            side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
            onSelected: onChanged == null ? null : (_) => onChanged!(m),
          ),
      ],
    );
  }
}

/// 選擇要抽幾個人：－ 數字 ＋
class PickCountSelector extends StatelessWidget {
  final int value;
  final int max;
  final bool compact;
  final ValueChanged<int>? onChanged;
  const PickCountSelector({super.key, required this.value, required this.max, this.onChanged, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final side = BorderSide(color: scheme.outline, width: AppTokens.hairline);
    final iconSize = compact ? 20.0 : 28.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.outlined(
          style: IconButton.styleFrom(side: side),
          iconSize: iconSize,
          onPressed: onChanged == null || value <= 1 ? null : () => onChanged!(value - 1),
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: compact ? 72 : 120,
          child: Text(
            compact ? '$value 人' : '$value',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: compact ? 20 : 56, fontWeight: FontWeight.w800, color: scheme.onSurface),
          ),
        ),
        IconButton.outlined(
          style: IconButton.styleFrom(side: side),
          iconSize: iconSize,
          onPressed: onChanged == null || value >= max ? null : () => onChanged!(value + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }
}

/// 從下方往上跳的小圓角視窗外框
Future<T?> showBottomCard<T>(BuildContext context, Widget Function(BuildContext) builder) {
  return showModalBottomSheet<T>(
    context: context,
    backgroundColor: Colors.transparent,
    elevation: 0,
    isScrollControlled: true,
    builder: (sheetContext) {
      final scheme = Theme.of(sheetContext).colorScheme;
      // 點視窗外面的灰色區域就關閉；點視窗本身不會關
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.pop(sheetContext),
        child: SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: GestureDetector(
              onTap: () {},
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.fromLTRB(28, 24, 28, 24),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: scheme.outline, width: AppTokens.hairline),
                ),
                child: builder(sheetContext),
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _PickCountSheet extends StatefulWidget {
  final int max;
  const _PickCountSheet({required this.max});
  @override
  State<_PickCountSheet> createState() => _PickCountSheetState();
}

class _PickCountSheetState extends State<_PickCountSheet> {
  int count = 1;
  PickMode mode = PickMode.normal;
  @override
  Widget build(BuildContext context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('要抽幾個人', style: TextStyle(fontSize: 22)),
          const SizedBox(height: 12),
          PickCountSelector(
            value: mode == PickMode.normal ? count : mode.fixedCount,
            max: widget.max,
            onChanged: mode == PickMode.normal ? (v) => setState(() => count = v) : null,
          ),
          const SizedBox(height: 14),
          PickModeSelector(value: mode, onChanged: (m) => setState(() => mode = m)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, (count, mode)),
              style: FilledButton.styleFrom(textStyle: const TextStyle(fontSize: 22)),
              child: const Text('開始選號'),
            ),
          ),
        ],
      );
}

class DiaryPage extends StatefulWidget {
  final AppState state;
  final bool editable;
  final ValueChanged<DateTime>? onDateChanged;
  const DiaryPage({super.key, required this.state, this.editable = true, this.onDateChanged});
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
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
              IconButton(
                onPressed: () {
                  setState(() => selectedDate = selectedDate.subtract(const Duration(days: 1)));
                  widget.onDateChanged?.call(selectedDate);
                },
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
                onPressed: () {
                  setState(() => selectedDate = selectedDate.add(const Duration(days: 1)));
                  widget.onDateChanged?.call(selectedDate);
                },
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
                          widget.state.deviceRole == 'bigscreen'
                              ? '${index + 1}. ${entries[index].content}'
                              : entries[index].content,
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
  late int selectedDay;

  @override
  void initState() {
    super.initState();
    selectedDay = (DateTime.now().weekday - 1).clamp(0, 4);
  }

  @override
  Widget build(BuildContext context) {
    final maxLesson = widget.state.scheduleEntries.isEmpty
        ? 6
        : widget.state.scheduleEntries.map((e) => e.lesson).reduce((a, b) => a > b ? a : b) + 1;
    final dayEntries = widget.state.scheduleEntries.where((e) => e.weekday == selectedDay).toList()
      ..sort((a, b) => a.lesson.compareTo(b.lesson));
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 720 ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('每週課表', style: TextStyle(fontSize: AppTokens.fontTitle, fontWeight: FontWeight.w800)),
              ),
              if (widget.editable) ...[
                IconButton.outlined(
                  tooltip: '移除最後一節（全週）',
                  onPressed: maxLesson == 0 ? null : () => _removeLesson(maxLesson - 1),
                  icon: const Icon(Icons.remove),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _addLesson(maxLesson),
                  icon: const Icon(Icons.add),
                  label: const Text('全週加一節'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (var day = 0; day < days.length; day++)
                ChoiceChip(
                  label: Text(days[day]),
                  selected: selectedDay == day,
                  selectedColor: scheme.surfaceContainerHighest,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => selectedDay = day),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFFDF5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                days[selectedDay],
                                style: const TextStyle(
                                  fontSize: AppTokens.fontTitle,
                                  fontWeight: FontWeight.w800,
                                  color: AppTokens.ink,
                                ),
                              ),
                              Text(
                                '共 ${dayEntries.length} 節課',
                                style: const TextStyle(fontSize: AppTokens.fontCaption, color: Color(0xFF5A5F75)),
                              ),
                            ],
                          ),
                        ),
                        if (widget.editable) ...[
                          IconButton.outlined(
                            tooltip: '移除${days[selectedDay]}最後一節',
                            onPressed: dayEntries.isEmpty ? null : () => _removeDayLesson(selectedDay),
                            icon: const Icon(Icons.remove),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            onPressed: () => _addDayLesson(selectedDay),
                            icon: const Icon(Icons.add),
                            label: const Text('新增課堂'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  Divider(height: 1, color: scheme.outlineVariant),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      itemCount: maxLesson,
                      itemBuilder: (context, lesson) {
                        final entry = dayEntries.where((item) => item.lesson == lesson).firstOrNull;
                        return _lessonRow(lesson, entry);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _lessonRow(int lesson, ScheduleEntry? entry) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: widget.editable ? () => _editLesson(selectedDay, lesson, entry) : null,
      child: Container(
        constraints: const BoxConstraints(minHeight: 76),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE7E1CF), width: AppTokens.hairline)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 86,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('第 ${lesson + 1} 節',
                      style: const TextStyle(fontSize: AppTokens.fontBody, fontWeight: FontWeight.w700)),
                  Text(
                    entry == null || (entry.startTime.isEmpty && entry.endTime.isEmpty)
                        ? '--:-- ~ --:--'
                        : '${entry.startTime.isEmpty ? '--:--' : entry.startTime} ~ ${entry.endTime.isEmpty ? '--:--' : entry.endTime}',
                    style: const TextStyle(fontSize: AppTokens.fontCaption, color: Color(0xFF5A5F75)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    entry == null || entry.subject.trim().isEmpty ? '點選新增科目' : entry.subject,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppTokens.fontBody,
                      fontWeight: FontWeight.w700,
                      color: entry == null || entry.subject.trim().isEmpty ? scheme.onSurfaceVariant : AppTokens.ink,
                    ),
                  ),
                  if (entry != null && entry.teacher.trim().isNotEmpty)
                    Text(
                      entry.teacher,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: AppTokens.fontCaption, color: Color(0xFF5A5F75)),
                    ),
                ],
              ),
            ),
            if (widget.editable) Icon(Icons.edit_outlined, size: 18, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
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

  Future<void> _editLesson(int day, int lesson, ScheduleEntry? old) async {
    final subject = TextEditingController(text: old?.subject ?? '');
    final teacher = TextEditingController(text: old?.teacher ?? '');
    final start = TextEditingController(text: old?.startTime ?? '08:00');
    final end = TextEditingController(text: old?.endTime ?? '08:50');
    final result = await showBottomCard<ScheduleEntry>(
      context,
      (sheetContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${days[day]}・第 ${lesson + 1} 節',
            style: const TextStyle(fontSize: AppTokens.fontTitle, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          TextField(controller: subject, autofocus: true, decoration: const InputDecoration(labelText: '科目')),
          const SizedBox(height: 10),
          TextField(controller: teacher, decoration: const InputDecoration(labelText: '老師名稱')),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: TextField(controller: start, decoration: const InputDecoration(labelText: '開始時間'))),
              const SizedBox(width: 10),
              Expanded(child: TextField(controller: end, decoration: const InputDecoration(labelText: '結束時間'))),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () => Navigator.pop(
                sheetContext,
                ScheduleEntry(
                  weekday: day,
                  lesson: lesson,
                  subject: subject.text.trim(),
                  teacher: teacher.text.trim(),
                  startTime: start.text.trim(),
                  endTime: end.text.trim(),
                ),
              ),
              child: const Text('儲存課堂'),
            ),
          ),
        ],
      ),
    );
    if (result != null) {
      final list = [...widget.state.scheduleEntries];
      list.removeWhere((e) => e.weekday == day && e.lesson == lesson);
      list.add(result);
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
            startTime: result.startTime,
            endTime: result.endTime,
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
  const AdminPage({
    super.key,
    required this.state,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return BigScreenStyle(textScale: 1.0, child: _page());
  }

  Widget _page() {
    return switch (page) {
      1 => AdminSection(
          key: const ValueKey('students'),
          title: '學生',
          tint: const Color(0xFFEAF3FF),
          tabs: [
            ('名單', () => StudentAdminPage(state: state)),
            ('座位', () => _SeatAdminPage(state: state)),
            ('簽到', () => AttendancePage(state: state)),
            ('照片', () => ClassPhotosPage(state: state)),
          ],
        ),
      2 => AdminSection(
          key: const ValueKey('stamp'),
          title: '蓋章',
          tint: const Color(0xFFFFF0F5),
          tabs: [
            ('加扣章', () => StampPage(state: state)),
            ('紀錄', () => RegistrationRecordsPage(state: state)),
            ('懲罰與獎勵', () => PunishRewardAdminPage(state: state)),
            ('政策', () => PolicyAdminPage(state: state)),
          ],
        ),
      3 => AdminSection(
          key: const ValueKey('lessons'),
          title: '課程',
          tint: const Color(0xFFF1FAFA),
          tabs: [
            ('課表', () => SchedulePage(state: state, editable: true)),
            ('時間', () => TimeManagementPage(state: state)),
            ('聯絡簿', () => DiaryAdminPage(state: state)),
            ('評分', () => RatingRecordsPage(state: state)),
          ],
        ),
      4 => AdminSection(
          key: const ValueKey('screen'),
          title: '大屏',
          tint: const Color(0xFFFFF8D6),
          tabs: [
            ('即時通知', () => TeacherNoticePage(state: state)),
            ('詢問', () => ChatPanel(state: state, from: 'teacher')),
            ('教材', () => MaterialAdminPage(state: state)),
            ('Chrome', () => ChromeAdminPage(state: state)),
          ],
        ),
      5 => AdminSection(
          key: const ValueKey('test'),
          title: '測試',
          tint: const Color(0xFFF4F0FF),
          tabs: [('提醒測試', () => _ReminderTestPage(state: state))],
        ),
      _ => AdminSection(
          key: const ValueKey('overview'),
          title: '總覽',
          tint: null,
          tabs: [('總覽', () => OverviewPage(state: state))],
        ),
    };
  }
}

class _AppInfoSettingsPage extends StatefulWidget {
  final AppState state;
  final bool showTitle;

  const _AppInfoSettingsPage({
    required this.state,
    this.showTitle = true,
  });

  @override
  State<_AppInfoSettingsPage> createState() => _AppInfoSettingsPageState();
}

class _AppInfoSettingsPageState extends State<_AppInfoSettingsPage> {
  final _classIdController = TextEditingController();
  final _bigScreenPinController = TextEditingController();
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
    _bigScreenPinController.dispose();
    _officerPinController.dispose();
    super.dispose();
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = '${packageInfo.version}+${packageInfo.buildNumber}');
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

  final _officerPinController = TextEditingController();

  Future<void> _saveOfficerPin() async {
    final pin = _officerPinController.text;
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('PIN 碼必須是 4 至 8 位數字')));
      return;
    }
    await widget.state.setOfficerPin(pin);
    _officerPinController.clear();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('管理者 PIN 碼已儲存')));
  }

  Future<void> _saveBigScreenExitPin() async {
    final pin = _bigScreenPinController.text;
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN 碼必須是 4 至 8 位數字')),
      );
      return;
    }
    await widget.state.setBigScreenExitPin(pin);
    _bigScreenPinController.clear();
    if (!mounted) return;
    final canSync = widget.state.cloudSyncEnabled && widget.state.classId.trim().isNotEmpty;
    final cloudError = widget.state.cloudSyncError;
    final message = !canSync
        ? 'PIN 碼已儲存在本機；設定班級代碼並啟用雲端同步後，其他裝置才能使用'
        : cloudError == null
            ? '教師與大屏共用 PIN 碼已儲存並同步'
            : 'PIN 碼已儲存在本機，但雲端同步失敗：$cloudError';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;

    return ListView(
      padding: EdgeInsets.fromLTRB(16, 20, 16, compact ? 24 : 32),
      children: [
        if (widget.showTitle) ...[
          const Text(
            '資訊與設定',
            style: TextStyle(fontSize: AppTokens.fontTitle, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 18),
        ],
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
                if (!kIsWeb && Platform.isWindows)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final msg = await checkWindowsUpdate(manual: true);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                          }
                        },
                        icon: const Icon(Icons.system_update_alt),
                        label: const Text('檢查更新'),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                const _InfoRow(label: '製作人', value: '張以樂'),
                const SizedBox(height: 8),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('深色模式'),
                  value: widget.state.darkMode,
                  onChanged: widget.state.setDarkMode,
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
                const Text('班級設定', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
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
                const Text('教師與大屏共用 PIN 碼', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  widget.state.bigScreenExitPinLength == null
                      ? '尚未設定'
                      : '已設定 ${widget.state.bigScreenExitPinLength} 位數 PIN 碼',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _bigScreenPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: 'PIN 碼',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saveBigScreenExitPin,
                    icon: const Icon(Icons.lock_outline),
                    label: const Text('儲存 PIN 碼'),
                  ),
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
                const Text('管理者 PIN 碼', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  widget.state.officerPinLength == null ? '尚未設定' : '已設定 ${widget.state.officerPinLength} 位數 PIN 碼',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _officerPinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  maxLength: 8,
                  decoration: const InputDecoration(
                    labelText: '管理者 PIN 碼',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton.icon(
                    onPressed: _saveOfficerPin,
                    icon: const Icon(Icons.badge_outlined),
                    label: const Text('儲存管理者 PIN 碼'),
                  ),
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
                const Text('聯絡簿文字大小', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(
                  '${(widget.state.diaryTextScale * 100).round()}%・一頁約 '
                  '${(6 / widget.state.diaryTextScale).round().clamp(3, 12)} 行',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                Slider(
                  value: widget.state.diaryTextScale,
                  min: 0.5,
                  max: 1.5,
                  divisions: 10,
                  label: '${(widget.state.diaryTextScale * 100).round()}%',
                  onChanged: (v) => setState(() => widget.state.setDiaryTextScale(v)),
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
              OutlinedButton.icon(
                onPressed: () => state.rotateSeats(-1),
                icon: const Icon(Icons.arrow_back),
                label: const Text('每排桌子向左挪'),
              ),
              OutlinedButton.icon(
                onPressed: () => state.rotateSeats(1),
                icon: const Icon(Icons.arrow_forward),
                label: const Text('每排桌子向右挪'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // 座位管理只能拖曳換位；新增、刪除、編輯同學都在「學生」分頁
          Expanded(child: _SeatRows(state: state, editable: false, draggable: true)),
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
            style: TextStyle(fontSize: AppTokens.fontTitle, fontWeight: FontWeight.w800),
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
    final period = testNow == null ? null : widget.state.periodAt(testNow);
    // 預覽畫面縮到剛好放得進頁面高度，不用往下捲（16:9）
    final previewMaxW = ((MediaQuery.sizeOf(context).height - 500) * 16 / 9).clamp(360.0, 1600.0);
    return ListView(
        // padding 放在 ListView 裡面，輸入框上方浮起來的標籤才不會被切掉
        padding: EdgeInsets.fromLTRB(isMobile ? 12 : 28, isMobile ? 20 : 30, isMobile ? 12 : 28, isMobile ? 12 : 28),
        children: [
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
            const SizedBox(height: 6),
            Text(
              period == null
                  ? '這個時間沒有特殊顯示'
                  : '特殊顯示：${period.text}　黃色按鈕：${TimePeriod.actions[period.action]?.$1 ?? '最小化（開始上課）'}',
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            // 用測試時間直接顯示大屏首頁（跟大屏看到的一樣）
            Center(
              child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: previewMaxW),
              child: AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(context).colorScheme.outline, width: AppTokens.hairline),
                ),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 1920,
                    height: 1080,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: IgnorePointer(
                            child: ColoredBox(
                              color: Theme.of(context).colorScheme.surfaceContainer,
                              child: Padding(
                                padding: const EdgeInsets.only(top: 70),
                                child: AnimatedBuilder(
                                  animation: widget.state,
                                  builder: (_, __) => BigScreenHomePage(state: widget.state),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // 測試時間剛好是下課時間時，預覽裡也會跳出教師評分
                        Positioned.fill(child: LessonRatingWatcher(state: widget.state)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ),
            ),
          ],
        ],
    );
  }
}

/// 大屏首頁：左邊座位表，右邊時間、目前課程與快捷按鈕。
class BigScreenHomePage extends StatefulWidget {
  final AppState state;
  const BigScreenHomePage({super.key, required this.state});

  @override
  State<BigScreenHomePage> createState() => _BigScreenHomePageState();
}

class _BigScreenHomePageState extends State<BigScreenHomePage> {
  Timer? _timer;
  final _random = Random();
  Set<int> _picked = {};
  bool _picking = false;

  /// 首頁選號：下方跳出小視窗選人數，動畫在座位表上亂跳
  Future<void> _startPick() async {
    if (_picking) return;
    final seats = widget.state.seats;
    final candidates = [
      for (var i = 0; i < seats.length; i++)
        if (seats[i].name.trim().isNotEmpty) i
    ];
    if (candidates.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請先在座位表填入同學姓名')));
      return;
    }
    final choice = await showBottomCard<(int, PickMode)>(context, (_) => _PickCountSheet(max: candidates.length));
    if (choice == null || !mounted) return;
    final (count, mode) = choice;
    // 特殊抽法：先抽一個中心點，被選到的是他周圍的人
    final center = candidates[_random.nextInt(candidates.length)];
    final special = specialPickTargets(seats, center, mode).toSet();
    final n = mode == PickMode.normal ? (count < candidates.length ? count : candidates.length) : 1;
    Set<int> sample() => ([...candidates]..shuffle(_random)).take(n).toSet();
    final winners = mode == PickMode.normal ? sample() : special;
    setState(() => _picking = true);
    const durations = [60, 60, 70, 80, 95, 115, 140, 170, 210, 260, 320];
    for (final ms in durations) {
      if (!mounted) return;
      setState(() => _picked = sample());
      await Future<void>.delayed(Duration(milliseconds: ms));
    }
    if (!mounted) return;
    if (mode != PickMode.normal) {
      // 先亮中心點一下，再換成被連累的人
      setState(() => _picked = {center});
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
    }
    setState(() {
      _picked = winners;
      _picking = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _two(int v) => v.toString().padLeft(2, '0');

  int _minutes(String time) {
    final parts = time.split(':');
    if (parts.length < 2) return -1;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  /// 回傳（主標題, 副標題）：上課中顯示這節課，下課顯示下一節。
  /// 大屏大字：蓋過上課的特殊顯示 → 課表上課 → 特殊顯示 → 課與課之間自動「下課」 → 放學
  String _buttonAction(DateTime now) {
    final state = widget.state;
    final nowMin = now.hour * 60 + now.minute;
    for (final e in state.scheduleEntries.where((e) => e.weekday == now.weekday - 1)) {
      final s = _minutes(e.startTime), en = _minutes(e.endTime);
      if (s >= 0 && en >= 0 && nowMin >= s && nowMin < en) return 'minimize';
    }
    return state.periodAt(now)?.action ?? 'minimize';
  }

  void _runButtonAction(String action) {
    final state = widget.state;
    switch (action) {
      case 'attendance':
        showPageDialog(context, '簽到', BigScreenAttendancePage(state: state));
      case 'stamp':
        openStampWithOfficerPin(context, state);
      case 'diary':
        showDiaryBook(context, state);
      case 'schedule':
        showPageDialog(context, '課表', BigScreenTimetable(state: state));
      case 'pick':
        _startPick();
      default:
        // 最小化，露出藏在後面的電子書和 Chrome
        if (isDesktopPlatform) windowManager.minimize();
    }
  }

  (String, String) _lessonText(DateTime now) {
    final state = widget.state;
    final nowMin = now.hour * 60 + now.minute;
    final forced = state.periodAt(now, overrideOnly: true);
    if (forced != null) return (forced.text, '');
    final lessons = state.scheduleEntries.where((e) => e.weekday == now.weekday - 1).toList()
      ..sort((a, b) => a.lesson.compareTo(b.lesson));
    String name(ScheduleEntry e) => e.subject.isEmpty ? '自習' : '${e.subject}課';
    var firstStart = -1;
    var lastEnd = -1;
    for (final e in lessons) {
      final start = _minutes(e.startTime);
      final end = _minutes(e.endTime);
      if (start < 0 || end < 0) continue;
      if (firstStart < 0 || start < firstStart) firstStart = start;
      if (end > lastEnd) lastEnd = end;
      if (nowMin >= start && nowMin < end) return (name(e), '第 ${e.lesson + 1} 節・${e.endTime} 下課');
    }
    final period = state.periodAt(now);
    if (period != null) return (period.text, '');
    if (firstStart >= 0 && nowMin >= firstStart && nowMin < lastEnd) return ('下課', '');
    return (lessons.isEmpty ? '今天沒有課' : '放學了', '');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = widget.state.reminderNow;
    final (lessonTitle, lessonSub) = _lessonText(now);

    final seats = Column(
      children: [
        Expanded(child: BigScreenSeatGrid(state: widget.state, highlight: _picked)),
        // 按鈕出現時：座位表平滑往上縮，按鈕彈出來
        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack, reverseCurve: Curves.easeIn),
                child: child,
              ),
            ),
            child: _picked.isNotEmpty && !_picking
                ? Padding(
                    key: const ValueKey('clear-pick'),
                    padding: const EdgeInsets.only(top: 14),
                    child: OutlinedButton.icon(
                      onPressed: () => setState(() => _picked = {}),
                      icon: const Icon(Icons.close),
                      label: const Text('取消選取', style: TextStyle(fontSize: 20)),
                    ),
                  )
                : const SizedBox(key: ValueKey('no-clear'), width: double.infinity),
          ),
        ),
      ],
    );

    final clock = FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        '${_two(now.hour)} : ${_two(now.minute)}',
        style: TextStyle(fontSize: 150, fontWeight: FontWeight.w500, height: 1, color: scheme.onSurface),
      ),
    );

    final lesson = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(lessonTitle, style: TextStyle(fontSize: 96, height: 1.1, color: scheme.onSurface)),
        ),
        if (lessonSub.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(lessonSub, style: TextStyle(fontSize: 20, color: scheme.onSurfaceVariant)),
          ),
      ],
    );

    // 黃色按鈕：上課中固定是「開始上課（最小化）」；其他時間看時間管理裡這段時間設定的動作
    final action = _buttonAction(now);
    final buttonText = TimePeriod.actions[action]?.$2 ?? '開始上課';
    final startButton = action == 'none'
        ? const SizedBox.shrink()
        : SizedBox(
      width: 420,
      height: 110,
      child: FilledButton(
        onPressed: action == 'minimize' && !isDesktopPlatform ? null : () => _runButtonAction(action),
        style: FilledButton.styleFrom(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
          side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
          textStyle: const TextStyle(fontSize: 34),
        ),
        child: Text(buttonText),
      ),
    );

    Widget roundButton(Object icon, String label, Widget Function()? page, {VoidCallback? onTap}) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: scheme.surfaceContainerHighest,
              shape: CircleBorder(side: BorderSide(color: scheme.outline, width: AppTokens.hairline)),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap ?? () => showPageDialog(context, label, page!()),
                child: SizedBox(
                  width: 120,
                  height: 120,
                  child: Center(
                      child: icon is String
                          ? AppIcon(icon, size: 52, color: scheme.onSurface)
                          : Icon(icon as IconData, size: 52, color: scheme.onSurface)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(label, style: TextStyle(fontSize: 26, color: scheme.onSurface)),
          ],
        );

    final shortcuts = Wrap(
      spacing: 36,
      runSpacing: 20,
      alignment: WrapAlignment.center,
      children: [
        roundButton(AppIcons.dice, '選號機', null, onTap: _startPick),
        roundButton(AppIcons.calendar, '課表', () => BigScreenTimetable(state: widget.state)),
        roundButton(AppIcons.book, '聯絡簿', null, onTap: () => showDiaryBook(context, widget.state)),
        roundButton(AppIcons.dashboard, '其他', null,
            onTap: () => showBottomCard<void>(context, (_) => BigScreenOtherMenu(state: widget.state))),
      ],
    );

    return ColoredBox(
      color: scheme.surfaceContainer,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 900) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                clock,
                const SizedBox(height: 8),
                lesson,
                const SizedBox(height: 20),
                Center(child: startButton),
                const SizedBox(height: 24),
                SizedBox(height: 520, child: seats),
                const SizedBox(height: 24),
                shortcuts,
              ],
            );
          }
          return Padding(
            padding: const EdgeInsets.fromLTRB(40, 22, 40, 32),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(flex: 11, child: seats),
                const SizedBox(width: 40),
                Expanded(
                  flex: 10,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: 760,
                      height: 1000,
                      child: Column(
                        children: [
                          const Spacer(flex: 3),
                          clock,
                          const SizedBox(height: 56),
                          lesson,
                          const SizedBox(height: 72),
                          startButton,
                          const Spacer(flex: 2),
                          shortcuts,
                          const SizedBox(height: 90),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// 大屏座位表：講台在上，每格顯示座號與姓名，點擊看詳細資料。
class BigScreenSeatGrid extends StatelessWidget {
  final AppState state;
  final Set<int> highlight;
  const BigScreenSeatGrid({super.key, required this.state, this.highlight = const {}});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final seats = state.seats;
    final cols = seats.isEmpty ? 6 : seats.map((s) => s.row).reduce((a, b) => a > b ? a : b) + 1;
    final rows = seats.isEmpty ? 5 : seats.map((s) => s.slot).reduce((a, b) => a > b ? a : b) + 1;

    int? indexAt(int col, int slot) {
      for (var i = 0; i < seats.length; i++) {
        if (seats[i].row == col && seats[i].slot == slot) return i;
      }
      return null;
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
            ),
            child: LayoutBuilder(
              builder: (context, box) {
                const gap = 14.0;
                const podiumHeight = 44.0;
                final cellW = (box.maxWidth - gap * (cols - 1)) / cols;
                final cellH = (box.maxHeight - podiumHeight - gap - gap * (rows - 1)) / rows;
                final cell = (cellW < cellH ? cellW : cellH).clamp(12.0, 400.0);
                final gridW = cell * cols + gap * (cols - 1);
                return Column(
                  children: [
                    Container(
                      width: gridW * 0.5,
                      height: podiumHeight,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF353456) : AppTokens.ink,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: scheme.outline, width: AppTokens.hairline),
                      ),
                      child: const Text('講台', style: TextStyle(fontSize: 18, color: Color(0xFFFFFFFE))),
                    ),
                    const SizedBox(height: gap),
                    Expanded(
                      child: Center(
                        child: SizedBox(
                          width: gridW,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              for (var slot = 0; slot < rows; slot++) ...[
                                if (slot > 0) const SizedBox(height: gap),
                                Row(
                                  children: [
                                    for (var col = 0; col < cols; col++) ...[
                                      if (col > 0) const SizedBox(width: gap),
                                      _seatCell(context, indexAt(col, slot), cell, scheme, isDark),
                                    ],
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _seatCell(BuildContext context, int? index, double size, ColorScheme scheme, bool isDark) {
    final radius = BorderRadius.circular(size * 0.32);
    if (index == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: radius,
          border: Border.all(color: scheme.outlineVariant, width: 1.5),
        ),
      );
    }
    final seat = state.seats[index];
    final picked = highlight.contains(index);
    final color = picked
        ? scheme.primary
        : seat.gender == '男'
            ? AppTokens.seatBoy(isDark)
            : seat.gender == '女'
                ? AppTokens.seatGirl(isDark)
                : scheme.surfaceContainerLowest;
    final cell = Material(
      color: color,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outline, width: picked ? 3 : AppTokens.hairline),
      ),
      child: InkWell(
        borderRadius: radius,
        onTap: () => _showSeatProfile(context, state, index, seat),
        child: SizedBox(
          width: size,
          height: size,
          child: Padding(
            padding: EdgeInsets.all(size * 0.08),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(seat.number, style: TextStyle(fontSize: 34, height: 1.1, color: scheme.onSurface)),
                  if (seat.name.isNotEmpty)
                    Text(seat.name, style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // 頭像暫時只放在詳細資料卡片，座位格不顯示
    return cell;
  }
}

/// 大屏各頁的索引（上方圖示列的順序）。
class BigScreenPages {
  BigScreenPages._();
  static const home = 0;
  static const registration = 1;
  static const lottery = 2;
  static const reminders = 3;
  static const seats = 4;
  static const schedule = 5;
  static const diary = 6;
}

/// 大屏頂端列：左邊返回、中間功能圖示、右邊留給視窗按鈕。
class BigScreenTopBar extends StatelessWidget {
  final List<Object> icons;
  final List<String> labels;
  final int current;
  final ValueChanged<int> onSelect;
  final VoidCallback onBack;
  final String? backTooltip;
  final bool showLabels;
  final bool showWindowControls;
  final bool showBackButton;
  final bool showSettingsButton;
  final VoidCallback? onOpenSettings;
  /// 有給的話，頂端列中間會出現「輸入框＋展示」，把文字投放到大屏
  final ValueChanged<String>? onProject;
  /// 放在設定按鈕左邊的通知鈴鐺
  final Widget? notificationButton;
  const BigScreenTopBar({
    super.key,
    required this.icons,
    required this.labels,
    required this.current,
    required this.onSelect,
    required this.onBack,
    this.backTooltip,
    this.showLabels = false,
    this.showWindowControls = true,
    this.showBackButton = true,
    this.showSettingsButton = true,
    this.onOpenSettings,
    this.onProject,
    this.notificationButton,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      onPanStart: isDesktopPlatform ? (_) => windowManager.startDragging() : null,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
          border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (showBackButton)
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: backTooltip ?? (current == BigScreenPages.home ? '退出大屏' : '回首頁'),
                  onPressed: onBack,
                  icon: AppIcon(AppIcons.chevronLeft, size: AppIcons.topBarSize, color: scheme.onSurface),
                ),
              ),
            if (showWindowControls || showSettingsButton)
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (notificationButton != null) notificationButton!,
                    if (showSettingsButton)
                      IconButton(
                        tooltip: '資訊與設定',
                        onPressed: onOpenSettings,
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    if (showWindowControls) const AppWindowControls(),
                  ],
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(
                  horizontal: (isDesktopPlatform ? (showSettingsButton ? 230 : 180) : 56) +
                      (notificationButton != null ? 48 : 0)),
              child: Center(
                child: onProject != null
                    ? _ProjectInput(onProject: onProject!)
                    : LayoutBuilder(builder: (context, box) {
                  // 頁面太多擠不下時，自動只顯示圖示（滑鼠移上去會顯示名稱），每一頁都看得到
                  final showLabels = this.showLabels && box.maxWidth >= icons.length * 132;
                  return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < icons.length; i++)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Tooltip(
                            message: labels[i],
                            child: Material(
                              color: current == i ? scheme.surfaceContainerHigh : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () => onSelect(i),
                                child: Container(
                                  height: 44,
                                  constraints: const BoxConstraints(minWidth: 48),
                                  padding: EdgeInsets.symmetric(horizontal: showLabels ? 12 : 0),
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      navIcon(icons[i],
                                          size: showLabels ? 22 : AppIcons.topBarSize, color: scheme.onSurface),
                                      if (showLabels) ...[
                                        const SizedBox(width: 8),
                                        Text(
                                          labels[i],
                                          style: TextStyle(
                                            fontSize: AppTokens.fontBody,
                                            color: scheme.onSurface,
                                            fontWeight: current == i ? FontWeight.w800 : FontWeight.normal,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                );
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 自動收合的頂端列：滑鼠離開 1 秒後往上收，只露出一小條；
/// 滑鼠移上去（或觸控點一下露出的那條）就展開。
class AutoHideBar extends StatefulWidget {
  final Widget child;
  final double height;
  final double peek;
  const AutoHideBar({super.key, required this.child, this.height = 60, this.peek = 10});

  @override
  State<AutoHideBar> createState() => _AutoHideBarState();
}

class _AutoHideBarState extends State<AutoHideBar> {
  static const _delay = Duration(seconds: 1);
  bool _expanded = true;
  bool _hovering = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _scheduleHide() {
    _timer?.cancel();
    _timer = Timer(_delay, () {
      if (!mounted) return;
      // 正在頂端列的輸入框打字時不要收起來，等打完再收
      final focused = FocusManager.instance.primaryFocus?.context?.findAncestorStateOfType<_AutoHideBarState>() == this;
      if (focused) {
        _scheduleHide();
        return;
      }
      if (!_hovering) setState(() => _expanded = false);
    });
  }

  void _expand() {
    if (!_expanded) setState(() => _expanded = true);
    _scheduleHide();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      top: _expanded ? 0 : -(widget.height - widget.peek),
      left: 0,
      right: 0,
      height: widget.height,
      child: MouseRegion(
        onEnter: (_) {
          _hovering = true;
          _expand();
        },
        onExit: (_) {
          _hovering = false;
          _scheduleHide();
        },
        child: Listener(
          // 展開狀態下任何點擊都重新計時
          onPointerDown: (_) => _expand(),
          behavior: HitTestBehavior.translucent,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(ignoring: !_expanded, child: widget.child),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 把整個頁面放進視窗裡打開（大屏首頁的快捷按鈕用）。
Future<void> showPageDialog(BuildContext context, String title, Widget page) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      final size = MediaQuery.sizeOf(dialogContext);
      return Dialog(
        insetPadding: const EdgeInsets.all(24),
        clipBehavior: Clip.antiAlias,
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
          side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
        ),
        child: SizedBox(
          width: (size.width * 0.86).clamp(320.0, 1400.0),
          height: (size.height * 0.86).clamp(320.0, 900.0),
          child: Column(
            children: [
              Container(
                height: 60,
                padding: const EdgeInsets.only(left: 24, right: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: scheme.outlineVariant, width: AppTokens.hairline)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title, style: TextStyle(fontSize: 22, color: scheme.onSurface)),
                    ),
                    IconButton(
                      tooltip: '關閉',
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: AppIcon(AppIcons.close, size: AppIcons.topBarSize, color: scheme.onSurface),
                    ),
                  ],
                ),
              ),
              Expanded(child: BigScreenStyle(child: page)),
            ],
          ),
        ),
      );
    },
  );
}

/// 大屏風格：字放大一點、卡片改大圓角＋黑色細框，跟大屏首頁一致。
class BigScreenStyle extends StatelessWidget {
  final Widget child;
  final double textScale;
  const BigScreenStyle({super.key, required this.child, this.textScale = 1.15});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final scheme = base.colorScheme;
    final outlineSide = BorderSide(color: scheme.outline, width: AppTokens.hairline);
    final mq = MediaQuery.of(context);
    return MediaQuery(
      data: mq.copyWith(textScaler: TextScaler.linear(textScale)),
      child: Theme(
        data: base.copyWith(
          cardTheme: base.cardTheme.copyWith(
            color: scheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24), side: outlineSide),
          ),
          chipTheme: base.chipTheme.copyWith(side: outlineSide),
          segmentedButtonTheme: SegmentedButtonThemeData(
            style: (base.segmentedButtonTheme.style ?? const ButtonStyle()).copyWith(
              side: WidgetStatePropertyAll(outlineSide),
              shape: const WidgetStatePropertyAll(
                RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(18))),
              ),
              padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 20, vertical: 14)),
            ),
          ),
        ),
        child: child,
      ),
    );
  }
}

/// 大屏各頁的外框：淺青背景＋與首頁相同的邊距＋白色大圓角面板。
class BigScreenPageFrame extends StatelessWidget {
  final Widget child;
  final bool panel;
  const BigScreenPageFrame({super.key, required this.child, this.panel = true});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width < 900;
    final content = BigScreenStyle(child: child);
    return ColoredBox(
      color: scheme.surfaceContainer,
      child: Padding(
        padding: narrow ? const EdgeInsets.fromLTRB(12, 12, 12, 16) : const EdgeInsets.fromLTRB(40, 22, 40, 32),
        child: panel
            ? Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(36),
                  border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
                ),
                child: Padding(padding: const EdgeInsets.all(12), child: content),
              )
            : content,
      ),
    );
  }
}

/// 選擇蓋章／扣章的理由（必填），可加證人。回傳寫進紀錄的文字。
Future<String?> _askStampReason(BuildContext context, bool add) async {
  final presets =
      add ? const ['準時完成作業', '確實完成幹部職責', '打掃確實', '幫助同學', '小老師認證'] : const ['秩序不佳', '未交作業', '打掃不確實', '擅自使用大屏', '上課講話'];
  String? reason;
  final custom = TextEditingController();
  final witness = TextEditingController();
  final result = await showDialog<String>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        final text = custom.text.trim().isNotEmpty ? custom.text.trim() : reason;
        return AlertDialog(
          title: Text(add ? '蓋章理由' : '扣章理由'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final p in presets)
                      ChoiceChip(
                        label: Text(p),
                        selected: reason == p && custom.text.trim().isEmpty,
                        showCheckmark: false,
                        onSelected: (_) => setState(() {
                          reason = p;
                          custom.clear();
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: custom,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: '其他理由（自己輸入）'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: witness,
                  decoration: const InputDecoration(labelText: '證人（額外加扣章時填）'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            FilledButton(
              onPressed: text == null || text.isEmpty
                  ? null
                  : () {
                      final w = witness.text.trim();
                      Navigator.pop(dialogContext, w.isEmpty ? text : '$text（證人：$w）');
                    },
              child: Text(add ? '確定蓋章' : '確定扣章'),
            ),
          ],
        );
      },
    ),
  );
  custom.dispose();
  witness.dispose();
  return result;
}

/// 教師後台：時間管理。
/// 上課時段直接讀課表（唯讀）；這裡只管「特殊顯示」：早自習、午休、打掃、放學等非上課時段。
/// 課與課之間沒被特殊顯示蓋到的空檔，大屏會自動顯示「下課」。
class TimeManagementPage extends StatefulWidget {
  final AppState state;
  const TimeManagementPage({super.key, required this.state});

  @override
  State<TimeManagementPage> createState() => _TimeManagementPageState();
}

class _TimeManagementPageState extends State<TimeManagementPage> {
  late List<_PeriodRow> rows;
  Timer? _saveTimer;

  List<_PeriodRow> _fromState() =>
      [for (final p in widget.state.timePeriods) _PeriodRow(p.start, p.end, p.text, p.action)];

  @override
  void initState() {
    super.initState();
    rows = _fromState();
    var changed = false;
    // 還沒有任何時段時，自動加入預設時間
    if (rows.isEmpty) {
      rows = [for (final p in TimePeriod.defaults()) _PeriodRow(p.start, p.end, p.text, p.action)];
      changed = true;
    }
    // 下課時間也列進來：課表裡兩節課中間的空檔，還沒有被任何時段蓋到的就自動加一段「下課」
    if (_addBreaks()) changed = true;
    if (changed) {
      rows.sort((a, b) => _min(a.start.text).compareTo(_min(b.start.text)));
      _save();
    }
  }

  int _min(String v) {
    final parts = v.trim().split(':');
    if (parts.length < 2) return -1;
    return (int.tryParse(parts[0]) ?? 0) * 60 + (int.tryParse(parts[1]) ?? 0);
  }

  bool _addBreaks() {
    // 每一節課的時間（取課表裡第一個有填時間的）
    final slots = <int, (String, String)>{};
    for (final e in widget.state.scheduleEntries) {
      if (_min(e.startTime) < 0 || _min(e.endTime) < 0) continue;
      slots.putIfAbsent(e.lesson, () => (e.startTime, e.endTime));
    }
    final order = slots.keys.toList()..sort();
    var added = false;
    for (var i = 0; i + 1 < order.length; i++) {
      final end = slots[order[i]]!.$2;
      final next = slots[order[i + 1]]!.$1;
      final s = _min(end), n = _min(next);
      if (n <= s) continue;
      final covered = rows.any((r) => _min(r.start.text) < n && _min(r.end.text) > s);
      if (covered) continue;
      rows.add(_PeriodRow(end, next, '下課', 'minimize'));
      added = true;
    }
    return added;
  }

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _save();
    }
    for (final r in rows) {
      r.dispose();
    }
    super.dispose();
  }

  bool _validTime(String v) => RegExp(r'^([01]?\d|2[0-3]):[0-5]\d$').hasMatch(v.trim());

  /// 有改動就自動儲存（停止輸入 0.8 秒後）
  void _changed() {
    setState(() {});
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _save);
  }

  /// 只存填寫完整的時段；還沒填完的那一列先不存，填好就會自動存進去
  Future<void> _save() async {
    String pad(String v) {
      final parts = v.trim().split(':');
      return '${parts[0].padLeft(2, '0')}:${parts[1]}';
    }

    await widget.state.saveTimePeriods([
      for (final r in rows)
        if (_validTime(r.start.text) && _validTime(r.end.text) && r.text.text.trim().isNotEmpty)
          TimePeriod(
            start: pad(r.start.text),
            end: pad(r.end.text),
            text: r.text.text.trim(),
            action: r.action,
          ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final now = widget.state.reminderNow;
    final todayLessons = widget.state.scheduleEntries.where((e) => e.weekday == now.weekday - 1).toList()
      ..sort((a, b) => a.lesson.compareTo(b.lesson));
    final caption = TextStyle(fontSize: AppTokens.fontCaption, color: scheme.onSurfaceVariant);
    return ListView(
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 16, isMobile ? 12 : 24, isMobile ? 12 : 24),
      children: [
        // 上課（唯讀）
        Text('今天的上課時間', style: caption),
        const SizedBox(height: 8),
        if (todayLessons.isEmpty)
          Text('今天課表沒有排課', style: TextStyle(color: scheme.onSurfaceVariant))
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final l in todayLessons)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
                  ),
                  child: Text('第 ${l.lesson + 1} 節　${l.startTime}–${l.endTime}　${l.subject}'),
                ),
            ],
          ),
        const SizedBox(height: 24),
        // 特殊顯示（可編輯）
        Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('特殊顯示', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: () => setState(() => rows.add(_PeriodRow('', '', '', 'minimize'))),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('新增時段'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text('還沒有特殊顯示', style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          ),
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                SizedBox(width: 28, child: Text('${i + 1}', style: TextStyle(color: scheme.onSurfaceVariant))),
                _timeField(rows[i].start, '開始'),
                const Padding(padding: EdgeInsets.symmetric(horizontal: 6), child: Text('–')),
                _timeField(rows[i].end, '結束'),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: rows[i].text,
                    onChanged: (_) => _changed(),
                    decoration: const InputDecoration(hintText: '大屏顯示文字', isDense: true),
                  ),
                ),
                const SizedBox(width: 8),
                // 這段時間大屏黃色按鈕的動作
                SizedBox(
                  width: isMobile ? 130 : 190,
                  child: DropdownButtonFormField<String>(
                    value: TimePeriod.actions.containsKey(rows[i].action) ? rows[i].action : 'minimize',
                    isDense: true,
                    isExpanded: true,
                    decoration: const InputDecoration(isDense: true, labelText: '黃色按鈕'),
                    items: [
                      for (final a in TimePeriod.actions.entries)
                        DropdownMenuItem(value: a.key, child: Text(a.value.$1, overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (v) {
                      rows[i].action = v ?? 'minimize';
                      _changed();
                    },
                  ),
                ),
                IconButton(
                  tooltip: '刪除這個時段',
                  onPressed: () {
                    rows.removeAt(i).dispose();
                    _changed();
                  },
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _timeField(TextEditingController c, String hint) => SizedBox(
        width: 92,
        child: TextField(
          controller: c,
          onChanged: (_) => _changed(),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            errorText: c.text.isEmpty || _validTime(c.text) ? null : '格式',
          ),
        ),
      );
}

class _PeriodRow {
  final TextEditingController start;
  final TextEditingController end;
  final TextEditingController text;
  String action;
  _PeriodRow(String s, String e, String t, this.action)
      : start = TextEditingController(text: s),
        end = TextEditingController(text: e),
        text = TextEditingController(text: t);

  void dispose() {
    start.dispose();
    end.dispose();
    text.dispose();
  }
}

/// 蓋章頁（取代原本的登記）：點同學可以多選，再按蓋章或扣章，選一個理由，每人各 ±1 章。
class StampPage extends StatefulWidget {
  final AppState state;
  const StampPage({super.key, required this.state});

  @override
  State<StampPage> createState() => _StampPageState();
}

class _StampPageState extends State<StampPage> {
  final Set<int> selected = {};
  bool busy = false;

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _apply(int delta) async {
    if (selected.isEmpty || busy) return;
    // 理由已經寫在登記表了，這裡直接蓋章／扣章
    setState(() => busy = true);
    final state = widget.state;
    final targets = selected.toList();
    for (final i in targets) {
      if (i >= state.seats.length) continue;
      await state.addStudentRecord(student: state.seats[i], type: delta > 0 ? '蓋章' : '扣章');
      await state.adjustSeatScore(i, delta);
    }
    if (state.deviceRole == 'bigscreen') {
      final names = [for (final i in targets) if (i < state.seats.length) state.seats[i].name].join('、');
      unawaited(state.postEvent('teacher', '大屏${delta > 0 ? '蓋章' : '扣章'}（${targets.length} 人）', names));
    }
    if (!mounted) return;
    setState(() {
      busy = false;
      selected.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('已幫 ${targets.length} 位同學${delta > 0 ? '蓋章' : '扣章'}')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final scheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        // 照座號順序排列
        int seatNo(int i) => int.tryParse(state.seats[i].number.replaceAll(RegExp(r'[^0-9]'), '')) ?? 9999;
        final indexes = [
          for (var i = 0; i < state.seats.length; i++)
            if (state.seats[i].name.trim().isNotEmpty) i,
        ]..sort((a, b) => seatNo(a).compareTo(seatNo(b)));
        int totalCount(String number, String type) =>
            state.studentRecords.where((r) => r.studentNumber == number && r.type == type).length;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(selected.isEmpty ? '點同學來選擇（可以多選）' : '已選 ${selected.length} 人',
                      style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant)),
                  TextButton(
                    onPressed: () => setState(() {
                      if (selected.length == indexes.length) {
                        selected.clear();
                      } else {
                        selected
                          ..clear()
                          ..addAll(indexes);
                      }
                    }),
                    child: Text(selected.length == indexes.length && indexes.isNotEmpty ? '取消全選' : '全選'),
                  ),
                  FilledButton.icon(
                    onPressed: selected.isEmpty || busy ? null : () => _apply(1),
                    icon: const Icon(Icons.approval_outlined),
                    label: const Text('蓋章', style: TextStyle(fontSize: 18)),
                  ),
                  OutlinedButton.icon(
                    onPressed: selected.isEmpty || busy ? null : () => _apply(-1),
                    icon: const Icon(Icons.remove),
                    label: const Text('扣章', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: indexes.isEmpty
                    ? Center(child: Text('請先在座位表填入同學姓名', style: TextStyle(color: scheme.onSurfaceVariant)))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 170,
                          mainAxisExtent: 118,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                        itemCount: indexes.length,
                        itemBuilder: (_, k) {
                          final i = indexes[k];
                          final seat = state.seats[i];
                          final on = selected.contains(i);
                          // 扣章是累積計算（不是只算本週），滿 5 個就要懲罰
                          final minus = totalCount(seat.number, '扣章');
                          final color = on
                              ? scheme.primary
                              : seat.gender == '男'
                                  ? AppTokens.seatBoy(isDark)
                                  : seat.gender == '女'
                                      ? AppTokens.seatGirl(isDark)
                                      : scheme.surfaceContainerLow;
                          return Material(
                            color: color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                              side: BorderSide(color: scheme.outline, width: on ? 3 : AppTokens.hairline),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => setState(() => on ? selected.remove(i) : selected.add(i)),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(seat.number,
                                            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                                        const Spacer(),
                                        if (minus >= 5)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: scheme.errorContainer,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text('反省單',
                                                style: TextStyle(fontSize: 12, color: scheme.onErrorContainer)),
                                          ),
                                      ],
                                    ),
                                    Text(seat.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                                    const Spacer(),
                                    Row(
                                      children: [
                                        Text('${seat.score} 章',
                                            style: TextStyle(
                                                fontSize: 16, fontWeight: FontWeight.w700, color: scheme.onSurface)),
                                        const Spacer(),
                                        Text('累積扣章 $minus',
                                            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
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
      },
    );
  }
}

/// 聯絡簿做成一本書：點開時封面以書背為軸翻開。
Future<void> showDiaryBook(BuildContext context, AppState state) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '關閉聯絡簿',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (dialogContext, _, __) => Center(child: _DiaryBook(state: state)),
    transitionBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
  );
}

class _DiaryBook extends StatefulWidget {
  final AppState state;
  const _DiaryBook({required this.state});

  @override
  State<_DiaryBook> createState() => _DiaryBookState();
}

class _DiaryBookState extends State<_DiaryBook> with TickerProviderStateMixin {
  late final AnimationController _open = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
    ..forward();
  late final AnimationController _turn = AnimationController(vsync: this, duration: const Duration(milliseconds: 950));
  final _input = TextEditingController();

  static const _paper = Color(0xFFFFFDF5);
  static const _line = Color(0xFFE7E1CF);
  static const _cover = Color(0xFF272343);
  static const _muted = Color(0xFF5A5F75);
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  DateTime shown = DateTime.now();
  DateTime target = DateTime.now();
  int turning = 0; // 1：翻到明天，-1：翻回昨天

  @override
  void dispose() {
    _open.dispose();
    _turn.dispose();
    _input.dispose();
    super.dispose();
  }

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<DiaryEntry> _entries(DateTime d) => widget.state.diaryEntries.where((e) => e.date == _key(d)).toList();

  Future<void> _turnPage(int dir) async {
    if (turning != 0 || _open.value < 1) return;
    setState(() {
      turning = dir;
      target = shown.add(Duration(days: dir));
    });
    await _turn.forward(from: 0);
    if (!mounted) return;
    setState(() {
      shown = target;
      turning = 0;
    });
  }

  Future<void> _add() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    await widget.state.saveDiaryEntries([
      ...widget.state.diaryEntries,
      DiaryEntry(date: _key(shown), tag: '一般', content: text),
    ]);
    _input.clear();
    if (mounted) setState(() {});
  }

  Future<void> _remove(DiaryEntry entry) async {
    await widget.state.saveDiaryEntries([
      for (final e in widget.state.diaryEntries)
        if (!identical(e, entry)) e,
    ]);
    if (mounted) setState(() {});
  }

  // 筆記本的格線：抬頭區高度 _head，之後每 _lh 一條線；文字都坐在線上（字放大，給全班看得清楚）
  static const double _head = 130;
  static const double _margin = 64;
  /// 頁面高度（build 時算好），用來決定每行多高、字多大
  double _pageH = 700;

  /// 一行：高度剛好一格，文字底部貼著橫線
  Widget _ruledRow(double lh, Widget child) => SizedBox(
        height: lh,
        child: Align(
          alignment: Alignment.bottomLeft,
          child: Padding(padding: EdgeInsets.only(bottom: lh * 0.18), child: child),
        ),
      );

  /// 一整頁（上方裝訂、往上翻的筆記本）：日期抬頭＋聯絡事項，最後一行是輸入列
  Widget _page(DateTime d, {bool interactive = false}) {
    final entries = _entries(d);
    // 一頁的基本行數由設定的「聯絡簿文字大小」決定（100% = 6 行）；項目更多時自動縮小，全部塞進一頁
    final baseRows = (6 / widget.state.diaryTextScale).round().clamp(3, 12);
    final rows = max(baseRows, entries.length + 1);
    final lh = ((_pageH - _head - 84) / rows).clamp(40.0, 150.0);
    final fs = (lh * 0.48).clamp(16.0, 80.0); // 字只佔一行的一半左右，上下留白不擠
    return Container(
      decoration: BoxDecoration(
        color: _paper,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border.all(color: AppTokens.ink, width: AppTokens.hairline),
      ),
      clipBehavior: Clip.antiAlias,
      child: CustomPaint(
        painter: _RuledLinesPainter(_line, top: _head, spacing: lh),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: _margin + 40, right: 64, bottom: 84),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: _head,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 26),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text('${d.month} 月 ${d.day} 日',
                                style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: AppTokens.ink)),
                            const SizedBox(width: 20),
                            Text('星期${_weekdays[d.weekday - 1]}',
                                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: _muted)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.zero,
                      children: [
                        for (var i = 0; i < entries.length; i++)
                          _ruledRow(lh, Row(
                            children: [
                              SizedBox(
                                width: fs * 1.8,
                                child: Text('${i + 1}.', style: TextStyle(fontSize: fs, color: _muted)),
                              ),
                              Expanded(
                                child: Text(entries[i].content,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: fs, fontWeight: FontWeight.w700, color: AppTokens.ink)),
                              ),
                              if (interactive)
                                InkWell(
                                  onTap: () => _remove(entries[i]),
                                  child: Padding(
                                    padding: const EdgeInsets.all(6),
                                    child: Icon(Icons.close, size: fs * 0.5, color: _muted),
                                  ),
                                ),
                            ],
                          )),
                        // 輸入列：直接寫在下一條線上
                        _ruledRow(lh, IgnorePointer(
                          ignoring: !interactive,
                          child: Row(
                            children: [
                              SizedBox(
                                width: fs * 1.8,
                                child: Text('${entries.length + 1}.', style: TextStyle(fontSize: fs, color: _muted)),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: interactive ? _input : null,
                                  onSubmitted: (_) => _add(),
                                  style: TextStyle(fontSize: fs, fontWeight: FontWeight.w700, color: AppTokens.ink),
                                  decoration: const InputDecoration(
                                    hintText: '寫下新的聯絡事項…',
                                    isDense: true,
                                    filled: false,
                                    contentPadding: EdgeInsets.zero,
                                    border: InputBorder.none,
                                    enabledBorder: InputBorder.none,
                                    focusedBorder: InputBorder.none,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              FilledButton(
                                onPressed: _add,
                                style: FilledButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                                  minimumSize: const Size(0, 64),
                                  textStyle: const TextStyle(fontSize: 30),
                                ),
                                child: const Text('新增'),
                              ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (interactive) ...[
              Positioned(
                right: 14,
                top: 14,
                child: IconButton(
                  tooltip: '關閉聯絡簿',
                  onPressed: () => Navigator.pop(context),
                  icon: const AppIcon(AppIcons.close, size: 30, color: AppTokens.ink),
                ),
              ),
              // 翻頁：前一天在左下、後一天在右下（也可以上下滑）
              Positioned(left: 12, bottom: 10, child: _turnButton('前一天', Icons.keyboard_arrow_down, () => _turnPage(-1))),
              Positioned(right: 12, bottom: 10, child: _turnButton('後一天', Icons.keyboard_arrow_up, () => _turnPage(1))),
            ],
          ],
        ),
      ),
    );
  }

  Widget _turnButton(String label, IconData icon, VoidCallback onTap) => IconButton(
        tooltip: label,
        onPressed: onTap,
        iconSize: 44,
        icon: Icon(icon, color: AppTokens.ink),
      );

  Widget _coverPage(DateTime now) => Container(
        decoration: const BoxDecoration(
          color: _cover,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo_wordmark.png',
                height: 72, color: const Color(0xFFFFFFFE), colorBlendMode: BlendMode.srcIn),
            const SizedBox(height: 28),
            const Text('聯絡簿', style: TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Color(0xFFFFFFFE))),
            const SizedBox(height: 12),
            Text('${now.month}/${now.day}', style: const TextStyle(fontSize: 28, color: Color(0xFFFFD803))),
          ],
        ),
      );

  /// 以上方裝訂處為軸整整翻一圈（360 度）的一頁：往上翻過裝訂條，再繞到筆記本後面。
  /// lift：0 = 平放在最上面、1 = 轉一圈回到筆記本正後方。面向我們時看到正面，背對時看到紙的背面
  Widget _lift(double lift, Widget front, {Color backColor = const Color(0xFFF3EFE2)}) {
    final back = Container(
      decoration: BoxDecoration(
        color: backColor,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
        border: Border.all(color: AppTokens.ink, width: AppTokens.hairline),
      ),
    );
    return IgnorePointer(
      child: Transform(
        alignment: Alignment.topCenter,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.0011)
          ..rotateX(-2 * pi * lift),
        child: cos(2 * pi * lift) >= 0 ? front : back,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final w = (size.width * 0.82).clamp(320.0, 1300.0);
    final h = (size.height * 0.88).clamp(320.0, 900.0);
    const ring = 34.0; // 上方裝訂條
    _pageH = h - ring;

    return Material(
      type: MaterialType.transparency,
      child: SizedBox(
        width: w,
        height: h,
        child: GestureDetector(
          // 往上滑＝後一天，往下滑＝前一天
          onVerticalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -300) _turnPage(1);
            if (v > 300) _turnPage(-1);
          },
          // 頁面在下、裝訂條畫在最上面：翻到後面的頁不會蓋住裝訂條
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                top: ring,
                child: AnimatedBuilder(
                  animation: Listenable.merge([_open, _turn]),
                  builder: (context, _) {
                    final v = Curves.easeInOutCubic.transform(_open.value);
                    final tv = Curves.easeInOutCubic.transform(_turn.value);
                    // 翻過頂端（超過半圈）之後，那一頁已經在筆記本後面往下掉，要畫在筆記本底下（像桌曆）
                    List<Widget> flip(Widget base, double lift, Widget page, {Color? backColor}) {
                      final moving = backColor == null ? _lift(lift, page) : _lift(lift, page, backColor: backColor);
                      return lift > 0.5 ? [moving, base] : [base, moving];
                    }
                    final List<Widget> layers;
                    if (v < 1) {
                      // 打開：封面翻一圈到後面
                      layers = flip(_page(shown), v, _coverPage(shown), backColor: _cover);
                    } else if (turning == 1) {
                      // 後一天：這一頁往上翻過裝訂條，繞到後面，露出下一頁
                      layers = flip(_page(target), tv, _page(shown));
                    } else if (turning == -1) {
                      // 前一天：上一頁從後面繞上來、翻過裝訂條蓋下來
                      layers = flip(_page(shown), 1 - tv, _page(target));
                    } else {
                      layers = [_page(shown, interactive: true)];
                    }
                    return Stack(
                      fit: StackFit.expand,
                      clipBehavior: Clip.none,
                      children: [for (final l in layers) Positioned.fill(child: l)],
                    );
                  },
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: // 裝訂條
              Container(
                height: ring,
                decoration: BoxDecoration(
                  color: AppTokens.ink,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  border: Border.all(color: AppTokens.ink, width: AppTokens.hairline),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    for (var i = 0; i < 12; i++)
                      Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(color: Color(0xFFE3F6F5), shape: BoxShape.circle),
                      ),
                  ],
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

/// 橫線筆記紙：抬頭下方開始每隔 spacing 一條線，左邊一條紅色邊線
class _RuledLinesPainter extends CustomPainter {
  final Color color;
  final double top;
  final double spacing;
  final double margin;
  const _RuledLinesPainter(this.color, {this.top = 72, this.spacing = 40, this.margin = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (var y = top; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    if (margin > 0) {
      final red = Paint()
        ..color = const Color(0x66D7263D)
        ..strokeWidth = 1.5;
      canvas.drawLine(Offset(margin, 0), Offset(margin, size.height), red);
    }
  }

  @override
  bool shouldRepaint(covariant _RuledLinesPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.top != top || oldDelegate.spacing != spacing;
}

/// 大屏專用課表：每科固定淡色、今天那欄加框、現在這節變黃並顯示倒數、午休自動插分隔列。
class BigScreenTimetable extends StatefulWidget {
  final AppState state;
  const BigScreenTimetable({super.key, required this.state});

  @override
  State<BigScreenTimetable> createState() => _BigScreenTimetableState();
}

class _BigScreenTimetableState extends State<BigScreenTimetable> {
  Timer? _timer;
  static const _days = ['一', '二', '三', '四', '五'];
  // 科目淡色（同一科永遠同一色）
  static const _tints = [
    Color(0xFFE3F6F5),
    Color(0xFFFFF3B0),
    Color(0xFFFFE1EC),
    Color(0xFFDCEBFF),
    Color(0xFFE6F4D7),
    Color(0xFFEDE4FF),
    Color(0xFFFFE8D6),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _min(String v) {
    final p = v.split(':');
    if (p.length < 2) return -1;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  /// 課程詳細卡片：跟同學卡片一樣的排版（上面課名、下面老師）
  void _showLessonCard(BuildContext context, ScheduleEntry e, int day, (int, int, String, String)? time) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;
        final hairline = BorderSide(color: scheme.outline, width: AppTokens.hairline);
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(28),
                border: Border.fromBorderSide(hairline),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: _tint(e.subject),
                    padding: const EdgeInsets.fromLTRB(24, 20, 12, 20),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLowest,
                            shape: BoxShape.circle,
                            border: Border.fromBorderSide(hairline),
                          ),
                          child: Text('${e.lesson + 1}',
                              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppTokens.ink)),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.subject,
                                  style:
                                      const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: AppTokens.ink)),
                              if (e.teacher.isNotEmpty)
                                Text(e.teacher, style: const TextStyle(fontSize: 18, color: Color(0xFF5A5F75))),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '關閉',
                          onPressed: () => Navigator.pop(dialogContext),
                          icon: const AppIcon(AppIcons.close, size: 22, color: AppTokens.ink),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                    child: Text(
                      '週${_days[day]}・第 ${e.lesson + 1} 節${time == null ? '' : '　${time.$3}–${time.$4}'}',
                      style: const TextStyle(fontSize: 18, color: AppTokens.ink),
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

  Color _tint(String subject) {
    if (subject.trim().isEmpty) return const Color(0xFFFFFFFE);
    var h = 0;
    for (final c in subject.codeUnits) {
      h = (h * 31 + c) & 0x7fffffff;
    }
    return _tints[h % _tints.length];
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final scheme = Theme.of(context).colorScheme;
    final now = state.reminderNow;
    final today = now.weekday - 1; // 0 = 週一
    final nowMin = now.hour * 60 + now.minute;
    final entries = state.scheduleEntries;
    final lessonCount = entries.isEmpty ? 0 : entries.map((e) => e.lesson).reduce(max) + 1;

    // 每一節的時間（各天共用，取第一筆有填的）
    final times = <int, (int, int, String, String)>{};
    for (final e in entries) {
      final s = _min(e.startTime), en = _min(e.endTime);
      if (s >= 0 && en > s) times.putIfAbsent(e.lesson, () => (s, en, e.startTime, e.endTime));
    }
    ScheduleEntry? cell(int day, int lesson) {
      for (final e in entries) {
        if (e.weekday == day && e.lesson == lesson) return e;
      }
      return null;
    }

    Widget header(int day) {
      final isToday = day == today;
      return Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            color: isToday ? scheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: isToday ? Border.all(color: AppTokens.ink, width: AppTokens.hairline) : null,
          ),
          child: Text(isToday ? '今天・週${_days[day]}' : '週${_days[day]}',
              style: TextStyle(
                  fontSize: 18, fontWeight: isToday ? FontWeight.w800 : FontWeight.normal, color: AppTokens.ink)),
        ),
      );
    }

    Widget lessonCell(int day, int lesson) {
      final e = cell(day, lesson);
      final t = times[lesson];
      final isToday = day == today;
      final isNow = isToday && t != null && nowMin >= t.$1 && nowMin < t.$2;
      final isPast = isToday && t != null && nowMin >= t.$2;
      final subject = e?.subject ?? '';
      // 一格最多 7 個字
      final shortName = subject.length > 7 ? subject.substring(0, 7) : subject;
      final box = Container(
        margin: const EdgeInsets.all(4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isNow ? scheme.primary : _tint(subject),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isToday ? AppTokens.ink : scheme.outlineVariant,
            width: isNow ? 3 : AppTokens.hairline,
          ),
        ),
        // 內容太多時整格等比縮小，不會爆版
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(shortName.isEmpty ? '—' : shortName,
                  maxLines: 1, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppTokens.ink)),
              if (isNow) ...[
                const SizedBox(height: 6),
                SizedBox(
                  width: 150,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ((nowMin - t!.$1) / (t!.$2 - t!.$1)).clamp(0.0, 1.0),
                      minHeight: 6,
                      color: AppTokens.ink,
                      backgroundColor: const Color(0x33272343),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text('還有 ${t!.$2 - nowMin} 分鐘下課', style: const TextStyle(fontSize: 13, color: AppTokens.ink)),
              ],
            ],
          ),
        ),
      );
      return Opacity(
        opacity: isPast ? 0.4 : 1,
        child: GestureDetector(
          onTap: e == null || subject.isEmpty ? null : () => _showLessonCard(context, e, day, t),
          child: box,
        ),
      );
    }

    if (lessonCount == 0) {
      return Center(child: Text('還沒有課表，請到教師後台「課表管理」設定', style: TextStyle(color: scheme.onSurfaceVariant)));
    }

    final rows = <Widget>[];
    for (var lesson = 0; lesson < lessonCount; lesson++) {
      // 跟上一節隔超過 30 分鐘 → 插一條午休分隔列
      final prev = times[lesson - 1], cur = times[lesson];
      if (prev != null && cur != null && cur.$1 - prev.$2 >= 30) {
        rows.add(Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              const SizedBox(width: 140),
              Expanded(child: Divider(color: scheme.outlineVariant)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('中午　${prev.$4}–${cur.$3}', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
              ),
              Expanded(child: Divider(color: scheme.outlineVariant)),
            ],
          ),
        ));
      }
      rows.add(Expanded(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 140,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text('${lesson + 1}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppTokens.ink)),
                    ),
                    if (cur != null) ...[
                      const SizedBox(width: 10),
                      Container(width: 1, height: 34, color: scheme.outlineVariant),
                      const SizedBox(width: 10),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(cur.$3,
                              style: const TextStyle(
                                  fontSize: 16, height: 1.25, fontWeight: FontWeight.w700, color: AppTokens.ink)),
                          Text('～${cur.$4}',
                              style: TextStyle(fontSize: 14, height: 1.25, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            for (var d = 0; d < 5; d++) Expanded(child: lessonCell(d, lesson)),
          ],
        ),
      ));
    }

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          SizedBox(
            height: 44,
            child: Row(children: [const SizedBox(width: 140), for (var d = 0; d < 5; d++) Expanded(child: header(d))]),
          ),
          const SizedBox(height: 6),
          ...rows,
        ],
      ),
    );
  }
}

/// 頂端列中間的投放輸入：可換行、不限字數，按「展示」投放到大屏
class _ProjectInput extends StatefulWidget {
  final ValueChanged<String> onProject;
  const _ProjectInput({required this.onProject});

  @override
  State<_ProjectInput> createState() => _ProjectInputState();
}

class _ProjectInputState extends State<_ProjectInput> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _show() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    widget.onProject(text);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 2,
              keyboardType: TextInputType.multiline,
              style: const TextStyle(fontSize: 15),
              decoration: InputDecoration(
                hintText: '輸入要投放到大屏的文字（Enter 換行）',
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                filled: true,
                fillColor: scheme.surfaceContainerLow,
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: _show,
            icon: const Icon(Icons.cast, size: 18),
            label: const Text('展示'),
          ),
        ],
      ),
    );
  }
}

/// 投放到大屏的全螢幕文字；點畫面或右上角叉叉關閉
class ProjectedTextOverlay extends StatelessWidget {
  final String text;
  final VoidCallback onClose;
  const ProjectedTextOverlay({super.key, required this.text, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // 字越多字越小，短句會非常大
    final n = text.length;
    final size = n <= 12 ? 110.0 : n <= 40 ? 76.0 : n <= 120 ? 52.0 : n <= 400 ? 38.0 : 28.0;
    return GestureDetector(
      onTap: onClose,
      child: ColoredBox(
        color: scheme.surfaceContainer,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(40, 60, 40, 32),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(36),
              border: Border.all(color: scheme.outline, width: AppTokens.hairline),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 40),
                      child: Text(
                        text,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: size, height: 1.35, fontWeight: FontWeight.w800, color: AppTokens.ink),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: IconButton(
                    tooltip: '關閉投放',
                    onPressed: onClose,
                    icon: const AppIcon(AppIcons.close, size: 28, color: AppTokens.ink),
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

// ───────────────────────── 教師即時通知 ─────────────────────────

TextStyle noticeTextStyle(NoticeStyle s, {double scale = 1}) => TextStyle(
      fontSize: s.size * scale,
      height: 1.35,
      fontWeight: s.bold ? FontWeight.w900 : FontWeight.w500,
      fontStyle: s.italic ? FontStyle.italic : FontStyle.normal,
      decoration: s.underline ? TextDecoration.underline : TextDecoration.none,
      color: Color(s.color),
    );

TextAlign noticeTextAlign(String align) => switch (align) {
      'left' => TextAlign.left,
      'right' => TextAlign.right,
      _ => TextAlign.center,
    };

/// 把通知轉成可以顯示的多段文字
TextSpan noticeTextSpan(TeacherNotice n, {double scale = 1}) => TextSpan(
      children: [for (final s in n.spans) TextSpan(text: s.text, style: noticeTextStyle(s.style, scale: scale))],
    );

/// 每個字都記住自己格式的輸入框控制器：選取一段字再按格式，就只改那幾個字
class RichNoticeController extends TextEditingController {
  final double scale;
  List<NoticeStyle> _styles;
  /// 沒有選取時，接下來打的字會用的格式
  NoticeStyle typingStyle;

  RichNoticeController({required TeacherNotice notice, this.scale = 1})
      : _styles = [for (final s in notice.spans) ...List.filled(s.text.length, s.style)],
        typingStyle = notice.spans.isEmpty ? const NoticeStyle() : notice.spans.last.style,
        super(text: notice.text);

  NoticeStyle _styleBefore(int i) {
    if (_styles.isEmpty) return typingStyle;
    if (i <= 0) return _styles.first;
    return _styles[(i - 1).clamp(0, _styles.length - 1)];
  }

  @override
  set value(TextEditingValue newValue) {
    final oldText = text;
    final newText = newValue.text;
    if (oldText != newText) {
      var p = 0;
      while (p < oldText.length && p < newText.length && oldText.codeUnitAt(p) == newText.codeUnitAt(p)) {
        p++;
      }
      var s = 0;
      while (s < oldText.length - p &&
          s < newText.length - p &&
          oldText.codeUnitAt(oldText.length - 1 - s) == newText.codeUnitAt(newText.length - 1 - s)) {
        s++;
      }
      final inserted = newText.length - s - p;
      if (_styles.length != oldText.length) {
        _styles = List.filled(oldText.length, typingStyle, growable: true);
      }
      _styles.replaceRange(p, oldText.length - s, List.filled(inserted, typingStyle));
    } else if (newValue.selection != selection && newValue.selection.isValid && newValue.selection.isCollapsed) {
      // 只移動游標：之後打的字跟游標前一個字同格式
      typingStyle = _styleBefore(newValue.selection.start);
    }
    super.value = newValue;
  }

  bool get _hasRange => selection.isValid && !selection.isCollapsed;

  /// 目前要在工具列顯示的格式（有選取就看第一個選到的字）
  NoticeStyle get currentStyle {
    if (_hasRange && selection.start < _styles.length) return _styles[selection.start];
    return typingStyle;
  }

  /// 套用格式：有選取就只改選取的字，沒選取就改接下來要打的字
  void apply(NoticeStyle Function(NoticeStyle) change) {
    if (_hasRange) {
      final end = selection.end.clamp(0, _styles.length);
      for (var i = selection.start; i < end; i++) {
        _styles[i] = change(_styles[i]);
      }
    } else {
      typingStyle = change(typingStyle);
    }
    notifyListeners();
  }

  /// 選取範圍裡是不是「全部」都符合（用來判斷粗體等按鈕要開還是關）
  bool all(bool Function(NoticeStyle) test) {
    if (_hasRange) {
      final end = selection.end.clamp(0, _styles.length);
      for (var i = selection.start; i < end; i++) {
        if (!test(_styles[i])) return false;
      }
      return true;
    }
    return test(typingStyle);
  }

  List<NoticeSpan> get spans {
    final out = <NoticeSpan>[];
    final t = text;
    var start = 0;
    for (var i = 1; i <= t.length; i++) {
      if (i == t.length || _styles[i] != _styles[start]) {
        out.add(NoticeSpan(t.substring(start, i), _styles[start]));
        start = i;
      }
    }
    return out;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    final t = text;
    if (_styles.length != t.length) _styles = List.filled(t.length, typingStyle, growable: true);
    final children = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= t.length; i++) {
      if (i == t.length || _styles[i] != _styles[start]) {
        children.add(TextSpan(text: t.substring(start, i), style: noticeTextStyle(_styles[start], scale: scale)));
        start = i;
      }
    }
    return TextSpan(style: style, children: children);
  }
}

/// 大屏上的通知：灰色背景＋一張大卡片。點叉叉或旁邊灰色才會關。
class TeacherNoticeOverlay extends StatelessWidget {
  final TeacherNotice notice;
  final VoidCallback onClose;
  const TeacherNoticeOverlay({super.key, required this.notice, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TweenAnimationBuilder<double>(
      key: ValueKey(notice.id),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.94 + 0.06 * Curves.easeOutBack.transform(v), child: child),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onClose,
              child: const ColoredBox(color: Color(0x99272343)),
            ),
          ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(56, 56, 56, 48),
              child: GestureDetector(
                onTap: () {}, // 點卡片本身不會關
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(36),
                    border: Border.all(color: scheme.outline, width: AppTokens.hairline),
                  ),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 64, vertical: 48),
                            child: SizedBox(
                              width: double.infinity,
                              child: Text.rich(
                                noticeTextSpan(notice),
                                textAlign: noticeTextAlign(notice.align),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        right: 14,
                        top: 14,
                        child: IconButton(
                          tooltip: '關閉通知',
                          onPressed: onClose,
                          icon: const AppIcon(AppIcons.close, size: 30, color: AppTokens.ink),
                        ),
                      ),
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
}

/// 教師後台：一個大輸入框，選取文字後可以只改那幾個字的格式
class TeacherNoticePage extends StatefulWidget {
  final AppState state;
  const TeacherNoticePage({super.key, required this.state});

  @override
  State<TeacherNoticePage> createState() => _TeacherNoticePageState();
}

class _TeacherNoticePageState extends State<TeacherNoticePage> {
  // 後台輸入框是大屏的縮小版（約一半），看起來的比例差不多
  static const _previewScale = 0.5;
  static const _colors = [0xFF272343, 0xFFE53935, 0xFF1E6FD9, 0xFF2E9E5B, 0xFFF08C00, 0xFF8E44AD];

  late final RichNoticeController ctrl;
  final focus = FocusNode();
  String align = 'center';
  bool sending = false;

  @override
  void initState() {
    super.initState();
    final n = widget.state.teacherNotice?.copy() ?? TeacherNotice(id: '');
    align = n.align;
    ctrl = RichNoticeController(notice: n, scale: _previewScale);
    ctrl.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    ctrl.removeListener(_refresh);
    ctrl.dispose();
    focus.dispose();
    super.dispose();
  }

  void _apply(NoticeStyle Function(NoticeStyle) change) {
    ctrl.apply(change);
    focus.requestFocus();
  }

  Future<void> _send() async {
    if (ctrl.text.trim().isEmpty) return;
    setState(() => sending = true);
    await widget.state.sendTeacherNotice(TeacherNotice(id: '', spans: ctrl.spans, align: align));
    if (!mounted) return;
    setState(() => sending = false);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已傳送到大屏')));
  }

  Future<void> _recall() async {
    await widget.state.clearTeacherNotice();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已收回通知')));
  }

  Widget _toggle(String tip, IconData icon, bool on, VoidCallback onTap) => IconButton(
        tooltip: tip,
        isSelected: on,
        onPressed: onTap,
        style: IconButton.styleFrom(
          backgroundColor: on ? AppTokens.accent : null,
          foregroundColor: AppTokens.ink,
        ),
        icon: Icon(icon),
      );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final live = widget.state.teacherNotice;
    final cur = ctrl.currentStyle;
    final bold = ctrl.all((s) => s.bold);
    final italic = ctrl.all((s) => s.italic);
    final underline = ctrl.all((s) => s.underline);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        // 格式工具列：算在輸入框「裡面」，點了不會讓選取消失
        TextFieldTapRegion(
          child: ExcludeFocus(
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                IconButton(
                  tooltip: '縮小',
                  onPressed: () => _apply((s) => s.copyWith(size: (s.size - 8).clamp(16.0, 240.0))),
                  icon: const Icon(Icons.text_decrease),
                ),
                SizedBox(
                  width: 48,
                  child: Text('${cur.size.round()}',
                      textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  tooltip: '放大',
                  onPressed: () => _apply((s) => s.copyWith(size: (s.size + 8).clamp(16.0, 240.0))),
                  icon: const Icon(Icons.text_increase),
                ),
                const SizedBox(width: 8),
                _toggle('粗體', Icons.format_bold, bold, () => _apply((s) => s.copyWith(bold: !bold))),
                _toggle('斜體', Icons.format_italic, italic, () => _apply((s) => s.copyWith(italic: !italic))),
                _toggle('底線', Icons.format_underline, underline,
                    () => _apply((s) => s.copyWith(underline: !underline))),
                const SizedBox(width: 8),
                _toggle('靠左', Icons.format_align_left, align == 'left', () => setState(() => align = 'left')),
                _toggle('置中', Icons.format_align_center, align == 'center', () => setState(() => align = 'center')),
                _toggle('靠右', Icons.format_align_right, align == 'right', () => setState(() => align = 'right')),
                const SizedBox(width: 8),
                for (final c in _colors)
                  GestureDetector(
                    onTap: () => _apply((s) => s.copyWith(color: c)),
                    child: Container(
                      width: 28,
                      height: 28,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: cur.color == c ? AppTokens.ink : scheme.outlineVariant,
                          width: cur.color == c ? 3 : 1,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // 大輸入框（直接用大屏的格式顯示）
        Container(
          constraints: const BoxConstraints(minHeight: 320),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 22),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outline, width: AppTokens.hairline),
          ),
          child: TextField(
            controller: ctrl,
            focusNode: focus,
            maxLines: null,
            minLines: 6,
            textAlign: noticeTextAlign(align),
            style: noticeTextStyle(const NoticeStyle(), scale: _previewScale),
            decoration: const InputDecoration(
              hintText: '輸入要顯示在大屏的內容（可換行）',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              filled: false,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            FilledButton.icon(
              onPressed: sending || ctrl.text.trim().isEmpty ? null : _send,
              icon: const Icon(Icons.send_rounded),
              label: const Text('傳送到大屏'),
            ),
            const SizedBox(width: 12),
            OutlinedButton(
              onPressed: live == null ? null : _recall,
              child: const Text('收回通知'),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                live == null ? '目前沒有通知' : '大屏顯示中：${live.text.split('\n').first}',
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────── 大屏「其他」：蓋章／懲罰抽籤／兌換獎勵 ─────────────────────────

class BigScreenOtherMenu extends StatelessWidget {
  final AppState state;
  const BigScreenOtherMenu({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    Widget tile(Object icon, String label, Widget Function()? page, {bool officer = false, VoidCallback? onTap}) => SizedBox(
          width: 196,
          height: 136,
          child: Material(
            color: scheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: onTap ?? () async {
                // 蓋章、懲罰抽籤、兌換獎勵都要先輸入管理者 PIN 碼
                if (officer && !await showOfficerPinDialog(context, state)) return;
                if (context.mounted) showPageDialog(context, officer ? '$label（管理者專用）' : label, page!());
              },
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  icon is String
                      ? AppIcon(icon, size: 40, color: scheme.onSurface)
                      : Icon(icon as IconData, size: 40, color: scheme.onSurface),
                  const SizedBox(height: 10),
                  Text(label, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                  if (officer)
                    Text('（管理者專用）',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                ],
              ),
            ),
          ),
        );
    // 從下方彈出的小視窗，2×2 排列
    return Wrap(
        spacing: 16,
        runSpacing: 16,
        alignment: WrapAlignment.center,
        children: [
          tile(AppIcons.clipboardPen, '蓋章', () => StampPage(state: state), officer: true),
          tile(Icons.casino_outlined, '懲罰抽籤', () => PunishmentDrawPage(state: state), officer: true),
          tile(Icons.redeem_outlined, '兌換獎勵', () => RewardRedeemPage(state: state), officer: true),
          tile(Icons.forum_outlined, '詢問', () => ChatPanel(state: state, from: 'bigscreen')),
          tile(Icons.how_to_vote_outlined, '投票', () => VotePage(state: state)),
          tile(Icons.public, 'Chrome', () => ChromePickerPage(state: state)),
          tile(Icons.gavel_rounded, '政策', null, onTap: () => showPolicyPaper(context, state)),
        ],
    );
  }
}

/// 懲罰抽籤：籤會快速跳動，慢慢停在其中一個
class PunishmentDrawPage extends StatefulWidget {
  final AppState state;
  const PunishmentDrawPage({super.key, required this.state});

  @override
  State<PunishmentDrawPage> createState() => _PunishmentDrawPageState();
}

class _PunishmentDrawPageState extends State<PunishmentDrawPage> {
  final _rng = Random();
  String? shown;
  bool rolling = false;
  bool done = false;

  Future<void> _draw() async {
    final items = widget.state.punishments;
    if (items.isEmpty || rolling) return;
    setState(() {
      rolling = true;
      done = false;
    });
    var delay = 50;
    while (delay < 360) {
      if (!mounted) return;
      setState(() => shown = items[_rng.nextInt(items.length)]);
      await Future<void>.delayed(Duration(milliseconds: delay));
      delay = (delay * 1.12).round() + 4;
    }
    if (!mounted) return;
    setState(() {
      shown = items[_rng.nextInt(items.length)];
      rolling = false;
      done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final items = widget.state.punishments;
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: items.isEmpty
                  ? Text('老師還沒有設定懲罰的籤', style: TextStyle(fontSize: 24, color: scheme.onSurfaceVariant))
                  : AnimatedScale(
                      scale: done ? 1.08 : 1,
                      duration: const Duration(milliseconds: 260),
                      curve: Curves.easeOutBack,
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 900, minWidth: 420, minHeight: 220),
                        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 36),
                        decoration: BoxDecoration(
                          color: done ? AppTokens.accent : scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(36),
                          border: Border.all(color: scheme.outline, width: AppTokens.hairline),
                        ),
                        child: Center(
                          widthFactor: 1,
                          child: Text(
                            shown ?? '按下面的按鈕抽籤',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: shown == null ? 32 : 60,
                              fontWeight: FontWeight.w900,
                              color: shown == null ? scheme.onSurfaceVariant : AppTokens.ink,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
          ),
          SizedBox(
            width: 320,
            height: 84,
            child: FilledButton(
              onPressed: items.isEmpty || rolling ? null : _draw,
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),
                side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
                textStyle: const TextStyle(fontSize: 28),
              ),
              child: Text(rolling ? '抽籤中…' : done ? '再抽一次' : '抽籤'),
            ),
          ),
          const SizedBox(height: 8),
          Text('共 ${items.length} 支籤', style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

/// 兌換獎勵：選同學 → 選獎勵 → 確認後扣章
class RewardRedeemPage extends StatefulWidget {
  final AppState state;
  const RewardRedeemPage({super.key, required this.state});

  @override
  State<RewardRedeemPage> createState() => _RewardRedeemPageState();
}

class _RewardRedeemPageState extends State<RewardRedeemPage> {
  int? seat;
  int? reward;
  bool busy = false;

  Future<void> _redeem() async {
    final s = seat, r = reward;
    final state = widget.state;
    if (s == null || r == null || busy || r >= state.rewards.length) return;
    final student = state.seats[s];
    final item = state.rewards[r];
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('確認兌換'),
        content: Text('${student.name} 要用 ${item.cost} 章兌換「${item.name}」？\n兌換後剩 ${student.score - item.cost} 章。',
            style: const TextStyle(fontSize: 18)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('兌換')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => busy = true);
    final done = await state.redeemReward(s, item);
    if (!mounted) return;
    setState(() {
      busy = false;
      if (done) {
        seat = null;
        reward = null;
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(done ? '${student.name} 已兌換「${item.name}」' : '章數不夠，無法兌換')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final scheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final indexes = [
          for (var i = 0; i < state.seats.length; i++)
            if (state.seats[i].name.trim().isNotEmpty) i,
        ];
        final picked = seat == null || seat! >= state.seats.length ? null : state.seats[seat!];
        final item = reward == null || reward! >= state.rewards.length ? null : state.rewards[reward!];
        final enough = picked != null && item != null && picked.score >= item.cost;

        return Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 左：選同學
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1. 選同學', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 150,
                          mainAxisExtent: 112,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        itemCount: indexes.length,
                        itemBuilder: (_, k) {
                          final i = indexes[k];
                          final s = state.seats[i];
                          final on = seat == i;
                          return Material(
                            color: on
                                ? scheme.primary
                                : s.gender == '男'
                                    ? AppTokens.seatBoy(isDark)
                                    : s.gender == '女'
                                        ? AppTokens.seatGirl(isDark)
                                        : scheme.surfaceContainerLow,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                              side: BorderSide(color: scheme.outline, width: on ? 3 : AppTokens.hairline),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(18),
                              onTap: () => setState(() => seat = on ? null : i),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(12, 8, 10, 8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(s.number, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                                    Text(s.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                                    const Spacer(),
                                    Text('${s.score} 章',
                                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurface)),
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
              ),
              const SizedBox(width: 20),
              // 右：選獎勵＋兌換
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('2. 選獎勵', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                    const SizedBox(height: 10),
                    Expanded(
                      child: state.rewards.isEmpty
                          ? Center(child: Text('老師還沒有設定獎勵', style: TextStyle(fontSize: 20, color: scheme.onSurfaceVariant)))
                          : ListView.separated(
                              itemCount: state.rewards.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 10),
                              itemBuilder: (_, k) {
                                final r = state.rewards[k];
                                final on = reward == k;
                                final afford = picked == null || picked.score >= r.cost;
                                return Material(
                                  color: on ? AppTokens.accent : scheme.surfaceContainerHighest,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                    side: BorderSide(color: scheme.outline, width: on ? 3 : AppTokens.hairline),
                                  ),
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(18),
                                    onTap: () => setState(() => reward = on ? null : k),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(r.name,
                                                style: TextStyle(
                                                    fontSize: 22,
                                                    fontWeight: FontWeight.w800,
                                                    color: afford ? AppTokens.ink : scheme.onSurfaceVariant)),
                                          ),
                                          Text('${r.cost} 章',
                                              style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.w700,
                                                  color: afford ? AppTokens.ink : scheme.error)),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      picked == null || item == null
                          ? '選好同學和獎勵後按兌換'
                          : enough
                              ? '${picked.name}：${picked.score} → ${picked.score - item.cost} 章'
                              : '${picked.name} 只有 ${picked.score} 章，不夠兌換',
                      style: TextStyle(fontSize: 17, color: enough || item == null ? scheme.onSurfaceVariant : scheme.error),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 72,
                      child: FilledButton(
                        onPressed: enough && !busy ? _redeem : null,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                          side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
                          textStyle: const TextStyle(fontSize: 26),
                        ),
                        child: const Text('兌換'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────── 教師後台：懲罰與獎勵管理 ─────────────────────────

class PunishRewardAdminPage extends StatefulWidget {
  final AppState state;
  const PunishRewardAdminPage({super.key, required this.state});

  @override
  State<PunishRewardAdminPage> createState() => _PunishRewardAdminPageState();
}

class _PunishRewardAdminPageState extends State<PunishRewardAdminPage> {
  final punishCtrl = TextEditingController();
  final rewardCtrl = TextEditingController();
  int newCost = 5;

  @override
  void dispose() {
    punishCtrl.dispose();
    rewardCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPunish() async {
    final v = punishCtrl.text.trim();
    if (v.isEmpty) return;
    await widget.state.savePunishments([...widget.state.punishments, v]);
    punishCtrl.clear();
  }

  Future<void> _addReward() async {
    final v = rewardCtrl.text.trim();
    if (v.isEmpty) return;
    await widget.state.saveRewards([...widget.state.rewards, RewardItem(name: v, cost: newCost)]);
    rewardCtrl.clear();
  }

  Future<void> _editPunish(int i) async {
    final ctrl = TextEditingController(text: widget.state.punishments[i]);
    final v = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('修改懲罰'),
        content: TextField(controller: ctrl, autofocus: true, onSubmitted: (s) => Navigator.pop(c, s)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, ctrl.text), child: const Text('儲存')),
        ],
      ),
    );
    Future<void>.delayed(const Duration(milliseconds: 600), ctrl.dispose);
    if (v == null || v.trim().isEmpty) return;
    final list = [...widget.state.punishments];
    list[i] = v.trim();
    await widget.state.savePunishments(list);
  }

  Future<void> _editReward(int i) async {
    final r = widget.state.rewards[i];
    final nameCtrl = TextEditingController(text: r.name);
    final costCtrl = TextEditingController(text: '${r.cost}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('修改獎勵'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: nameCtrl, autofocus: true, decoration: const InputDecoration(labelText: '獎勵名稱')),
            const SizedBox(height: 12),
            TextField(
              controller: costCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: '需要幾個章'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('儲存')),
        ],
      ),
    );
    final name = nameCtrl.text.trim();
    final cost = int.tryParse(costCtrl.text) ?? r.cost;
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      nameCtrl.dispose();
      costCtrl.dispose();
    });
    if (ok != true || name.isEmpty) return;
    final list = [...widget.state.rewards];
    list[i] = RewardItem(name: name, cost: cost < 0 ? 0 : cost);
    await widget.state.saveRewards(list);
  }

  Widget _section({required String title, required Widget adder, required List<Widget> rows}) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 14),
          adder,
          const SizedBox(height: 10),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text('還沒有項目', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
            ),
          ...rows,
        ],
      ),
    );
  }

  Widget _row(String text, String? trailing, VoidCallback onEdit, VoidCallback onDelete) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.only(left: 16, right: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
      ),
      child: Row(
        children: [
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600))),
          if (trailing != null)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(trailing, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          IconButton(tooltip: '修改', onPressed: onEdit, icon: const Icon(Icons.edit_outlined, size: 20)),
          IconButton(tooltip: '刪除', onPressed: onDelete, icon: const Icon(Icons.delete_outline, size: 20)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final state = widget.state;
        final punish = _section(
          title: '懲罰抽籤',
          adder: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: punishCtrl,
                  decoration: const InputDecoration(hintText: '新增一支籤，例如：掃走廊一週'),
                  onSubmitted: (_) => _addPunish(),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton(onPressed: _addPunish, child: const Text('新增')),
            ],
          ),
          rows: [
            for (var i = 0; i < state.punishments.length; i++)
              _row(state.punishments[i], null, () => _editPunish(i),
                  () => state.savePunishments([...state.punishments]..removeAt(i))),
          ],
        );
        final reward = _section(
          title: '兌換獎勵',
          adder: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: rewardCtrl,
                  decoration: const InputDecoration(hintText: '獎勵名稱，例如：免寫一次作業'),
                  onSubmitted: (_) => _addReward(),
                ),
              ),
              const SizedBox(width: 10),
              IconButton(
                tooltip: '少一章',
                onPressed: newCost <= 0 ? null : () => setState(() => newCost--),
                icon: const Icon(Icons.remove),
              ),
              SizedBox(
                width: 56,
                child: Text('$newCost 章', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              IconButton(tooltip: '多一章', onPressed: () => setState(() => newCost++), icon: const Icon(Icons.add)),
              const SizedBox(width: 6),
              FilledButton(onPressed: _addReward, child: const Text('新增')),
            ],
          ),
          rows: [
            for (var i = 0; i < state.rewards.length; i++)
              _row(state.rewards[i].name, '${state.rewards[i].cost} 章', () => _editReward(i),
                  () => state.saveRewards([...state.rewards]..removeAt(i))),
          ],
        );
        return LayoutBuilder(builder: (context, c) {
          final wide = c.maxWidth >= 980;
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: punish),
                    const SizedBox(width: 20),
                    Expanded(child: reward),
                  ],
                )
              else ...[
                punish,
                const SizedBox(height: 20),
                reward,
              ],
            ],
          );
        });
      },
    );
  }
}

// ───────────────────────── 詢問：大屏和教師後台聊天 ─────────────────────────

/// from：'bigscreen'（大屏）或 'teacher'（教師後台）。自己的訊息在右邊。
class ChatPanel extends StatefulWidget {
  final AppState state;
  final String from;
  const ChatPanel({super.key, required this.state, required this.from});

  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final ctrl = TextEditingController();
  final scroll = ScrollController();
  final focus = FocusNode();
  late Stream<List<Map<String, dynamic>>> stream;
  bool sending = false;
  int _lastCount = 0;

  bool get _isTeacher => widget.from == 'teacher';

  @override
  void initState() {
    super.initState();
    stream = widget.state.cloud.watchChat(widget.state.classId);
  }

  @override
  void dispose() {
    ctrl.dispose();
    scroll.dispose();
    focus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = ctrl.text.trim();
    if (text.isEmpty || sending) return;
    setState(() => sending = true);
    try {
      await widget.state.cloud.pushChatMessage(widget.state.classId, from: widget.from, text: text);
      ctrl.clear();
      unawaited(widget.state.postEvent(
        _isTeacher ? 'bigscreen' : 'teacher',
        _isTeacher ? '老師回覆了詢問' : '大屏傳來新的詢問',
        text,
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('傳送失敗：$e')));
      }
    } finally {
      if (mounted) setState(() => sending = false);
      focus.requestFocus();
    }
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('清空所有訊息？'),
        content: const Text('大屏和教師後台的對話都會一起清掉。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('清空')),
        ],
      ),
    );
    if (ok == true) await widget.state.cloud.clearChat(widget.state.classId);
  }

  String _time(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (d.year == now.year && d.month == now.month && d.day == now.day) return hm;
    return '${d.month}/${d.day} $hm';
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scroll.hasClients) {
        scroll.animateTo(scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final big = !_isTeacher; // 大屏字比較大
    final fs = big ? 22.0 : 16.0;
    final ready = widget.state.cloud.isConfigured && widget.state.classId.trim().isNotEmpty;

    return Padding(
      padding: EdgeInsets.fromLTRB(big ? 20 : 24, big ? 16 : 20, big ? 20 : 24, big ? 16 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isTeacher)
            Row(
              children: [
                const Spacer(),
                TextButton.icon(
                  onPressed: ready ? _clear : null,
                  icon: const Icon(Icons.delete_sweep_outlined),
                  label: const Text('清空對話'),
                ),
              ],
            ),
          if (_isTeacher) const SizedBox(height: 14),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
              ),
              child: !ready
                  ? Center(
                      child: Text('需要先設定雲端和班級代碼才能聊天',
                          style: TextStyle(fontSize: fs, color: scheme.onSurfaceVariant)))
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: stream,
                      builder: (context, snap) {
                        final msgs = snap.data ?? const [];
                        if (msgs.length != _lastCount) {
                          _lastCount = msgs.length;
                          _scrollToEnd();
                        }
                        if (snap.hasError) {
                          return Center(child: Text('讀取失敗：${snap.error}', style: TextStyle(color: scheme.error)));
                        }
                        if (msgs.isEmpty) {
                          return Center(
                            child: Text(_isTeacher ? '還沒有人詢問' : '有問題就在下面輸入，老師會在後台看到',
                                style: TextStyle(fontSize: fs, color: scheme.onSurfaceVariant)),
                          );
                        }
                        return ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.all(18),
                          itemCount: msgs.length,
                          itemBuilder: (_, i) {
                            final m = msgs[i];
                            final mine = m['from'] == widget.from;
                            final who = m['from'] == 'teacher' ? '老師' : '大屏';
                            final at = (m['at'] as num?)?.toInt() ?? 0;
                            return Align(
                              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 620),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  child: Column(
                                    crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                    children: [
                                      Text('$who · ${_time(at)}',
                                          style: TextStyle(fontSize: fs * 0.62, color: scheme.onSurfaceVariant)),
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                        decoration: BoxDecoration(
                                          color: mine ? AppTokens.accent : scheme.surfaceContainerHighest,
                                          borderRadius: BorderRadius.circular(18),
                                          border: Border.all(color: scheme.outline, width: AppTokens.hairline),
                                        ),
                                        child: SelectableText(
                                          '${m['text'] ?? ''}',
                                          style: TextStyle(fontSize: fs, height: 1.35, color: AppTokens.ink),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CallbackShortcuts(
                  // Enter 送出，Shift+Enter 換行
                  bindings: {const SingleActivator(LogicalKeyboardKey.enter): _send},
                  child: TextField(
                    controller: ctrl,
                    focusNode: focus,
                    enabled: ready,
                    minLines: 1,
                    maxLines: 4,
                    style: TextStyle(fontSize: fs),
                    decoration: InputDecoration(hintText: _isTeacher ? '回覆同學…' : '輸入想問老師的問題…'),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                height: big ? 60 : 48,
                child: FilledButton.icon(
                  onPressed: ready && !sending ? _send : null,
                  icon: const Icon(Icons.send_rounded),
                  label: Text('傳送', style: TextStyle(fontSize: big ? 20 : 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 教師後台：大頁外框（標題＋彩色分頁標籤＋內容面板） ─────────────────────────

/// 分頁標籤的顏色（跟大屏同一組：黃、青、粉、藍）
const _adminTabColors = [Color(0xFFFFD803), Color(0xFFBAE8E8), Color(0xFFFFE1EC), Color(0xFFDCEBFF)];

class AdminSection extends StatefulWidget {
  final String title;
  /// 內容面板的底色；null = 不包面板（總覽自己排彩色卡片）
  final Color? tint;
  final List<(String, Widget Function())> tabs;
  const AdminSection({super.key, required this.title, required this.tint, required this.tabs});

  @override
  State<AdminSection> createState() => _AdminSectionState();
}

class _AdminSectionState extends State<AdminSection> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final tabs = widget.tabs;
    final current = tab.clamp(0, tabs.length - 1);
    final body = KeyedSubtree(key: ValueKey(current), child: tabs[current].$2());

    final tabBar = tabs.length < 2
        ? const SizedBox.shrink()
        : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (var i = 0; i < tabs.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Material(
                      color: i == current ? _adminTabColors[i % _adminTabColors.length] : Colors.transparent,
                      shape: StadiumBorder(
                        side: BorderSide(
                          color: i == current ? scheme.outline : scheme.outlineVariant,
                          width: AppTokens.hairline,
                        ),
                      ),
                      child: InkWell(
                        customBorder: const StadiumBorder(),
                        onTap: () => setState(() => tab = i),
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: mobile ? 14 : 20, vertical: mobile ? 8 : 10),
                          child: Text(
                            tabs[i].$1,
                            style: TextStyle(
                              fontSize: mobile ? 15 : 17,
                              fontWeight: i == current ? FontWeight.w800 : FontWeight.w500,
                              color: i == current ? AppTokens.ink : scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(mobile ? 12 : 8, mobile ? 52 : 0, mobile ? 12 : 0, 16),
          child: Row(
            children: [
              Text(widget.title,
                  style: TextStyle(fontSize: mobile ? 26 : 34, fontWeight: FontWeight.w900, color: scheme.onSurface)),
              const SizedBox(width: 12),
              Expanded(child: Align(alignment: Alignment.centerRight, child: tabBar)),
            ],
          ),
        ),
        Expanded(
          child: widget.tint == null
              ? body
              : Container(
                  clipBehavior: Clip.antiAlias,
                  margin: mobile ? const EdgeInsets.fromLTRB(8, 0, 8, 8) : EdgeInsets.zero,
                  decoration: BoxDecoration(
                    color: isDark ? scheme.surfaceContainerLow : widget.tint,
                    borderRadius: BorderRadius.circular(mobile ? 24 : 36),
                    border: Border.all(color: scheme.outline, width: AppTokens.hairline),
                  ),
                  child: body,
                ),
        ),
      ],
    );
  }
}

// ───────────────────────── 教師後台：學生管理 ─────────────────────────

class StudentAdminPage extends StatelessWidget {
  final AppState state;
  const StudentAdminPage({super.key, required this.state});

  static int _num(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9]'), '')) ?? 9999;

  /// 新增同學：放進人數最少的那一排最後面，然後直接打開編輯
  Future<void> _add(BuildContext context) async {
    final rows = state.seats.map((s) => s.row).toSet().toList()..sort();
    var target = 0;
    if (rows.isNotEmpty) {
      target = rows.first;
      var fewest = 1 << 30;
      for (final r in rows) {
        final n = state.seats.where((s) => s.row == r).length;
        if (n < fewest) {
          fewest = n;
          target = r;
        }
      }
    }
    await state.addSeat(row: target);
    if (context.mounted) await _editSeat(context, state, state.seats.length - 1, true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: state,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final order = [for (var i = 0; i < state.seats.length; i++) i]
          ..sort((a, b) {
            final c = _num(state.seats[a].number).compareTo(_num(state.seats[b].number));
            return c != 0 ? c : state.seats[a].number.compareTo(state.seats[b].number);
          });
        final boys = state.seats.where((s) => s.gender == '男' && s.name.trim().isNotEmpty).length;
        final girls = state.seats.where((s) => s.gender == '女' && s.name.trim().isNotEmpty).length;
        final named = state.seats.where((s) => s.name.trim().isNotEmpty).length;

        const head = TextStyle(fontSize: 14, fontWeight: FontWeight.w800);
        Widget cell(double? w, Widget child) => w == null ? Expanded(child: child) : SizedBox(width: w, child: child);

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => _add(context),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: const Text('新增學生'),
                  ),
                  const Spacer(),
                  Text('共 $named 人　男 $boys　女 $girls',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTokens.accent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outline, width: AppTokens.hairline),
                ),
                child: Row(
                  children: [
                    cell(70, const Text('座號', style: head)),
                    cell(150, const Text('姓名', style: head)),
                    cell(60, const Text('性別', style: head)),
                    cell(150, const Text('職位', style: head)),
                    cell(70, const Text('章數', style: head)),
                    cell(null, const Text('備註', style: head)),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: order.isEmpty
                    ? Center(child: Text('還沒有學生', style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant)))
                    : ListView.separated(
                        itemCount: order.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (_, k) {
                          final i = order[k];
                          final s = state.seats[i];
                          final color = s.gender == '男'
                              ? AppTokens.seatBoy(isDark)
                              : s.gender == '女'
                                  ? AppTokens.seatGirl(isDark)
                                  : scheme.surfaceContainerLowest;
                          final empty = s.name.trim().isEmpty;
                          return Material(
                            color: color,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: scheme.outlineVariant, width: AppTokens.hairline),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => _editSeat(context, state, i, true),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                child: Row(
                                  children: [
                                    cell(70, Text(s.number, style: const TextStyle(fontWeight: FontWeight.w700))),
                                    cell(
                                      150,
                                      Text(empty ? '空位' : s.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.w800,
                                              color: empty ? scheme.onSurfaceVariant : scheme.onSurface)),
                                    ),
                                    cell(60, Text(s.gender.isEmpty ? '—' : s.gender)),
                                    cell(150, Text(s.label.isEmpty ? '—' : s.label, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                    cell(70, Text('${s.score}', style: const TextStyle(fontWeight: FontWeight.w800))),
                                    cell(
                                      null,
                                      Text(s.note.isEmpty ? '—' : s.note,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: scheme.onSurfaceVariant)),
                                    ),
                                    const SizedBox(width: 40, child: Icon(Icons.edit_outlined, size: 18)),
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
      },
    );
  }
}

// ───────────────────────── 教師後台：聯絡簿管理（沒有翻書動畫） ─────────────────────────

class DiaryAdminPage extends StatefulWidget {
  final AppState state;
  const DiaryAdminPage({super.key, required this.state});

  @override
  State<DiaryAdminPage> createState() => _DiaryAdminPageState();
}

class _DiaryAdminPageState extends State<DiaryAdminPage> {
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];

  DateTime date = DateTime.now();
  final ctrl = TextEditingController();
  final focus = FocusNode();

  @override
  void dispose() {
    ctrl.dispose();
    focus.dispose();
    super.dispose();
  }

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _add() async {
    final text = ctrl.text.trim();
    if (text.isEmpty) return;
    await widget.state.saveDiaryEntries([
      ...widget.state.diaryEntries,
      DiaryEntry(date: _key(date), tag: '一般', content: text),
    ]);
    ctrl.clear();
    focus.requestFocus();
  }

  Future<void> _edit(DiaryEntry e) async {
    final c = TextEditingController(text: e.content);
    final ok = await showDialog<bool>(
      context: context,
      builder: (dc) => AlertDialog(
        title: const Text('修改聯絡簿'),
        content: SizedBox(
          width: 460,
          child: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextField(
                controller: c, autofocus: true, maxLines: 3, minLines: 1, decoration: const InputDecoration(labelText: '內容')),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dc, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(dc, true), child: const Text('儲存')),
        ],
      ),
    );
    final text = c.text.trim();
    Future<void>.delayed(const Duration(milliseconds: 600), c.dispose);
    if (ok != true || text.isEmpty) return;
    e.content = text;
    await widget.state.saveDiaryEntries(widget.state.diaryEntries);
  }

  Future<void> _move(DiaryEntry e, int dir, List<DiaryEntry> day) async {
    final list = widget.state.diaryEntries;
    final k = day.indexOf(e);
    final other = k + dir;
    if (other < 0 || other >= day.length) return;
    final a = list.indexOf(e), b = list.indexOf(day[other]);
    list[a] = day[other];
    list[b] = e;
    await widget.state.saveDiaryEntries(list);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        final scheme = Theme.of(context).colorScheme;
        final key = _key(date);
        final day = widget.state.diaryEntries.where((e) => e.date == key).toList();
        final isToday = key == _key(DateTime.now());

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 日期切換
              Row(
                children: [
                  IconButton(
                    tooltip: '前一天',
                    onPressed: () => setState(() => date = date.subtract(const Duration(days: 1))),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('${date.month} 月 ${date.day} 日　星期${_weekdays[date.weekday - 1]}',
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  IconButton(
                    tooltip: '後一天',
                    onPressed: () => setState(() => date = date.add(const Duration(days: 1))),
                    icon: const Icon(Icons.chevron_right),
                  ),
                  const SizedBox(width: 6),
                  if (!isToday)
                    OutlinedButton(onPressed: () => setState(() => date = DateTime.now()), child: const Text('回到今天')),
                  const Spacer(),
                  Text('${day.length} 項', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
                ],
              ),
              const SizedBox(height: 14),
              // 新增
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: ctrl,
                            focusNode: focus,
                            decoration: const InputDecoration(hintText: '輸入聯絡簿內容，按 Enter 新增'),
                            onSubmitted: (_) => _add(),
                          ),
                        ),
                        const SizedBox(width: 10),
                        FilledButton.icon(onPressed: _add, icon: const Icon(Icons.add), label: const Text('新增')),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              // 這一天的項目
              Expanded(
                child: day.isEmpty
                    ? Center(child: Text('這天還沒有聯絡簿', style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant)))
                    : ListView.separated(
                        itemCount: day.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final e = day[i];
                          return Container(
                            padding: const EdgeInsets.fromLTRB(16, 10, 6, 10),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
                            ),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 32,
                                  child: Text('${i + 1}.', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                                ),
                                Expanded(child: Text(e.content, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600))),
                                IconButton(
                                  tooltip: '往上',
                                  onPressed: i == 0 ? null : () => _move(e, -1, day),
                                  icon: const Icon(Icons.arrow_upward, size: 20),
                                ),
                                IconButton(
                                  tooltip: '往下',
                                  onPressed: i == day.length - 1 ? null : () => _move(e, 1, day),
                                  icon: const Icon(Icons.arrow_downward, size: 20),
                                ),
                                IconButton(
                                  tooltip: '修改',
                                  onPressed: () => _edit(e),
                                  icon: const Icon(Icons.edit_outlined, size: 20),
                                ),
                                IconButton(
                                  tooltip: '刪除',
                                  onPressed: () => widget.state
                                      .saveDiaryEntries([...widget.state.diaryEntries]..remove(e)),
                                  icon: const Icon(Icons.delete_outline, size: 20),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ───────────────────────── 通知鈴鐺（頂端列設定按鈕左邊） ─────────────────────────

/// target：這台裝置要收哪一邊的通知（'teacher' 或 'bigscreen'）
class NotificationBell extends StatefulWidget {
  final AppState state;
  final String target;
  const NotificationBell({super.key, required this.state, required this.target});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  StreamSubscription<List<Map<String, dynamic>>>? _sub;
  List<Map<String, dynamic>> events = const [];
  int _newestShown = 0;
  String _classId = '';

  @override
  void initState() {
    super.initState();
    _listen();
    widget.state.addListener(_onState);
  }

  void _onState() {
    if (widget.state.classId != _classId) _listen();
    if (mounted) setState(() {});
  }

  void _listen() {
    _sub?.cancel();
    _classId = widget.state.classId;
    _newestShown = DateTime.now().millisecondsSinceEpoch;
    _sub = widget.state.cloud.watchEvents(_classId, widget.target).listen((list) {
      if (!mounted) return;
      // 新來的通知跳出小提示
      final fresh = list.where((e) => ((e['at'] as num?)?.toInt() ?? 0) > _newestShown).toList();
      if (fresh.isNotEmpty) {
        _newestShown = (fresh.first['at'] as num).toInt();
        final e = fresh.first;
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(
          content: Text('${e['title'] ?? ''}${(e['body'] ?? '').toString().isEmpty ? '' : '：${e['body']}'}',
              maxLines: 2, overflow: TextOverflow.ellipsis),
          action: SnackBarAction(label: '查看', onPressed: _open),
        ));
      }
      setState(() => events = list);
    }, onError: (_) {});
  }

  @override
  void dispose() {
    widget.state.removeListener(_onState);
    _sub?.cancel();
    super.dispose();
  }

  int get _unread =>
      events.where((e) => ((e['at'] as num?)?.toInt() ?? 0) > widget.state.notifSeenAt).length;

  String _time(int ms) {
    final d = DateTime.fromMillisecondsSinceEpoch(ms);
    final now = DateTime.now();
    final hm = '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    if (d.year == now.year && d.month == now.month && d.day == now.day) return hm;
    return '${d.month}/${d.day} $hm';
  }

  Future<void> _open() async {
    final seenBefore = widget.state.notifSeenAt;
    unawaited(widget.state.markNotificationsSeen());
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black12,
      builder: (dc) {
        final scheme = Theme.of(dc).colorScheme;
        return Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 66, right: 120),
            child: Material(
              color: scheme.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
                side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
              ),
              clipBehavior: Clip.antiAlias,
              child: SizedBox(
                width: 380,
                height: 480,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
                      child: Row(
                        children: [
                          const Text('通知', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                          const Spacer(),
                          IconButton(
                            tooltip: '關閉',
                            onPressed: () => Navigator.pop(dc),
                            icon: AppIcon(AppIcons.close, size: 22, color: scheme.onSurface),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: events.isEmpty
                          ? Center(child: Text('目前沒有通知', style: TextStyle(color: scheme.onSurfaceVariant)))
                          : ListView.separated(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                              itemCount: events.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (_, i) {
                                final e = events[i];
                                final at = (e['at'] as num?)?.toInt() ?? 0;
                                final isNew = at > seenBefore;
                                final body = (e['body'] ?? '').toString();
                                return Container(
                                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                                  decoration: BoxDecoration(
                                    color: isNew ? const Color(0xFFFFF8D6) : scheme.surfaceContainerLow,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color: isNew ? scheme.outline : scheme.outlineVariant, width: AppTokens.hairline),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text('${e['title'] ?? ''}',
                                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                          ),
                                          Text(_time(at), style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                                        ],
                                      ),
                                      if (body.isNotEmpty) ...[
                                        const SizedBox(height: 4),
                                        Text(body,
                                            maxLines: 3,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                                      ],
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = _unread;
    return IconButton(
      tooltip: '通知',
      onPressed: _open,
      icon: Badge(
        isLabelVisible: n > 0,
        backgroundColor: const Color(0xFFE53935),
        label: Text(n > 99 ? '99+' : '$n'),
        child: Icon(n > 0 ? Icons.notifications_active_outlined : Icons.notifications_none_outlined),
      ),
    );
  }
}

// ───────────────────────── 大屏「其他 → 投票」 ─────────────────────────

/// 投票：自行投票（同學輪流按左右按鈕）／開會投票（主持人數舉手人數後填入）
class VotePage extends StatefulWidget {
  final AppState state;
  const VotePage({super.key, required this.state});

  @override
  State<VotePage> createState() => _VotePageState();
}

class _VotePageState extends State<VotePage> {
  static const _left = Color(0xFFDCEBFF);
  static const _right = Color(0xFFFFE1EC);

  String? mode; // null = 選模式、'self' = 自行投票、'meeting' = 開會投票
  final topic = TextEditingController();
  final leftName = TextEditingController(text: '贊成');
  final rightName = TextEditingController(text: '反對');
  bool started = false;
  int a = 0, b = 0;
  int? lastTap; // 剛按的是哪一邊（給一點回饋）

  int get classSize => widget.state.students.length;

  @override
  void dispose() {
    topic.dispose();
    leftName.dispose();
    rightName.dispose();
    super.dispose();
  }

  void _reset({bool toMenu = false}) => setState(() {
        a = 0;
        b = 0;
        lastTap = null;
        started = false;
        if (toMenu) mode = null;
      });

  String get _l => leftName.text.trim().isEmpty ? '選項一' : leftName.text.trim();
  String get _r => rightName.text.trim().isEmpty ? '選項二' : rightName.text.trim();

  // ── 共用：設定題目和兩個選項 ──
  Widget _setup(ColorScheme scheme, String startLabel) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: topic,
              style: const TextStyle(fontSize: 24),
              decoration: const InputDecoration(labelText: '投票題目'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: leftName,
                    style: const TextStyle(fontSize: 22),
                    decoration: const InputDecoration(labelText: '左邊選項'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: rightName,
                    style: const TextStyle(fontSize: 22),
                    decoration: const InputDecoration(labelText: '右邊選項'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _reset(toMenu: true),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('換投票方式', style: TextStyle(fontSize: 18)),
                ),
                const Spacer(),
                SizedBox(
                  height: 64,
                  width: 220,
                  child: FilledButton(
                    onPressed: () => setState(() => started = true),
                    style: FilledButton.styleFrom(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
                      side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
                      textStyle: const TextStyle(fontSize: 24),
                    ),
                    child: Text(startLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ── 共用：結果長條 ──
  Widget _result(ColorScheme scheme, {required bool editable}) {
    final total = a + b;
    final abstain = (classSize - total).clamp(0, 999);
    Widget bar(String name, int n, Color color, void Function(int) set) {
      final ratio = classSize == 0 ? 0.0 : (n / classSize).clamp(0.0, 1.0);
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            SizedBox(
              width: 160,
              child: Text(name, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            ),
            Expanded(
              child: Container(
                height: 56,
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: scheme.outline, width: AppTokens.hairline),
                ),
                clipBehavior: Clip.antiAlias,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    widthFactor: ratio,
                    heightFactor: 1,
                    child: ColoredBox(color: color),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            if (editable) ...[
              IconButton.outlined(
                onPressed: n <= 0 ? null : () => setState(() => set(n - 1)),
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 6),
            ],
            SizedBox(
              width: 90,
              child: Text('$n 票',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            ),
            if (editable) ...[
              const SizedBox(width: 6),
              IconButton.outlined(
                onPressed: total >= classSize ? null : () => setState(() => set(n + 1)),
                icon: const Icon(Icons.add),
              ),
            ],
          ],
        ),
      );
    }

    final winner = a == b ? '平手' : (a > b ? '$_l 勝出' : '$_r 勝出');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topic.text.trim().isNotEmpty)
          Text(topic.text.trim(),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
        const SizedBox(height: 18),
        bar(_l, a, _left, (v) => a = v),
        bar(_r, b, _right, (v) => b = v),
        const SizedBox(height: 10),
        Text('全班 $classSize 人・已投 $total 票・未投 $abstain 人',
            textAlign: TextAlign.center, style: TextStyle(fontSize: 20, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        if (!editable || total > 0)
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
              decoration: BoxDecoration(
                color: AppTokens.accent,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: scheme.outline, width: AppTokens.hairline),
              ),
              child: Text(winner, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: AppTokens.ink)),
            ),
          ),
      ],
    );
  }

  // ── 自行投票 ──
  Widget _selfVote(ColorScheme scheme) {
    final total = a + b;
    final done = classSize > 0 && total >= classSize;
    if (done) {
      return Column(
        children: [
          Expanded(child: Center(child: SingleChildScrollView(child: _result(scheme, editable: false)))),
          _bottomButtons(),
        ],
      );
    }
    Widget voteButton(String name, Color color, int side) => Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Material(
              color: color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(36),
                side: BorderSide(color: scheme.outline, width: lastTap == side ? 4 : AppTokens.hairline),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(36),
                onTap: () => setState(() {
                  if (side == 0) {
                    a++;
                  } else {
                    b++;
                  }
                  lastTap = side;
                }),
                child: Center(
                  child: Text(name,
                      style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: AppTokens.ink)),
                ),
              ),
            ),
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (topic.text.trim().isNotEmpty)
          Text(topic.text.trim(),
              textAlign: TextAlign.center, style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(
          classSize == 0 ? '請先在後台建立學生資料' : '一人按一次・已投 $total / $classSize',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 22, color: scheme.onSurfaceVariant),
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              voteButton(_l, _left, 0),
              voteButton(_r, _right, 1),
            ],
          ),
        ),
        _bottomButtons(),
      ],
    );
  }

  // ── 開會投票 ──
  Widget _meetingVote(ColorScheme scheme) {
    return Column(
      children: [
        Expanded(child: Center(child: SingleChildScrollView(child: _result(scheme, editable: true)))),
        _bottomButtons(),
      ],
    );
  }

  Widget _bottomButtons() => Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _reset(),
              icon: const Icon(Icons.refresh),
              label: const Text('重新投票', style: TextStyle(fontSize: 18)),
            ),
            const SizedBox(width: 14),
            TextButton.icon(
              onPressed: () => _reset(toMenu: true),
              icon: const Icon(Icons.arrow_back),
              label: const Text('換投票方式', style: TextStyle(fontSize: 18)),
            ),
          ],
        ),
      );

  // ── 選模式 ──
  Widget _menu(ColorScheme scheme) {
    Widget card(IconData icon, String title, String m, Color color) => SizedBox(
          width: 340,
          height: 280,
          child: Material(
            color: color,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(36),
              side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(36),
              onTap: () => setState(() {
                mode = m;
                a = 0;
                b = 0;
                lastTap = null;
                started = false;
              }),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 72, color: AppTokens.ink),
                  const SizedBox(height: 18),
                  Text(title, style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: AppTokens.ink)),
                ],
              ),
            ),
          ),
        );
    return Center(
      child: Wrap(
        spacing: 32,
        runSpacing: 32,
        alignment: WrapAlignment.center,
        children: [
          card(Icons.touch_app_outlined, '自行投票', 'self', _left),
          card(Icons.front_hand_outlined, '開會投票', 'meeting', _right),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget body;
    if (mode == null) {
      body = _menu(scheme);
    } else if (!started) {
      body = _setup(scheme, mode == 'self' ? '開始投票' : '開始計票');
    } else {
      body = mode == 'self' ? _selfVote(scheme) : _meetingVote(scheme);
    }
    return Padding(padding: const EdgeInsets.all(24), child: body);
  }
}

// ───────────────────────── 教師評分：下課那一瞬間跳出 ─────────────────────────

/// 放在大屏最上層。每秒看一次「現在」（測試時間也算），剛好到某節課的下課時間就跳出評分。
class LessonRatingWatcher extends StatefulWidget {
  final AppState state;
  /// 大屏用：跳出時把視窗叫回來並蓋在其他 app 上面（後台預覽不用）
  final bool bringToFront;
  const LessonRatingWatcher({super.key, required this.state, this.bringToFront = false});

  @override
  State<LessonRatingWatcher> createState() => _LessonRatingWatcherState();
}

class _LessonRatingWatcherState extends State<LessonRatingWatcher> {
  Timer? _timer;
  /// 這次開機已經跳過（評分或關掉）的課，避免同一分鐘一直跳
  final _handled = <String>{};
  ({String key, String date, int lesson, String subject})? _due;
  int stars = 0;
  int hover = 0;
  bool sent = false;

  @override
  void initState() {
    super.initState();
    // 不能在 initState 裡直接 setState，等第一個畫面畫完再檢查
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _check());
    widget.state.addListener(_onState);
  }

  @override
  void dispose() {
    _timer?.cancel();
    widget.state.removeListener(_onState);
    super.dispose();
  }

  // 資料變動時可能正在畫畫面，延到下一個畫面再檢查
  void _onState() => WidgetsBinding.instance.addPostFrameCallback((_) => _check());

  String _hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  String _norm(String t) {
    final p = t.trim().split(':');
    if (p.length < 2) return t.trim();
    return '${p[0].padLeft(2, '0')}:${p[1].padLeft(2, '0')}';
  }

  void _check() {
    if (!mounted || _due != null) return;
    final state = widget.state;
    final now = state.reminderNow;
    final hm = _hm(now);
    final date = _date(now);
    for (final e in state.scheduleEntries) {
      if (e.weekday != now.weekday - 1 || _norm(e.endTime) != hm) continue;
      final key = '${date}_${e.lesson}';
      if (_handled.contains(key) || state.isLessonRated(key)) continue;
      setState(() {
        _due = (key: key, date: date, lesson: e.lesson, subject: e.subject.isEmpty ? '自習' : e.subject);
        stars = 0;
        hover = 0;
        sent = false;
      });
      _bringToFront(true);
      return;
    }
  }

  /// 評分時把大屏視窗從最小化叫回來、固定在最上層；送出後取消固定
  Future<void> _bringToFront(bool on) async {
    if (!widget.bringToFront || !isDesktopPlatform) return;
    try {
      if (on) {
        if (await windowManager.isMinimized()) await windowManager.restore();
        await windowManager.show();
        await windowManager.maximize();
        await windowManager.setAlwaysOnTop(true);
        await windowManager.focus();
      } else {
        await windowManager.setAlwaysOnTop(false);
      }
    } catch (_) {}
  }

  void _close() {
    final d = _due;
    if (d != null) _handled.add(d.key);
    setState(() => _due = null);
  }

  Future<void> _submit() async {
    final d = _due;
    if (d == null || stars == 0 || sent) return;
    setState(() => sent = true);
    _handled.add(d.key);
    await widget.state.submitLessonRating(
      key: d.key,
      date: d.date,
      lesson: d.lesson,
      subject: d.subject,
      stars: stars,
    );
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await _bringToFront(false);
    if (mounted) setState(() => _due = null);
  }

  @override
  Widget build(BuildContext context) {
    final d = _due;
    if (d == null) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final shown = hover > 0 ? hover : stars;
    return TweenAnimationBuilder<double>(
      key: ValueKey(d.key),
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      builder: (context, v, child) => Opacity(
        opacity: v.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.94 + 0.06 * Curves.easeOutBack.transform(v), child: child),
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: Color(0x99272343))),
          Center(
            child: Container(
              width: 760,
              padding: const EdgeInsets.fromLTRB(48, 40, 48, 40),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: scheme.outline, width: AppTokens.hairline),
              ),
              child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        sent ? '謝謝老師！' : '我們班在這堂課表現得如何？',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w900, color: AppTokens.ink),
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (var i = 1; i <= 5; i++)
                            MouseRegion(
                              cursor: SystemMouseCursors.click,
                              onEnter: (_) => setState(() => hover = i),
                              onExit: (_) => setState(() => hover = 0),
                              child: GestureDetector(
                                onTap: sent ? null : () => setState(() => stars = i),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6),
                                  child: AnimatedScale(
                                    scale: i <= shown ? 1.1 : 1,
                                    duration: const Duration(milliseconds: 160),
                                    child: Icon(
                                      i <= shown ? Icons.star_rounded : Icons.star_outline_rounded,
                                      size: 88,
                                      color: i <= shown ? const Color(0xFFFFC400) : scheme.outlineVariant,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      SizedBox(
                        width: 280,
                        height: 72,
                        child: FilledButton(
                          onPressed: stars == 0 || sent ? null : _submit,
                          style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(36)),
                            side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
                            textStyle: const TextStyle(fontSize: 26),
                          ),
                          child: Text(sent ? '已送出' : '送出'),
                        ),
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

// ───────────────────────── 教師後台：教師評分紀錄 ─────────────────────────

class RatingRecordsPage extends StatefulWidget {
  final AppState state;
  const RatingRecordsPage({super.key, required this.state});

  @override
  State<RatingRecordsPage> createState() => _RatingRecordsPageState();
}

class _RatingRecordsPageState extends State<RatingRecordsPage> {
  static const _weekdays = ['一', '二', '三', '四', '五', '六', '日'];
  static const _colors = [Color(0xFFFFD803), Color(0xFFBAE8E8), Color(0xFFFFE1EC), Color(0xFFDCEBFF)];
  late final Stream<List<Map<String, dynamic>>> stream = widget.state.cloud.watchRatings(widget.state.classId);

  String _dateLabel(String key) {
    final d = DateTime.tryParse(key);
    if (d == null) return key;
    return '${d.month} 月 ${d.day} 日　星期${_weekdays[d.weekday - 1]}';
  }

  Widget _stars(num value, double size) {
    final full = value.round();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 1; i <= 5; i++)
          Icon(i <= full ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size, color: i <= full ? const Color(0xFFFFC400) : const Color(0xFFD5DADF)),
      ],
    );
  }

  Future<void> _delete(Map<String, dynamic> r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('刪除這筆評分？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('刪除')),
        ],
      ),
    );
    if (ok == true) await widget.state.cloud.deleteRating(widget.state.classId, '${r['id']}');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ready = widget.state.cloud.isConfigured && widget.state.classId.trim().isNotEmpty;
    if (!ready) {
      return Center(child: Text('需要先設定雲端和班級代碼', style: TextStyle(color: scheme.onSurfaceVariant)));
    }
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return Center(child: Text('讀取失敗：${snap.error}', style: TextStyle(color: scheme.error)));
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return Center(
            child: Text(snap.connectionState == ConnectionState.waiting ? '讀取中…' : '還沒有評分紀錄',
                style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant)),
          );
        }
        int stars(Map<String, dynamic> r) => (r['stars'] as num?)?.toInt() ?? 0;
        final avg = list.map(stars).reduce((a, b) => a + b) / list.length;
        // 各科平均
        final bySubject = <String, List<int>>{};
        for (final r in list) {
          bySubject.putIfAbsent('${r['subject'] ?? ''}', () => []).add(stars(r));
        }
        final subjects = bySubject.entries.toList()
          ..sort((a, b) => (b.value.reduce((x, y) => x + y) / b.value.length)
              .compareTo(a.value.reduce((x, y) => x + y) / a.value.length));
        // 依日期分組
        final byDate = <String, List<Map<String, dynamic>>>{};
        for (final r in list) {
          byDate.putIfAbsent('${r['date'] ?? ''}', () => []).add(r);
        }
        final dates = byDate.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            // 總平均＋各科平均
            Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                Container(
                  width: 240,
                  height: 120,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFD803),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: scheme.outline, width: AppTokens.hairline),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('總平均', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTokens.ink)),
                      const Spacer(),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(avg.toStringAsFixed(1),
                              style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w900, height: 1, color: AppTokens.ink)),
                          const SizedBox(width: 6),
                          Text('/ 5・${list.length} 節',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTokens.ink)),
                        ],
                      ),
                    ],
                  ),
                ),
                for (var i = 0; i < subjects.length; i++)
                  Container(
                    width: 200,
                    height: 120,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: _colors[(i + 1) % _colors.length],
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: scheme.outline, width: AppTokens.hairline),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(subjects[i].key,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTokens.ink)),
                        const Spacer(),
                        Text(
                          (subjects[i].value.reduce((a, b) => a + b) / subjects[i].value.length).toStringAsFixed(1),
                          style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, height: 1, color: AppTokens.ink),
                        ),
                        const SizedBox(height: 4),
                        Text('${subjects[i].value.length} 節',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTokens.ink)),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            // 每天的紀錄
            for (final date in dates) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8, top: 6),
                child: Text(_dateLabel(date), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              for (final r in (byDate[date]!
                ..sort((a, b) => ((a['lesson'] as num?) ?? 0).compareTo((b['lesson'] as num?) ?? 0))))
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(18, 10, 6, 10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 80,
                        child: Text('第 ${(((r['lesson'] as num?) ?? 0).toInt()) + 1} 節',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      ),
                      Expanded(
                        child: Text('${r['subject'] ?? ''}',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                      ),
                      _stars(stars(r), 26),
                      const SizedBox(width: 6),
                      IconButton(
                        tooltip: '刪除',
                        onPressed: () => _delete(r),
                        icon: const Icon(Icons.delete_outline, size: 20),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        );
      },
    );
  }
}

// ───────────────────────── 自動打開下一節的教材資料夾 ─────────────────────────

/// 打開資料夾（學校電腦沒有系統管理員權限，所以只開資料夾，電子書由老師自己點）
Future<bool> openMaterialFolder(String path) async {
  if (kIsWeb || !Platform.isWindows || path.trim().isEmpty) return false;
  try {
    await Process.start('explorer', [path.trim()], mode: ProcessStartMode.detached);
    return true;
  } catch (_) {
    return false;
  }
}

/// 放在大屏上（看不見）。每秒看一次時間：
/// 下課後 N 分鐘（預設 5，教師後台可改）自動打開「下一節」的教材資料夾。
/// 一天的第一節，或中間隔很久（例如午休）的那一節，改成上課前 5 分鐘打開。
class MaterialAutoOpener extends StatefulWidget {
  final AppState state;
  const MaterialAutoOpener({super.key, required this.state});

  @override
  State<MaterialAutoOpener> createState() => _MaterialAutoOpenerState();
}

class _MaterialAutoOpenerState extends State<MaterialAutoOpener> {
  Timer? _timer;
  final _done = <String>{};

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _check());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  int _min(String t) {
    final p = t.trim().split(':');
    if (p.length < 2) return -1;
    return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
  }

  void _check() {
    final state = widget.state;
    final now = state.reminderNow;
    final nowMin = now.hour * 60 + now.minute;
    final today = state.scheduleEntries
        .where((e) => e.weekday == now.weekday - 1 && _min(e.startTime) >= 0 && _min(e.endTime) >= 0)
        .toList()
      ..sort((a, b) => _min(a.startTime).compareTo(_min(b.startTime)));
    for (var i = 0; i < today.length; i++) {
      final next = today[i];
      final start = _min(next.startTime);
      int at;
      if (i > 0 && start - _min(today[i - 1].endTime) <= 20) {
        at = _min(today[i - 1].endTime) + state.materialOpenDelay;
      } else {
        at = start - 5;
      }
      if (at >= start) at = start - 1;
      if (nowMin != at) continue;
      final key = '${now.year}-${now.month}-${now.day}_${next.lesson}';
      if (_done.contains(key)) continue;
      _done.add(key);
      final folder = state.materialFor(next.subject);
      if (folder != null) openMaterialFolder(folder.path);
      // 這一科有設定 Chrome 使用者的話，也一起打開
      for (final p in state.chromeFor(next.subject)) {
        openChromeProfile(p);
      }
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// 教師後台：教材資料夾管理
class MaterialAdminPage extends StatefulWidget {
  final AppState state;
  const MaterialAdminPage({super.key, required this.state});

  @override
  State<MaterialAdminPage> createState() => _MaterialAdminPageState();
}

class _MaterialRow {
  final TextEditingController name;
  final TextEditingController keywords;
  final TextEditingController path;
  _MaterialRow(MaterialFolder m)
      : name = TextEditingController(text: m.name),
        keywords = TextEditingController(text: m.keywords),
        path = TextEditingController(text: m.path);
  MaterialFolder get value => MaterialFolder(name: name.text.trim(), keywords: keywords.text.trim(), path: path.text.trim());
  void dispose() {
    name.dispose();
    keywords.dispose();
    path.dispose();
  }
}

class _MaterialAdminPageState extends State<MaterialAdminPage> {
  late List<_MaterialRow> rows = [for (final m in widget.state.materialFolders) _MaterialRow(m)];
  late int delay = widget.state.materialOpenDelay;
  Timer? _saveTimer;

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _save();
    }
    for (final r in rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _changed() {
    setState(() {});
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _save);
  }

  Future<void> _save() => widget.state.saveMaterialFolders([for (final r in rows) r.value], delay);

  Future<void> _resetDefaults() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('恢復成預設的教材路徑？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('恢復')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      for (final r in rows) {
        r.dispose();
      }
      rows = [for (final m in MaterialFolder.defaults()) _MaterialRow(m)];
    });
    _changed();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            const Text('下課後', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            IconButton.outlined(
              onPressed: delay <= 0
                  ? null
                  : () {
                      delay--;
                      _changed();
                    },
              icon: const Icon(Icons.remove),
            ),
            SizedBox(
              width: 56,
              child: Text('$delay',
                  textAlign: TextAlign.center, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            ),
            IconButton.outlined(
              onPressed: delay >= 30
                  ? null
                  : () {
                      delay++;
                      _changed();
                    },
              icon: const Icon(Icons.add),
            ),
            const SizedBox(width: 8),
            const Text('分鐘，自動打開下一節的教材', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: _resetDefaults,
              icon: const Icon(Icons.restore),
              label: const Text('恢復預設'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: () {
                setState(() => rows.add(_MaterialRow(MaterialFolder(name: '', keywords: '', path: ''))));
              },
              icon: const Icon(Icons.add),
              label: const Text('新增'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTokens.accent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline, width: AppTokens.hairline),
          ),
          child: const Row(
            children: [
              SizedBox(width: 140, child: Text('名稱', style: TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(width: 12),
              SizedBox(width: 180, child: Text('課表科目（用逗號分開）', style: TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(width: 12),
              Expanded(child: Text('資料夾路徑', style: TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(width: 96),
            ],
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < rows.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
            ),
            child: Row(
              children: [
                SizedBox(
                  width: 140,
                  child: TextField(
                    controller: rows[i].name,
                    onChanged: (_) => _changed(),
                    decoration: const InputDecoration(isDense: true, hintText: '名稱'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 180,
                  child: TextField(
                    controller: rows[i].keywords,
                    onChanged: (_) => _changed(),
                    decoration: const InputDecoration(isDense: true, hintText: '例如：英語,英文'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: rows[i].path,
                    onChanged: (_) => _changed(),
                    style: const TextStyle(fontSize: 13),
                    decoration: const InputDecoration(isDense: true, hintText: r'\\伺服器\資料夾'),
                  ),
                ),
                IconButton(
                  tooltip: '打開看看',
                  onPressed: () async {
                    final ok = await openMaterialFolder(rows[i].path.text);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('打不開：這台電腦可能連不到學校的伺服器')));
                    }
                  },
                  icon: const Icon(Icons.folder_open_outlined, size: 20),
                ),
                IconButton(
                  tooltip: '刪除',
                  onPressed: () {
                    rows.removeAt(i).dispose();
                    _changed();
                  },
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── Chrome 使用者 ─────────────────────────

/// 找 Chrome 裝在哪裡（不用系統管理員權限）
String? _findChrome() {
  final env = Platform.environment;
  final candidates = [
    '${env['ProgramFiles'] ?? r'C:\Program Files'}\\Google\\Chrome\\Application\\chrome.exe',
    '${env['ProgramFiles(x86)'] ?? r'C:\Program Files (x86)'}\\Google\\Chrome\\Application\\chrome.exe',
    if (env['LOCALAPPDATA'] != null) '${env['LOCALAPPDATA']}\\Google\\Chrome\\Application\\chrome.exe',
  ];
  for (final c in candidates) {
    if (File(c).existsSync()) return c;
  }
  return null;
}

/// 用指定的 Chrome 使用者打開（可順便開網址）
Future<bool> openChromeProfile(ChromeProfile p) async {
  if (kIsWeb || !Platform.isWindows || p.profileDir.trim().isEmpty) return false;
  final args = ['--profile-directory=${p.profileDir.trim()}', if (p.url.trim().isNotEmpty) p.url.trim()];
  try {
    final chrome = _findChrome();
    if (chrome != null) {
      await Process.start(chrome, args, mode: ProcessStartMode.detached);
    } else {
      // 找不到路徑就交給 Windows 找
      await Process.start('cmd', ['/c', 'start', '', 'chrome', ...args], mode: ProcessStartMode.detached);
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// 大屏「其他 → Chrome」：點一個使用者就用他打開 Chrome
class ChromePickerPage extends StatelessWidget {
  final AppState state;
  const ChromePickerPage({super.key, required this.state});

  static const _colors = [Color(0xFFFFD803), Color(0xFFBAE8E8), Color(0xFFFFE1EC), Color(0xFFDCEBFF)];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final list = state.chromeProfiles;
    if (list.isEmpty) {
      return Center(
        child: Text('還沒有設定 Chrome 使用者，請到教師後台「班級 → Chrome」新增',
            style: TextStyle(fontSize: 22, color: scheme.onSurfaceVariant)),
      );
    }
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Wrap(
          spacing: 20,
          runSpacing: 20,
          alignment: WrapAlignment.center,
          children: [
            for (var i = 0; i < list.length; i++)
              SizedBox(
                width: 260,
                height: 150,
                child: Material(
                  color: _colors[i % _colors.length],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                    side: BorderSide(color: scheme.outline, width: AppTokens.hairline),
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(24),
                    onTap: () async {
                      final ok = await openChromeProfile(list[i]);
                      if (!context.mounted) return;
                      if (ok) {
                        Navigator.of(context).maybePop();
                      } else {
                        ScaffoldMessenger.of(context)
                            .showSnackBar(const SnackBar(content: Text('打不開 Chrome，請確認這台電腦有安裝 Chrome')));
                      }
                    },
                    child: Center(
                      child: Text(list[i].name.isEmpty ? list[i].profileDir : list[i].name,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: AppTokens.ink)),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 教師後台：Chrome 使用者管理（含取得設定檔名稱的教學）
class ChromeAdminPage extends StatefulWidget {
  final AppState state;
  const ChromeAdminPage({super.key, required this.state});

  @override
  State<ChromeAdminPage> createState() => _ChromeAdminPageState();
}

class _ChromeRow {
  final TextEditingController name;
  final TextEditingController dir;
  final TextEditingController url;
  final TextEditingController keywords;
  _ChromeRow(ChromeProfile p)
      : name = TextEditingController(text: p.name),
        dir = TextEditingController(text: p.profileDir),
        url = TextEditingController(text: p.url),
        keywords = TextEditingController(text: p.keywords);
  ChromeProfile get value => ChromeProfile(
      name: name.text.trim(), profileDir: dir.text.trim(), url: url.text.trim(), keywords: keywords.text.trim());
  void dispose() {
    name.dispose();
    dir.dispose();
    url.dispose();
    keywords.dispose();
  }
}

class _ChromeAdminPageState extends State<ChromeAdminPage> {
  late List<_ChromeRow> rows = [for (final p in widget.state.chromeProfiles) _ChromeRow(p)];
  Timer? _saveTimer;

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      _save();
    }
    for (final r in rows) {
      r.dispose();
    }
    super.dispose();
  }

  void _changed() {
    setState(() {});
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), _save);
  }

  Future<void> _save() => widget.state.saveChromeProfiles([for (final r in rows) r.value]);

  Widget _field(TextEditingController c, String hint, {double? width}) {
    final f = TextField(
      controller: c,
      onChanged: (_) => _changed(),
      decoration: InputDecoration(isDense: true, hintText: hint),
    );
    return width == null ? Expanded(child: f) : SizedBox(width: width, child: f);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const step = TextStyle(fontSize: 15, height: 1.6, color: AppTokens.ink);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // 教學
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFDCEBFF),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: scheme.outline, width: AppTokens.hairline),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('怎麼找到「設定檔名稱」', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTokens.ink)),
              SizedBox(height: 10),
              Text('1. 在學校電腦打開 Chrome，切換到你要的那個使用者（右上角的頭像）。', style: step),
              Text('2. 在網址列輸入 chrome://version 然後按 Enter。', style: step),
              Text('3. 找到「設定檔路徑」這一行，看最後一段，例如 …\\User Data\\Profile 2。', style: step),
              Text('4. 最後那段（Default、Profile 1、Profile 2…）就是設定檔名稱，填到下面的欄位。', style: step),
              Text('5. 每個使用者都重複一次。填好後可以按右邊的 ▶ 試開看看。', style: step),
              SizedBox(height: 8),
              Text('「課表科目」有填的話，會跟教材一起在下課後自動打開；不填就只能從大屏「其他 → Chrome」手動選。',
                  style: TextStyle(fontSize: 14, height: 1.6, fontWeight: FontWeight.w700, color: AppTokens.ink)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            const Spacer(),
            FilledButton.icon(
              onPressed: () => setState(() => rows.add(_ChromeRow(ChromeProfile(name: '', profileDir: '')))),
              icon: const Icon(Icons.add),
              label: const Text('新增使用者'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppTokens.accent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outline, width: AppTokens.hairline),
          ),
          child: const Row(
            children: [
              SizedBox(width: 140, child: Text('顯示名稱', style: TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(width: 12),
              SizedBox(width: 130, child: Text('設定檔名稱', style: TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(width: 12),
              Expanded(child: Text('網址（可不填）', style: TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(width: 12),
              SizedBox(width: 160, child: Text('課表科目（可不填）', style: TextStyle(fontWeight: FontWeight.w800))),
              SizedBox(width: 96),
            ],
          ),
        ),
        const SizedBox(height: 8),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Text('還沒有 Chrome 使用者', textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          ),
        for (var i = 0; i < rows.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(16, 8, 6, 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant, width: AppTokens.hairline),
            ),
            child: Row(
              children: [
                _field(rows[i].name, '例如：數學老師', width: 140),
                const SizedBox(width: 12),
                _field(rows[i].dir, 'Profile 1', width: 130),
                const SizedBox(width: 12),
                _field(rows[i].url, 'https://…'),
                const SizedBox(width: 12),
                _field(rows[i].keywords, '例如：數學', width: 160),
                IconButton(
                  tooltip: '試開看看',
                  onPressed: () async {
                    final ok = await openChromeProfile(rows[i].value);
                    if (!ok && context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('打不開：請確認有填設定檔名稱、這台電腦有 Chrome')));
                    }
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 22),
                ),
                IconButton(
                  tooltip: '刪除',
                  onPressed: () {
                    rows.removeAt(i).dispose();
                    _changed();
                  },
                  icon: const Icon(Icons.delete_outline, size: 20),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── 字型：標楷體（先準備好，還沒套用） ─────────────────────────

/// 標楷體：用 Windows 內建的「標楷體」（DFKai-SB），不把字型檔包進 app（標楷體是授權字型，不能自己散佈）。
/// 之後要用時：Text('…', style: AppFonts.kai(const TextStyle(fontSize: 40)))
/// 或整個 app 套用：ThemeData(fontFamily: AppFonts.kaiFamily, …)
class AppFonts {
  static const kaiFamily = 'DFKai-SB';
  /// 找不到標楷體時依序改用這些（Mac 的楷體、全字庫正楷體…）
  static const kaiFallback = ['標楷體', 'BiauKai', 'TW-Kai', 'KaiTi', 'STKaiti'];

  static TextStyle kai([TextStyle base = const TextStyle()]) =>
      base.copyWith(fontFamily: kaiFamily, fontFamilyFallback: kaiFallback);
}

// ───────────────────────── 大屏首頁「政策」：729 蓋章政策（修正版），一張紙的樣子、標楷體 ─────────────────────────

const _policySections = <(String, List<String>)>[
  ('一、說明描述', [
    '指定管理者保管印章，所有幹部要蓋章皆須經過管理者同意領取印章後才可蓋章。',
    '確實完成幹部、排長職責，或經任課教師認證之小老師，可以由導師或管理者蓋章。',
    '有蓋章權之幹部可以觀察同學並通知管理者進行加扣章，但不可隨意執行，必要時應找證人當作證據。',
    '印章分成結算章和兌換章。',
    '加章時兩種各 +1，扣章時兩種各 -1。',
    '結算章：結算前可以加扣，不能拿來兌換，作為期末換座位之依據。',
    '兌換章只能用來兌換物品，兌換後扣除相對章數，不能作為換座位之依據。',
    '兌換章可以奉獻（假設 1 人捐 5 個章，全班 29 個人，共 145 章，獎品若為 100 章，即可兌換，且全班都獲得禮品），奉獻總數達到目標後全班都會得到獎勵；目標章數依獎品價值決定。',
    '獎項或其他項目由全班在班會課共同決定，不可自行修改（提名、投票表決）。',
    '同一週內被扣滿 5 章時，需進行懲罰處理。',
    '被亂扣章後 3 天內可以申訴，可以找教師處理。',
    '申訴期間，該筆紀錄先保留，不列入懲罰之計算。',
    '數位化：在大屏上蓋章，並加上排行榜，讓同學可以用手機查看自己的章數。',
  ]),
  ('二、蓋章項目', [
    '班長、副班長、榮譽股長（正副）、內掃管理者、外掃管理者、午餐股長、資訊股長、聯絡簿長，每週選三個填寫理由經由管理者同意後蓋章。',
    '小老師須蓋章者，最多以三個為限，填寫理由經由管理者同意後蓋章。',
    '每排排長每天檢查作業，每天皆準時或提早完成作業者，與管理者說明理由並經由同意後蓋一個章。',
    '檢查排長蓋 1–2 個章。',
    '確實完成幹部、排長職責，或經任課教師認證之小老師，可以由導師或管理者蓋章。',
    '舉報違規之同學且有證人者兩者皆可蓋一章，填寫理由經由管理者同意後蓋章。',
    '抓到亂丟垃圾並舉報者，即可蓋章，填寫理由經由管理者同意後蓋章。',
  ]),
  ('三、扣章項目', [
    '班長、副班長、榮譽股長（正副）、內掃管理者、外掃管理者、午餐股長、資訊股長、聯絡簿長，每週選三個填寫理由經由管理者同意後蓋章，扣章填寫名單，由教師或管理者處理。',
    '小老師須蓋章者，最多以三個為限，填寫理由經由管理者同意後蓋章，扣章填寫名單，由教師或管理者處理。',
    '若有人未經允許擅自使用、遊玩大屏與黑板，資訊股長可依情況扣章並給予處罰。',
    '一節下課時間使用大屏扣除一章。',
    '下課時間只能使用簽到、登記、查看功能，其他操作需經教師或資訊股長同意。',
    '要帶食物進班都要登記（不管大的小的貴的便宜的好吃得不好吃的），若違反規定被抓到扣除兩章印章。',
    '亂丟垃圾者扣章，填寫理由經由管理者同意後扣章。',
    '中午 12：05～12：25 無理由離開座位者扣章，填寫理由經由管理者同意後扣章。',
    '早自習教師不在教室，離開座位者扣章，填寫理由經由管理者同意後扣章。',
    '隨意亂畫黑板者扣章，填寫理由經由管理者同意後扣章。',
    '寧靜日吵鬧或擾亂上課秩序、干擾上課進度者，填寫理由經由管理者同意後扣章。',
    '臨時有需要扣章之情況，由教師或管理者決定。',
  ]),
  ('四、規則', [
    '經授權之幹部可以執行加扣章。',
    '一個理由只能加扣一章，有其他需求須通知教師。',
    '全班共同表決之結果擁有最高決定權。',
    '每個人都有參與之權利，蓋章者禁止出現刻板印象、偏見、歧視等行為。',
    '出現異議時，進行全班表決；表決結果需經教師同意。',
    '額外之加扣章須找證人。',
    '參與者須接受獎勵和處罰，不可拒絕。',
    '福和國中七年二十九班所有學生皆為參與者。',
    '除不可抗拒之理由外，懲罰須在達到門檻後的隔天下午 4：00 前完成。',
    '禁止濫用權利進行不適當之活動，例如威脅、交易。',
  ]),
  ('五、規則違約條', [
    '幹部違反第二、四、六、十條：取消蓋章權。',
    '違反第七、九條：需額外處罰。',
  ]),
  ('六、懲罰（累扣五章時抽籤決定）', [
    '不能兌換獎勵',
    '上台跳舞（至少30秒）',
    '幫忙倒垃圾',
    '外掃區掃地',
    '搬餐桶（一個月）',
    '出錢買獎勵',
  ]),
  ('七、獎勵', [
    '合作社禮卷（教師決定）',
    '餅乾（教師決定）',
    '由被處罰同學出錢',
    '免死金牌*1（一個月限用一次）',
    '札記免一周',
  ]),
];

/// 內建的政策全文（教師後台沒改過時用這份）
String get defaultPolicyText => [
      '729 蓋章政策（修正版）',
      for (final (title, items) in _policySections) ...['', title, ...items],
    ].join('\n');

String policyTextOf(AppState state) => state.policyText.trim().isEmpty ? defaultPolicyText : state.policyText;

/// 把政策文字拆成：標題、[(段落標題, 條文)]。「一、」「二、」開頭的行是段落標題
(String, List<(String, List<String>)>) parsePolicy(String text) {
  final lines = text.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
  if (lines.isEmpty) return ('', []);
  final heading = RegExp(r'^[一二三四五六七八九十]+、');
  var title = '';
  var start = 0;
  if (!heading.hasMatch(lines.first)) {
    title = lines.first;
    start = 1;
  }
  final sections = <(String, List<String>)>[];
  for (final l in lines.skip(start)) {
    if (heading.hasMatch(l) || sections.isEmpty) {
      sections.add((heading.hasMatch(l) ? l : '', heading.hasMatch(l) ? <String>[] : <String>[l]));
    } else {
      sections.last.$2.add(l);
    }
  }
  return (title, sections);
}

Future<void> showPolicyPaper(BuildContext context, AppState state) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '關閉',
    barrierColor: const Color(0xB3606770), // 旁邊留灰
    transitionDuration: const Duration(milliseconds: 260),
    transitionBuilder: (context, a, _, child) {
      final v = Curves.easeOutCubic.transform(a.value);
      return Opacity(
        opacity: a.value,
        child: Transform.translate(offset: Offset(0, 40 * (1 - v)), child: child),
      );
    },
    pageBuilder: (context, _, __) => _PolicyPaper(text: policyTextOf(state)),
  );
}

class _PolicyPaper extends StatelessWidget {
  final String text;
  const _PolicyPaper({required this.text});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final h = size.height * 0.94;
    // 跟 A4 紙差不多寬（約 21 公分，螢幕上大概 900）；內容太長就在紙上往下捲
    final w = min(size.width * 0.92, max(h / 1.414, 900.0));
    const ink = Color(0xFF1A1A1A);
    TextStyle kai(double s, {FontWeight w = FontWeight.w400, double height = 1.7}) =>
        AppFonts.kai(TextStyle(fontSize: s, fontWeight: w, height: height, color: ink));
    final k = w / 800; // 字級以紙寬 800 為基準
    final (paperTitle, sections) = parsePolicy(text);
    return Center(
      child: Material(
        color: const Color(0xFFFFFFFE),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFF272343), width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: SizedBox(
          width: w,
          height: h,
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(90 * k, 80 * k, 90 * k, 90 * k),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (paperTitle.isNotEmpty)
                        Center(child: Text(paperTitle, style: kai(40 * k, w: FontWeight.w700, height: 1.3))),
                      SizedBox(height: 36 * k),
                      for (final (title, items) in sections) ...[
                        SizedBox(height: 26 * k),
                        if (title.isNotEmpty) Text(title, style: kai(26 * k, w: FontWeight.w700)),
                        SizedBox(height: 10 * k),
                        for (var i = 0; i < items.length; i++)
                          Padding(
                            padding: EdgeInsets.only(left: 16 * k, bottom: 10 * k),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                SizedBox(width: 48 * k, child: Text('${i + 1}.', style: kai(20 * k, height: 1.8))),
                                Expanded(child: Text(items[i], style: kai(20 * k, height: 1.8))),
                              ],
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                right: 8,
                top: 8,
                child: IconButton(
                  tooltip: '關閉',
                  onPressed: () => Navigator.pop(context),
                  icon: const AppIcon(AppIcons.close, size: 26, color: AppTokens.ink),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 教師後台：編輯蓋章政策（大屏首頁「政策」顯示這份）
class PolicyAdminPage extends StatefulWidget {
  final AppState state;
  const PolicyAdminPage({super.key, required this.state});

  @override
  State<PolicyAdminPage> createState() => _PolicyAdminPageState();
}

class _PolicyAdminPageState extends State<PolicyAdminPage> {
  late final ctrl = TextEditingController(text: policyTextOf(widget.state));
  Timer? _saveTimer;

  @override
  void dispose() {
    if (_saveTimer?.isActive ?? false) {
      _saveTimer!.cancel();
      widget.state.savePolicyText(ctrl.text);
    }
    ctrl.dispose();
    super.dispose();
  }

  void _changed(String _) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 800), () => widget.state.savePolicyText(ctrl.text));
  }

  Future<void> _reset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('恢復成內建的修正版政策？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('恢復')),
        ],
      ),
    );
    if (ok != true) return;
    ctrl.text = defaultPolicyText;
    await widget.state.savePolicyText('');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('第一行是標題；「一、」「二、」開頭的行是段落標題；其他每一行是一條規定。改完會自動儲存並同步到大屏。',
                    style: TextStyle(color: scheme.onSurfaceVariant)),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(onPressed: _reset, icon: const Icon(Icons.restore), label: const Text('恢復預設')),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () async {
                  await widget.state.savePolicyText(ctrl.text);
                  if (context.mounted) await showPolicyPaper(context, widget.state);
                },
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('預覽'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: scheme.outline, width: AppTokens.hairline),
              ),
              child: TextField(
                controller: ctrl,
                onChanged: _changed,
                expands: true,
                maxLines: null,
                style: AppFonts.kai(const TextStyle(fontSize: 18, height: 1.7)),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── 外部頭像資料夾（exe 旁邊的「頭像」） ─────────────────────────

/// exe 旁邊的「頭像」資料夾：
///   1.png、2.png…（檔名 = 座號）丟進去就會顯示；
///   「頭像設定.txt」每行「座號 = 左, 上, 寬, 高」，隨時用記事本改，改完在 app 按 F5。
/// 自動更新只會蓋 app 本身，不會動這個資料夾。
class ExternalAvatars {
  static const folderName = '頭像';
  static const settingsName = '頭像設定.txt';
  static final version = ValueNotifier<int>(0);
  static final Map<String, File> _files = {};
  static final Map<String, AvatarTweak> _tweaks = {};
  static AvatarTweak? _default;
  static bool _hasSettings = false;

  static Directory? get _dir {
    if (kIsWeb || !Platform.isWindows) return null;
    return Directory('${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}$folderName');
  }

  static File? fileFor(String seat) => _files[seat];

  /// 有「頭像設定.txt」就完全照它（沒寫到的座號用它的「預設」）；沒有才用 lib/ui_tweaks.dart
  static AvatarTweak tweakFor(String seat) => _hasSettings
      ? (_tweaks[seat] ?? _default ?? defaultAvatarTweak)
      : (avatarTweaks[seat] ?? defaultAvatarTweak);

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();
  static String _line(String key, AvatarTweak t) =>
      '$key = ${_fmt(t.left)}, ${_fmt(t.top)}, ${_fmt(t.width)}, ${_fmt(t.height)}';

  /// 第一次：建立資料夾，放入打包在 app 裡的頭像和目前的設定
  static Future<void> init() async {
    final dir = _dir;
    if (dir == null) return;
    try {
      if (!dir.existsSync()) dir.createSync(recursive: true);
      // 每次打開：app 裡有、資料夾裡還沒有的圖片檔就放進去（去背的 png 和原圖 jpg 都會放；
      // 同一個座號兩個都有時顯示 png，去背不好看就把那張 png 刪掉，改用原圖）。已經在資料夾裡的不會被蓋掉
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final asset in manifest.listAssets().where((a) => a.startsWith('assets/avatars/'))) {
        final name = asset.split('/').last;
        final target = File('${dir.path}${Platform.pathSeparator}$name');
        if (target.existsSync()) continue;
        final data = await rootBundle.load(asset);
        target.writeAsBytesSync(data.buffer.asUint8List());
      }
      final settings = File('${dir.path}${Platform.pathSeparator}$settingsName');
      if (settings.existsSync()) {
        // 設定檔裡還沒有的座號，用 app 裡的數字補在最後面（已經寫的不會動）
        final text = settings.readAsStringSync();
        final have = RegExp(r'^\s*(\S+?)\s*[=＝]', multiLine: true).allMatches(text).map((m) => m.group(1)).toSet();
        final missing = [for (final e in avatarTweaks.entries) if (!have.contains(e.key)) _line(e.key, e.value)];
        if (missing.isNotEmpty) {
          settings.writeAsStringSync('${text.endsWith('\n') ? '' : '\r\n'}${missing.join('\r\n')}\r\n',
              mode: FileMode.append);
        }
      } else {
        final lines = [
          '# 頭像設定：每行「座號 = 左, 上, 寬, 高」',
          '# 左：負越多越往左；上：負越多越往上；寬、高：圖片大小',
          '# 圖片放在同一個資料夾，檔名就是座號（例如 7.png）',
          '# 改完存檔，回到 app 按 F5 就會更新',
          '',
          _line('預設', defaultAvatarTweak),
          for (final e in avatarTweaks.entries) _line(e.key, e.value),
        ];
        // 加 BOM，記事本打開中文不會亂碼
        settings.writeAsStringSync('﻿${lines.join('\r\n')}\r\n');
      }
    } catch (_) {}
    await reload();
  }

  /// 重新讀資料夾裡的圖片和設定
  static Future<String> reload() async {
    final dir = _dir;
    if (dir == null) return '只有 Windows 版支援頭像資料夾';
    try {
      if (!dir.existsSync()) return '找不到「$folderName」資料夾';
      _files.clear();
      _tweaks.clear();
      _default = null;
      for (final f in dir.listSync().whereType<File>()) {
        final name = f.uri.pathSegments.last;
        final m = RegExp(r'^(\d+)\.(png|jpe?g|webp|gif)$', caseSensitive: false).firstMatch(name);
        // 同一個座號有 png 也有 jpg 時，用 png（去背過的）
        if (m != null && !(_files[m.group(1)!]?.path.toLowerCase().endsWith('.png') ?? false)) _files[m.group(1)!] = f;
      }
      final settings = File('${dir.path}${Platform.pathSeparator}$settingsName');
      var bad = 0;
      _hasSettings = settings.existsSync();
      if (_hasSettings) {
        for (var line in settings.readAsLinesSync()) {
          line = line.replaceAll('﻿', '').trim();
          if (line.isEmpty || line.startsWith('#')) continue;
          final parts = line.split(RegExp(r'[=＝]'));
          if (parts.length != 2) {
            bad++;
            continue;
          }
          final nums = parts[1].split(RegExp(r'[,，\s]+')).where((e) => e.isNotEmpty).map(double.tryParse).toList();
          if (nums.length != 4 || nums.contains(null)) {
            bad++;
            continue;
          }
          final t = AvatarTweak(left: nums[0]!, top: nums[1]!, width: nums[2]!, height: nums[3]!);
          final key = parts[0].trim();
          if (key == '預設') {
            _default = t;
          } else {
            _tweaks[key] = t;
          }
        }
      }
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
      version.value++;
      return '已重新載入 ${_files.length} 張頭像${bad > 0 ? '（設定檔有 $bad 行看不懂，已略過）' : ''}';
    } catch (e) {
      return '重新載入失敗：$e';
    }
  }
}

