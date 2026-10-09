import 'package:shared_preferences/shared_preferences.dart';

class SessionService {
  SessionService._();

  static const String _isLoggedInKey = 'isLoggedIn';
  static const String _userTypeKey = 'userType';
  static const String _libraryIdKey = 'libraryId';

  // ============================================================
  // SAVE STUDENT SESSION
  // ============================================================

  static Future<void> saveStudentSession(String libraryId) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userTypeKey, 'student');
    await prefs.setString(_libraryIdKey, libraryId);
  }

  // ============================================================
  // SAVE ADMIN SESSION
  // ============================================================

  static Future<void> saveAdminSession() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setBool(_isLoggedInKey, true);
    await prefs.setString(_userTypeKey, 'admin');

    await prefs.remove(_libraryIdKey);
  }

  // ============================================================
  // CHECK LOGIN STATUS
  // ============================================================

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getBool(_isLoggedInKey) ?? false;
  }

  // ============================================================
  // GET USER TYPE
  // ============================================================

  static Future<String?> getUserType() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_userTypeKey);
  }

  // ============================================================
  // GET STUDENT LIBRARY ID
  // ============================================================

  static Future<String?> getLibraryId() async {
    final prefs = await SharedPreferences.getInstance();

    return prefs.getString(_libraryIdKey);
  }

  // ============================================================
  // LOGOUT
  // ============================================================

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_isLoggedInKey);
    await prefs.remove(_userTypeKey);
    await prefs.remove(_libraryIdKey);
  }
}
