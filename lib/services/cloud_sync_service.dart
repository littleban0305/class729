import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../firebase_config_flag.dart';
import 'auth_service.dart';

/// 雲端同步服務：
/// - classes/{classId}：大屏可公開讀取的資料（提醒、座位、課表、聯絡簿、今日簽到狀態）
/// - classes/{classId}/private/state：教師私有完整資料，需要 Firebase Auth
///
/// 這樣可以避免把秩序不佳、缺交作業、整潔評分、照片與完整簽到時間直接公開給大屏。
class CloudSyncService {
  FirebaseFirestore? get _db => kFirebaseConfigured && firebaseRuntimeReady ? FirebaseFirestore.instance : null;

  bool get isConfigured => kFirebaseConfigured;

  static Map<String, dynamic> mergePrivateState({
    required Map<String, dynamic> existing,
    required Map<String, dynamic> incoming,
  }) {
    final merged = Map<String, dynamic>.from(existing);
    for (final entry in incoming.entries) {
      if (entry.key == 'teacherPassword') {
        final value = entry.value;
        if (value != null && value.toString().trim().isNotEmpty) {
          merged['teacherPassword'] = value;
        }
        continue;
      }
      merged[entry.key] = entry.value;
    }
    return merged;
  }

  CollectionReference<Map<String, dynamic>> _classes(FirebaseFirestore db) => db.collection('classes');

