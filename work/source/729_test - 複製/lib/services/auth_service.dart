import 'package:firebase_auth/firebase_auth.dart';
import '../firebase_config_flag.dart';

/// Wraps FirebaseAuth so the rest of the app never talks to Firebase directly.
/// If Firebase hasn't been configured yet ([kFirebaseConfigured] is false), every
/// call fails gracefully with a Chinese error message instead of throwing.
class AuthService {
  FirebaseAuth? get _auth => kFirebaseConfigured ? FirebaseAuth.instance : null;

  bool get isConfigured => kFirebaseConfigured;

  Stream<User?> get authStateChanges => _auth?.authStateChanges() ?? const Stream<User?>.empty();

  User? get currentUser => _auth?.currentUser;

  Future<String?> signIn(String email, String password) async {
    final auth = _auth;
    if (auth == null) return '雲端尚未設定，請先執行 flutterfire configure';
    try {
      await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  Future<String?> signUp(String email, String password) async {
    final auth = _auth;
    if (auth == null) return '雲端尚未設定，請先執行 flutterfire configure';
    try {
      await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      return null;
    } on FirebaseAuthException catch (e) {
      return _message(e);
    }
  }

  Future<void> signOut() async {
    await _auth?.signOut();
  }

  String _message(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return '找不到這個帳號';
      case 'wrong-password':
      case 'invalid-credential':
        return '密碼錯誤';
      case 'email-already-in-use':
        return '這個帳號已經被註冊過了';
      case 'weak-password':
        return '密碼強度不夠，至少需要 6 個字元';
      case 'invalid-email':
        return '帳號格式不正確';
      default:
        return e.message ?? '登入失敗，請稍後再試';
    }
  }
}
