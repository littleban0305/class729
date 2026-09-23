import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'records_models.dart';
import 'services/cloud_sync_service.dart';
import 'services/auth_service.dart';
import 'firebase_config_flag.dart';

class AppState extends ChangeNotifier {
  static const _remindersKey = 'reminders';
  static const _seatsKey = 'seats';
  static const _diaryKey = 'diary';
  static const _scheduleKey = 'schedule';
  static const _darkModeKey = 'darkMode';
  static const _testNowKey = 'testNow';
  static const _attendanceKey = 'attendance';
  static const _studentRecordsKey = 'studentRecords';
  static const _cleanlinessKey = 'cleanliness';
  static const _photosKey = 'classPhotos';
  static const _lateThresholdKey = 'lateThreshold';
  static const _weeklySelectionsKey = 'weeklySelections';
  static const _classIdKey = 'classId';
  static const _deviceRoleKey = 'deviceRole';

  final CloudSyncService cloud = CloudSyncService();
  String classId = '';
  bool cloudSyncEnabled = false;
  String deviceRole = '';
  StreamSubscription<Map<String, dynamic>?>? _publicCloudSubscription;
  StreamSubscription<Map<String, dynamic>?>? _teacherCloudSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _registrationSubscription;
  String _watchedPublicClassId = '';
  String _watchedTeacherClassId = '';
  String? cloudSyncError;
  DateTime? lastCloudSyncAt;

  String _normalizeClassId(String value) {
    final trimmed = value.trim();
    return trimmed;
  }

  void setCloudSyncError(String? error) {
    cloudSyncError = error;
    notifyListeners();
  }

  List<ReminderData> reminders = [];
  List<SeatData> seats = [];
  List<String> diary = [];
  List<String> schedule = [];
  List<ScheduleEntry> scheduleEntries = [];
  List<DiaryEntry> diaryEntries = [];
  bool darkMode = false;
  DateTime? testNow;
  List<AttendanceRecord> attendanceRecords = [];
  List<StudentRecord> studentRecords = [];
  List<CleanlinessRecord> cleanlinessRecords = [];
  List<ClassPhoto> classPhotos = [];
  List<WeeklySelection> weeklySelections = [];
  String lateThreshold = '07:30';
  DateTime get reminderNow => testNow ?? DateTime.now();

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    cloudSyncEnabled = kFirebaseConfigured && firebaseRuntimeReady;
    final reminderRaw = prefs.getString(_remindersKey);
    final seatRaw = prefs.getString(_seatsKey);
    final diaryRaw = prefs.getString(_diaryKey);
    final scheduleRaw = prefs.getString(_scheduleKey);
    final attendanceRaw = prefs.getString(_attendanceKey);
    final studentRecordsRaw = prefs.getString(_studentRecordsKey);
    final cleanlinessRaw = prefs.getString(_cleanlinessKey);
    final photosRaw = prefs.getString(_photosKey);
    final weeklySelectionsRaw = prefs.getString(_weeklySelectionsKey);
    classId = _normalizeClassId(prefs.getString(_classIdKey) ?? '');
    deviceRole = prefs.getString(_deviceRoleKey) ?? '';
    lateThreshold = prefs.getString(_lateThresholdKey) ?? '07:30';
    darkMode = prefs.getBool(_darkModeKey) ?? false;
    final testNowRaw = prefs.getString(_testNowKey);
    testNow = testNowRaw == null ? null : DateTime.tryParse(testNowRaw);

