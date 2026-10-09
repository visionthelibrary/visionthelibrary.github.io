import 'package:cloud_firestore/cloud_firestore.dart';

class AttendanceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _dateId(DateTime date) {
    return "${date.year}-"
        "${date.month.toString().padLeft(2, '0')}-"
        "${date.day.toString().padLeft(2, '0')}";
  }

  DocumentReference<Map<String, dynamic>> _dayDocument(
    String libraryId,
    DateTime date,
  ) {
    return _firestore
        .collection("attendance")
        .doc(libraryId)
        .collection("days")
        .doc(_dateId(date));
  }

  List<Map<String, dynamic>> _getSessions(Map<String, dynamic> data) {
    final rawSessions = data["sessions"];

    if (rawSessions is List) {
      return rawSessions
          .whereType<Map>()
          .map((session) => Map<String, dynamic>.from(session))
          .toList();
    }

    // Old single-session data compatibility.
    final entryAt = data["entryAt"];
    final exitAt = data["exitAt"];

    if (entryAt != null) {
      return [
        {
          "sessionNo": 1,
          "entryAt": entryAt,
          "exitAt": exitAt,
          "autoEntry": data["autoEntry"] ?? false,
          "autoExit": data["autoExit"] ?? false,
        },
      ];
    }

    return [];
  }

  bool _hasOpenSession(Map<String, dynamic> data) {
    final sessions = _getSessions(data);

    if (sessions.isEmpty) {
      return false;
    }

    final lastSession = sessions.last;

    return lastSession["entryAt"] != null && lastSession["exitAt"] == null;
  }

  Future<int> _getMaxSessions() async {
    try {
      final snapshot = await _firestore
          .collection("library_settings")
          .doc("config")
          .get();

      if (!snapshot.exists) {
        return 3;
      }

      final data = snapshot.data();

      final value = data?["maxSessionsPerDay"];

      if (value is int && value > 0) {
        return value;
      }

      if (value is num && value > 0) {
        return value.toInt();
      }

      return 3;
    } catch (_) {
      return 3;
    }
  }

  /// Checks and processes attendance rollover when
  /// the student opens the app.
  ///
  /// IMPORTANT:
  /// The app does NOT run in the background.
  ///
  /// Example:
  ///
  /// Day 1
  /// 08:00 PM -> Manual Entry
  /// No Manual Exit
  ///
  /// Day 2
  /// App opened
  /// -> Day 1 session is completed at 11:59:59 PM
  /// -> Day 2 automatic entry is created at 12:00:00 AM
  ///
  /// If Day 2 student manually exits:
  ///
  /// Day 2
  /// 12:00 AM -> Auto Entry
  /// 05:00 AM -> Manual Exit
  ///
  /// Day 3
  /// -> No automatic entry
  ///
  /// If Day 2 is still open when Day 3 is opened:
  ///
  /// Day 2 -> Auto Exit at 11:59:59 PM
  /// Day 3 -> Auto Entry at 12:00:00 AM
  Future<void> checkPreviousAttendance(String libraryId) async {
    try {
      final now = DateTime.now();

      final todayStart = DateTime(now.year, now.month, now.day, 0, 0, 0);

      final previousDay = todayStart.subtract(const Duration(days: 1));

      final previousDocument = _dayDocument(libraryId, previousDay);

      final todayDocument = _dayDocument(libraryId, todayStart);

      final previousSnapshot = await previousDocument.get();

      /*
       * No previous attendance means there is
       * nothing to rollover.
       */
      if (!previousSnapshot.exists) {
        return;
      }

      final previousData = previousSnapshot.data();

      if (previousData == null) {
        return;
      }

      /*
       * If previous day is already completed,
       * DO NOT create automatic entry today.
       */
      if (!_hasOpenSession(previousData)) {
        return;
      }

      final previousSessions = _getSessions(previousData);

      if (previousSessions.isEmpty) {
        return;
      }

      final previousLastIndex = previousSessions.length - 1;

      final previousLastSession = Map<String, dynamic>.from(
        previousSessions[previousLastIndex],
      );

      /*
       * Safety check.
       */
      if (previousLastSession["entryAt"] == null) {
        return;
      }

      if (previousLastSession["exitAt"] != null) {
        return;
      }

      /*
       * Previous day's open session is
       * automatically closed at 11:59:59 PM.
       */
      final automaticExit = Timestamp.fromDate(
        DateTime(
          previousDay.year,
          previousDay.month,
          previousDay.day,
          23,
          59,
          59,
        ),
      );

      previousLastSession["exitAt"] = automaticExit;

      previousLastSession["autoExit"] = true;

      previousSessions[previousLastIndex] = previousLastSession;

      await previousDocument.update({
        "sessions": previousSessions,
        "exitAt": automaticExit,
        "status": "Completed",
        "autoExit": true,
        "updatedAt": FieldValue.serverTimestamp(),
      });

      /*
       * Now check today's document.
       *
       * We create today's automatic session
       * ONLY if today's attendance does not
       * already exist.
       */
      final todaySnapshot = await todayDocument.get();

      /*
       * If today already has attendance,
       * NEVER overwrite it.
       *
       * This protects a manually completed
       * today's session.
       */
      if (todaySnapshot.exists) {
        final todayData = todaySnapshot.data();

        if (todayData != null) {
          final todaySessions = _getSessions(todayData);

          if (todaySessions.isNotEmpty) {
            return;
          }
        }
      }

      /*
       * Check maximum session limit.
       *
       * Automatic midnight entry counts as
       * one session for the new day.
       */
      final maxSessions = await _getMaxSessions();

      if (maxSessions <= 0) {
        return;
      }

      /*
       * Automatic entry exactly at 12:00 AM.
       */
      final automaticEntry = Timestamp.fromDate(todayStart);

      final todaySessions = [
        {
          "sessionNo": 1,
          "entryAt": automaticEntry,
          "exitAt": null,
          "autoEntry": true,
          "autoExit": false,
        },
      ];

      await todayDocument.set({
        "libraryId": libraryId,
        "date": _dateId(todayStart),
        "status": "Present",

        "entryAt": automaticEntry,
        "exitAt": null,

        "sessions": todaySessions,

        "currentSession": 1,
        "totalSessions": 1,

        "autoEntry": true,
        "autoExit": false,

        "wifiName": "Vision",
        "markedBy": "System",

        "createdAt": FieldValue.serverTimestamp(),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      // Do not crash the Attendance screen if
      // rollover checking fails.
      //
      // The student can still use manual
      // attendance.
      return;
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getTodayAttendance(
    String libraryId,
  ) async {
    final today = DateTime.now();

    return _dayDocument(libraryId, today).get();
  }

  Future<List<Map<String, dynamic>>> getTodaySessions(String libraryId) async {
    final snapshot = await getTodayAttendance(libraryId);

    if (!snapshot.exists) {
      return [];
    }

    final data = snapshot.data();

    if (data == null) {
      return [];
    }

    return _getSessions(data);
  }

  Future<bool> hasOpenSession(String libraryId) async {
    final snapshot = await getTodayAttendance(libraryId);

    if (!snapshot.exists) {
      return false;
    }

    final data = snapshot.data();

    if (data == null) {
      return false;
    }

    return _hasOpenSession(data);
  }
}
