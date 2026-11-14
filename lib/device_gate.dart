import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_state.dart';
import 'firebase_config_flag.dart';
import 'models.dart';
import 'main.dart'
    show
        MainShell,
        ReminderPresentation,
        LotteryPage,
        DiaryPage,
        SchedulePage,
        BigScreenHomePage,
        BigScreenTopBar,
        BigScreenPages,
        StampPage,
        AppIcons,
        AutoHideBar,
        BigScreenPageFrame,
        BigScreenSeatGrid,
        showPinEntryDialog,
        showSettingsWindow,
        showSettingsWindowAfterPin,
        ProjectedTextOverlay,
        TeacherNoticeOverlay,
        NotificationBell,
        showOfficerPinDialog,
        LessonRatingWatcher,
        MaterialAutoOpener;

/// Decides what a device is allowed to see: an unconfigured device must pick a
/// role first, a "大屏" device only gets the public classroom interface and attendance, with editable 聯絡簿 as a limited exception.
class DeviceRoleGate extends StatefulWidget {
  final AppState state;
  const DeviceRoleGate({
    super.key,
    required this.state,
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
            return TeacherPinGate(state: widget.state);
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
        child: Stack(
          children: [
            Center(
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
            AutoHideBar(
              child: BigScreenTopBar(
                icons: const [],
                labels: const [],
                current: 0,
                onSelect: (_) {},
                onBack: () {},
                showBackButton: false,
                onOpenSettings: () => showSettingsWindow(context, state),
              ),
            ),
          ],
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
  int page = BigScreenPages.home;
  String? projectedText; // 頂端列投放的文字；null 代表沒有在投放

  // 順序對應 BigScreenPages
  final labels = const ['首頁', '登記（管理者專用）', '選號機', '提醒', '座位表', '課表', '聯絡簿'];
  final icons = const [
    AppIcons.dashboard,
    AppIcons.clipboardPen,
    AppIcons.dice,
    AppIcons.bell,
    AppIcons.grid,
    AppIcons.calendar,
    AppIcons.book,
  ];

  Future<void> _go(int value) async {
    // 進入蓋章頁要先輸入管理者 PIN 碼
    if (value == BigScreenPages.registration && page != value) {
      if (!await showOfficerPinDialog(context, widget.state) || !mounted) return;
    }
    setState(() => page = value);
  }

  Future<void> _back() async {
    if (page != BigScreenPages.home) {
      _go(BigScreenPages.home);
      return;
    }
    final ok = await showPinEntryDialog(context, widget.state);
    if (ok) {
      await widget.state.setDeviceRole('');
    }
  }

  Widget _page() {
    switch (page) {
      // 每一頁都套上跟首頁一樣的外框與風格
      case BigScreenPages.registration:
        return BigScreenPageFrame(child: StampPage(state: widget.state));
      case BigScreenPages.lottery:
        return BigScreenPageFrame(child: LotteryPage(state: widget.state));
      case BigScreenPages.reminders:
        return BigScreenPageFrame(child: ReminderPresentation(state: widget.state));
      case BigScreenPages.seats:
        return BigScreenPageFrame(
          panel: false,
          child: AnimatedBuilder(
            animation: widget.state,
            builder: (_, __) => BigScreenSeatGrid(state: widget.state),
          ),
        );
      case BigScreenPages.schedule:
        return BigScreenPageFrame(child: SchedulePage(state: widget.state, editable: false));
      case BigScreenPages.diary:
        return BigScreenPageFrame(child: DiaryPage(state: widget.state, editable: true));
      case BigScreenPages.home:
      default:
        return AnimatedBuilder(
          animation: widget.state,
          builder: (_, __) => BigScreenHomePage(state: widget.state),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 頂端列浮在內容上方，圓角外面露出的是內容本身的底色
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned.fill(
              top: 10,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 160),
                child: KeyedSubtree(key: ValueKey<int>(page), child: _page()),
              ),
            ),
            if (projectedText != null)
              Positioned.fill(
                child: ProjectedTextOverlay(
                  text: projectedText!,
                  onClose: () => setState(() => projectedText = null),
                ),
              ),
            AutoHideBar(
              // 跳頁按鈕都拿掉了；中間是投放輸入框，左邊返回、右邊設定與視窗按鈕
              child: BigScreenTopBar(
                icons: const [],
                labels: const [],
                current: page,
                onSelect: _go,
                onBack: _back,
                onOpenSettings: () => showSettingsWindow(context, widget.state),
                onProject: (text) => setState(() => projectedText = text),
                notificationButton: NotificationBell(state: widget.state, target: 'bigscreen'),
              ),
            ),
            // 教師評分：下課那一瞬間跳出
            Positioned.fill(child: LessonRatingWatcher(state: widget.state, bringToFront: true)),
            // 下課後自動打開下一節的教材資料夾（看不見）
            Positioned(left: 0, top: 0, child: MaterialAutoOpener(state: widget.state)),
            // 教師即時通知：蓋在最上層，只有大屏點叉叉或灰色背景才會關
            Positioned.fill(
              child: AnimatedBuilder(
                animation: widget.state,
                builder: (context, _) => widget.state.showTeacherNotice
                    ? TeacherNoticeOverlay(
                        notice: widget.state.teacherNotice!,
                        onClose: widget.state.dismissTeacherNotice,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ],
        ),
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
        title: Text(student.name, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
        content: Text(late ? '遲到' : '準時',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: late ? const Color(0xFFE07A00) : const Color(0xFF2E9E5B))),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            autofocus: true,
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('簽到'),
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
                      // 沒簽到：男藍、女粉；已簽到：灰色；遲到：淡橘
                      final isDark = Theme.of(context).brightness == Brightness.dark;
                      final Color bg = isDark
                          ? Theme.of(context).colorScheme.surfaceContainerHigh
                          : already
                              ? (existing!.late ? const Color(0xFFFFE7C2) : const Color(0xFFECEEF1))
                              : student.gender == '男'
                                  ? const Color(0xFFDCEBFF)
                                  : student.gender == '女'
                                      ? const Color(0xFFFFE1EC)
                                      : const Color(0xFFFFFFFE);
                      final fg = isDark
                          ? Theme.of(context).colorScheme.onSurface
                          : (already ? const Color(0xFF5A5F75) : const Color(0xFF272343));
                      return FilledButton(
                        onPressed:
                            already || pending.contains(student.number) ? null : () => _confirmAttendance(student),
                        style: FilledButton.styleFrom(
                            backgroundColor: bg,
                            foregroundColor: fg,
                            disabledBackgroundColor: bg,
                            disabledForegroundColor: fg,
                            side: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1),
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

class TeacherPinGate extends StatefulWidget {
  final AppState state;
  const TeacherPinGate({
    super.key,
    required this.state,
  });

  @override
  State<TeacherPinGate> createState() => _TeacherPinGateState();
}

class _TeacherPinGateState extends State<TeacherPinGate> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  bool _ready = false;
  bool _unlocked = false;
  bool _openSettingsAfterUnlock = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadPin();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _loadPin() async {
    if (widget.state.cloudSyncEnabled && widget.state.classId.trim().isNotEmpty) {
      try {
        final result = await widget.state.pullFromCloud();
        if (result != null && result != '雲端還沒有這個班級的資料' && mounted) {
          setState(() => _error = '讀取雲端 PIN 碼失敗：$result');
          return;
        }
      } catch (error) {
        if (!mounted) return;
        setState(() => _error = '讀取雲端 PIN 碼失敗：$error');
        return;
      }
    }
    if (!mounted) return;
    setState(() => _ready = true);
  }

  void _onPinChanged(String value) {
    final pinLength = widget.state.bigScreenExitPinLength;
    if (pinLength == null || value.length < pinLength) {
      setState(() => _error = null);
      return;
    }
    if (widget.state.verifyBigScreenExitPin(value)) {
      final openSettings = _openSettingsAfterUnlock;
      setState(() {
        _error = null;
        _unlocked = true;
      });
      if (openSettings) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          showSettingsWindowAfterPin(
            context,
            widget.state,
          );
        });
      }
    } else {
      setState(() {
        _error = 'PIN 碼錯誤，請重新輸入';
        _controller.clear();
      });
    }
  }

  Future<void> _createPin() async {
    final pin = _controller.text;
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      setState(() => _error = 'PIN 碼必須是 4 至 8 位數字');
      return;
    }
    try {
      await widget.state.setBigScreenExitPin(pin);
    } catch (error) {
      if (mounted) setState(() => _error = '儲存 PIN 碼失敗：$error');
      return;
    }
    if (!mounted) return;
    setState(() {
      _error = null;
      _unlocked = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      if (_error != null) {
        return Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_error!),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => setState(() {
                    _error = null;
                    _loadPin();
                  }),
                  child: const Text('重新載入'),
                ),
                TextButton(
                  onPressed: () => widget.state.setDeviceRole(''),
                  child: const Text('返回裝置選擇'),
                ),
              ],
            ),
          ),
        );
      }
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_unlocked) {
      return MainShell(
        state: widget.state,
      );
    }
    final pinLength = widget.state.bigScreenExitPinLength;
    final creating = pinLength == null;
    final dotCount = pinLength ?? 8;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            AutoHideBar(
              child: BigScreenTopBar(
                icons: const [],
                labels: const [],
                current: 0,
                onSelect: (_) {},
                onBack: () => widget.state.setDeviceRole(''),
                backTooltip: '返回裝置用途選擇',
                onOpenSettings: creating ? null : () => setState(() => _openSettingsAfterUnlock = true),
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        creating ? '建立教師 PIN 碼' : '請輸入PIN碼',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      if (creating) ...[
                        const SizedBox(height: 12),
                        const Text('設定 4 至 8 位數字，之後可用同一組 PIN 進入教師後台或退出大屏。'),
                      ],
                      SizedBox(height: creating ? 24 : 32),
                      GestureDetector(
                        onTap: _focusNode.requestFocus,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            for (var i = 0; i < dotCount; i++)
                              Container(
                                width: 18,
                                height: 18,
                                margin: const EdgeInsets.symmetric(horizontal: 4),
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
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            maxLength: creating ? 8 : pinLength,
                            style: const TextStyle(fontSize: 1, color: Colors.transparent),
                            cursorColor: Colors.transparent,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              counterText: '',
                              contentPadding: EdgeInsets.zero,
                              isCollapsed: true,
                            ),
                            onChanged: _onPinChanged,
                          ),
                        ),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Text(_error!, style: TextStyle(color: scheme.error)),
                      ],
                      if (creating) ...[
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _createPin,
                          child: const Text('設定 PIN 並進入後台'),
                        ),
                      ],
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