    if (reminderRaw != null) {
      reminders = (jsonDecode(reminderRaw) as List)
          .whereType<Map>()
          .map((e) => ReminderData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      reminders = [];
    }

    if (seatRaw != null) {
      seats = (jsonDecode(seatRaw) as List)
          .whereType<Map>()
          .map((e) => SeatData.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (seats.length >= 30 && seats.every((seat) => seat.row == 0)) {
        for (var i = 0; i < seats.length; i++) {
          seats[i].row = i ~/ 5;
          seats[i].slot = i % 5;
          seats[i].number = '${seats[i].row + 1}-${i % 5 + 1}';
        }
      }
      for (final row in seats.map((seat) => seat.row).toSet()) {
        var nextSlot = 0;
        for (final seat in seats.where((seat) => seat.row == row)) {
          if (seat.slot < 0) seat.slot = nextSlot;
          nextSlot = seat.slot + 1;
        }
      }
    } else {
      seats = [
        for (var row = 0; row < 6; row++)
          for (var position = 0; position < 5; position++)
            SeatData(number: '${row + 1}-${position + 1}', name: '', row: row, slot: position),
      ];
    }

    if (diaryRaw != null) {
      final raw = jsonDecode(diaryRaw) as List;
      if (raw.every((item) => item is Map)) {
        diaryEntries = raw.whereType<Map>().map((e) => DiaryEntry.fromJson(Map<String, dynamic>.from(e))).toList();
      } else {
        diaryEntries = raw.whereType<String>().map((e) => DiaryEntry(date: _today(), tag: '一般', content: e)).toList();
      }
    }
    if (attendanceRaw != null) {
      final raw = jsonDecode(attendanceRaw) as List;
      attendanceRecords =
          raw.whereType<Map>().map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (studentRecordsRaw != null) {
      final raw = jsonDecode(studentRecordsRaw) as List;
      studentRecords = raw.whereType<Map>().map((e) => StudentRecord.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (cleanlinessRaw != null) {
      final raw = jsonDecode(cleanlinessRaw) as List;
      cleanlinessRecords =
          raw.whereType<Map>().map((e) => CleanlinessRecord.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (photosRaw != null) {
      final raw = jsonDecode(photosRaw) as List;
      classPhotos = raw.whereType<Map>().map((e) => ClassPhoto.fromJson(Map<String, dynamic>.from(e))).toList();
    }
    if (weeklySelectionsRaw != null) {
      final raw = jsonDecode(weeklySelectionsRaw) as List;
      weeklySelections =
          raw.whereType<Map>().map((e) => WeeklySelection.fromJson(Map<String, dynamic>.from(e))).toList();
    }

    if (scheduleRaw != null) {
      final raw = jsonDecode(scheduleRaw) as List;
      if (raw.every((item) => item is Map)) {
        scheduleEntries =
            raw.whereType<Map>().map((e) => ScheduleEntry.fromJson(Map<String, dynamic>.from(e))).toList();
      } else {
        final legacySchedule = raw.whereType<String>().toList();
        scheduleEntries = legacySchedule
            .asMap()
            .entries
            .map((entry) => ScheduleEntry(
                  weekday: entry.key % 5,
                  lesson: entry.key ~/ 5,
                  subject: entry.value,
                ))
            .toList();
      }
    }

    _syncPublicCloudListener();
    _syncTeacherCloudListener();
    _syncRegistrationListener();
    notifyListeners();
  }

  void _syncPublicCloudListener() {
    final id = classId.trim();
    final shouldWatch = cloudSyncEnabled && id.isNotEmpty && deviceRole == 'bigscreen';
    if (!shouldWatch) {
      _publicCloudSubscription?.cancel();
      _publicCloudSubscription = null;
      _watchedPublicClassId = '';
      return;
    }
    if (_watchedPublicClassId == id && _publicCloudSubscription != null) return;
    _publicCloudSubscription?.cancel();
    _watchedPublicClassId = id;
    cloudSyncError = null;
    _publicCloudSubscription = cloud.watchPublicState(id).listen(
      (data) {
        if (data == null) return;
        cloudSyncError = null;
        lastCloudSyncAt = DateTime.now();
        unawaited(applyPublicCloudData(data));
      },
      onError: (Object error, StackTrace stack) {
        cloudSyncError = error.toString();
        notifyListeners();
      },
    );
  }

  void _syncTeacherCloudListener() {
    final id = classId.trim();
    final shouldWatch = cloudSyncEnabled && id.isNotEmpty && deviceRole == 'teacher';
    if (!shouldWatch) {
      _teacherCloudSubscription?.cancel();
      _teacherCloudSubscription = null;
      _watchedTeacherClassId = '';
      return;
    }
    if (_watchedTeacherClassId == id && _teacherCloudSubscription != null) return;
    _teacherCloudSubscription?.cancel();
    _watchedTeacherClassId = id;
    cloudSyncError = null;
    _teacherCloudSubscription = cloud.watchState(id).listen(
      (data) {
        if (data == null) return;
        cloudSyncError = null;
        lastCloudSyncAt = DateTime.now();
        _applyImportedData(data, preserveTestNow: true);
        notifyListeners();
      },
      onError: (Object error, StackTrace stack) {
        cloudSyncError = error.toString();
        notifyListeners();
      },
    );
  }

  void _syncRegistrationListener() {
    final shouldWatch = cloudSyncEnabled && deviceRole == 'teacher' && classId.trim().isNotEmpty;
    if (!shouldWatch) {
      _registrationSubscription?.cancel();
      _registrationSubscription = null;
      return;
    }
    _registrationSubscription?.cancel();
    _registrationSubscription = cloud.watchRegistrations(classId).listen((items) {
      var changed = false;
      for (final item in items) {
        final id = item['id'] as String? ?? '';
        if (id.isEmpty || studentRecords.any((record) => record.id == id)) continue;
        studentRecords.insert(0, StudentRecord.fromJson(item));
        changed = true;
      }
      if (changed) {
        unawaited(_save(syncCloud: false));
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _publicCloudSubscription?.cancel();
    _publicCloudSubscription = null;
    _teacherCloudSubscription?.cancel();
    _teacherCloudSubscription = null;
    _registrationSubscription?.cancel();
    _registrationSubscription = null;
    super.dispose();
  }

  Future<void> _save({bool syncCloud = true}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_remindersKey, jsonEncode(reminders.map((e) => e.toJson()).toList()));
    await prefs.setString(_seatsKey, jsonEncode(seats.map((e) => e.toJson()).toList()));
    await prefs.setString(_diaryKey, jsonEncode(diary));
    await prefs.setString(_scheduleKey, jsonEncode(schedule));
    await prefs.setString(_diaryKey, jsonEncode(diaryEntries.map((e) => e.toJson()).toList()));
    await prefs.setString(_scheduleKey, jsonEncode(scheduleEntries.map((e) => e.toJson()).toList()));
    await prefs.setString(_attendanceKey, jsonEncode(attendanceRecords.map((e) => e.toJson()).toList()));
    await prefs.setString(_studentRecordsKey, jsonEncode(studentRecords.map((e) => e.toJson()).toList()));
    await prefs.setString(_cleanlinessKey, jsonEncode(cleanlinessRecords.map((e) => e.toJson()).toList()));
    await prefs.setString(_photosKey, jsonEncode(classPhotos.map((e) => e.toJson()).toList()));
    await prefs.setString(_weeklySelectionsKey, jsonEncode(weeklySelections.map((e) => e.toJson()).toList()));
    if (syncCloud && cloudSyncEnabled && classId.isNotEmpty) {
      final snapshot = exportData();
      if (deviceRole == 'teacher') {
        await _pushTeacherSnapshot(snapshot);
      } else if (deviceRole == 'bigscreen') {
        await _pushBigScreenSnapshot(snapshot);
      }
    }
  }

  Future<void> _pushTeacherSnapshot(Map<String, dynamic> snapshot) async {
    try {
      final authError = await AuthService().ensureFirebaseSession();
      if (authError != null) throw Exception('教師雲端登入失敗：$authError');
      final normalizedId = _normalizeClassId(classId);
      if (normalizedId != classId) {
        classId = normalizedId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_classIdKey, classId);
      }
      await Future.wait([
        cloud.pushState(classId, snapshot),
        cloud.pushPublicDiary(classId, snapshot),
      ]);
      cloudSyncError = null;
      lastCloudSyncAt = DateTime.now();
      notifyListeners();
    } catch (error) {
      cloudSyncError = error.toString();
      notifyListeners();
    }
  }

  Future<void> _pushBigScreenSnapshot(Map<String, dynamic> snapshot) async {
    try {
      final authError = await AuthService().ensureFirebaseSession();
      if (authError != null) throw Exception('大屏雲端登入失敗：$authError');
      final normalizedId = _normalizeClassId(classId);
      if (normalizedId != classId) {
        classId = normalizedId;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_classIdKey, classId);
      }
      await Future.wait([
        cloud.pushPublicDiary(classId, snapshot),
        cloud.pushAttendanceToday(classId, snapshot),
      ]);
      cloudSyncError = null;
      lastCloudSyncAt = DateTime.now();
      notifyListeners();
    } catch (error) {
      cloudSyncError = error.toString();
      notifyListeners();
    }
  }

  Future<void> setClassId(String value) async {
    classId = _normalizeClassId(value);
    cloudSyncEnabled = kFirebaseConfigured && firebaseRuntimeReady;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_classIdKey, classId);
    _syncPublicCloudListener();
    _syncTeacherCloudListener();
    _syncRegistrationListener();
    if (deviceRole == 'teacher' && cloudSyncEnabled && classId.isNotEmpty) {
      try {
        final remote = await cloud.fetchState(classId);
        if (remote != null) {
          _applyImportedData(remote, preserveTestNow: true);
          await _save(syncCloud: false);
        }
      } catch (error) {
        cloudSyncError = error.toString();
      }
    }
    notifyListeners();
  }

  Future<void> setDeviceRole(String value) async {
    deviceRole = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_deviceRoleKey, value);
    _syncPublicCloudListener();
    _syncTeacherCloudListener();
    _syncRegistrationListener();
    notifyListeners();
  }

  Future<String?> pushToCloud() async {
    if (!cloudSyncEnabled) return 'Firebase 尚未初始化，無法同步';
    if (classId.trim().isEmpty) return '請先設定班級代碼';
    final authError = await AuthService().ensureFirebaseSession();
    if (authError != null) return '教師雲端登入失敗：$authError';
    try {
      await cloud.pushState(classId, exportData());
      cloudSyncError = null;
      lastCloudSyncAt = DateTime.now();
      notifyListeners();
      return null;
    } catch (error) {
      cloudSyncError = error.toString();
      notifyListeners();
      return cloudSyncError;
    }
  }

  /// Pulls the latest cloud snapshot and overwrites local data (last-write-wins).
  Future<String?> pullFromCloud() async {
    if (classId.isEmpty) return '請先設定班級代碼';
    final authError = await AuthService().ensureFirebaseSession();
    if (authError != null) return '教師雲端登入失敗：$authError';
    final data = await cloud.fetchState(classId);
    if (data == null) return '雲端還沒有這個班級的資料';
    _applyImportedData(data, preserveTestNow: true);
    await _save(syncCloud: false);
    notifyListeners();
    return null;
  }

  /// 套用公開雲端資料給大屏，不會把公開資料再次上傳。
  Future<void> applyPublicCloudData(Map<String, dynamic> data) async {
    if (data['reminders'] is List ||
        data['seats'] is List ||
        data['diaryEntries'] is List ||
        data['scheduleEntries'] is List ||
        data['attendanceToday'] is List ||
        data.containsKey('testNow')) {
      final publicData = <String, dynamic>{
        'reminders': data['reminders'] ?? reminders.map((e) => e.toJson()).toList(),
        'seats': data['seats'] ?? seats.map((e) => e.toJson()).toList(),
        'diaryEntries': data['diaryEntries'] ?? diaryEntries.map((e) => e.toJson()).toList(),
        'scheduleEntries': data['scheduleEntries'] ?? scheduleEntries.map((e) => e.toJson()).toList(),
        'attendanceRecords': data['attendanceToday'] ?? <dynamic>[],
        'studentRecords': <dynamic>[],
        'cleanlinessRecords': <dynamic>[],
        'classPhotos': <dynamic>[],
        'weeklySelections': <dynamic>[],
        'lateThreshold': data['lateThreshold'] ?? lateThreshold,
        'testNow': data['testNow'] is String ? data['testNow'] as String : null,
        'darkMode': darkMode,
      };
      _applyPublicData(publicData);
      await _save(syncCloud: false);
    }
    notifyListeners();
  }

  void _applyPublicData(Map<String, dynamic> data) {
    reminders = ((data['reminders'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => ReminderData.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    seats = ((data['seats'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => SeatData.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    diaryEntries = ((data['diaryEntries'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => DiaryEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    scheduleEntries = ((data['scheduleEntries'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => ScheduleEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    lateThreshold = data['lateThreshold'] as String? ?? lateThreshold;
    if (data.containsKey('testNow')) {
      final value = data['testNow'];
      testNow = value is String ? DateTime.tryParse(value) : null;
    }
    cleanlinessRecords = ((data['cleanlinessRecords'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => CleanlinessRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    weeklySelections = ((data['weeklySelections'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => WeeklySelection.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    final today = _dateKey(DateTime.now());
    attendanceRecords.removeWhere((e) => e.date == today);
    final publicAttendance = ((data['attendanceRecords'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e).map((key, value) => MapEntry(key, value))))
        .map((e) => AttendanceRecord(
              studentNumber: e.studentNumber,
              studentName: e.studentName,
              date: e.date,
              time: e.time,
              late: e.late,
            ))
        .toList();
    attendanceRecords.addAll(publicAttendance);
  }

  DateTime weekStartOf(DateTime value) =>
      DateTime(value.year, value.month, value.day).subtract(Duration(days: value.weekday - 1));

  WeeklySelection weeklySelectionFor(DateTime value) {
    final key = _dateKey(weekStartOf(value));
    return weeklySelections.firstWhere((e) => e.weekStart == key, orElse: () => WeeklySelection(weekStart: key));
  }

  Future<void> saveWeeklySelection(DateTime week,
      {required List<String> excellent, required List<String> needsWork}) async {
    final key = _dateKey(weekStartOf(week));
    weeklySelections.removeWhere((e) => e.weekStart == key);
    weeklySelections.add(WeeklySelection(
      weekStart: key,
      excellentNumbers: excellent.take(3).toList(),
      needsWorkNumbers: needsWork.take(3).toList(),
      locked: true,
    ));
    await _save();
    notifyListeners();
  }

  Future<String?> saveReminder(ReminderData item, {int? index}) async {
    if (item.timeRanges.isEmpty) {
      return '至少需要一段套用時間';
    }
    for (final range in item.timeRanges) {
      final newStart = _timeToMinutes(range.startTime);
      final newEnd = _timeToMinutes(range.endTime);
      if (newStart < 0 || newEnd < 0) {
        return '時間格式必須是 00:00 到 23:59';
      }
      if (newStart >= newEnd) {
        return '每段時間的結束時間必須晚於開始時間';
      }
    }
    if (index == null) {
      reminders.add(item);
    } else {
      reminders[index] = item;
    }
    await _save();
    notifyListeners();
    return null;
  }

  int _timeToMinutes(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return -1;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null || hour < 0 || hour > 23 || minute < 0 || minute > 59) return -1;
    return hour * 60 + minute;
  }

  Future<void> deleteReminder(int index) async {
    reminders.removeAt(index);
    await _save();
    notifyListeners();
  }

  Future<void> duplicateReminder(int index) async {
    final source = reminders[index];
    final copy = ReminderData(
      title: '${source.title} 副本',
      content: source.content,
      date: source.date,
      startTime: source.startTime,
      endTime: source.endTime,
      lessonType: source.lessonType,
      autoEvaluationEnabled: source.autoEvaluationEnabled,
      evaluations: source.evaluations
          .map((evaluation) => LessonEvaluationRecord(
                id: '${evaluation.id}-copy',
                score: evaluation.score,
                note: evaluation.note,
                createdAt: DateTime.tryParse(evaluation.createdAt) ?? DateTime.now(),
                lessonType: evaluation.lessonType,
              ))
          .toList(),
      timeRanges: source.timeRanges.map((range) => range.copyWith()).toList(),
      repeatType: source.repeatType,
      repeatDates: List<String>.from(source.repeatDates),
      buttons: source.buttons.map((button) => ActionButtonData(text: button.text, url: button.url)).toList(),
      layout: List<String>.from(source.layout),
      blocks: {
        for (final entry in source.blocks.entries) entry.key: entry.value.copyWith(),
      },
      elements: source.elements.map((element) => element.copyWith()).toList(),
    );
    reminders.insert(index + 1, copy);
    await _save();
    notifyListeners();
  }

  Future<void> updateSeat(int index, String name) async {
    seats[index].name = name;
    await _save();
    notifyListeners();
  }

  Future<void> updateSeatDetails(int index,
      {required String number,
      required String name,
      required String gender,
      String label = '',
      String note = '',
      int? score}) async {
    seats[index].number = number;
    seats[index].name = name;
    seats[index].gender = gender;
    seats[index].label = label;
    seats[index].note = note;
    if (score != null) seats[index].score = score;
    await _save();
    notifyListeners();
  }

  Future<void> adjustSeatScore(int index, int delta) async {
    if (index < 0 || index >= seats.length) return;
    seats[index].score += delta;
    await _save();
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    darkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
    notifyListeners();
  }

  Future<void> setTestNow(DateTime? value) async {
    testNow = value;
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_testNowKey);
    } else {
      await prefs.setString(_testNowKey, value.toIso8601String());
    }
    if (cloudSyncEnabled && classId.isNotEmpty && deviceRole == 'teacher') {
      try {
        await cloud.pushState(classId, exportData());
      } catch (error) {
        cloudSyncError = error.toString();
      }
    }
    notifyListeners();
  }

  Future<void> addRow() async {
    final nextRow = seats.isEmpty ? 0 : seats.map((seat) => seat.row).reduce((a, b) => a > b ? a : b) + 1;
    await addSeat(row: nextRow);
  }

  Future<void> addSeat({required int row}) async {
    final rowSeats = seats.where((seat) => seat.row == row).toList();
    final slot = rowSeats.isEmpty ? 0 : rowSeats.map((seat) => seat.slot).reduce((a, b) => a > b ? a : b) + 1;
    seats.add(SeatData(number: '${row + 1}-${slot + 1}', name: '', row: row, slot: slot));
    await _save();
    notifyListeners();
  }

  Future<void> deleteSeat(int index) async {
    final row = seats[index].row;
    seats.removeAt(index);
    _normalizeRowSlots(row);
    await _save();
    notifyListeners();
  }

  Future<void> deleteRow(int row) async {
    seats.removeWhere((seat) => seat.row == row);
    final remainingRows = seats.map((seat) => seat.row).toSet().toList()..sort();
    for (var newRow = 0; newRow < remainingRows.length; newRow++) {
      for (final seat in seats.where((seat) => seat.row == remainingRows[newRow])) {
        seat.row = newRow;
      }
    }
    for (var newRow = 0; newRow < remainingRows.length; newRow++) {
      _normalizeRowSlots(newRow);
    }
    await _save();
    notifyListeners();
  }

  void _normalizeRowSlots(int row) {
    final rowSeats = seats.where((seat) => seat.row == row).toList()..sort((a, b) => a.slot.compareTo(b.slot));
    for (var slot = 0; slot < rowSeats.length; slot++) {
      rowSeats[slot].slot = slot;
    }
  }

  Future<void> rotateSeats(int direction) async {
    if (seats.isEmpty) return;
    final highestRow = seats.map((seat) => seat.row).reduce((a, b) => a > b ? a : b);
    final slots = seats.map((seat) => seat.slot).toSet();
    for (final slot in slots) {
      final slotSeats = seats.where((seat) => seat.slot == slot).toList();
      final occupiedRows = slotSeats.map((seat) => seat.row).toSet();
      int? emptyRow;
      if (direction < 0) {
        for (var row = 0; row < highestRow; row++) {
          if (!occupiedRows.contains(row) && occupiedRows.contains(row + 1)) {
            emptyRow = row;
            break;
          }
        }
      } else {
        for (var row = highestRow; row > 0; row--) {
          if (!occupiedRows.contains(row) && occupiedRows.contains(row - 1)) {
            emptyRow = row;
            break;
          }
        }
      }
      if (emptyRow == null) {
        for (final seat in slotSeats) {
          if (direction < 0) {
            seat.row = seat.row == 0 ? highestRow : seat.row - 1;
          } else {
            seat.row = seat.row == highestRow ? 0 : seat.row + 1;
          }
        }
        continue;
      }
      for (final seat in slotSeats) {
        if (direction < 0 && seat.row > emptyRow) {
          seat.row--;
        } else if (direction > 0 && seat.row < emptyRow) {
          seat.row++;
        }
      }
    }
    await _save();
    notifyListeners();
  }

  Future<void> swapSeats(int firstIndex, int secondIndex) async {
    if (firstIndex == secondIndex) return;
    final first = seats[firstIndex];
    final second = seats[secondIndex];
    final number = first.number;
    final name = first.name;
    final gender = first.gender;
    final label = first.label;
    first.number = second.number;
    first.name = second.name;
    first.gender = second.gender;
    first.label = second.label;
    second.number = number;
    second.name = name;
    second.gender = gender;
    second.label = label;
    await _save();
    notifyListeners();
  }

  Future<void> moveSeatTo(int index, {required int row, required int slot}) async {
    final occupied = seats.any((seat) => seat.row == row && seat.slot == slot);
    if (occupied) return;
    seats[index].row = row;
    seats[index].slot = slot;
    await _save();
    notifyListeners();
  }

  Future<void> setDiary(List<String> value) async {
    diary = value;
    await _save();
    notifyListeners();
  }

  Future<void> setSchedule(List<String> value) async {
    schedule = value;
    await _save();
    notifyListeners();
  }

  String _today() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> saveScheduleEntries(List<ScheduleEntry> value) async {
    scheduleEntries = value;
    await _save();
    notifyListeners();
  }

  Future<void> saveDiaryEntries(List<DiaryEntry> value) async {
    diaryEntries = value;
    await _save();
    notifyListeners();
  }

  List<SeatData> get students {
    final result = seats.where((seat) => seat.name.trim().isNotEmpty).toList();
    result.sort(_compareSeatNumbers);
    return result;
  }

  int _compareSeatNumbers(SeatData first, SeatData second) {
    final firstParts = RegExp(r'\d+').allMatches(first.number).map((match) => int.parse(match.group(0)!)).toList();
    final secondParts = RegExp(r'\d+').allMatches(second.number).map((match) => int.parse(match.group(0)!)).toList();
    for (var i = 0; i < firstParts.length && i < secondParts.length; i++) {
      final comparison = firstParts[i].compareTo(secondParts[i]);
      if (comparison != 0) return comparison;
    }
    if (firstParts.length != secondParts.length) return firstParts.length.compareTo(secondParts.length);
    return first.number.compareTo(second.number);
  }

  String _dateKey(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  String _timeKey(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:${value.second.toString().padLeft(2, '0')}';

  bool isLateAt(DateTime value) {
    final parts = lateThreshold.split(':');
    final hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 7 : 7;
    final minute = parts.length > 1 ? int.tryParse(parts[1]) ?? 30 : 30;
    final lateAfterMinutes = hour * 60 + minute;
    return value.hour * 60 + value.minute >= lateAfterMinutes;
  }

  Future<void> setLateThreshold(String value) async {
    lateThreshold = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_lateThresholdKey, value);
    notifyListeners();
  }

  static const int attendanceCutoffMinutes = 8 * 60;

  bool isAttendanceClosed(DateTime value) => value.hour * 60 + value.minute >= attendanceCutoffMinutes;

  Future<void> recordLate(SeatData student) async {
    final value = DateTime.now();
    final date = _dateKey(value);
    attendanceRecords.removeWhere((item) => item.studentNumber == student.number && item.date == date);
    attendanceRecords.add(AttendanceRecord(
      studentNumber: student.number,
      studentName: student.name,
      date: date,
      time: '遲到',
      late: true,
    ));
    await _save();
    notifyListeners();
  }

  Future<void> recordAttendance(SeatData student, {DateTime? at, bool? late}) async {
    final value = at ?? DateTime.now();
    attendanceRecords.removeWhere((item) => item.studentNumber == student.number && item.date == _dateKey(value));
    attendanceRecords.add(AttendanceRecord(
      studentNumber: student.number,
      studentName: student.name,
      date: _dateKey(value),
      time: _timeKey(value),
      late: late ?? isLateAt(value),
    ));
    await _save();
    notifyListeners();
  }

  Future<void> addStudentRecord({
    required SeatData student,
    required String type,
    String note = '',
    DateTime? at,
  }) async {
    final value = at ?? DateTime.now();
    studentRecords.insert(
        0,
        StudentRecord(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          studentNumber: student.number,
          studentName: student.name,
          date: _dateKey(value),
          time: _timeKey(value),
          type: type,
          note: note,
        ));
    await _save();
    notifyListeners();
  }

  Future<bool> submitRegistration({
    required SeatData student,
    required String type,
    String note = '',
  }) async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final value = DateTime.now();
    final data = StudentRecord(
      id: id,
      studentNumber: student.number,
      studentName: student.name,
      date: _dateKey(value),
      time: _timeKey(value),
      type: type,
      note: note,
    ).toJson();
    try {
      if (!cloudSyncEnabled || classId.isEmpty) return false;
      await cloud.pushRegistration(classId, data);
      return true;
    } catch (error) {
      cloudSyncError = error.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> deleteStudentRecord(String id) async {
    studentRecords.removeWhere((record) => record.id == id);
    if (cloudSyncEnabled && classId.isNotEmpty) {
      await cloud.deleteRegistration(classId, id);
    }
    await _save();
    notifyListeners();
  }

  Future<void> updateStudentRecord(String id, {required String type, required String note}) async {
    final index = studentRecords.indexWhere((record) => record.id == id);
    if (index < 0) return;
    final record = studentRecords[index];
    studentRecords[index] = StudentRecord(
      id: record.id,
      studentNumber: record.studentNumber,
      studentName: record.studentName,
      date: record.date,
      time: record.time,
      type: type,
      note: note,
    );
    if (cloudSyncEnabled && classId.isNotEmpty) {
      await cloud.updateRegistration(classId, id, studentRecords[index].toJson());
    }
    await _save();
    notifyListeners();
  }

  Future<void> addCleanlinessRecord({
    required String area,
    required String evaluator,
    required int score,
    String studentNumber = '',
    String studentName = '',
    String result = '一般',
    String note = '',
    DateTime? at,
  }) async {
    final value = at ?? DateTime.now();
    cleanlinessRecords.insert(
        0,
        CleanlinessRecord(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          date: _dateKey(value),
          area: area,
          evaluator: evaluator,
          score: score,
          studentNumber: studentNumber,
          studentName: studentName,
          result: result,
          note: note,
        ));
    await _save();
    notifyListeners();
  }

  Future<void> deleteCleanlinessRecord(String id) async {
    cleanlinessRecords.removeWhere((record) => record.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> addClassPhoto(ClassPhoto photo) async {
    classPhotos.insert(0, photo);
    await _save();
    notifyListeners();
  }

  Future<void> deleteClassPhoto(String id) async {
    classPhotos.removeWhere((photo) => photo.id == id);
    await _save();
    notifyListeners();
  }

  Map<String, dynamic> exportData() => {
        'version': 1,
        'reminders': reminders.map((e) => e.toJson()).toList(),
        'seats': seats.map((e) => e.toJson()).toList(),
        'diaryEntries': diaryEntries.map((e) => e.toJson()).toList(),
        'scheduleEntries': scheduleEntries.map((e) => e.toJson()).toList(),
        'darkMode': darkMode,
        'testNow': testNow?.toIso8601String(),
        'attendanceRecords': attendanceRecords.map((e) => e.toJson()).toList(),
        'studentRecords': studentRecords.map((e) => e.toJson()).toList(),
        'cleanlinessRecords': cleanlinessRecords.map((e) => e.toJson()).toList(),
        'classPhotos': classPhotos.map((e) => e.toJson()).toList(),
        'weeklySelections': weeklySelections.map((e) => e.toJson()).toList(),
        'lateThreshold': lateThreshold,
      };

  Future<void> exportToFile(String path) async {
    await File(path).writeAsString(const JsonEncoder.withIndent('  ').convert(exportData()));
  }

  Future<String?> importFromFile(String path) async {
    try {
      final decoded = jsonDecode(await File(path).readAsString());
      if (decoded is! Map) return '資料檔格式錯誤';
      final data = Map<String, dynamic>.from(decoded);
      final hasValidCollections = data['reminders'] is List &&
          data['seats'] is List &&
          data['diaryEntries'] is List &&
          data['scheduleEntries'] is List;
      if (!hasValidCollections) return '資料檔內容格式錯誤';
      _applyImportedData(data);
      await _save();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_darkModeKey, darkMode);
      await prefs.setString(_lateThresholdKey, lateThreshold);
      if (testNow == null) {
        await prefs.remove(_testNowKey);
      } else {
        await prefs.setString(_testNowKey, testNow!.toIso8601String());
      }
      notifyListeners();
      return null;
    } on FormatException {
      return '資料檔不是有效的 JSON';
    } on FileSystemException {
      return '無法讀取資料檔';
    } on Object {
      return '資料檔內容格式錯誤';
    }
  }

  void _applyImportedData(Map<String, dynamic> data, {bool preserveTestNow = false}) {
    reminders = ((data['reminders'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => ReminderData.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    seats = ((data['seats'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => SeatData.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    diaryEntries = ((data['diaryEntries'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => DiaryEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    scheduleEntries = ((data['scheduleEntries'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => ScheduleEntry.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    attendanceRecords = ((data['attendanceRecords'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => AttendanceRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    studentRecords = ((data['studentRecords'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => StudentRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    cleanlinessRecords = ((data['cleanlinessRecords'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => CleanlinessRecord.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    lateThreshold = data['lateThreshold'] as String? ?? '07:30';
    classPhotos = ((data['classPhotos'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => ClassPhoto.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    weeklySelections = ((data['weeklySelections'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => WeeklySelection.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    darkMode = data['darkMode'] as bool? ?? false;
    if (!preserveTestNow) {
      testNow = data['testNow'] is String ? DateTime.tryParse(data['testNow'] as String) : null;
    }
  }
}