  Future<User> _ensureAuthenticatedUser() async {
    if (!kFirebaseConfigured || !firebaseRuntimeReady) {
      throw StateError('Firebase 尚未初始化');
    }
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) return currentUser;
    try {
      return await AuthService.ensureAnonymouslyAuthenticated();
    } catch (error) {
      debugPrint('[CloudSyncService] Auth before access failed: $error');
      rethrow;
    }
  }

  Future<void> _ensureWriteUser() async {
    await _ensureAuthenticatedUser();
  }

  Map<String, dynamic> _publicData(Map<String, dynamic> data) {
    final publicData = <String, dynamic>{
      'version': data['version'] ?? 1,
      'reminders': data['reminders'] ?? <dynamic>[],
      'seats': data['seats'] ?? <dynamic>[],
      'diaryEntries': data['diaryEntries'] ?? <dynamic>[],
      'scheduleEntries': data['scheduleEntries'] ?? <dynamic>[],
      'lateThreshold': data['lateThreshold'] ?? '07:30',
      'testNow': data['testNow'],
      // 教師端/後台需要知道精確簽到時間；公開資料仍保留今日簽到狀態，並維持實際打卡時間。
      'attendanceToday': _publicAttendanceToday(data['attendanceRecords']),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    return publicData;
  }

  List<Map<String, dynamic>> _publicAttendanceToday(dynamic raw) {
    final today = DateTime.now();
    final dateKey =
        '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    if (raw is! List) return <Map<String, dynamic>>[];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .where((e) => (e['date'] as String? ?? '') == dateKey)
        .map((e) => <String, dynamic>{
              'studentNumber': e['studentNumber'] as String? ?? '',
              'studentName': e['studentName'] as String? ?? '',
              'date': e['date'] as String? ?? dateKey,
              'time': e['time'] as String? ?? '',
              'late': e['late'] as bool? ?? false,
            })
        .toList();
  }

  Future<void> pushPublicState(String classId, Map<String, dynamic> data) async {
    final db = _db;
    final id = classId.trim();
    if (db == null) throw StateError('Firebase 尚未初始化');
    if (id.isEmpty) throw StateError('請先設定班級代碼');
    await _ensureWriteUser();
    await _classes(db).doc(id).set(_publicData(data), SetOptions(merge: true));
  }

  String _normalizeClassId(String value) {
    final trimmed = value.trim();
    return trimmed;
  }

  Future<void> pushPublicDiary(String classId, Map<String, dynamic> data) async {
    final db = _db;
    final id = _normalizeClassId(classId);
    if (db == null) throw StateError('Firebase 尚未初始化');
    if (id.isEmpty) throw StateError('請先設定班級代碼');
    await _ensureWriteUser();
    await _classes(db).doc(id).set({
      'diaryEntries': data['diaryEntries'] ?? <dynamic>[],
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> pushState(String classId, Map<String, dynamic> data) async {
    final db = _db;
    final id = _normalizeClassId(classId);
    if (db == null) throw StateError('Firebase 尚未初始化');
    if (id.isEmpty) throw StateError('請先設定班級代碼');
    await _ensureWriteUser();

    // 公開資料使用 merge，避免大屏簽到更新把其他欄位覆蓋掉。
    await _classes(db).doc(id).set(_publicData(data), SetOptions(merge: true));
    final privateData = Map<String, dynamic>.from(data)..remove('testNow');
    final existingPrivate = (await _classes(db).doc(id).collection('private').doc('state').get()).data() ?? {};
    final mergedPrivate = mergePrivateState(
      existing: existingPrivate,
      incoming: {
        ...privateData,
        'updatedAt': FieldValue.serverTimestamp(),
      },
    );
    await _classes(db).doc(id).collection('private').doc('state').set(mergedPrivate, SetOptions(merge: true));
  }

  Future<void> pushAttendanceToday(String classId, Map<String, dynamic> data) async {
    final db = _db;
    final id = _normalizeClassId(classId);
    if (db == null) throw StateError('Firebase 尚未初始化');
    if (id.isEmpty) throw StateError('請先設定班級代碼');
    await _ensureWriteUser();
    await _classes(db).doc(id).set({
      'attendanceToday': _publicAttendanceToday(data['attendanceRecords']),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> fetchState(String classId) async {
    final db = _db;
    final id = _normalizeClassId(classId);
    if (db == null) throw StateError('Firebase 尚未初始化');
    if (id.isEmpty) throw StateError('請先設定班級代碼');

    await _ensureAuthenticatedUser();
    final privateSnapshot = await _classes(db).doc(id).collection('private').doc('state').get();
    if (privateSnapshot.exists) return privateSnapshot.data();

    // 相容舊版：如果以前只有 classes/{classId}，仍可讀取舊的整包資料。
    final publicSnapshot = await _classes(db).doc(id).get();
    return publicSnapshot.data();
  }

  Stream<Map<String, dynamic>?> watchPrivateState(String classId) {
    final db = _db;
    final id = classId.trim();
    if (db == null || id.isEmpty) return const Stream.empty();
    return Stream.fromFuture(_ensureAuthenticatedUser()).asyncExpand((_) {
      return _classes(db)
          .doc(id)
          .collection('private')
          .doc('state')
          .snapshots(includeMetadataChanges: true)
          .map((doc) => doc.data());
    });
  }

  Stream<Map<String, dynamic>?> watchState(String classId) => watchPrivateState(classId);

  /// BigScreen 專用的公開即時資料監聽。
  Stream<Map<String, dynamic>?> watchPublicState(String classId) {
    final db = _db;
    final id = classId.trim();
    if (db == null || id.isEmpty) return const Stream.empty();

    return Stream.fromFuture(_ensureAuthenticatedUser()).asyncExpand((_) {
      return _classes(db).doc(id).snapshots(includeMetadataChanges: true).map((doc) => doc.data()).handleError((error) {
        debugPrint('[CloudSyncService] watchPublicState error: $error');
        return null;
      });
    });
  }

  Future<void> pushRegistration(String classId, Map<String, dynamic> data) async {
    final db = _db;
    final id = classId.trim();
    if (db == null) throw StateError('Firebase 尚未初始化');
    if (id.isEmpty) throw StateError('請先設定班級代碼');
    await _ensureWriteUser();
    final submissionId = data['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString();
    await _classes(db).doc(id).collection('submissions').doc(submissionId).set({
      ...data,
      'source': 'bigscreen',
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateRegistration(String classId, String id, Map<String, dynamic> data) async {
    final db = _db;
    final classKey = classId.trim();
    if (db == null || classKey.isEmpty || id.isEmpty) return;
    await _ensureWriteUser();
    await _classes(db).doc(classKey).collection('submissions').doc(id).set(data, SetOptions(merge: true));
  }

  Future<void> deleteRegistration(String classId, String id) async {
    final db = _db;
    final classKey = classId.trim();
    if (db == null || classKey.isEmpty || id.isEmpty) return;
    await _ensureWriteUser();
    await _classes(db).doc(classKey).collection('submissions').doc(id).delete();
  }

  Stream<List<Map<String, dynamic>>> watchRegistrations(String classId) {
    final db = _db;
    final id = classId.trim();
    if (db == null || id.isEmpty) return const Stream.empty();
    return Stream.fromFuture(_ensureAuthenticatedUser()).asyncExpand((_) {
      return _classes(db).doc(id).collection('submissions').snapshots().map(
            (snapshot) => snapshot.docs.map((doc) => doc.data()).toList(),
          );
    });
  }
}
