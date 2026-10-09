import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

import '../services/attendance_service.dart';

class AttendanceScreen extends StatefulWidget {
  final String libraryId;

  const AttendanceScreen({super.key, required this.libraryId});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // ============================================================
  // LOCATION SETTINGS
  // ============================================================

  // Library coordinates:
  // 27°06'33.2"N 84°27'56.8"E
  //
  // Decimal:
  // Latitude  = 27.109222
  // Longitude = 84.465778

  static const double libraryLatitude = 27.109222;

  static const double libraryLongitude = 84.465778;

  // Student must be within 50 meters.
  static const double allowedRadius = 50.0;

  // Maximum sessions if Firebase setting is unavailable.
  static const int defaultMaxSessions = 3;

  // ============================================================
  // SERVICES
  // ============================================================

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  final AttendanceService _attendanceService = AttendanceService();

  // ============================================================
  // STATE
  // ============================================================

  bool isLocationVerified = false;

  bool isCheckingLocation = true;

  bool isLoading = false;

  bool isInitializing = true;

  bool isLocationServiceEnabled = false;

  int maxSessions = defaultMaxSessions;

  double? currentDistance;

  double? currentAccuracy;

  String locationStatus = "Checking...";

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _initializeAttendance();
  }

  Future<void> _initializeAttendance() async {
    try {
      // Previous-day rollover.
      await _attendanceService.checkPreviousAttendance(widget.libraryId);

      await _loadMaxSessions();

      await _checkLocation();
    } catch (e) {
      debugPrint("Attendance initialization failed: $e");
    } finally {
      if (mounted) {
        setState(() {
          isInitializing = false;
        });
      }
    }
  }

  // ============================================================
  // DATE / FIRESTORE
  // ============================================================

  String _todayId() {
    final now = DateTime.now();

    return "${now.year}-"
        "${now.month.toString().padLeft(2, '0')}-"
        "${now.day.toString().padLeft(2, '0')}";
  }

  DocumentReference<Map<String, dynamic>> _todayDocument() {
    return _firestore
        .collection("attendance")
        .doc(widget.libraryId)
        .collection("days")
        .doc(_todayId());
  }

  // ============================================================
  // MAX SESSIONS
  // ============================================================

  Future<void> _loadMaxSessions() async {
    try {
      final snapshot = await _firestore
          .collection("library_settings")
          .doc("config")
          .get();

      if (!mounted) return;

      if (snapshot.exists) {
        final data = snapshot.data();

        final value = data?["maxSessionsPerDay"];

        if (value is int && value > 0) {
          setState(() {
            maxSessions = value;
          });
        } else if (value is num && value > 0) {
          setState(() {
            maxSessions = value.toInt();
          });
        }
      }
    } catch (e) {
      debugPrint("Failed to load max sessions: $e");
    }
  }

  // ============================================================
  // LOCATION CHECK
  // ============================================================

  Future<void> _checkLocation() async {
    if (mounted) {
      setState(() {
        isCheckingLocation = true;
        locationStatus = "Checking location...";
      });
    }

    try {
      // --------------------------------------------------------
      // STEP 1
      // CHECK LOCATION SERVICE / GPS
      // --------------------------------------------------------

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();

      isLocationServiceEnabled = serviceEnabled;

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          isLocationVerified = false;
          isCheckingLocation = false;
          currentDistance = null;
          currentAccuracy = null;
          locationStatus = "Location is turned off";
        });

        return;
      }

      // --------------------------------------------------------
      // STEP 2
      // CHECK PERMISSION
      // --------------------------------------------------------

      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied) {
        if (!mounted) return;

        setState(() {
          isLocationVerified = false;
          isCheckingLocation = false;
          currentDistance = null;
          currentAccuracy = null;
          locationStatus = "Location permission denied";
        });

        return;
      }

      if (permission == LocationPermission.deniedForever) {
        if (!mounted) return;

        setState(() {
          isLocationVerified = false;
          isCheckingLocation = false;
          currentDistance = null;
          currentAccuracy = null;
          locationStatus = "Location permission permanently denied";
        });

        return;
      }

      // --------------------------------------------------------
      // STEP 3
      // GET CURRENT LOCATION
      // --------------------------------------------------------

      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 0,
          forceLocationManager: false,
        ),
      );

      final double distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        libraryLatitude,
        libraryLongitude,
      );

      final double accuracy = position.accuracy;

      final bool insideRadius = distance <= allowedRadius;

      // --------------------------------------------------------
      // STEP 4
      // UPDATE UI
      // --------------------------------------------------------

      if (!mounted) return;

      setState(() {
        currentDistance = distance;
        currentAccuracy = accuracy;

        isLocationVerified = insideRadius;

        isCheckingLocation = false;

        if (insideRadius) {
          locationStatus = "Location Verified";
        } else {
          locationStatus = "Outside Library";
        }
      });

      debugPrint("Current Latitude: ${position.latitude}");

      debugPrint("Current Longitude: ${position.longitude}");

      debugPrint("Distance from library: ${distance.toStringAsFixed(2)} m");

      debugPrint("Location accuracy: ${accuracy.toStringAsFixed(2)} m");
    } catch (e) {
      debugPrint("Location check failed: $e");

      if (!mounted) return;

      setState(() {
        isLocationVerified = false;
        isCheckingLocation = false;
        currentDistance = null;
        currentAccuracy = null;
        locationStatus = "Unable to determine location";
      });
    }
  }

  // ============================================================
  // VERIFY LOCATION BEFORE ATTENDANCE
  // ============================================================

  Future<bool> _verifyLocation() async {
    await _checkLocation();

    if (!mounted) return false;

    if (!isLocationVerified) {
      String message;

      if (!isLocationServiceEnabled) {
        message = "Please turn on your phone's location.";
      } else if (locationStatus == "Location permission denied") {
        message = "Location permission is required.";
      } else if (locationStatus == "Location permission permanently denied") {
        message = "Please allow location permission in Settings.";
      } else if (currentDistance != null) {
        message =
            "You are ${currentDistance!.toStringAsFixed(0)} m away. "
            "You must be within 50 m of the library.";
      } else {
        message = "Unable to verify your location.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );

      return false;
    }

    return true;
  }

  // ============================================================
  // GET SESSIONS
  // ============================================================

  List<Map<String, dynamic>> _getSessions(Map<String, dynamic> data) {
    final rawSessions = data["sessions"];

    if (rawSessions is List) {
      return rawSessions
          .whereType<Map>()
          .map((session) => Map<String, dynamic>.from(session))
          .toList();
    }

    /*
     * OLD SINGLE SESSION DOCUMENT
     * COMPATIBILITY
     */

    final oldEntry = data["entryAt"];

    final oldExit = data["exitAt"];

    if (oldEntry != null) {
      return [
        {
          "sessionNo": 1,
          "entryAt": oldEntry,
          "exitAt": oldExit,
          "autoEntry": data["autoEntry"] ?? false,
          "autoExit": data["autoExit"] ?? false,
        },
      ];
    }

    return [];
  }

  // ============================================================
  // INSIDE CHECK
  // ============================================================

  bool _isInside(Map<String, dynamic> data) {
    final sessions = _getSessions(data);

    if (sessions.isEmpty) {
      return false;
    }

    final lastSession = sessions.last;

    return lastSession["entryAt"] != null && lastSession["exitAt"] == null;
  }

  // ============================================================
  // MARK ENTRY
  // ============================================================

  Future<void> _markEntry() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      // --------------------------------------------------------
      // LOCATION VERIFICATION
      // --------------------------------------------------------

      final locationOk = await _verifyLocation();

      if (!locationOk) return;

      // --------------------------------------------------------
      // FIRESTORE
      // --------------------------------------------------------

      final docRef = _todayDocument();

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        List<Map<String, dynamic>> sessions = [];

        if (snapshot.exists) {
          final data = snapshot.data()!;

          sessions = _getSessions(data);

          if (sessions.isNotEmpty) {
            final lastSession = sessions.last;

            /*
               * Cannot start another session
               * while current session is active.
               */

            if (lastSession["entryAt"] != null &&
                lastSession["exitAt"] == null) {
              throw Exception("EXIT_REQUIRED_FIRST");
            }
          }
        }

        if (sessions.length >= maxSessions) {
          throw Exception("MAX_SESSIONS_REACHED");
        }

        final nextSessionNo = sessions.length + 1;

        final now = Timestamp.now();

        sessions.add({
          "sessionNo": nextSessionNo,
          "entryAt": now,
          "exitAt": null,
          "autoEntry": false,
          "autoExit": false,
        });

        final dataToSave = <String, dynamic>{
          "libraryId": widget.libraryId,

          "date": _todayId(),

          "status": "Present",

          /*
             * Current session.
             */
          "entryAt": now,

          "exitAt": null,

          /*
             * All sessions.
             */
          "sessions": sessions,

          "currentSession": nextSessionNo,

          "totalSessions": sessions.length,

          "autoEntry": false,

          "autoExit": false,

          "markedBy": "Student",

          "updatedAt": FieldValue.serverTimestamp(),
        };

        if (!snapshot.exists) {
          dataToSave["createdAt"] = FieldValue.serverTimestamp();

          transaction.set(docRef, dataToSave);
        } else {
          transaction.update(docRef, dataToSave);
        }
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Attendance marked successfully."),
          backgroundColor: Colors.green,
        ),
      );

      // Refresh location after attendance.
      await _checkLocation();
    } on Exception catch (e) {
      if (!mounted) return;

      final message = e.toString();

      if (message.contains("EXIT_REQUIRED_FIRST")) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Please mark your exit before starting another session.",
            ),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (message.contains("MAX_SESSIONS_REACHED")) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Maximum $maxSessions sessions allowed today."),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to mark attendance: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // MARK EXIT
  // ============================================================

  Future<void> _markExit() async {
    if (isLoading) return;

    setState(() {
      isLoading = true;
    });

    try {
      // --------------------------------------------------------
      // LOCATION VERIFICATION
      // --------------------------------------------------------

      final locationOk = await _verifyLocation();

      if (!locationOk) return;

      // --------------------------------------------------------
      // FIRESTORE
      // --------------------------------------------------------

      final docRef = _todayDocument();

      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);

        if (!snapshot.exists) {
          throw Exception("ATTENDANCE_NOT_FOUND");
        }

        final data = snapshot.data()!;

        final sessions = _getSessions(data);

        if (sessions.isEmpty) {
          throw Exception("ATTENDANCE_NOT_FOUND");
        }

        final lastIndex = sessions.length - 1;

        final lastSession = Map<String, dynamic>.from(sessions[lastIndex]);

        if (lastSession["entryAt"] == null) {
          throw Exception("ATTENDANCE_NOT_FOUND");
        }

        if (lastSession["exitAt"] != null) {
          throw Exception("EXIT_ALREADY_MARKED");
        }

        final now = Timestamp.now();

        /*
           * Manual exit.
           */

        lastSession["exitAt"] = now;

        lastSession["autoExit"] = false;

        sessions[lastIndex] = lastSession;

        transaction.update(docRef, {
          "sessions": sessions,

          "entryAt": lastSession["entryAt"],

          "exitAt": now,

          "currentSession": lastSession["sessionNo"] ?? sessions.length,

          "totalSessions": sessions.length,

          "status": "Completed",

          "autoExit": false,

          "updatedAt": FieldValue.serverTimestamp(),
        });
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Exit marked successfully."),
          backgroundColor: Colors.green,
        ),
      );

      await _checkLocation();
    } on Exception catch (e) {
      if (!mounted) return;

      final message = e.toString();

      if (message.contains("ATTENDANCE_NOT_FOUND")) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Mark attendance first."),
            backgroundColor: Colors.orange,
          ),
        );
      } else if (message.contains("EXIT_ALREADY_MARKED")) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Exit is already marked."),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to mark exit: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatTime(dynamic value, BuildContext context) {
    if (value is Timestamp) {
      return TimeOfDay.fromDateTime(value.toDate()).format(context);
    }

    return "--:--";
  }

  // ============================================================
  // SESSION CARD
  // ============================================================

  Widget _buildSessionCard(Map<String, dynamic> session, BuildContext context) {
    final sessionNo = session["sessionNo"]?.toString() ?? "-";

    final entryAt = session["entryAt"];

    final exitAt = session["exitAt"];

    final bool completed = exitAt != null;

    final bool autoEntry = session["autoEntry"] == true;

    final bool autoExit = session["autoExit"] == true;

    String statusText;

    if (!completed) {
      statusText = autoEntry ? "Auto Entry" : "Active";
    } else if (autoExit) {
      statusText = "Auto Completed";
    } else {
      statusText = "Completed";
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: completed
                      ? Colors.green.withValues(alpha: .15)
                      : Colors.orange.withValues(alpha: .15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  completed ? Icons.check_circle_outline : Icons.login,
                  color: completed ? Colors.green : Colors.orange,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  "Session $sessionNo",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Text(
                statusText,
                style: GoogleFonts.poppins(
                  color: completed ? Colors.green : Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _buildTimeColumn(
                  icon: Icons.login,
                  title: "Entry",
                  value: _formatTime(entryAt, context),
                  color: Colors.green,
                ),
              ),

              Container(width: 1, height: 42, color: Colors.white24),

              Expanded(
                child: _buildTimeColumn(
                  icon: Icons.logout,
                  title: "Exit",
                  value: exitAt == null
                      ? "--:--"
                      : _formatTime(exitAt, context),
                  color: Colors.orange,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TIME COLUMN
  // ============================================================

  Widget _buildTimeColumn({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, color: color, size: 20),

        const SizedBox(width: 8),

        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
            ),
            Text(
              value,
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget buildInfoRow(
    IconData icon,
    String title,
    String value,
    Color valueColor,
  ) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 24),

        const SizedBox(width: 15),

        Expanded(
          child: Text(
            title,
            style: GoogleFonts.poppins(color: Colors.white, fontSize: 15),
          ),
        ),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: GoogleFonts.poppins(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final today = _todayId();

    return Scaffold(
      backgroundColor: const Color(0xff0F172A),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,

        title: Text(
          "Attendance",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            onPressed: isCheckingLocation ? null : _checkLocation,
            icon: const Icon(Icons.location_on, color: Colors.white),
          ),
        ],
      ),

      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: _firestore
            .collection("attendance")
            .doc(widget.libraryId)
            .collection("days")
            .doc(today)
            .snapshots(),

        builder: (context, snapshot) {
          bool isInside = false;

          List<Map<String, dynamic>> sessions = [];

          Timestamp? currentEntryTime;

          Timestamp? currentExitTime;

          if (snapshot.hasData && snapshot.data!.exists) {
            final data = snapshot.data!.data();

            if (data != null) {
              sessions = _getSessions(data);

              isInside = _isInside(data);

              if (sessions.isNotEmpty) {
                final lastSession = sessions.last;

                currentEntryTime = lastSession["entryAt"];

                currentExitTime = lastSession["exitAt"];
              }
            }
          }

          final sessionCount = sessions.length;

          return RefreshIndicator(
            onRefresh: _initializeAttendance,

            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),

              padding: const EdgeInsets.all(20),

              child: Column(
                children: [
                  // ==================================================
                  // LOCATION INFO CARD
                  // ==================================================
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: .10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),

                    child: Column(
                      children: [
                        // LOCATION STATUS
                        buildInfoRow(
                          Icons.location_on,
                          "Location",
                          isCheckingLocation ? "Checking..." : locationStatus,
                          isLocationVerified ? Colors.green : Colors.orange,
                        ),

                        const Divider(color: Colors.white24, height: 28),

                        // DISTANCE
                        buildInfoRow(
                          Icons.social_distance,
                          "Distance",
                          isCheckingLocation
                              ? "Checking..."
                              : currentDistance != null
                              ? "${currentDistance!.toStringAsFixed(1)} m"
                              : "--",
                          isLocationVerified ? Colors.green : Colors.orange,
                        ),

                        const Divider(color: Colors.white24, height: 28),

                        // LOCATION VERIFICATION
                        buildInfoRow(
                          Icons.verified_outlined,
                          "Location Verification",
                          isCheckingLocation
                              ? "Checking..."
                              : isLocationVerified
                              ? "Verified"
                              : "Not Verified",
                          isLocationVerified ? Colors.green : Colors.redAccent,
                        ),

                        // GPS ACCURACY
                        if (currentAccuracy != null) ...[
                          const Divider(color: Colors.white24, height: 28),

                          buildInfoRow(
                            Icons.gps_fixed,
                            "GPS Accuracy",
                            "${currentAccuracy!.toStringAsFixed(1)} m",
                            Colors.blue,
                          ),
                        ],

                        const Divider(color: Colors.white24, height: 28),

                        // ATTENDANCE
                        buildInfoRow(
                          Icons.fact_check,
                          "Attendance",
                          isInside
                              ? "Present"
                              : sessionCount > 0
                              ? "Completed"
                              : "Not Marked",
                          isInside
                              ? Colors.green
                              : sessionCount > 0
                              ? Colors.green
                              : Colors.orange,
                        ),

                        // ==========================================
                        // ENTRY TIME
                        // ==========================================
                        if (currentEntryTime != null) ...[
                          const Divider(color: Colors.white24, height: 28),

                          buildInfoRow(
                            Icons.login,
                            "Entry Time",
                            _formatTime(currentEntryTime, context),
                            Colors.green,
                          ),
                        ],

                        // ==========================================
                        // EXIT TIME
                        // ONLY AFTER ACTUAL EXIT
                        // ==========================================
                        if (currentExitTime != null) ...[
                          const Divider(color: Colors.white24, height: 28),

                          buildInfoRow(
                            Icons.logout,
                            "Exit Time",
                            _formatTime(currentExitTime, context),
                            Colors.orange,
                          ),
                        ],

                        const Divider(color: Colors.white24, height: 28),

                        // TODAY'S SESSIONS
                        buildInfoRow(
                          Icons.layers_outlined,
                          "Today's Sessions",
                          "$sessionCount / $maxSessions",
                          sessionCount >= maxSessions
                              ? Colors.orange
                              : Colors.blue,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // MAIN BUTTON
                  // ==================================================
                  SizedBox(
                    width: double.infinity,
                    height: 55,

                    child: ElevatedButton.icon(
                      onPressed:
                          isLoading ||
                              isInitializing ||
                              !isLocationVerified ||
                              isCheckingLocation
                          ? null
                          : isInside
                          ? _markExit
                          : sessionCount >= maxSessions
                          ? null
                          : _markEntry,

                      icon: isLoading || isInitializing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              isInside
                                  ? Icons.logout
                                  : sessionCount >= maxSessions
                                  ? Icons.check_circle
                                  : Icons.login,
                            ),

                      label: Text(
                        isInitializing
                            ? "CHECKING..."
                            : isCheckingLocation
                            ? "CHECKING LOCATION..."
                            : isLoading
                            ? "PLEASE WAIT..."
                            : isInside
                            ? "MARK EXIT"
                            : sessionCount >= maxSessions
                            ? "SESSIONS COMPLETED"
                            : "MARK ATTENDANCE",

                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),

                      style: ElevatedButton.styleFrom(
                        backgroundColor: isInside
                            ? Colors.orange
                            : Colors.green,

                        foregroundColor: Colors.white,

                        disabledBackgroundColor: Colors.white24,

                        disabledForegroundColor: Colors.white54,

                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // TODAY'S SESSIONS TITLE
                  // ==================================================
                  Align(
                    alignment: Alignment.centerLeft,

                    child: Text(
                      "Today's Sessions",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 15),

                  // ==================================================
                  // NO SESSIONS
                  // ==================================================
                  if (sessions.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(25),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),

                      child: Column(
                        children: [
                          const Icon(
                            Icons.history,
                            color: Colors.white54,
                            size: 42,
                          ),

                          const SizedBox(height: 12),

                          Text(
                            "No Sessions Yet",
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            "Your attendance sessions will appear here.",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.poppins(
                              color: Colors.white60,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    )
                  // ==================================================
                  // SESSION LIST
                  // ==================================================
                  else
                    ...sessions.map(
                      (session) => _buildSessionCard(session, context),
                    ),

                  // ==================================================
                  // LOCATION WARNING
                  // ==================================================
                  if (!isLocationVerified && !isCheckingLocation)
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Text(
                        currentDistance != null
                            ? "You must be within 50 meters of the library."
                            : locationStatus,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 13,
                        ),
                      ),
                    ),

                  const SizedBox(height: 35),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
