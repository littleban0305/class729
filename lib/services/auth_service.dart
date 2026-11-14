import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../firebase_config_flag.dart';

class AuthService {
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<User> ensureAnonymouslyAuthenticated() async {
    final currentUser = _auth.currentUser;
    if (currentUser != null) return currentUser;

    try {
      final credential = await _auth.signInAnonymously();
      final user = credential.user;
      if (user == null) {
        throw StateError('Anonymous sign-in returned null user.');
      }
      return user;
    } on FirebaseAuthException catch (error) {
      debugPrint(
          '[AuthService] Anonymous sign-in failed: ${error.code} ${error.message}');
      rethrow;
    } catch (error) {
      debugPrint('[AuthService] Anonymous sign-in error: $error');
      rethrow;
    }
  }

  Future<String?> ensureFirebaseSession() async {
    if (!kFirebaseConfigured || !firebaseRuntimeReady) {
      return 'Firebase 尚未初始化';
    }
    if (_auth.currentUser != null) return null;
    try {
      await ensureAnonymouslyAuthenticated();
      return null;
    } on FirebaseAuthException catch (error) {
      debugPrint(
          'Firebase anonymous sign-in failed: ${error.code} ${error.message}');
      return error.message ?? error.code;
    } catch (error) {
      debugPrint('Firebase anonymous sign-in error: $error');
      return error.toString();
    }
  }
}
