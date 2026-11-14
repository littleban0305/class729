import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'app_state.dart';
import 'models.dart';
import 'records_models.dart';

String _todayLabel() {
  final now = DateTime.now();
  return '${now.year}/${now.month.toString().padLeft(2, '0')}/${now.day.toString().padLeft(2, '0')}';
}

String _shortDate(String value) => value.replaceAll('-', '/');

List<SeatData> _students(AppState state) => state.students;

class TeacherManagementPage extends StatefulWidget {
  final AppState state;
  const TeacherManagementPage({super.key, required this.state});

  @override
  State<TeacherManagementPage> createState() => _TeacherManagementPageState();
}

class _TeacherManagementPageState extends State<TeacherManagementPage> {
  int tab = 0;

  @override
  Widget build(BuildContext context) {
    const labels = ['簽到', '老師紀錄', '整潔', '照片'];
    const icons = [
      Icons.how_to_reg_outlined,
      Icons.assignment_outlined,
      Icons.cleaning_services_outlined,
      Icons.photo_library_outlined
    ];
    return Column(
      children: [
        SizedBox(
          height: 68,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            scrollDirection: Axis.horizontal,
            itemCount: labels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) => ChoiceChip(
              selected: tab == i,
              avatar: Icon(icons[i], size: 18),
              label: Text(labels[i]),
              onSelected: (_) => setState(() => tab = i),
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 160),
            child: switch (tab) {
              0 => AttendancePage(key: const ValueKey('attendance'), state: widget.state),
              1 => StudentRecordsPage(key: const ValueKey('student-records'), state: widget.state),
              2 => CleanlinessPage(key: const ValueKey('cleanliness'), state: widget.state),
              _ => ClassPhotosPage(key: const ValueKey('photos'), state: widget.state),
            },
          ),
        ),
      ],
    );
  }
}

class AttendancePage extends StatefulWidget {
  final AppState state;
  const AttendancePage({super.key, required this.state});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

/// 簽到：標題列 + 統計 + 篩選 + 學生格子。
class _AttendancePageState extends State<AttendancePage> {
  static const _filters = ['全部', '已到', '未到', '遲到'];
  String filter = '全部';

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final scheme = Theme.of(context).colorScheme;
    final students = _students(state);
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final records = state.attendanceRecords.where((e) => e.date == todayKey).toList();
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    AttendanceRecord? recordOf(SeatData s) {
      for (final r in records) {
        if (r.studentNumber == s.number) return r;
      }
      return null;
    }

    final signed = students.where((s) => recordOf(s) != null).length;
    final late = students.where((s) => recordOf(s)?.late ?? false).length;
    final visible = students.where((s) {
      final r = recordOf(s);
      return switch (filter) {
        '已到' => r != null,
        '未到' => r == null,
        '遲到' => r?.late ?? false,
        _ => true,
      };
    }).toList();

    Widget stat(String label, int value, Color color) => Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('$label $value', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
          ),
        );

