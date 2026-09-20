import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_config_flag.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static const account = 'c729';
  static const defaultPassword = 'Aa29289493';
  static const _passwordKey = 'teacherPassword';
  static const _signedInKey = 'teacherSignedIn';
  static const _classIdKey = 'classId';

  bool get isConfigured => true;

  Future<bool> get isSignedIn async {
    final prefs = await SharedPreferences.getInstance();
    final signedIn = prefs.getBool(_signedInKey) ?? false;
    if (signedIn) await ensureFirebaseSession();
    return signedIn;
  }

  Future<String> _resolveSavedPassword(SharedPreferences prefs) async {
    final localPassword = prefs.getString(_passwordKey) ?? defaultPassword;
    final classId = (prefs.getString(_classIdKey) ?? '').trim();
    if (classId.isEmpty || !kFirebaseConfigured || !firebaseRuntimeReady) return localPassword;
    try {
      final remotePassword = await loadTeacherPasswordFromCloud(classId);
      if (remotePassword != null && remotePassword.trim().isNotEmpty) {
        if (remotePassword != localPassword) {
          await prefs.setString(_passwordKey, remotePassword);
        }
        return remotePassword;
      }
    } catch (_) {
      // Ignore remote lookup errors and fall back to local password.
    }
    return localPassword;
  }

  Future<String?> loadTeacherPasswordFromCloud(String classId) async {
    final trimmedClassId = classId.trim();
    if (trimmedClassId.isEmpty || !kFirebaseConfigured || !firebaseRuntimeReady) return null;
    final authError = await ensureFirebaseSession();
    if (authError != null) {
      debugPrint('[AuthService] loadTeacherPasswordFromCloud: auth unavailable: $authError');
      return null;
    }
    final remoteSnapshot = await FirebaseFirestore.instance
        .collection('classes')
        .doc(trimmedClassId)
        .collection('private')
        .doc('state')
        .get();
    return remoteSnapshot.data()?['teacherPassword'] as String?;
  }

  Future<void> syncTeacherPasswordToCloud(String password, {String? classIdOverride}) async {
    final prefs = await SharedPreferences.getInstance();
    final classId = (classIdOverride ?? prefs.getString(_classIdKey) ?? '').trim();
    if (classId.isEmpty || !kFirebaseConfigured || !firebaseRuntimeReady) return;
    final authError = await ensureFirebaseSession();
    if (authError != null) {
      debugPrint('[AuthService] syncTeacherPasswordToCloud: auth unavailable: $authError');
      return;
    }
    await FirebaseFirestore.instance.collection('classes').doc(classId).collection('private').doc('state').set(
      {'teacherPassword': password},
      SetOptions(merge: true),
    );
    await prefs.setString(_passwordKey, password);
  }

  Future<String?> signIn(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPassword = await _resolveSavedPassword(prefs);
    if (username.trim() != account) return '帳號錯誤';
    if (password != savedPassword) return '密碼錯誤';
    await prefs.setBool(_signedInKey, true);
    await ensureFirebaseSession();
    await syncTeacherPasswordToCloud(savedPassword);
    return null;
  }

  static Future<User> ensureAnonymouslyAuthenticated() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      debugPrint('[AuthService] Already authenticated with UID: ${currentUser.uid}');
      return currentUser;
    }

    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        throw Exception('Anonymous sign-in returned null user.');
      }
      debugPrint('[AuthService] Anonymous sign-in success: ${user.uid}');
      return user;
    } on FirebaseAuthException catch (error) {
      debugPrint('[AuthService] Anonymous sign-in failed: ${error.code} ${error.message}');
      rethrow;
    } catch (error) {
      debugPrint('[AuthService] Anonymous sign-in error: $error');
      rethrow;
    }
  }

  Future<String?> ensureFirebaseSession() async {
    if (!kFirebaseConfigured || !firebaseRuntimeReady) return 'Firebase 尚未初始化';
    if (_auth.currentUser != null) return null;
    try {
      await ensureAnonymouslyAuthenticated();
      return null;
    } on FirebaseAuthException catch (error) {
      debugPrint('Firebase anonymous sign-in failed: ${error.code} ${error.message}');
      return error.message ?? error.code;
    } catch (error) {
      debugPrint('Firebase anonymous sign-in error: $error');
      return error.toString();
    }
  }

  Future<String?> changePassword(String currentPassword, String newPassword) async {
    final prefs = await SharedPreferences.getInstance();
    final classId = (prefs.getString(_classIdKey) ?? '').trim();
    final savedPassword = await _resolveSavedPassword(prefs);
    if (currentPassword != savedPassword) return '目前密碼錯誤';
    if (newPassword.length < 6) return '新密碼至少需要 6 個字元';
    await prefs.setString(_passwordKey, newPassword);
    if (kFirebaseConfigured && firebaseRuntimeReady) {
      final authError = await ensureFirebaseSession();
      if (authError != null) {
        debugPrint('[AuthService] changePassword: auth unavailable: $authError');
        return '雲端驗證失敗，請重試';
      }
      if (classId.isNotEmpty) {
        try {
          await syncTeacherPasswordToCloud(newPassword, classIdOverride: classId);
        } catch (_) {
          // Keep the local update even if cloud sync is temporarily unavailable.
        }
      }
    }
    return null;
  }

  Future<void> signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_signedInKey, false);
    if (kFirebaseConfigured && firebaseRuntimeReady) {
      await FirebaseAuth.instance.signOut();
    }
  }
}