/// Cloud synchronization controls retained for administrative integrations.
class CloudDevicePage extends StatefulWidget {
  final AppState state;
  const CloudDevicePage({super.key, required this.state});

  @override
  State<CloudDevicePage> createState() => _CloudDevicePageState();
}

class _CloudDevicePageState extends State<CloudDevicePage> {
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
            !kFirebaseConfigured
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
                onPressed: busy || !kFirebaseConfigured || !firebaseRuntimeReady
                    ? null
                    : () => _run(() async {
                          final result = await widget.state.pushToCloud();
                          return result ?? '已上傳到雲端';
                        }),
                icon: const Icon(Icons.cloud_upload_outlined),
                label: const Text('立即上傳到雲端'),
              ),
              OutlinedButton.icon(
                onPressed: busy || !kFirebaseConfigured || !firebaseRuntimeReady
                    ? null
                    : () => _run(() async {
                          final result = await widget.state.pullFromCloud();
                          return result ?? '已從雲端下載並覆蓋本機';
                        }),
                icon: const Icon(Icons.cloud_download_outlined),
                label: const Text('從雲端下載並覆蓋本機'),
              ),
            ],
          ),
          if (message != null) ...[const SizedBox(height: 14), Text(message!)],
        ],
      ),
    );
  }
}