    const lateColor = Color(0xFFB06000);
    // 已到用深青色：黃色主色當文字在白底上看不清楚
    final signedColor = Theme.of(context).brightness == Brightness.dark ? scheme.primary : const Color(0xFF2D7D7A);

    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 16, isMobile ? 12 : 24, isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text('簽到紀錄', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(width: 10),
              Text(_todayLabel(), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            runSpacing: 6,
            children: [
              stat('已到', signed, signedColor),
              stat('未到', students.length - signed, scheme.outline),
              stat('遲到', late, lateColor),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _filters)
                ChoiceChip(
                  label: Text(f),
                  selected: filter == f,
                  showCheckmark: false,
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: filter == f ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                  ),
                  onSelected: (_) => setState(() => filter = f),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: students.isEmpty
                ? Center(child: Text('請先在座位表填入同學姓名', style: TextStyle(color: scheme.onSurfaceVariant)))
                : visible.isEmpty
                    ? Center(child: Text('沒有符合的同學', style: TextStyle(color: scheme.onSurfaceVariant)))
                    : GridView.builder(
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 170, mainAxisExtent: 92, crossAxisSpacing: 10, mainAxisSpacing: 10),
                        itemCount: visible.length,
                        itemBuilder: (_, i) {
                          final student = visible[i];
                          final record = recordOf(student);
                          final isLate = record?.late ?? false;
                          final label = record == null
                              ? '尚未簽到'
                              : (isLate && state.reminderNow.hour >= 8
                                  ? '遲到'
                                  : (record.time == '遲到'
                                      ? '遲到'
                                      : '${record.time.length >= 5 ? record.time.substring(0, 5) : record.time}${isLate ? ' · 遲到' : ''}'));
                          final accent = record == null ? scheme.onSurfaceVariant : (isLate ? lateColor : signedColor);
                          return Container(
                            padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                            decoration: BoxDecoration(
                              color: record == null ? scheme.surfaceContainerLow : scheme.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: record == null ? scheme.outlineVariant : scheme.outline,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(student.number, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
                                Text(
                                  student.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    color: record == null ? scheme.onSurfaceVariant : scheme.onSurface,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Container(
                                      width: 6,
                                      height: 6,
                                      decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                                    ),
                                    const SizedBox(width: 6),
                                    Flexible(
                                      child: Text(
                                        label,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(fontSize: 13, color: accent),
                                      ),
                                    ),
                                  ],
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
  }
}

class TextSnackBar extends SnackBar {
  TextSnackBar(String message, {super.key}) : super(content: Text(message));
}

class RegistrationRecordsPage extends StatefulWidget {
  final AppState state;
  const RegistrationRecordsPage({super.key, required this.state});

  @override
  State<RegistrationRecordsPage> createState() => _RegistrationRecordsPageState();
}

/// 登記紀錄：標題列 + 篩選 + 列表 + 右側詳細資料（寬螢幕）。
class _RegistrationRecordsPageState extends State<RegistrationRecordsPage> {
  static const _types = ['蓋章', '扣章', '兌換'];
  static const _periods = ['今天', '本週', '全部'];

  String? typeFilter;
  String period = '本週';
  String? selectedId;

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  List<StudentRecord> _filtered() {
    final now = DateTime.now();
    final today = _key(now);
    final weekStart = _key(widget.state.weekStartOf(now));
    return widget.state.studentRecords.where((r) {
      if (!_types.contains(r.type)) return false;
      if (typeFilter != null && r.type != typeFilter) return false;
      if (period == '今天' && r.date != today) return false;
      if (period == '本週' && r.date.compareTo(weekStart) < 0) return false;
      return true;
    }).toList()
      ..sort((a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'));
  }

  List<SeatData> get _uniqueStudents {
    final unique = <String, SeatData>{};
    for (final s in _students(widget.state)) {
      final key = s.number.trim().isEmpty ? s.name.trim() : s.number.trim();
      if (key.isNotEmpty) unique.putIfAbsent(key, () => s);
    }
    return unique.values.toList();
  }

  SeatData? _studentOf(StudentRecord r) {
    for (final s in _students(widget.state)) {
      if (s.number == r.studentNumber) return s;
    }
    return null;
  }

  String _shortTime(StudentRecord r) {
    final date = r.date.length >= 10 ? r.date.substring(5).replaceAll('-', '/') : _shortDate(r.date);
    final time = r.time.length >= 5 ? r.time.substring(0, 5) : r.time;
    return '$date $time';
  }

  (Color, Color) _tagColors(String type) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (type) {
      '秩序不佳' || '扣章' => (scheme.errorContainer, scheme.onErrorContainer),
      '蓋章' => isDark
          ? (const Color(0xFF1E4D3A), const Color(0xFFB8F0D4))
          : (const Color(0xFFD6F5E5), const Color(0xFF145C3A)),
      '兌換' => isDark
          ? (const Color(0xFF5C3B00), const Color(0xFFFDD663))
          : (const Color(0xFFFEEFC3), const Color(0xFF7A4A00)),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
  }

  Widget _tag(String type) {
    final (bg, fg) = _tagColors(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(type, style: TextStyle(fontSize: 13, color: fg)),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      labelStyle: TextStyle(
        fontSize: 13,
        color: selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
      ),
      onSelected: (_) => onTap(),
    );
  }

  Future<void> _openAddDialog() async {
    final students = _uniqueStudents;
    if (students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(TextSnackBar('請先在座位表填入同學姓名'));
      return;
    }
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _StampPolicyDialog(state: widget.state, students: students),
    );
    if (saved == true && mounted) setState(() {});
  }

  Future<void> _editRecord(StudentRecord record) async {
    final noteController = TextEditingController(text: record.note);
    var typeValue = _types.contains(record.type) ? record.type : _types.first;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('編輯 ${record.studentName} 的紀錄'),
          content: SizedBox(
            width: 360,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: typeValue,
                  items: _types.map((value) => DropdownMenuItem(value: value, child: Text(value))).toList(),
                  onChanged: (value) => setDialogState(() => typeValue = value ?? typeValue),
                  decoration: const InputDecoration(labelText: '類型'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: noteController,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '備註'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                await widget.state.updateStudentRecord(record.id, type: typeValue, note: noteController.text.trim());
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
    noteController.dispose();
    if (mounted) setState(() {});
  }

  Future<bool> _deleteRecord(StudentRecord record) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('刪除這筆紀錄？'),
        content: Text('${record.studentNumber} ${record.studentName}・${record.type}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('取消')),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(dialogContext).colorScheme.error),
            child: const Text('刪除'),
          ),
        ],
      ),
    );
    if (ok != true) return false;
    await widget.state.deleteStudentRecord(record.id);
    // 刪掉蓋章／扣章紀錄時，章數自動退回
    final undo = record.type == '蓋章' ? -1 : (record.type == '扣章' ? 1 : 0);
    final seatIndex = widget.state.seats.indexWhere((s) => s.number == record.studentNumber);
    if (undo != 0 && seatIndex >= 0) await widget.state.adjustSeatScore(seatIndex, undo);
    if (mounted) setState(() => selectedId = null);
    return true;
  }

  Widget _detail(StudentRecord r, {VoidCallback? onClose}) {
    final scheme = Theme.of(context).colorScheme;
    final student = _studentOf(r);
    final count = widget.state.studentRecords.where((e) => e.studentNumber == r.studentNumber).length;
    Widget field(String label, Widget value) => Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              value,
            ],
          ),
        );
    return ListView(
      padding: const EdgeInsets.all(20),
      shrinkWrap: onClose != null,
      children: [
        Row(
          children: [
            Expanded(child: Text('詳細資料', style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant))),
            if (onClose != null) IconButton(onPressed: onClose, icon: const Icon(Icons.close, size: 20)),
          ],
        ),
        const SizedBox(height: 4),
        Text('${r.studentNumber}  ${r.studentName}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        field('類型', Align(alignment: Alignment.centerLeft, child: _tag(r.type))),
        field('備註', Text(r.note.isEmpty ? '—' : r.note, style: const TextStyle(fontSize: 15))),
        field('時間', Text('${_shortDate(r.date)} ${r.time}', style: const TextStyle(fontSize: 15))),
        if (student != null)
          field('目前分數', Text('${student.score}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800))),
        field('累計紀錄', Text('$count 筆', style: const TextStyle(fontSize: 15))),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () => _editRecord(r),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('編輯'),
              ),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () async {
                final deleted = await _deleteRecord(r);
                if (deleted && onClose != null) onClose();
              },
              style: TextButton.styleFrom(foregroundColor: scheme.error),
              child: const Text('刪除'),
            ),
          ],
        ),
      ],
    );
  }

  void _openSheet(StudentRecord r) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(child: _detail(r, onClose: () => Navigator.pop(sheetContext))),
    );
  }

  Widget _headerRow(ColorScheme scheme) {
    final style = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      child: Row(
        children: [
          SizedBox(width: 56, child: Text('座號', style: style)),
          SizedBox(width: 96, child: Text('姓名', style: style)),
          Expanded(child: Text('類型・備註', style: style)),
          SizedBox(width: 110, child: Text('時間', style: style, textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _row(StudentRecord r, {required bool isMobile, required bool showPanel}) {
    final scheme = Theme.of(context).colorScheme;
    final selected = showPanel && r.id == selectedId;
    final timeStyle = TextStyle(fontSize: 13, color: scheme.onSurfaceVariant);
    final note = r.note.isEmpty
        ? const SizedBox.shrink()
        : Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(r.note, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
            ),
          );
    return Material(
      color: selected ? scheme.primary.withValues(alpha: 0.08) : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showPanel ? setState(() => selectedId = r.id) : _openSheet(r),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text('${r.studentNumber}  ${r.studentName}',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                        ),
                        Text(_shortTime(r), style: timeStyle),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(children: [_tag(r.type), note]),
                  ],
                )
              : Row(
                  children: [
                    SizedBox(width: 56, child: Text(r.studentNumber, style: const TextStyle(fontSize: 15))),
                    SizedBox(
                      width: 96,
                      child: Text(r.studentName,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
                    ),
                    Expanded(child: Row(children: [_tag(r.type), note])),
                    SizedBox(width: 110, child: Text(_shortTime(r), style: timeStyle, textAlign: TextAlign.right)),
                  ],
                ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final isMobile = width < 600;
    final showPanel = width >= 1000;
    final records = _filtered();
    StudentRecord? selected;
    for (final r in records) {
      if (r.id == selectedId) {
        selected = r;
        break;
      }
    }

    final list = Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 16, isMobile ? 12 : 24, isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text('蓋章紀錄', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
              FilledButton.icon(
                onPressed: _openAddDialog,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('新增紀錄'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final p in _periods) _filterChip(p, period == p, () => setState(() => period = p)),
              Container(width: 1, height: 22, color: scheme.outlineVariant),
              _filterChip('全部類型', typeFilter == null, () => setState(() => typeFilter = null)),
              for (final t in _types)
                _filterChip(t, typeFilter == t, () => setState(() => typeFilter = typeFilter == t ? null : t)),
            ],
          ),
          const SizedBox(height: 12),
          if (!isMobile) _headerRow(scheme),
          Expanded(
            child: records.isEmpty
                ? Center(
                    child: Text(
                      period == '全部' && typeFilter == null ? '還沒有任何紀錄，按「新增紀錄」開始登記' : '這個篩選條件下沒有紀錄',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    itemCount: records.length,
                    itemBuilder: (_, i) => _row(records[i], isMobile: isMobile, showPanel: showPanel),
                  ),
          ),
        ],
      ),
    );

    if (!showPanel) return list;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: list),
        Container(
          width: 300,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLow,
            border: Border(left: BorderSide(color: scheme.outlineVariant)),
          ),
          child: selected == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '點選一筆紀錄\n查看詳細資料',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              : _detail(selected),
        ),
      ],
    );
  }
}

