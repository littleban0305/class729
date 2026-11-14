import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
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
  static const _timePeriodsKey = 'timePeriods';
  static const _teacherNoticeKey = 'teacherNotice';
  static const _punishmentsKey = 'punishments';
  static const _materialFoldersKey = 'materialFolders';
  static const _chromeProfilesKey = 'chromeProfiles';
  static const _policyTextKey = 'policyText';
  static const _materialOpenDelayKey = 'materialOpenDelay';
  static const _rewardsKey = 'rewards';
  static const _lessonRatingsKey = 'lessonRatings';
  static const _dismissedNoticeKey = 'dismissedNoticeId';
  static const _notifSeenKey = 'notifSeenAt';
  static const _diaryTextScaleKey = 'diaryTextScale';
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
  static const _bigScreenExitPinVerifierKey = 'bigScreenExitPinVerifier';
  static const _officerPinVerifierKey = 'officerPinVerifier';

  final CloudSyncService cloud = CloudSyncService();
  String classId = '';
  bool cloudSyncEnabled = false;
  String deviceRole = '';
  String bigScreenExitPinVerifier = '';
  /// 管理者 PIN 碼（進入大屏蓋章頁要輸入）
  String officerPinVerifier = '';
  StreamSubscription<Map<String, dynamic>?>? _publicCloudSubscription;
  StreamSubscription<Map<String, dynamic>?>? _teacherCloudSubscription;
  StreamSubscription<List<Map<String, dynamic>>>? _registrationSubscription;
  bool _seatMutationPending = false;
  DateTime? _ignorePublicCloudUntil;
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

  int? get officerPinLength {
    final parts = officerPinVerifier.split(':');
    return parts.length == 3 ? int.tryParse(parts[0]) : null;
  }

  Future<void> setOfficerPin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw const FormatException('PIN 碼必須是 4 至 8 位數字');
    }
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final digest = sha256.convert([...salt, ...utf8.encode(pin)]).toString();
    officerPinVerifier = '${pin.length}:${base64UrlEncode(salt)}:$digest';
    await _save();
    notifyListeners();
  }

  bool verifyOfficerPin(String pin) => _verifyPin(officerPinVerifier, pin);

  bool _verifyPin(String verifier, String pin) {
    final parts = verifier.split(':');
    if (parts.length != 3 || int.tryParse(parts[0]) != pin.length) return false;
    try {
      final salt = base64Url.decode(parts[1]);
      final expected = parts[2];
      final actual = sha256.convert([...salt, ...utf8.encode(pin)]).toString();
      if (actual.length != expected.length) return false;
      var difference = 0;
      for (var i = 0; i < actual.length; i++) {
        difference |= actual.codeUnitAt(i) ^ expected.codeUnitAt(i);
      }
      return difference == 0;
    } on FormatException {
      return false;
    }
  }

  int? get bigScreenExitPinLength {
    final parts = bigScreenExitPinVerifier.split(':');
    return parts.length == 3 ? int.tryParse(parts[0]) : null;
  }

  Future<void> setBigScreenExitPin(String pin) async {
    if (!RegExp(r'^\d{4,8}$').hasMatch(pin)) {
      throw const FormatException('PIN 碼必須是 4 至 8 位數字');
    }
    final salt = List<int>.generate(16, (_) => Random.secure().nextInt(256));
    final saltText = base64UrlEncode(salt);
    final digest = sha256.convert([...salt, ...utf8.encode(pin)]).toString();
    bigScreenExitPinVerifier = '${pin.length}:$saltText:$digest';
    await _save();
    notifyListeners();
  }

  bool verifyBigScreenExitPin(String pin) {
    final parts = bigScreenExitPinVerifier.split(':');
    if (parts.length != 3 || int.tryParse(parts[0]) != pin.length) return false;
    try {
      final salt = base64Url.decode(parts[1]);
      final expected = parts[2];
      final actual = sha256.convert([...salt, ...utf8.encode(pin)]).toString();
      if (actual.length != expected.length) return false;
      var difference = 0;
      for (var i = 0; i < actual.length; i++) {
        difference |= actual.codeUnitAt(i) ^ expected.codeUnitAt(i);
      }
      return difference == 0;
    } on FormatException {
      return false;
    }
  }

  List<ReminderData> reminders = [];
  List<SeatData> seats = [];
  List<String> diary = [];
  List<String> schedule = [];
  List<ScheduleEntry> scheduleEntries = [];
  List<DiaryEntry> diaryEntries = [];
  List<TimePeriod> timePeriods = [];
  /// 教師即時通知（null = 目前沒有通知）
  TeacherNotice? teacherNotice;
  /// 懲罰抽籤的籤（教師後台管理）
  List<String> punishments = [];
  /// 教材資料夾（下課後自動打開下一節的教材）
  List<MaterialFolder> materialFolders = MaterialFolder.defaults();
  /// 下課後幾分鐘自動打開下一節的教材
  int materialOpenDelay = 5;
  /// Chrome 使用者清單（教師後台設定）
  List<ChromeProfile> chromeProfiles = [];
  /// 蓋章政策全文（空白 = 用內建的修正版）。格式：第一行標題；「一、」開頭是段落標題；其他每行一條
  String policyText = '';
  /// 兌換獎勵的項目（教師後台管理）
  List<RewardItem> rewards = [];
  /// 教師評分紀錄（每節課 1～5 顆星）：{id, date, lesson, subject, stars, at}
  List<Map<String, dynamic>> lessonRatings = [];
  /// 這台大屏已經關掉的通知 id（只存在本機，不同步）
  String dismissedNoticeId = '';
  /// 這台裝置最後一次看通知的時間（只存在本機）
  int notifSeenAt = 0;
  /// 聯絡簿文字大小（1.0 = 一頁 6 行；越大字越大、一頁行數越少）。只存在這台裝置
  double diaryTextScale = 1.0;
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
    await prefs.remove('teacherPassword');
    await prefs.remove('teacherSignedIn');
    cloudSyncEnabled = kFirebaseConfigured && firebaseRuntimeReady;
    final reminderRaw = prefs.getString(_remindersKey);
    final seatRaw = prefs.getString(_seatsKey);
    final diaryRaw = prefs.getString(_diaryKey);
    final noticeRaw = prefs.getString(_teacherNoticeKey);
    if (noticeRaw != null) {
      try {
        teacherNotice = TeacherNotice.tryParse(jsonDecode(noticeRaw));
      } catch (_) {}
    }
    dismissedNoticeId = prefs.getString(_dismissedNoticeKey) ?? '';
    notifSeenAt = prefs.getInt(_notifSeenKey) ?? 0;
    diaryTextScale = prefs.getDouble(_diaryTextScaleKey) ?? 1.0;
    try {
      final mf = prefs.getString(_materialFoldersKey);
      if (mf != null) {
        materialFolders = (jsonDecode(mf) as List)
            .whereType<Map>()
            .map((e) => MaterialFolder.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      materialOpenDelay = prefs.getInt(_materialOpenDelayKey) ?? 5;
      policyText = prefs.getString(_policyTextKey) ?? '';
      final cp = prefs.getString(_chromeProfilesKey);
      if (cp != null) {
        chromeProfiles = (jsonDecode(cp) as List)
            .whereType<Map>()
            .map((e) => ChromeProfile.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      _addMaterialKeyword('英語', '世界節慶萬花筒');
      _addMaterialKeyword('地理', '全球與鄉土');
      _addMaterialKeyword('美術', '視覺藝術');
      final p = prefs.getString(_punishmentsKey);
      if (p != null) punishments = (jsonDecode(p) as List).map((e) => e.toString()).toList();
      final lr = prefs.getString(_lessonRatingsKey);
      if (lr != null) {
        lessonRatings = (jsonDecode(lr) as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
      final r = prefs.getString(_rewardsKey);
      if (r != null) {
        rewards = (jsonDecode(r) as List)
            .whereType<Map>()
            .map((e) => RewardItem.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    } catch (_) {}
    final timePeriodsRaw = prefs.getString(_timePeriodsKey);
    if (timePeriodsRaw != null) {
      try {
        timePeriods = (jsonDecode(timePeriodsRaw) as List)
            .whereType<Map>()
            .map((e) => TimePeriod.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}
    }
    final scheduleRaw = prefs.getString(_scheduleKey);
    final attendanceRaw = prefs.getString(_attendanceKey);
    final studentRecordsRaw = prefs.getString(_studentRecordsKey);
    final cleanlinessRaw = prefs.getString(_cleanlinessKey);
    final photosRaw = prefs.getString(_photosKey);
    final weeklySelectionsRaw = prefs.getString(_weeklySelectionsKey);
    classId = _normalizeClassId(prefs.getString(_classIdKey) ?? '');
    deviceRole = prefs.getString(_deviceRoleKey) ?? '';
    bigScreenExitPinVerifier = prefs.getString(_bigScreenExitPinVerifierKey) ?? '';
    officerPinVerifier = prefs.getString(_officerPinVerifierKey) ?? '';
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
    // 大屏：套用全部公開資料。教師後台：只拿章數（大屏蓋章只寫在公開資料裡，教師後台以前收不到）
    final shouldWatch = cloudSyncEnabled && id.isNotEmpty && (deviceRole == 'bigscreen' || deviceRole == 'teacher');
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
        if (_seatMutationPending || (_ignorePublicCloudUntil?.isAfter(DateTime.now()) ?? false)) return;
        cloudSyncError = null;
        lastCloudSyncAt = DateTime.now();
        if (deviceRole == 'teacher') {
          unawaited(_applyPublicSeatScores(data));
        } else {
          unawaited(applyPublicCloudData(data));
        }
      },
      onError: (Object error, StackTrace stack) {
        cloudSyncError = error.toString();
        notifyListeners();
      },
    );
  }

  /// 教師後台：用雲端公開資料裡的章數更新自己的座位（只改章數，不動名字、位置）
  Future<void> _applyPublicSeatScores(Map<String, dynamic> data) async {
    final raw = data['seats'];
    if (raw is! List) return;
    final scores = <String, int>{};
    for (final e in raw.whereType<Map>()) {
      final number = '${e['number'] ?? ''}';
      final score = e['score'];
      if (number.isNotEmpty && score is num) scores[number] = score.toInt();
    }
    var changed = false;
    for (final seat in seats) {
      final s = scores[seat.number];
      if (s != null && s != seat.score) {
        seat.score = s;
        changed = true;
      }
    }
    if (!changed) return;
    // 存到本機和教師的雲端資料，這樣下次打開也是最新的章數
    await _save();
    notifyListeners();
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
        if (_seatMutationPending) return;
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
    await prefs.setString(_timePeriodsKey, jsonEncode(timePeriods.map((e) => e.toJson()).toList()));
    await prefs.setString(_teacherNoticeKey, jsonEncode(teacherNotice?.toJson()));
    await prefs.setString(_dismissedNoticeKey, dismissedNoticeId);
    await prefs.setString(_punishmentsKey, jsonEncode(punishments));
    await prefs.setString(_materialFoldersKey, jsonEncode(materialFolders.map((e) => e.toJson()).toList()));
    await prefs.setInt(_materialOpenDelayKey, materialOpenDelay);
    await prefs.setString(_chromeProfilesKey, jsonEncode(chromeProfiles.map((e) => e.toJson()).toList()));
    await prefs.setString(_policyTextKey, policyText);
    await prefs.setString(_rewardsKey, jsonEncode(rewards.map((e) => e.toJson()).toList()));
    await prefs.setString(_lessonRatingsKey, jsonEncode(lessonRatings));
    await prefs.setString(_scheduleKey, jsonEncode(scheduleEntries.map((e) => e.toJson()).toList()));
    await prefs.setString(_attendanceKey, jsonEncode(attendanceRecords.map((e) => e.toJson()).toList()));
    await prefs.setString(_studentRecordsKey, jsonEncode(studentRecords.map((e) => e.toJson()).toList()));
    await prefs.setString(_cleanlinessKey, jsonEncode(cleanlinessRecords.map((e) => e.toJson()).toList()));
    await prefs.setString(_photosKey, jsonEncode(classPhotos.map((e) => e.toJson()).toList()));
    await prefs.setString(_weeklySelectionsKey, jsonEncode(weeklySelections.map((e) => e.toJson()).toList()));
    await prefs.setString(_bigScreenExitPinVerifierKey, bigScreenExitPinVerifier);
    await prefs.setString(_officerPinVerifierKey, officerPinVerifier);
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
        cloud.pushPublicState(classId, snapshot),
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
        data['timePeriods'] is List ||
        data.containsKey('teacherNotice') ||
        data['punishments'] is List ||
        data['materialFolders'] is List ||
        data['chromeProfiles'] is List ||
        data['policyText'] is String ||
        data['rewards'] is List ||
        data['attendanceToday'] is List ||
        data['bigScreenExitPinVerifier'] is String ||
        data['officerPinVerifier'] is String ||
        data.containsKey('testNow')) {
      final publicData = <String, dynamic>{
        'reminders': data['reminders'] ?? reminders.map((e) => e.toJson()).toList(),
        'seats': data['seats'] ?? seats.map((e) => e.toJson()).toList(),
        'diaryEntries': data['diaryEntries'] ?? diaryEntries.map((e) => e.toJson()).toList(),
        'scheduleEntries': data['scheduleEntries'] ?? scheduleEntries.map((e) => e.toJson()).toList(),
        'timePeriods': data['timePeriods'] ?? timePeriods.map((e) => e.toJson()).toList(),
        'teacherNotice': data.containsKey('teacherNotice') ? data['teacherNotice'] : teacherNotice?.toJson(),
        'punishments': data['punishments'] ?? punishments,
        'materialFolders': data['materialFolders'] ?? materialFolders.map((e) => e.toJson()).toList(),
        'materialOpenDelay': data['materialOpenDelay'] ?? materialOpenDelay,
        'chromeProfiles': data['chromeProfiles'] ?? chromeProfiles.map((e) => e.toJson()).toList(),
        'policyText': data['policyText'] ?? policyText,
        'rewards': data['rewards'] ?? rewards.map((e) => e.toJson()).toList(),
        'attendanceRecords': data['attendanceToday'] ?? <dynamic>[],
        'studentRecords': <dynamic>[],
        'cleanlinessRecords': <dynamic>[],
        'classPhotos': <dynamic>[],
        'weeklySelections': <dynamic>[],
        'lateThreshold': data['lateThreshold'] ?? lateThreshold,
        'testNow': data['testNow'] is String ? data['testNow'] as String : null,
        'darkMode': darkMode,
        if (data['bigScreenExitPinVerifier'] is String) 'bigScreenExitPinVerifier': data['bigScreenExitPinVerifier'],
        if (data['officerPinVerifier'] is String) 'officerPinVerifier': data['officerPinVerifier'],
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
    if (data.containsKey('teacherNotice')) {
      teacherNotice = TeacherNotice.tryParse(data['teacherNotice']);
    }
    if (data['materialFolders'] is List) {
      materialFolders = (data['materialFolders'] as List)
          .whereType<Map>()
          .map((e) => MaterialFolder.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data['materialOpenDelay'] is num) materialOpenDelay = (data['materialOpenDelay'] as num).toInt();
    if (data['chromeProfiles'] is List) {
      chromeProfiles = (data['chromeProfiles'] as List)
          .whereType<Map>()
          .map((e) => ChromeProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data['policyText'] is String) policyText = data['policyText'] as String;
    if (data['punishments'] is List) {
      punishments = (data['punishments'] as List).map((e) => e.toString()).toList();
    }
    if (data['rewards'] is List) {
      rewards = (data['rewards'] as List)
          .whereType<Map>()
          .map((e) => RewardItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data['timePeriods'] is List) {
      timePeriods = (data['timePeriods'] as List)
          .whereType<Map>()
          .map((e) => TimePeriod.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
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
    if (data['bigScreenExitPinVerifier'] is String) {
      bigScreenExitPinVerifier = data['bigScreenExitPinVerifier'] as String;
    }
    if (data['officerPinVerifier'] is String) {
      officerPinVerifier = data['officerPinVerifier'] as String;
    }
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
    // 剛改完章數的 5 秒內不要被雲端的舊資料蓋回去（大屏和教師後台都一樣）
    _ignorePublicCloudUntil = DateTime.now().add(const Duration(seconds: 5));
    _seatMutationPending = true;
    notifyListeners();
    try {
      await _save();
    } finally {
      _seatMutationPending = false;
    }
  }

  Future<void> adjustSeatScoreByStudent(SeatData student, int delta) async {
    final index = seats.indexWhere((seat) => seat.number == student.number && seat.name == student.name);
    if (index < 0) {
      final fallback = seats.indexWhere((seat) => seat.number == student.number);
      if (fallback < 0) return;
      seats[fallback].score += delta;
    } else {
      seats[index].score += delta;
    }
    // 剛改完章數的 5 秒內不要被雲端的舊資料蓋回去（大屏和教師後台都一樣）
    _ignorePublicCloudUntil = DateTime.now().add(const Duration(seconds: 5));
    _seatMutationPending = true;
    notifyListeners();
    try {
      await _save();
    } finally {
      _seatMutationPending = false;
    }
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
      rowSeats[slot].number = '${row + 1}-${slot + 1}';
    }
  }

  Future<void> rotateSeats(int direction) async {
    if (seats.isEmpty) return;
    final gridWidth = (seats.map((seat) => seat.row).reduce((a, b) => a > b ? a : b) + 1).clamp(6, 10000);
    for (final seat in seats) {
      seat.row = (seat.row + direction) % gridWidth;
      if (seat.row < 0) seat.row += gridWidth;
    }
    await _save();
    notifyListeners();
  }

  Future<void> swapSeats(int firstIndex, int secondIndex) async {
    if (firstIndex == secondIndex) return;
    final first = seats[firstIndex];
    final second = seats[secondIndex];
    final firstRow = first.row;
    final firstSlot = first.slot;
    final secondRow = second.row;
    final secondSlot = second.slot;
    first.row = secondRow;
    first.slot = secondSlot;
    second.row = firstRow;
    second.slot = firstSlot;

    _seatMutationPending = true;
    notifyListeners();
    try {
      await _save();
    } finally {
      _seatMutationPending = false;
    }
  }

  Future<void> moveSeatTo(int index, {required int row, required int slot}) async {
    final target = seats[index];
    final occupied = seats.any((seat) => seat.row == row && seat.slot == slot && seat != target);
    if (occupied) return;
    if (target.row == row && target.slot == slot) return;

    target.row = row;
    target.slot = slot;
    _seatMutationPending = true;
    notifyListeners();
    try {
      await _save();
    } finally {
      _seatMutationPending = false;
    }
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

  /// 老師傳送即時通知（給新的 id，大屏就會重新跳出來）
  Future<void> sendTeacherNotice(TeacherNotice notice) async {
    teacherNotice = notice.copy()..id = DateTime.now().millisecondsSinceEpoch.toString();
    await _save();
    notifyListeners();
    unawaited(postEvent('bigscreen', '老師傳送了即時通知', teacherNotice!.text));
  }

  /// 老師收回通知（所有大屏都會關掉）
  Future<void> clearTeacherNotice() async {
    teacherNotice = null;
    await _save();
    notifyListeners();
  }

  /// 這台大屏關掉目前的通知（只影響本機）
  Future<void> dismissTeacherNotice() async {
    dismissedNoticeId = teacherNotice?.id ?? '';
    await _save(syncCloud: false);
    notifyListeners();
  }

  Future<void> savePolicyText(String value) async {
    policyText = value;
    await _save();
    notifyListeners();
  }

  Future<void> saveChromeProfiles(List<ChromeProfile> value) async {
    chromeProfiles = [for (final p in value) if (p.profileDir.trim().isNotEmpty) p];
    await _save();
    notifyListeners();
  }

  /// 依課表科目找要自動打開的 Chrome 使用者
  List<ChromeProfile> chromeFor(String subject) =>
      [for (final p in chromeProfiles) if (p.keywordList.isNotEmpty && p.matches(subject)) p];

  Future<void> saveMaterialFolders(List<MaterialFolder> value, int delay) async {
    materialFolders = [for (final m in value) if (m.path.trim().isNotEmpty) m];
    materialOpenDelay = delay.clamp(0, 30);
    await _save();
    notifyListeners();
  }

  /// 舊資料補上新的課表科目名稱（例如「世界節慶萬花筒」開英語）
  void _addMaterialKeyword(String name, String keyword) {
    for (final m in materialFolders) {
      if (m.name == name && !m.keywordList.contains(keyword)) {
        m.keywords = m.keywords.trim().isEmpty ? keyword : '${m.keywords},$keyword';
      }
    }
  }

  /// 依課表科目找教材資料夾（找不到回傳 null）
  MaterialFolder? materialFor(String subject) {
    for (final m in materialFolders) {
      if (m.keywordList.isNotEmpty && m.matches(subject)) return m;
    }
    return null;
  }

  Future<void> savePunishments(List<String> value) async {
    punishments = [for (final p in value) if (p.trim().isNotEmpty) p.trim()];
    await _save();
    notifyListeners();
  }

  Future<void> saveRewards(List<RewardItem> value) async {
    rewards = [for (final r in value) if (r.name.trim().isNotEmpty) RewardItem(name: r.name.trim(), cost: r.cost)];
    await _save();
    notifyListeners();
  }

  /// 同學兌換獎勵：扣章並留下紀錄。章不夠回傳 false。
  Future<bool> redeemReward(int seatIndex, RewardItem reward) async {
    if (seatIndex < 0 || seatIndex >= seats.length) return false;
    final seat = seats[seatIndex];
    if (seat.score < reward.cost) return false;
    studentRecords.insert(
        0,
        StudentRecord(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          studentNumber: seat.number,
          studentName: seat.name,
          date: _dateKey(DateTime.now()),
          time: _timeKey(DateTime.now()),
          type: '兌換',
          note: '${reward.name}（${reward.cost} 章）',
        ));
    await adjustSeatScore(seatIndex, -reward.cost);
    unawaited(postEvent('teacher', '兌換獎勵', '${seat.name} 用 ${reward.cost} 章兌換「${reward.name}」'));
    return true;
  }

  /// 發一則通知給另一邊（target：'teacher' 或 'bigscreen'）。失敗也不影響原本的動作。
  Future<void> postEvent(String target, String title, [String body = '']) async {
    if (!cloud.isConfigured || classId.trim().isEmpty) return;
    try {
      await cloud.pushEvent(classId, target: target, title: title, body: body);
    } catch (_) {}
  }

  Future<void> setDiaryTextScale(double value) async {
    diaryTextScale = value.clamp(0.5, 1.5);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_diaryTextScaleKey, diaryTextScale);
    notifyListeners();
  }

  Future<void> markNotificationsSeen() async {
    notifSeenAt = DateTime.now().millisecondsSinceEpoch;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notifSeenKey, notifSeenAt);
    notifyListeners();
  }

  /// 這節課是否已經評過分（key = 日期_節次）
  bool isLessonRated(String key) => lessonRatings.any((e) => e['id'] == key);

  /// 送出教師評分：存在本機，也存到雲端 classes/{班級}/ratings，並通知教師後台
  Future<void> submitLessonRating({
    required String key,
    required String date,
    required int lesson,
    required String subject,
    required int stars,
  }) async {
    final rating = <String, dynamic>{
      'id': key,
      'date': date,
      'lesson': lesson,
      'subject': subject,
      'stars': stars,
      'at': DateTime.now().millisecondsSinceEpoch,
    };
    lessonRatings.removeWhere((e) => e['id'] == key);
    lessonRatings.add(rating);
    await _save(syncCloud: false);
    notifyListeners();
    if (cloud.isConfigured && classId.trim().isNotEmpty) {
      try {
        await cloud.pushRating(classId, rating);
      } catch (_) {}
    }
    unawaited(postEvent('teacher', '教師評分：第 ${lesson + 1} 節 $subject', '${'★' * stars}${'☆' * (5 - stars)}'));
  }

  /// 大屏現在要不要顯示通知
  bool get showTeacherNotice => teacherNotice != null && teacherNotice!.id != dismissedNoticeId;

  Future<void> saveTimePeriods(List<TimePeriod> value) async {
    timePeriods = [...value]..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    await _save();
    notifyListeners();
  }

  /// 現在所在的特殊顯示時段；[overrideOnly] 為 true 時只找「蓋過上課」的時段
  TimePeriod? periodAt(DateTime time, {bool overrideOnly = false}) {
    final minutes = time.hour * 60 + time.minute;
    for (final p in timePeriods) {
      if (overrideOnly && !p.overrideLesson) continue;
      if (p.startMinutes >= 0 && minutes >= p.startMinutes && minutes < p.endMinutes) return p;
    }
    return null;
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
    final isLate = late ?? isLateAt(value);
    attendanceRecords.removeWhere((item) => item.studentNumber == student.number && item.date == _dateKey(value));
    attendanceRecords.add(AttendanceRecord(
      studentNumber: student.number,
      studentName: student.name,
      date: _dateKey(value),
      time: _timeKey(value),
      late: isLate,
    ));
    if (!isLate) {
      await adjustSeatScoreByStudent(student, 1);
      return;
    }
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
    final lowered = type.trim();
    final isPenalty =
        lowered.contains('秩序') || lowered.contains('晚進') || lowered.contains('缺交') || lowered.contains('被記');
    if (isPenalty) {
      await adjustSeatScoreByStudent(student, -1);
      return;
    }
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
      unawaited(postEvent('teacher', '新的登記：$type', '${student.number} ${student.name}${note.isEmpty ? '' : '・$note'}'));
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
        'timePeriods': timePeriods.map((e) => e.toJson()).toList(),
        'teacherNotice': teacherNotice?.toJson(),
        'punishments': punishments,
        'materialFolders': materialFolders.map((e) => e.toJson()).toList(),
        'materialOpenDelay': materialOpenDelay,
        'chromeProfiles': chromeProfiles.map((e) => e.toJson()).toList(),
        'policyText': policyText,
        'rewards': rewards.map((e) => e.toJson()).toList(),
        'darkMode': darkMode,
        'testNow': testNow?.toIso8601String(),
        'attendanceRecords': attendanceRecords.map((e) => e.toJson()).toList(),
        'studentRecords': studentRecords.map((e) => e.toJson()).toList(),
        'cleanlinessRecords': cleanlinessRecords.map((e) => e.toJson()).toList(),
        'classPhotos': classPhotos.map((e) => e.toJson()).toList(),
        'weeklySelections': weeklySelections.map((e) => e.toJson()).toList(),
        'lateThreshold': lateThreshold,
        'bigScreenExitPinVerifier': bigScreenExitPinVerifier,
        'officerPinVerifier': officerPinVerifier,
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
    timePeriods = ((data['timePeriods'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => TimePeriod.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    teacherNotice = TeacherNotice.tryParse(data['teacherNotice']);
    punishments = ((data['punishments'] as List?) ?? []).map((e) => e.toString()).toList();
    if (data['materialFolders'] is List) {
      materialFolders = (data['materialFolders'] as List)
          .whereType<Map>()
          .map((e) => MaterialFolder.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data['materialOpenDelay'] is num) materialOpenDelay = (data['materialOpenDelay'] as num).toInt();
    if (data['chromeProfiles'] is List) {
      chromeProfiles = (data['chromeProfiles'] as List)
          .whereType<Map>()
          .map((e) => ChromeProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    if (data['policyText'] is String) policyText = data['policyText'] as String;
    rewards = ((data['rewards'] as List?) ?? [])
        .whereType<Map>()
        .map((e) => RewardItem.fromJson(Map<String, dynamic>.from(e)))
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
    if (data['bigScreenExitPinVerifier'] is String) {
      bigScreenExitPinVerifier = data['bigScreenExitPinVerifier'] as String;
    }
    if (data['officerPinVerifier'] is String) {
      officerPinVerifier = data['officerPinVerifier'] as String;
    }
    if (data['darkMode'] is bool) {
      darkMode = data['darkMode'] as bool;
    }
    if (!preserveTestNow) {
      testNow = data['testNow'] is String ? DateTime.tryParse(data['testNow'] as String) : null;
    }
  }
}
