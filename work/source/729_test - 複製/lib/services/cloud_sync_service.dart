import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../firebase_config_flag.dart';

/// 雲端同步服務：
/// - classes/{classId}：大屏可公開讀取的資料（提醒、座位、課表、聯絡簿、今日簽到狀態）
/// - classes/{classId}/private/state：教師私有完整資料，需要 Firebase Auth
///
/// 這樣可以避免把秩序、缺交作業、整潔評分、照片與完整簽到時間直接公開給大屏。
class CloudSyncService {
  FirebaseFirestore? get _db => kFirebaseConfigured ? FirebaseFirestore.instance : null;

  bool get isConfigured => kFirebaseConfigured;

  CollectionReference<Map<String, dynamic>> _classes(FirebaseFirestore db) => db.collection('classes');

  Map<String, dynamic> _publicData(Map<String, dynamic> data) {
    final publicData = <String, dynamic>{
      'version': data['version'] ?? 1,
      'reminders': data['reminders'] ?? <dynamic>[],
      'seats': data['seats'] ?? <dynamic>[],
      'diaryEntries': data['diaryEntries'] ?? <dynamic>[],
      'scheduleEntries': data['scheduleEntries'] ?? <dynamic>[],
      // 大屏只需要知道今天誰已簽到，不需要看到精確時間或遲到紀錄。
      'attendanceToday': _publicAttendanceToday(data['attendanceRecords']),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return publicData;
  }

  List<Map<String, dynamic>> _publicAttendanceToday(dynamic raw) {
    final today = DateTime.now();
    final dateKey = '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['date'] as String? ?? '') == dateKey)
        .map((e) => <String, dynamic>{
              'studentNumber': e['studentNumber'] as String? ?? '',
              'studentName': e['studentName'] as String? ?? '',
              'date': dateKey,
            })
        .toList();
  }

  Future<void> pushState(String classId, Map<String, dynamic> data) async {
    final db = _db;
    final id = classId.trim();
    if (db == null || id.isEmpty) return;

    // 公開資料使用 merge，避免大屏簽到更新把其他欄位覆蓋掉。
    await _classes(db).doc(id).set(_publicData(data), SetOptions(merge: true));
    await _classes(db).doc(id).collection('private').doc('state').set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: false));
  }

  Future<void> pushAttendanceToday(String classId, Map<String, dynamic> data) async {
    final db = _db;
    final id = classId.trim();
    if (db == null || id.isEmpty) return;
    await _classes(db).doc(id).set({
      'attendanceToday': _publicAttendanceToday(data['attendanceRecords']),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> fetchState(String classId) async {
    final db = _db;
    final id = classId.trim();
    if (db == null || id.isEmpty) return null;

    final privateSnapshot = await _classes(db).doc(id).collection('private').doc('state').get();
    if (privateSnapshot.exists) return privateSnapshot.data();

    // 相容舊版：如果以前只有 classes/{classId}，仍可讀取舊的整包資料。
    final publicSnapshot = await _classes(db).doc(id).get();
    return publicSnapshot.data();
  }

  Stream<Map<String, dynamic>?> watchState(String classId) {
    final db = _db;
    final id = classId.trim();
    if (db == null || id.isEmpty) return const Stream.empty();
    return _classes(db).doc(id).snapshots().map((doc) => doc.data());
  }

  /// BigScreen 專用的公開即時資料監聽。
  Stream<Map<String, dynamic>?> watchPublicState(String classId) => watchState(classId);
}