class StudentRecordsPage extends StatefulWidget {
  final AppState state;
  final String heading;
  final String initialType;
  final List<String>? visibleTypes;
  const StudentRecordsPage({
    super.key,
    required this.state,
    this.heading = '老師紀錄',
    this.initialType = '秩序不佳',
    this.visibleTypes,
  });

  @override
  State<StudentRecordsPage> createState() => _StudentRecordsPageState();
}

class _StudentRecordsPageState extends State<StudentRecordsPage> {
  late String type;
  SeatData? student;
  final noteController = TextEditingController();

  static const types = ['整潔', '秩序不佳', '晚進教室'];

  List<String> get availableTypes => widget.visibleTypes ?? types;

  List<SeatData> get availableStudents {
    final unique = <String, SeatData>{};
    for (final student in _students(widget.state)) {
      final key = student.number.trim().isEmpty ? student.name.trim() : student.number.trim();
      if (key.isNotEmpty) unique.putIfAbsent(key, () => student);
    }
    return unique.values.toList();
  }

  @override
  void initState() {
    super.initState();
    type = availableTypes.contains(widget.initialType) ? widget.initialType : availableTypes.first;
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (student == null) return;
    await widget.state.addStudentRecord(student: student!, type: type, note: noteController.text.trim());
    noteController.clear();
    if (mounted) setState(() {});
  }

