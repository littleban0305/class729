import 'dart:async';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'main.dart' show MainShell, ReminderPage, LotteryPage, SeatPage, DiaryPage, SchedulePage;
import 'services/auth_service.dart';
import 'teacher_pages.dart' show BigScreenPage;

/// Decides what a device is allowed to see: an unconfigured device must pick a
/// role first, a "大屏" device only ever gets the read-only sign-in screen, and
/// a "教師" device must log in (when cloud is configured) before reaching [MainShell].
class DeviceRoleGate extends StatefulWidget {
  final AppState state;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  const DeviceRoleGate({super.key, required this.state, required this.onThemeModeChanged});

  @override
  State<DeviceRoleGate> createState() => _DeviceRoleGateState();
}

class _DeviceRoleGateState extends State<DeviceRoleGate> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.state,
      builder: (context, _) {
        switch (widget.state.deviceRole) {
          case 'bigscreen':
            return BigScreenDeviceShell(state: widget.state);
          case 'teacher':
            return AuthGate(state: widget.state, onThemeModeChanged: widget.onThemeModeChanged);
          default:
            return DeviceRoleSetupPage(state: widget.state);
        }
      },
    );
  }
}

class DeviceRoleSetupPage extends StatelessWidget {
  final AppState state;
  const DeviceRoleSetupPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('729', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              const Text('這台裝置要作為什麼用途？', style: TextStyle(fontSize: 18)),
              const SizedBox(height: 28),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.admin_panel_settings_outlined, size: 32),
                  title: const Text('教師管理裝置', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('可以編輯提醒、座位、聯絡簿、簽到、整潔、照片等所有後台功能，需要登入'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => state.setDeviceRole('teacher'),
                ),
              ),
              const SizedBox(height: 14),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.tv_outlined, size: 32),
                  title: const Text('大屏 / 簽到裝置', style: TextStyle(fontWeight: FontWeight.w800)),
                  subtitle: const Text('只能顯示提醒與讓同學簽到，沒有任何管理權限，不需要登入'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => state.setDeviceRole('bigscreen'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Big-screen devices never see admin UI — this is the entire widget tree they get.
class BigScreenDeviceShell extends StatefulWidget {
  final AppState state;
  const BigScreenDeviceShell({super.key, required this.state});

  @override
  State<BigScreenDeviceShell> createState() => _BigScreenDeviceShellState();
}

class _BigScreenDeviceShellState extends State<BigScreenDeviceShell> {
  StreamSubscription<Map<String, dynamic>?>? _cloudSubscription;
  String _watchedClassId = '';
  int page = 0;

  final labels = const ['首頁', '提醒', '選號', '座位表', '聯絡簿', '課表'];
  final icons = const [
    Icons.dashboard_outlined,
    Icons.notifications_none,
    Icons.casino_outlined,
    Icons.grid_view,
    Icons.menu_book_outlined,
    Icons.calendar_month_outlined,
  ];

  @override
  void initState() {
    super.initState();
    _syncCloudListener();
  }

  @override
  void didUpdateWidget(covariant BigScreenDeviceShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncCloudListener();
  }

  void _syncCloudListener() {
    final id = widget.state.classId.trim();
    if (id == _watchedClassId) return;
    _watchedClassId = id;
    _cloudSubscription?.cancel();
    _cloudSubscription = null;
    if (!widget.state.cloudSyncEnabled || id.isEmpty) return;
    _cloudSubscription = widget.state.cloud.watchPublicState(id).listen((data) {
      if (data == null) return;
      widget.state.applyPublicCloudData(data);
    });
  }

  @override
  void dispose() {
    _cloudSubscription?.cancel();
    super.dispose();
  }

  Widget _page() {
    switch (page) {
      case 1:
        return ReminderPage(state: widget.state);
      case 2:
        return LotteryPage(state: widget.state);
      case 3:
        return SeatPage(state: widget.state);
      case 4:
        return DiaryPage(state: widget.state, editable: false);
      case 5:
        return SchedulePage(state: widget.state, editable: false);
      default:
        return BigScreenPage(state: widget.state);
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncCloudListener();
    final mobile = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
      appBar: mobile
          ? AppBar(
              title: Text(labels[page], style: const TextStyle(fontWeight: FontWeight.w800)),
              actions: [
                IconButton(
                  tooltip: '裝置設定',
                  icon: const Icon(Icons.settings_outlined),
                  onPressed: () => _showDeviceSettings(context),
                )
              ],
            )
          : null,
      drawer: mobile
          ? Drawer(
              child: SafeArea(
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(10, 12, 10, 16),
                  itemCount: labels.length + 2,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return const Padding(
                        padding: EdgeInsets.fromLTRB(14, 10, 14, 18),
                        child: Text('729', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
                      );
                    }
                    if (index == labels.length + 1) {
                      return ListTile(
                        leading: const Icon(Icons.settings_outlined),
                        title: const Text('裝置設定'),
                        onTap: () {
                          Navigator.pop(context);
                          _showDeviceSettings(context);
                        },
                      );
                    }
                    final i = index - 1;
                    return ListTile(
                      selected: page == i,
                      leading: Icon(icons[i]),
                      title: Text(labels[i]),
                      onTap: () {
                        setState(() => page = i);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            )
          : null,
      body: mobile
          ? AnimatedSwitcher(duration: const Duration(milliseconds: 160), child: _page())
          : Stack(
              children: [
                Row(
                  children: [
                    _BigScreenRail(
                      labels: labels,
                      icons: icons,
                      current: page,
                      onSelect: (value) => setState(() => page = value),
                    ),
                    Expanded(child: AnimatedSwitcher(duration: const Duration(milliseconds: 160), child: _page())),
                  ],
                ),
                Positioned(
                  right: 10,
                  top: 10,
                  child: IconButton(
                    tooltip: '裝置設定',
                    icon: const Icon(Icons.settings_outlined),
                    onPressed: () => _showDeviceSettings(context),
                  ),
                )
              ],
            ),
    );
  }

  Future<void> _showDeviceSettings(BuildContext context) async {
    final controller = TextEditingController(text: widget.state.classId);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('大屏裝置設定'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: controller, decoration: const InputDecoration(labelText: '班級代碼（與教師端相同才能同步）')),
          const SizedBox(height: 12),
          const Align(
              alignment: Alignment.centerLeft,
              child: Text('這台裝置沒有管理權限，只能顯示與簽到。', style: TextStyle(color: Colors.black54))),
        ]),
        actions: [
          TextButton(
            onPressed: () async {
              await widget.state.setDeviceRole('');
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('改回選擇裝置用途'),
          ),
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
          FilledButton(
            onPressed: () async {
              await widget.state.setClassId(controller.text.trim());
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('儲存'),
          ),
        ],
      ),
    );
    controller.dispose();
  }
}

class _BigScreenRail extends StatelessWidget {
  final List<String> labels;
  final List<IconData> icons;
  final int current;
  final ValueChanged<int> onSelect;

  const _BigScreenRail({required this.labels, required this.icons, required this.current, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF171A24),
      child: SizedBox(
        width: 190,
        child: SafeArea(
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 18, 18, 14),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('729', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
                ),
              ),
              for (int i = 0; i < labels.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  child: Material(
                    color: current == i ? const Color(0xFF30364A) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelect(i),
                      child: SizedBox(
                        height: 50,
                        child: Row(
                          children: [
                            const SizedBox(width: 14),
                            Icon(icons[i], color: Colors.white70),
                            const SizedBox(width: 12),
                            Text(labels[i], style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              const Padding(
                padding: EdgeInsets.all(14),
                child: Text('大屏模式', style: TextStyle(color: Colors.white54)),
              )
            ],
          ),
        ),
      ),
    );
  }
}

/// Gates the full teacher app behind a login when cloud sync is configured; falls
/// back to a one-time acknowledgement when Firebase hasn't been set up yet.
class AuthGate extends StatefulWidget {
  final AppState state;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  const AuthGate({super.key, required this.state, required this.onThemeModeChanged});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final auth = AuthService();
  bool localModeAccepted = false;

  @override
  Widget build(BuildContext context) {
    if (!auth.isConfigured) {
      if (!localModeAccepted) {
        return Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.cloud_off_outlined, size: 48),
                  const SizedBox(height: 16),
                  const Text('雲端登入尚未設定', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  const Text('需要先執行 flutterfire configure 並填入 firebase_options.dart 才能啟用帳號登入與雲端同步。目前可以先以本機模式使用。',
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: () => setState(() => localModeAccepted = true), child: const Text('以本機模式繼續')),
                ]),
              ),
            ),
          ),
        );
      }
      return MainShell(state: widget.state, onThemeModeChanged: widget.onThemeModeChanged);
    }

    return StreamBuilder(
      stream: auth.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snapshot.data == null) {
          return LoginPage(auth: auth);
        }
        return MainShell(state: widget.state, onThemeModeChanged: widget.onThemeModeChanged);
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  final AuthService auth;
  const LoginPage({super.key, required this.auth});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  bool signUpMode = false;
  bool loading = false;
  String? error;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    final message = signUpMode
        ? await widget.auth.signUp(emailController.text, passwordController.text)
        : await widget.auth.signIn(emailController.text, passwordController.text);
    if (!mounted) return;
    setState(() {
      loading = false;
      error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('729 教師登入', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
              const SizedBox(height: 24),
              TextField(
                  controller: emailController,
                  decoration: const InputDecoration(labelText: '帳號 Email'),
                  keyboardType: TextInputType.emailAddress),
              const SizedBox(height: 12),
              TextField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: '密碼'),
                  obscureText: true),
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, style: const TextStyle(color: Colors.red)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: loading ? null : _submit,
                child: Text(loading ? '處理中...' : (signUpMode ? '註冊並登入' : '登入')),
              ),
              TextButton(
                onPressed: () => setState(() => signUpMode = !signUpMode),
                child: Text(signUpMode ? '已經有帳號？改為登入' : '第一次使用？註冊教師帳號'),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Teacher-only tab (inside AdminPage) for classId + manual push/pull + sign out.
class CloudDevicePage extends StatefulWidget {
  final AppState state;
  const CloudDevicePage({super.key, required this.state});

  @override
  State<CloudDevicePage> createState() => _CloudDevicePageState();
}

class _CloudDevicePageState extends State<CloudDevicePage> {
  final auth = AuthService();
  late final TextEditingController classIdController;
  String? message;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    classIdController = TextEditingController(text: widget.state.classId);
  }

  @override
  void dispose() {
    classIdController.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() {
      busy = true;
      message = null;
    });
    final result = await action();
    if (!mounted) return;
    setState(() {
      busy = false;
      message = result ?? '完成';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 720 ? 12 : 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('雲端與裝置', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 16),
        Text(auth.isConfigured ? '雲端同步：已設定' : '雲端同步：尚未設定（需執行 flutterfire configure）',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 620;
            final editor = TextField(
              controller: classIdController,
              decoration: const InputDecoration(labelText: '班級代碼（大屏裝置需輸入相同代碼）'),
            );
            final save = FilledButton(
              onPressed: () async {
                await widget.state.setClassId(classIdController.text.trim());
                await widget.state.setDeviceRole(widget.state.deviceRole);
                widget.state.cloudSyncEnabled = auth.isConfigured;
                setState(() => message = '班級代碼已儲存');
              },
              child: const Text('儲存代碼'),
            );
            return compact
                ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [editor, const SizedBox(height: 10), save])
                : Row(children: [Expanded(child: editor), const SizedBox(width: 12), save]);
          },
        ),
        const SizedBox(height: 16),
        Wrap(spacing: 12, runSpacing: 12, children: [
          FilledButton.icon(
            onPressed: busy || !auth.isConfigured
                ? null
                : () => _run(() async {
                      await widget.state.cloud.pushState(widget.state.classId, widget.state.exportData());
                      return '已上傳到雲端';
                    }),
            icon: const Icon(Icons.cloud_upload_outlined),
            label: const Text('立即上傳到雲端'),
          ),
          OutlinedButton.icon(
            onPressed: busy || !auth.isConfigured ? null : () => _run(() => widget.state.pullFromCloud()),
            icon: const Icon(Icons.cloud_download_outlined),
            label: const Text('從雲端下載並覆蓋本機'),
          ),
          OutlinedButton.icon(
            onPressed: () async {
              await auth.signOut();
              await widget.state.setDeviceRole('');
            },
            icon: const Icon(Icons.logout),
            label: const Text('登出並改回選擇裝置用途'),
          ),
        ]),
        if (message != null) ...[
          const SizedBox(height: 14),
          Text(message!),
        ],
      ]),
    );
  }
}
