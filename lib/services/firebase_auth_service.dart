import 'package:firebase_auth/firebase_auth.dart';

class FirebaseAuthService {
  FirebaseAuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;

  static Future<void> ensureSignedIn() async {
    if (_auth.currentUser != null) {
      return;
    }

    await _auth.signInAnonymously();
  }

  static User? get currentUser => _auth.currentUser;

  static Future<void> logout() async {
    await _auth.signOut();
  }
}