  Future<void> _editRecord(StudentRecord record) async {
    final noteController = TextEditingController(text: record.note);
    var typeValue = record.type;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('編輯 ${record.studentName} 的紀錄'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                initialValue: typeValue,
                items: const ['整潔', '秩序不佳', '晚進教室']
                    .map((value) => DropdownMenuItem(value: value, child: Text(value)))
                    .toList(),
                onChanged: (value) => setDialogState(() => typeValue = value ?? typeValue),
                decoration: const InputDecoration(labelText: '類型'),
              ),
              TextField(
                controller: noteController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '備註'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('取消')),
            FilledButton(
              onPressed: () async {
                await widget.state.updateStudentRecord(record.id, type: typeValue, note: noteController.text.trim());
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('儲存'),
            ),
          ],
        ),
      ),
    );
    noteController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final records = widget.state.studentRecords.where((record) => availableTypes.contains(record.type)).toList();
    final students = availableStudents;
    SeatData? selectedStudent;
    if (student != null) {
      for (final item in students) {
        if (item.number == student!.number) {
          selectedStudent = item;
          break;
        }
      }
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(widget.heading, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            if (availableTypes.length > 1)
              DropdownButton<String>(
                  value: type,
                  items: availableTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => type = v ?? type)),
            DropdownButton<SeatData>(
                value: selectedStudent,
                hint: const Text('選擇同學'),
                items: students.map((e) => DropdownMenuItem(value: e, child: Text('${e.number}  ${e.name}'))).toList(),
                onChanged: (v) => setState(() => student = v)),
            FilledButton.icon(
                onPressed: student == null ? null : _add, icon: const Icon(Icons.add), label: const Text('登記')),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
            controller: noteController,
            decoration: const InputDecoration(labelText: '備註（可不填）', border: OutlineInputBorder())),
        const SizedBox(height: 16),
        Expanded(
          child: records.isEmpty
              ? const Center(child: Text('目前沒有老師紀錄'))
              : ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final r = records[i];
                    return Card(
                      child: ListTile(
                        title:
                            Text('${r.studentName}  ·  ${r.type}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        subtitle: Text('${_shortDate(r.date)} ${r.time}${r.note.isEmpty ? '' : '  ·  ${r.note}'}'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(icon: const Icon(Icons.edit_outlined), onPressed: () => _editRecord(r)),
                            IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => widget.state.deleteStudentRecord(r.id)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

class CleanlinessPage extends StatelessWidget {
  final AppState state;
  const CleanlinessPage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final mobile = MediaQuery.sizeOf(context).width < 720;
    return ListView(
      padding: EdgeInsets.fromLTRB(mobile ? 14 : 24, 12, mobile ? 14 : 24, 28),
      children: [
        Text('整潔', style: TextStyle(fontSize: mobile ? 28 : 32, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        _WeeklySelectionPanel(state: state),
      ],
    );
  }
}

class _WeeklySelectionPanel extends StatefulWidget {
  final AppState state;
  const _WeeklySelectionPanel({required this.state});

  @override
  State<_WeeklySelectionPanel> createState() => _WeeklySelectionPanelState();
}

class _WeeklySelectionPanelState extends State<_WeeklySelectionPanel> {
  late Set<String> excellent;
  late Set<String> needsWork;
  bool editing = false;

  @override
  void initState() {
    super.initState();
    _loadFromState();
  }

  void _loadFromState() {
    final selection = widget.state.weeklySelectionFor(DateTime.now());
    excellent = selection.excellentNumbers.toSet();
    needsWork = selection.needsWorkNumbers.toSet();
    editing = !selection.locked;
  }

  Future<void> _submit() async {
    await widget.state
        .saveWeeklySelection(DateTime.now(), excellent: excellent.toList(), needsWork: needsWork.toList());
    if (mounted) setState(() => editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final students = _students(widget.state);
    final selection = widget.state.weeklySelectionFor(DateTime.now());
    final weekLabel = '${_shortDate(selection.weekStart)} 開始的這一週';
    String nameOf(String number) =>
        students.firstWhere((s) => s.number == number, orElse: () => SeatData(number: number, name: number)).name;

    if (!editing) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('本週評選（$weekLabel）', style: const TextStyle(fontWeight: FontWeight.w800)),
                TextButton.icon(
                  onPressed: () => setState(() => editing = true),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('重新評選'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 560;
                final excellentText =
                    selection.excellentNumbers.isEmpty ? '本週未選出' : selection.excellentNumbers.map(nameOf).join('、');
                final needsWorkText =
                    selection.needsWorkNumbers.isEmpty ? '本週未選出' : selection.needsWorkNumbers.map(nameOf).join('、');
                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('優秀', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(excellentText),
                      const SizedBox(height: 12),
                      const Text('待改進', style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(needsWorkText),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('優秀', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(excellentText),
                        ],
                      ),
                    ),
                    const SizedBox(width: 28),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('待改進', style: TextStyle(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 4),
                          Text(needsWorkText),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ]),
        ),
      );
    }

    Widget chipList(Set<String> selected, Set<String> other, ValueChanged<String> onToggle) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: students.map((s) {
            final picked = selected.contains(s.number);
            return FilterChip(
              label: Text(s.name),
              selected: picked,
              onSelected: other.contains(s.number)
                  ? null
                  : (_) {
                      if (!picked && selected.length >= 3) return;
                      onToggle(s.number);
                    },
            );
          }).toList(),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('本週評選（$weekLabel，最多各選 3 位，也可以不選）', style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          const Text('優秀', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          chipList(
              excellent,
              needsWork,
              (number) => setState(() {
                    if (!excellent.remove(number)) excellent.add(number);
                  })),
          const SizedBox(height: 14),
          const Text('待改進', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          chipList(
              needsWork,
              excellent,
              (number) => setState(() {
                    if (!needsWork.remove(number)) needsWork.add(number);
                  })),
          const SizedBox(height: 14),
          Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.check), label: const Text('送出本週評選'))),
        ]),
      ),
    );
  }
}

