import 'dart:async';

import 'package:flutter/material.dart';

import 'app_state.dart';
import 'firebase_config_flag.dart';
import 'models.dart';
import 'main.dart'
    show
        MainShell,
        ReminderPresentation,
        LotteryPage,
        SeatPage,
        DiaryPage,
        SchedulePage,
        TeacherMobileDrawer,
        WindowBar,
        SideBar;
import 'services/auth_service.dart';

/// Decides what a device is allowed to see: an unconfigured device must pick a
/// role first, a "大屏" device only gets the public classroom interface and attendance, with editable 聯絡簿 as a limited exception, and
/// a "教師" device must log in (when cloud is configured) before reaching [MainShell].
class DeviceRoleGate extends StatefulWidget {
  final AppState state;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  const DeviceRoleGate({
    super.key,
    required this.state,
    required this.onThemeModeChanged,
  });

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
            return AuthGate(
              state: widget.state,
              onThemeModeChanged: widget.onThemeModeChanged,
            );
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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    '729',
                    style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 8),
                  const Text('這台裝置要作為什麼用途？', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 28),
                  Card(
                    child: ListTile(
                      leading: const Icon(
                        Icons.admin_panel_settings_outlined,
                        size: 32,
                      ),
                      title: const Text(
                        '教師管理裝置',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => state.setDeviceRole('teacher'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.tv_outlined, size: 32),
                      title: const Text(
                        '大屏 / 簽到裝置',
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => state.setDeviceRole('bigscreen'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Big-screen devices never see teacher admin UI. They expose public classroom pages and a limited editable 聯絡簿.
class BigScreenDeviceShell extends StatefulWidget {
  final AppState state;
  const BigScreenDeviceShell({super.key, required this.state});

  @override
  State<BigScreenDeviceShell> createState() => _BigScreenDeviceShellState();
}

class _BigScreenDeviceShellState extends State<BigScreenDeviceShell> {
  int page = 0;
  bool compact = false;

  final labels = const ['提醒', '登記', '選號', '座位表', '聯絡簿', '課表'];
  final icons = const [
    Icons.notifications_none,
    Icons.assignment_outlined,
    Icons.casino_outlined,
    Icons.grid_view_outlined,
    Icons.menu_book_outlined,
    Icons.calendar_month_outlined,
  ];
  Widget _page() {
    switch (page) {
      case 1:
        return BigScreenRegistrationPage(state: widget.state);
      case 2:
        return LotteryPage(state: widget.state);
      case 3:
        return SeatPage(state: widget.state);
      case 4:
        return DiaryPage(state: widget.state, editable: true);
      case 5:
        return SchedulePage(state: widget.state, editable: false);
      case 0:
      default:
        return ReminderPresentation(state: widget.state);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      drawer: mobile
          ? TeacherMobileDrawer(
              labels: labels,
              icons: icons,
              current: page,
              onSelect: (value) => setState(() => page = value),
              extraItems: [
                ListTile(
                  leading: const Icon(Icons.logout_outlined),
                  title: const Text('退出'),
                  onTap: () async {
                    Navigator.pop(context);
                    await widget.state.setDeviceRole('');
                  },
                ),
              ],
            )
          : null,
      body: mobile
          ? SafeArea(
              top: true,
              bottom: false,
              child: Stack(
                children: [
                  Column(
                    children: [
                      Builder(
                        builder: (barContext) => WindowBar(
                          title: labels[page],
                          mobile: mobile,
                          onOpenMenu: () => Scaffold.of(barContext).openDrawer(),
                        ),
                      ),
                      Expanded(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: _page(),
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
                    const WindowBar(title: '大屏'),
                    Expanded(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 160),
                        child: _page(),
                      ),
                    ),
                  ],
                ),
                SideBar(
                  expanded: !compact,
                  current: page,
                  labels: labels,
                  icons: icons,
                  onSelect: (value) => setState(() => page = value),
                  onToggle: () => setState(() => compact = !compact),
                  onExit: () async {
                    await widget.state.setDeviceRole('');
                  },
                ),
              ],
            ),
    );
  }
}

class BigScreenRegistrationPage extends StatefulWidget {
  final AppState state;
  const BigScreenRegistrationPage({super.key, required this.state});

  @override
  State<BigScreenRegistrationPage> createState() => _BigScreenRegistrationPageState();
}

class _BigScreenRegistrationPageState extends State<BigScreenRegistrationPage> {
  String type = '整潔';
  final selected = <String>{};
  final excellent = <String>{};
  final needsWork = <String>{};
  final noteController = TextEditingController();
  bool sending = false;

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if ((type == '整潔' ? excellent.isEmpty && needsWork.isEmpty : selected.isEmpty) || sending) return;
    setState(() => sending = true);
    var success = true;
    final groups =
        type == '整潔' ? <String, Set<String>>{'優秀': excellent, '待改進': needsWork} : <String, Set<String>>{'': selected};
    for (final entry in groups.entries) {
      for (final student in widget.state.students.where((student) => entry.value.contains(student.number))) {
        final sent = await widget.state.submitRegistration(
          student: student,
          type: type,
          note: type == '整潔' ? entry.key : noteController.text.trim(),
        );
        success = success && sent;
      }
    }
    if (!mounted) return;
    setState(() {
      sending = false;
      selected.clear();
      excellent.clear();
      needsWork.clear();
      noteController.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success ? '已送出' : '送出失敗，請確認雲端設定')));
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final students = widget.state.students;
    final cleanliness = type == '整潔';
    return ListView(
      padding: EdgeInsets.fromLTRB(mobile ? 14 : 24, 12, mobile ? 14 : 24, 28),
      children: [
        Text('登記', style: TextStyle(fontSize: mobile ? 28 : 34, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: '整潔', label: Text('整潔'), icon: Icon(Icons.cleaning_services_outlined)),
            ButtonSegment(value: '秩序不佳', label: Text('秩序不佳'), icon: Icon(Icons.gavel_outlined)),
            ButtonSegment(value: '晚進教室', label: Text('晚進教室'), icon: Icon(Icons.login_outlined)),
          ],
          selected: {type},
          onSelectionChanged: (value) => setState(() {
            type = value.first;
            selected.clear();
            excellent.clear();
            needsWork.clear();
          }),
        ),
        const SizedBox(height: 18),
        Text(cleanliness ? '選擇本次整潔評選同學（最多 3 位）' : '選擇同學後送出登記',
            style: TextStyle(fontSize: 16, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        if (cleanliness) ...[
          const Text('優秀（最多 3 位）', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _studentChips(students, excellent, needsWork),
          const SizedBox(height: 14),
          const Text('待改進（最多 3 位）', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          _studentChips(students, needsWork, excellent),
        ] else
          _studentChips(students, selected, const <String>{}),
        const SizedBox(height: 16),
        TextField(
          controller: noteController,
          maxLines: 2,
          decoration: InputDecoration(
            labelText: cleanliness ? '備註（可不填）' : '備註（可不填）',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed:
              (type == '整潔' ? excellent.isEmpty && needsWork.isEmpty : selected.isEmpty) || sending ? null : _submit,
          icon: const Icon(Icons.send_outlined),
          label: Text(sending ? '送出中...' : '送出'),
        ),
      ],
    );
  }

  Widget _studentChips(List<SeatData> students, Set<String> selected, Set<String> other) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: students.map((student) {
        final picked = selected.contains(student.number);
        return FilterChip(
          label: Text(student.name),
          selected: picked,
          onSelected: other.contains(student.number)
              ? null
              : (_) => setState(() {
                    if (picked) {
                      selected.remove(student.number);
                    } else if (selected.length < 3 || type != '整潔') {
                      selected.add(student.number);
                    }
                  }),
        );
      }).toList(),
    );
  }
}

class BigScreenStudentRecordPage extends StatefulWidget {
  final AppState state;
  final String type;
  const BigScreenStudentRecordPage({super.key, required this.state, required this.type});

  @override
  State<BigScreenStudentRecordPage> createState() => _BigScreenStudentRecordPageState();
}

class _BigScreenStudentRecordPageState extends State<BigScreenStudentRecordPage> {
  SeatData? selected;
  final noteController = TextEditingController();

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final student = selected;
    if (student == null) return;
    await widget.state.addStudentRecord(
      student: student,
      type: widget.type,
      note: noteController.text.trim(),
    );
    noteController.clear();
    if (mounted) setState(() => selected = null);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${student.name} 已登記「${widget.type}」')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 720;
    final students = widget.state.students;
    return ListView(
      padding: EdgeInsets.fromLTRB(mobile ? 14 : 24, 12, mobile ? 14 : 24, 28),
      children: [
        Text(widget.type, style: TextStyle(fontSize: mobile ? 28 : 34, fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        Text('選擇同學後登記',
            style: TextStyle(fontSize: mobile ? 16 : 18, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 14),
        if (students.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('目前沒有同學資料')))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: mobile ? 2 : 4,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              mainAxisExtent: mobile ? 64 : 72,
            ),
            itemCount: students.length,
            itemBuilder: (_, i) {
              final student = students[i];
              final picked = selected?.number == student.number;
              return FilledButton.tonal(
                onPressed: () => setState(() => selected = student),
                style: FilledButton.styleFrom(
                  backgroundColor: picked ? Theme.of(context).colorScheme.primaryContainer : null,
                ),
                child: Text('${student.number}  ${student.name}', maxLines: 1, overflow: TextOverflow.ellipsis),
              );
            },
          ),
        const SizedBox(height: 14),
        TextField(
          controller: noteController,
          maxLines: 2,
          decoration: const InputDecoration(labelText: '備註', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: selected == null ? null : _submit,
          icon: const Icon(Icons.check),
          label: Text('登記${widget.type}'),
        ),
      ],
    );
  }
}

class BigScreenAttendancePage extends StatefulWidget {
  final AppState state;
  const BigScreenAttendancePage({super.key, required this.state});

  @override
  State<BigScreenAttendancePage> createState() => _BigScreenAttendancePageState();
}

class _BigScreenAttendancePageState extends State<BigScreenAttendancePage> {
  final pending = <String>{};

  String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  Future<void> _confirmAttendance(SeatData student) async {
    if (pending.contains(student.number)) return;
    final now = widget.state.reminderNow;
    final late = widget.state.isLateAt(now);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('確認簽到'),
        content: Text('${student.name}\n${late ? '目前將記錄為遲到。' : '目前將記錄為準時。'}\n確定要簽到嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('確認簽到'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final current = widget.state.reminderNow;
    final today = _date(current);
    final alreadySigned = widget.state.attendanceRecords.any(
      (record) => record.studentNumber == student.number && record.date == today,
    );
    if (widget.state.isAttendanceClosed(current)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('簽到時間已截止')));
      return;
    }
    if (alreadySigned) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('這位同學今天已簽到')));
      return;
    }

    setState(() => pending.add(student.number));
    try {
      await widget.state.recordAttendance(student, at: current, late: widget.state.isLateAt(current));
    } finally {
      if (mounted) setState(() => pending.remove(student.number));
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.state.reminderNow;
    if (widget.state.isAttendanceClosed(now)) return const SizedBox.expand();
    final students = widget.state.students;
    final today = _date(now);
    final records = widget.state.attendanceRecords.where((e) => e.date == today).toList();
    final signed = records.map((e) => e.studentNumber).toSet();
    final mobile = MediaQuery.sizeOf(context).width < 720;
    return Padding(
      padding: EdgeInsets.fromLTRB(mobile ? 10 : 28, mobile ? 10 : 28, mobile ? 10 : 28, mobile ? 14 : 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('簽到', style: TextStyle(fontSize: 34, fontWeight: FontWeight.w900)),
              Text(
                _time(now),
                style: TextStyle(fontSize: mobile ? 18 : 24, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('請先由教師在後台建立同學資料。', style: TextStyle(fontSize: 20)))
                : GridView.builder(
                    gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: mobile ? 180 : 230,
                        mainAxisExtent: 92,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12),
                    itemCount: students.length,
                    itemBuilder: (context, index) {
                      final student = students[index];
                      final already = signed.contains(student.number);
                      final existing = already ? records.firstWhere((e) => e.studentNumber == student.number) : null;
                      return FilledButton.tonal(
                        onPressed:
                            already || pending.contains(student.number) ? null : () => _confirmAttendance(student),
                        style: FilledButton.styleFrom(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Text(student.number, style: const TextStyle(fontSize: 12)),
                          Text(student.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                          if (already) Text(existing!.late ? '已簽到 · 遲到' : '已簽到', style: const TextStyle(fontSize: 12)),
                        ]),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

Future<void> showDeviceSettingsDialog(BuildContext context, AppState state) async {
  final controller = TextEditingController(text: state.classId);
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('大屏裝置設定'),
      content: TextField(
        controller: controller,
        decoration: const InputDecoration(labelText: '班級代碼（與教師端相同才能同步）'),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () async {
            await state.setClassId(controller.text.trim());
            if (dialogContext.mounted) Navigator.pop(dialogContext);
          },
          child: const Text('儲存'),
        ),
      ],
    ),
  );
  controller.dispose();
}

class AuthGate extends StatefulWidget {
  final AppState state;
  final ValueChanged<ThemeMode> onThemeModeChanged;
  const AuthGate({
    super.key,
    required this.state,
    required this.onThemeModeChanged,
  });

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final auth = AuthService();
  bool? signedIn;

  @override
  void initState() {
    super.initState();
    _loadSignInState();
  }

  Future<void> _loadSignInState() async {
    final value = await auth.isSignedIn;
    if (!mounted) return;
    setState(() => signedIn = value);
    if (value && widget.state.classId.isNotEmpty && widget.state.cloudSyncEnabled) {
      unawaited(_pullCloudInBackground());
    }
  }

  Future<void> _pullCloudInBackground() async {
    try {
      await widget.state.pullFromCloud().timeout(const Duration(seconds: 8));
    } catch (error) {
      widget.state.setCloudSyncError('登入後同步逾時，已先使用本機資料');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (signedIn == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (signedIn!) {
      return MainShell(
        state: widget.state,
        onThemeModeChanged: widget.onThemeModeChanged,
      );
    }
    return LoginPage(
      auth: auth,
      onSignedIn: () => setState(() => signedIn = true),
      onBack: () => widget.state.setDeviceRole(''),
    );
  }
}

class LoginPage extends StatefulWidget {
  final AuthService auth;
  final VoidCallback onSignedIn;
  final Future<void> Function() onBack;
  const LoginPage({super.key, required this.auth, required this.onSignedIn, required this.onBack});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final accountController = TextEditingController(text: AuthService.account);
  final passwordController = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void dispose() {
    accountController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      loading = true;
      error = null;
    });
    final message = await widget.auth.signIn(
      accountController.text,
      passwordController.text,
    );
    if (!mounted) return;
    setState(() {
      loading = false;
      error = message;
    });
    if (message == null) widget.onSignedIn();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 4,
              child: IconButton(
                tooltip: '返回裝置用途選擇',
                onPressed: loading ? null : widget.onBack,
                icon: const Icon(Icons.arrow_back),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        '729 教師管理裝置',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 24),
                      TextField(
                        controller: accountController,
                        decoration: const InputDecoration(
                          labelText: '帳號',
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: '密碼'),
                        obscureText: true,
                      ),
                      if (error != null) ...[
                        const SizedBox(height: 12),
                        Text(error!, style: const TextStyle(color: Colors.red)),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: loading ? null : _submit,
                        child: Text(
                          loading ? '登入中...' : '登入',
                        ),
                      ),
                    ],
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
                final result = await auth.changePassword(
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
    if (changed == true && mounted) setState(() => message = '登入密碼已更新');
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

  String _formatSyncTime(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 720 ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '雲端與裝置',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          Text(
            !auth.isConfigured
                ? '雲端同步：尚未設定'
                : !firebaseRuntimeReady
                    ? '雲端同步：Firebase 初始化失敗'
                    : widget.state.cloudSyncError != null
                        ? '雲端同步：同步錯誤'
                        : '雲端同步：已連線${widget.state.lastCloudSyncAt == null ? '' : ' · ${_formatSyncTime(widget.state.lastCloudSyncAt!)}'}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: widget.state.cloudSyncError == null ? null : Theme.of(context).colorScheme.error,
            ),
          ),
          if (firebaseRuntimeError != null) ...[
            const SizedBox(height: 6),
            Text(firebaseRuntimeError!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          if (widget.state.cloudSyncError != null) ...[
            const SizedBox(height: 6),
            Text(widget.state.cloudSyncError!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final editor = TextField(
                controller: classIdController,
                decoration: const InputDecoration(
                  labelText: '班級代碼（大屏裝置需輸入相同代碼）',
                ),
              );
              final save = FilledButton(
                onPressed: () async {
                  await widget.state.setClassId(classIdController.text.trim());
                  await widget.state.setDeviceRole(widget.state.deviceRole);
                  widget.state.cloudSyncEnabled = kFirebaseConfigured && firebaseRuntimeReady;
                  setState(() => message = '班級代碼已儲存');
                },
                child: const Text('儲存代碼'),
              );
              return compact
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [editor, const SizedBox(height: 10), save],
                    )
                  : Row(
                      children: [
                        Expanded(child: editor),
                        const SizedBox(width: 12),
                        save,
                      ],
                    );
            },
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton.icon(
                onPressed: busy || !auth.isConfigured || !firebaseRuntimeReady
                    ? null
                    : () => _run(() async {
                          final result = await widget.state.pushToCloud();
                          return result ?? '已上傳到雲端';
                        }),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('立即上傳到雲端'),
              ),
              OutlinedButton.icon(
                onPressed: busy || !auth.isConfigured || !firebaseRuntimeReady
                    ? null
                    : () => _run(() async {
                          final result = await widget.state.pullFromCloud();
                          return result ?? '已從雲端下載並覆蓋本機';
                        }),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('從雲端下載並覆蓋本機'),
              ),
              OutlinedButton.icon(
                onPressed: _changePassword,
                icon: const Icon(Icons.password_outlined),
                label: const Text('更改登入密碼'),
              ),
            ],
          ),
          if (message != null) ...[const SizedBox(height: 14), Text(message!)],
        ],
      ),
    );
  }
}
