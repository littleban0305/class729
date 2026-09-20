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

class AttendancePage extends StatelessWidget {
  final AppState state;
  const AttendancePage({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final students = _students(state);
    final today = DateTime.now();
    final todayKey =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final records = state.attendanceRecords.where((e) => e.date == todayKey).toList();
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    return Padding(
      padding: EdgeInsets.fromLTRB(isMobile ? 12 : 24, 8, isMobile ? 12 : 24, isMobile ? 12 : 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('簽到紀錄', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
              Text(_todayLabel(), style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text('${records.length} 人已登記 / ${students.length} 人',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: students.isEmpty
                ? const Center(child: Text('請先在座位表填入同學姓名'))
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190, mainAxisExtent: 98, crossAxisSpacing: 12, mainAxisSpacing: 12),
                    itemCount: students.length,
                    itemBuilder: (_, i) {
                      final student = students[i];
                      final matching = records.where((e) => e.studentNumber == student.number);
                      final record = matching.isEmpty ? null : matching.first;
                      final label = record == null
                          ? '尚未簽到'
                          : (record.late && state.reminderNow.hour >= 8
                              ? '遲到'
                              : (record.time == '遲到' ? '遲到' : '${record.time}${record.late ? ' · 遲到' : ''}'));
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(student.number, style: const TextStyle(fontSize: 12)),
                              Text(
                                student.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: record == null
                                      ? Theme.of(context).colorScheme.onSurfaceVariant
                                      : Theme.of(context).colorScheme.primary,
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

class _RegistrationRecordsPageState extends State<RegistrationRecordsPage> {
  String type = '整潔';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '整潔', label: Text('整潔'), icon: Icon(Icons.cleaning_services_outlined)),
                ButtonSegment(value: '秩序不佳', label: Text('秩序不佳'), icon: Icon(Icons.gavel_outlined)),
                ButtonSegment(value: '晚進教室', label: Text('晚進教室'), icon: Icon(Icons.login_outlined)),
              ],
              selected: {type},
              onSelectionChanged: (value) => setState(() => type = value.first),
            ),
          ),
        ),
        Expanded(
          child: StudentRecordsPage(
            key: ValueKey<String>(type),
            state: widget.state,
            heading: '$type 紀錄',
            initialType: type,
            visibleTypes: [type],
          ),
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

  static const types = ['整潔', '秩序不佳', '晚進教室', '缺交作業'];

  List<String> get availableTypes => widget.visibleTypes ?? types;

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
                items: const ['整潔', '秩序不佳', '晚進教室', '缺交作業']
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(widget.heading, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
            if (availableTypes.length > 1)
              DropdownButton<String>(
                  value: type,
                  items: availableTypes.map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: (v) => setState(() => type = v ?? type)),
            DropdownButton<SeatData>(
                value: student,
                hint: const Text('選擇同學'),
                items: _students(widget.state)
                    .map((e) => DropdownMenuItem(value: e, child: Text('${e.number}  ${e.name}')))
                    .toList(),
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
            const Text('班級照片', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
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