class ClassPhotosPage extends StatefulWidget {
  final AppState state;
  const ClassPhotosPage({super.key, required this.state});
  @override
  State<ClassPhotosPage> createState() => _ClassPhotosPageState();
}

class _ClassPhotosPageState extends State<ClassPhotosPage> {
  final titleController = TextEditingController();

  @override
  void dispose() {
    titleController.dispose();
    super.dispose();
  }

  Future<void> _addPhoto() async {
    const group = XTypeGroup(label: '圖片', extensions: ['jpg', 'jpeg', 'png', 'webp']);
    final file = await openFile(acceptedTypeGroups: [group], confirmButtonText: '選擇照片');
    if (file == null) return;
    final now = DateTime.now();
    final date =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final title = titleController.text.trim();
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final appDir = await getApplicationSupportDirectory();
    final photoDir = Directory('${appDir.path}${Platform.pathSeparator}class_photos');
    await photoDir.create(recursive: true);
    final sourceName = file.name;
    final extension = sourceName.contains('.') ? sourceName.substring(sourceName.lastIndexOf('.')) : '.jpg';
    final storedPath = '${photoDir.path}${Platform.pathSeparator}$id$extension';
    await File(file.path).copy(storedPath);
    await widget.state.addClassPhoto(ClassPhoto(
      id: id,
      path: storedPath,
      date: date,
      title: title,
    ));
    titleController.clear();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final photos = [...widget.state.classPhotos]..sort((a, b) => b.date.compareTo(a.date));
    final grouped = <String, List<ClassPhoto>>{};
    for (final photo in photos) {
      grouped.putIfAbsent(photo.date, () => []).add(photo);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('班級照片', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            SizedBox(
                width: 230,
                child: TextField(controller: titleController, decoration: const InputDecoration(hintText: '照片名稱／活動'))),
            FilledButton.icon(
                onPressed: _addPhoto, icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('新增照片')),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: photos.isEmpty
              ? const Center(child: Text('尚無班級照片'))
              : ListView(
                  children: grouped.entries.map((entry) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 24),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          const Icon(Icons.event_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(_shortDate(entry.key),
                              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(width: 8),
                          Text('${entry.value.length} 張',
                              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                        ]),
                        const SizedBox(height: 10),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 280, mainAxisExtent: 250, crossAxisSpacing: 14, mainAxisSpacing: 14),
                          itemCount: entry.value.length,
                          itemBuilder: (_, i) {
                            final photo = entry.value[i];
                            final exists = File(photo.path).existsSync();
                            Future<void> deletePhoto() async {
                              try {
                                final local = File(photo.path);
                                if (await local.exists()) await local.delete();
                              } catch (_) {}
                              await widget.state.deleteClassPhoto(photo.id);
                            }

                            return Card(
                              clipBehavior: Clip.antiAlias,
                              child: Stack(children: [
                                Positioned.fill(
                                    child: exists
                                        ? Image.file(File(photo.path), fit: BoxFit.cover)
                                        : const ColoredBox(
                                            color: Color(0x22000000),
                                            child: Center(child: Icon(Icons.broken_image_outlined, size: 46)))),
                                Positioned(
                                    left: 0,
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(10),
                                      color: Colors.black54,
                                      child: Text(photo.title.isEmpty ? '未命名照片' : photo.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                    )),
                                Positioned(
                                    right: 6,
                                    top: 6,
                                    child: IconButton.filledTonal(
                                        onPressed: deletePhoto, icon: const Icon(Icons.delete_outline))),
                              ]),
                            );
                          },
                        ),
                      ]),
                    );
                  }).toList(),
                ),
        ),
      ]),
    );
  }
}

class BigScreenPage extends StatelessWidget {
  final AppState state;
  const BigScreenPage({super.key, required this.state});

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final students = _students(state);
    final now = DateTime.now();
    final dateKey = _dateKey(now);
    final signed = state.attendanceRecords.where((e) => e.date == dateKey).map((e) => e.studentNumber).toSet();
    final activeReminder = state.reminders.where((e) => e.isActiveAt(state.reminderNow)).toList();
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final minuteOfDay = now.hour * 60 + now.minute;
    final signInOpen = minuteOfDay < AppState.attendanceCutoffMinutes;
    final lateWindow = signInOpen && minuteOfDay >= (7 * 60 + 30);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('提醒', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                  const Spacer(),
                  Text(
                    '${now.year}/${now.month}/${now.day}',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView(
                  children: [
                    if (activeReminder.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(28),
                          child: Text('目前沒有提醒', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        ),
                      )
                    else
                      ...activeReminder.map(
                        (item) => Card(
                          margin: const EdgeInsets.only(bottom: 14),
                          child: Padding(
                            padding: EdgeInsets.all(isMobile ? 18 : 28),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.title.isEmpty ? '提醒' : item.title,
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                                const SizedBox(height: 10),
                                Text(item.content, style: const TextStyle(fontSize: 18)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (signInOpen) ...[
                      const SizedBox(height: 18),
                      Card(
                        child: Padding(
                          padding: EdgeInsets.all(isMobile ? 16 : 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('簽到', style: TextStyle(fontSize: isMobile ? 24 : 28, fontWeight: FontWeight.w900)),
                              const SizedBox(height: 6),
                              Text(
                                lateWindow ? '現在簽到會記為「遲到」。08:00 後簽到區會消失。' : '簽到開放中。07:30 後會記為「遲到」。',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
                              ),
                              const SizedBox(height: 14),
                              if (students.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(22),
                                  child: Center(child: Text('請先在教師後台加入同學')),
                                )
                              else
                                GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                                    maxCrossAxisExtent: 220,
                                    mainAxisExtent: 92,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: students.length,
                                  itemBuilder: (_, i) {
                                    final s = students[i];
                                    final checked = signed.contains(s.number);
                                    return FilledButton.tonal(
                                      onPressed: checked
                                          ? null
                                          : () async {
                                              await state.recordAttendance(s);
                                            },
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            s.name,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                                          ),
                                          Text(checked ? '已簽到' : (lateWindow ? '遲到簽到' : '點擊簽到')),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                              const SizedBox(height: 10),
                              Center(
                                child: Text(
                                  '已登記 ${signed.length} / ${students.length}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 總覽：一眼看完今天班上的狀況。
class OverviewPage extends StatelessWidget {
  final AppState state;
  const OverviewPage({super.key, required this.state});

  static const _weekdayNames = ['一', '二', '三', '四', '五', '六', '日'];

  String _key(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final today = _key(now);
    final weekStart = _key(state.weekStartOf(now));
    final students = _students(state);
    final attendance = state.attendanceRecords.where((e) => e.date == today).toList();
    final signedNumbers = attendance.map((e) => e.studentNumber).toSet();
    final missing = students.where((s) => !signedNumbers.contains(s.number)).toList();
    final lateCount = attendance.where((e) => e.late).length;
    final weekRecords = state.studentRecords.where((r) => r.date.compareTo(weekStart) >= 0).toList();
    final recent = [...state.studentRecords]..sort((a, b) => '${b.date} ${b.time}'.compareTo('${a.date} ${a.time}'));
    final activeReminders = state.reminders.where((r) => r.isActiveAt(state.reminderNow)).toList();
    final diary = state.diaryEntries.where((e) => e.date == today).toList();
    final lessons = state.scheduleEntries.where((e) => e.weekday == now.weekday - 1).toList()
      ..sort((a, b) => a.lesson.compareTo(b.lesson));
    final progress = students.isEmpty ? 0.0 : (signedNumbers.length / students.length).clamp(0.0, 1.0);
    // 累積扣章快滿 5 個（4 個以上）的同學
    final warn = [
      for (final s in students)
        (s, state.studentRecords.where((r) => r.studentNumber == s.number && r.type == '扣章').length)
    ].where((e) => e.$2 >= 4).toList()
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final notice = state.teacherNotice;

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 600;
        final pad = isMobile ? 12.0 : 24.0;
        final inner = width - pad * 2;
        final statCols = inner >= 900 ? 4 : 2;
        final statWidth = (inner - 12 * (statCols - 1)) / statCols;
        final twoCol = inner >= 760;
        final panelWidth = twoCol ? (inner - 12) / 2 : inner;

        return ListView(
          padding: EdgeInsets.fromLTRB(pad, 0, pad, pad),
          children: [
            Text(
              '${now.month} 月 ${now.day} 日 星期${_weekdayNames[now.weekday - 1]}',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: statWidth,
                  child: _StatTile(
                    label: '今日簽到',
                    value: '${signedNumbers.length}',
                    suffix: '/ ${students.length} 人',
                    color: const Color(0xFFFFD803),
                    progress: progress,
                  ),
                ),
                SizedBox(
                  width: statWidth,
                  child: _StatTile(label: '今日遲到', value: '$lateCount', suffix: '人', color: const Color(0xFFFFE1EC)),
                ),
                SizedBox(
                  width: statWidth,
                  child: _StatTile(
                      label: '本週登記', value: '${weekRecords.length}', suffix: '筆', color: const Color(0xFFDCEBFF)),
                ),
                SizedBox(
                  width: statWidth,
                  child: _StatTile(
                      label: '快滿 5 個扣章', value: '${warn.length}', suffix: '人', color: const Color(0xFFBAE8E8)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: panelWidth,
                  child: _Panel(
                    title: '尚未簽到',
                    color: const Color(0xFFFFF8D6),
                    trailing: '${missing.length} 人',
                    child: students.isEmpty
                        ? const _EmptyText('請先在座位表填入同學姓名')
                        : missing.isEmpty
                            ? const _EmptyText('全班都到了')
                            : Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  for (final s in missing)
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: scheme.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(999),
                                        border: Border.all(color: scheme.outlineVariant),
                                      ),
                                      child: Text('${s.number} ${s.name}', style: const TextStyle(fontSize: 13)),
                                    ),
                                ],
                              ),
                  ),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _Panel(
                    title: '最近登記',
                    color: const Color(0xFFEAF3FF),
                    child: recent.isEmpty
                        ? const _EmptyText('還沒有登記紀錄')
                        : Column(
                            children: [
                              for (final r in recent.take(5))
                                _ListLine(
                                  leading: '${r.studentNumber} ${r.studentName}',
                                  middle: r.note.isEmpty ? r.type : '${r.type}・${r.note}',
                                  trailing: _shortDate(r.date.length >= 10 ? r.date.substring(5) : r.date),
                                ),
                            ],
                          ),
                  ),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _Panel(
                    title: '今日課表',
                    color: const Color(0xFFF1FAFA),
                    child: lessons.isEmpty
                        ? const _EmptyText('今天沒有排課')
                        : Column(
                            children: [
                              for (final l in lessons)
                                _ListLine(
                                  leading: '第 ${l.lesson + 1} 節',
                                  middle: l.teacher.isEmpty ? l.subject : '${l.subject}・${l.teacher}',
                                  trailing: l.startTime.isEmpty ? '' : '${l.startTime}–${l.endTime}',
                                ),
                            ],
                          ),
                  ),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _Panel(
                    title: '今日聯絡簿',
                    color: const Color(0xFFFFF0F5),
                    child: diary.isEmpty
                        ? const _EmptyText('今天還沒有寫聯絡簿')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (var i = 0; i < diary.length; i++)
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4),
                                  child: Text('${i + 1}. ${diary[i].content}', style: const TextStyle(fontSize: 15)),
                                ),
                            ],
                          ),
                  ),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _Panel(
                    title: '扣章警示',
                    trailing: '累積 4 個以上',
                    color: const Color(0xFFFFF0F5),
                    child: warn.isEmpty
                        ? const _EmptyText('目前沒有人快滿 5 個')
                        : Column(
                            children: [
                              for (final w in warn.take(8))
                                _ListLine(
                                  leading: '${w.$1.number} ${w.$1.name}',
                                  middle: w.$2 >= 5 ? '已滿 5 個，要懲罰' : '再 1 個就滿 5 個',
                                  trailing: '${w.$2} 個',
                                ),
                            ],
                          ),
                  ),
                ),
                SizedBox(
                  width: panelWidth,
                  child: _Panel(
                    title: '大屏通知',
                    trailing: '${activeReminders.length} 則提醒進行中',
                    color: const Color(0xFFFFF8D6),
                    child: notice == null
                        ? const _EmptyText('目前沒有即時通知')
                        : Text(notice.text, maxLines: 4, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final Color color;
  final double? progress;
  const _StatTile({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const ink = Color(0xFF272343);
    final fg = isDark ? scheme.onSurface : ink;
    final muted = isDark ? scheme.onSurfaceVariant : ink.withValues(alpha: 0.7);
    return Container(
      height: 120,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? scheme.surfaceContainerHigh : color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: muted)),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(value, style: TextStyle(fontSize: 38, fontWeight: FontWeight.w900, color: fg, height: 1)),
              const SizedBox(width: 6),
              Text(suffix, style: TextStyle(fontSize: 13, color: muted)),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                color: ink,
                backgroundColor: Colors.white.withValues(alpha: 0.6),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final String title;
  final String? trailing;
  final Widget child;
  final Color color;
  const _Panel({required this.title, required this.child, this.trailing, this.color = const Color(0xFFFFFFFE)});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minHeight: 180),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark ? scheme.surfaceContainerLowest : color,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: scheme.outline, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(title,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: scheme.onSurface))),
              if (trailing != null) Text(trailing!, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ListLine extends StatelessWidget {
  final String leading;
  final String middle;
  final String trailing;
  const _ListLine({required this.leading, required this.middle, required this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: scheme.outlineVariant))),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            child: Text(leading, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
          ),
          Expanded(
            child: Text(middle, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 15)),
          ),
          if (trailing.isNotEmpty) Text(trailing, style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _EmptyText extends StatelessWidget {
  final String text;
  const _EmptyText(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text, style: TextStyle(fontSize: 15, color: Theme.of(context).colorScheme.onSurfaceVariant)),
      );
}

// ───────────────────────── 729 蓋章政策（修正版）登記表 ─────────────────────────

/// 一個事件／理由代號。delta：預設章數（扣章為負）；needNote：要填理由
class PolicyReason {
  final int code;
  final String text;
  final int delta;
  final bool needNote;
  const PolicyReason(this.code, this.text, this.delta, {this.needNote = false});
  String get label => '($code) $text';
}

/// 管理者（座號 4、11、13、17）的事件／理由代號
const managerReasons = <PolicyReason>[
  PolicyReason(1, '玩大屏', -1),
  PolicyReason(2, '罵髒話', -1),
  PolicyReason(3, '教室內奔跑', -1),
  PolicyReason(4, '幹部通報', -1, needNote: true),
  PolicyReason(5, '危險動作', -1),
  PolicyReason(6, '上課趁教師尚未來時離開座位/聊天', -1),
  PolicyReason(7, '亂丟垃圾', -1),
  PolicyReason(8, '亂畫黑板', -1),
  PolicyReason(9, '教室內亂丟東西', -1),
  PolicyReason(10, '早自習離開座位/聊天', -1),
  PolicyReason(11, '中午吃飯時間離開座位/聊天', -1),
  PolicyReason(12, '午休離開座位/聊天', -1),
  PolicyReason(13, '上課遲到', -1),
  PolicyReason(14, '擾亂上課進度', -1),
  PolicyReason(15, '協助收拾講台/整理講台', 1),
  PolicyReason(16, '擦黑板(非打掃時間)', 1),
  PolicyReason(17, '幹部蓋章', 1, needNote: true),
  PolicyReason(18, '排長確實檢查作業', 1),
];

/// 重要幹部的事件／理由代號（幹部名稱 → 代號）
const officerReasons = <String, List<PolicyReason>>{
  '班長(正副)': [PolicyReason(1, '教師不在秩序不良', -1), PolicyReason(2, '上課遲到', -1)],
  '事務(正副)': [PolicyReason(1, '值日生未擦黑板', -1), PolicyReason(2, '未準時交回條', -1)],
  '聯絡簿長(正副)': [PolicyReason(1, '早自習結束前未交聯絡簿', -1)],
  '設備(正副)': [
    PolicyReason(1, '亂畫黑板', -1),
    PolicyReason(2, '隨意使用籤筒', -1),
    PolicyReason(3, '破壞班上公物', -1),
    PolicyReason(4, '主動關冷氣與電扇(離開教室時)', 1),
  ],
  '午餐股長': [
    PolicyReason(1, '當周負責人未在12:05前抬餐進教室', -1),
    PolicyReason(2, '在有人未裝完時盛第二次飯', -1),
    PolicyReason(3, '多拿限制數量之食物', -1),
    PolicyReason(4, '協助打飯、放盛飯餐具', 1),
  ],
  '排長': [PolicyReason(1, '未寫功課', -1)],
};

/// 新增紀錄：照「729蓋章政策登記表」的欄位——座號、事件/理由、章數調整、證人、日期時間、備註
class _StampPolicyDialog extends StatefulWidget {
  final AppState state;
  final List<SeatData> students;
  const _StampPolicyDialog({required this.state, required this.students});

  @override
  State<_StampPolicyDialog> createState() => _StampPolicyDialogState();
}

class _StampPolicyDialogState extends State<_StampPolicyDialog> {
  bool officer = false; // false = 管理者登記表、true = 重要幹部登記表
  String officerName = officerReasons.keys.first;
  SeatData? student;
  PolicyReason? reason;
  int delta = -1;
  final witness = TextEditingController();
  final note = TextEditingController();
  final signer = TextEditingController();
  bool saving = false;

  @override
  void dispose() {
    Future<void>.delayed(const Duration(milliseconds: 600), () {
      witness.dispose();
      note.dispose();
      signer.dispose();
    });
    super.dispose();
  }

  List<PolicyReason> get _reasons => officer ? officerReasons[officerName]! : managerReasons;

  bool get _canSave =>
      student != null &&
      reason != null &&
      delta != 0 &&
      !(reason!.needNote && note.text.trim().isEmpty) &&
      !(officer && signer.text.trim().isEmpty);

  Future<void> _save() async {
    if (!_canSave || saving) return;
    setState(() => saving = true);
    final r = reason!;
    final parts = <String>[
      officer ? '[$officerName]${r.label}' : '[管理者]${r.label}',
      if (witness.text.trim().isNotEmpty) '證人：${witness.text.trim()}',
      if (officer) '管理者：${signer.text.trim()}',
      if (note.text.trim().isNotEmpty) note.text.trim(),
    ];
    await widget.state.addStudentRecord(
      student: student!,
      type: delta > 0 ? '蓋章' : '扣章',
      note: '${parts.join('・')}（${delta > 0 ? '+' : ''}$delta）',
    );
    final seatIndex = widget.state.seats.indexWhere((s) => s.number == student!.number);
    if (seatIndex >= 0) await widget.state.adjustSeatScore(seatIndex, delta);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reasons = _reasons;
    if (reason != null && !reasons.contains(reason)) reason = null;
    return AlertDialog(
      title: const Text('新增紀錄'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 4),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: false, label: Text('管理者登記表')),
                  ButtonSegment(value: true, label: Text('重要幹部登記表')),
                ],
                selected: {officer},
                onSelectionChanged: (v) => setState(() {
                  officer = v.first;
                  reason = null;
                }),
              ),
              if (officer) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: officerName,
                  items: [for (final k in officerReasons.keys) DropdownMenuItem(value: k, child: Text(k))],
                  onChanged: (v) => setState(() {
                    officerName = v ?? officerName;
                    reason = null;
                  }),
                  decoration: const InputDecoration(labelText: '幹部名稱'),
                ),
              ],
              const SizedBox(height: 16),
              DropdownButtonFormField<SeatData>(
                initialValue: student,
                items: [
                  for (final e in widget.students) DropdownMenuItem(value: e, child: Text('${e.number}  ${e.name}')),
                ],
                onChanged: (v) => setState(() => student = v),
                decoration: const InputDecoration(labelText: '座號'),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<PolicyReason>(
                key: ValueKey('$officer-$officerName'),
                initialValue: reason,
                isExpanded: true,
                items: [
                  for (final r in reasons)
                    DropdownMenuItem(value: r, child: Text(r.label, overflow: TextOverflow.ellipsis)),
                ],
                onChanged: (v) => setState(() {
                  reason = v;
                  if (v != null) delta = v.delta;
                }),
                decoration: const InputDecoration(labelText: '事件 / 理由'),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Text('章數調整', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  IconButton.outlined(
                    onPressed: delta <= -2 ? null : () => setState(() => delta = delta == 1 ? -1 : delta - 1),
                    icon: const Icon(Icons.remove),
                  ),
                  SizedBox(
                    width: 64,
                    child: Text(
                      delta > 0 ? '+$delta' : '$delta',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w900,
                        color: delta > 0 ? const Color(0xFF2E9E5B) : scheme.error,
                      ),
                    ),
                  ),
                  IconButton.outlined(
                    onPressed: delta >= 2 ? null : () => setState(() => delta = delta == -1 ? 1 : delta + 1),
                    icon: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (officer) ...[
                TextField(
                  controller: signer,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: '管理者簽名（必填）'),
                ),
                const SizedBox(height: 16),
              ] else ...[
                TextField(controller: witness, decoration: const InputDecoration(labelText: '證人（選填）')),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: note,
                maxLines: 2,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: reason?.needNote == true ? '理由（必填）' : '備註（選填）',
                ),
              ),
              const SizedBox(height: 12),
              Text('注意：所有加扣章皆須登記，尚未登記者則不列入計算。',
                  style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
        FilledButton(onPressed: _canSave && !saving ? _save : null, child: const Text('登記')),
      ],
    );
  }
}

