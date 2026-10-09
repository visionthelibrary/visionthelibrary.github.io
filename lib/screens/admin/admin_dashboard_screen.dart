import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'admin_profile_screen.dart';
import 'student_management_screen.dart';
import 'attendance_management_screen.dart';
import 'library_management_screen.dart';
import 'library_report_screen.dart';
import 'about_library_management_screen.dart';
import 'notice_management_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  // ============================================================
  // TODAY DATE ID
  // ============================================================

  String _todayId() {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // CHECK PRESENT
  // ============================================================

  bool _isPresent(Map<String, dynamic> data) {
    final status = data['status']?.toString();

    if (status == 'Present' || status == 'Completed') {
      return true;
    }

    final sessions = data['sessions'];

    if (sessions is List && sessions.isNotEmpty) {
      return true;
    }

    // Old attendance structure compatibility.
    if (data['entryAt'] != null) {
      return true;
    }

    return false;
  }

  // ============================================================
  // GET TODAY PRESENT COUNT
  // ============================================================

  Stream<int> _presentTodayStream() {
    final todayId = _todayId();

    return FirebaseFirestore.instance
        .collection('students')
        .snapshots()
        .asyncMap((studentSnapshot) async {
          int presentCount = 0;

          for (final studentDocument in studentSnapshot.docs) {
            final data = studentDocument.data();

            final libraryId =
                data['libraryId']?.toString() ?? studentDocument.id;

            final attendanceDocument = await FirebaseFirestore.instance
                .collection('attendance')
                .doc(libraryId)
                .collection('days')
                .doc(todayId)
                .get();

            if (!attendanceDocument.exists) {
              continue;
            }

            final attendanceData = attendanceDocument.data();

            if (attendanceData == null) {
              continue;
            }

            if (_isPresent(attendanceData)) {
              presentCount++;
            }
          }

          return presentCount;
        });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Dashboard se back karne par logout nahi hoga.
      canPop: true,

      onPopInvokedWithResult: (didPop, result) {
        // Intentionally empty.
        //
        // SessionService.logout() yahan nahi karna hai.
        // Actual logout sirf Admin Profile -> Logout se hoga.
      },

      child: Scaffold(
        body: Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height,

          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xff0F172A), Color(0xff1E3A8A), Color(0xff2563EB)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),

          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // ==================================================
                  // HEADER
                  // ==================================================
                  Row(
                    children: [
                      const Icon(
                        Icons.local_library,
                        color: Colors.white,
                        size: 42,
                      ),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              "Vision The Library",
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            Text(
                              "Admin Panel",
                              style: GoogleFonts.poppins(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),

                      Container(
                        height: 52,
                        width: 52,

                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white24),
                        ),

                        child: IconButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    const AdminProfileScreen(),
                              ),
                            );
                          },

                          icon: const Icon(
                            Icons.admin_panel_settings,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 35),

                  // ==================================================
                  // TITLE
                  // ==================================================
                  Text(
                    "Admin Dashboard",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 4),

                  Text(
                    "Manage your library",
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // LIVE SUMMARY CARDS
                  // ==================================================
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: FirebaseFirestore.instance
                        .collection('students')
                        .snapshots(),

                    builder: (context, studentSnapshot) {
                      final totalStudents =
                          studentSnapshot.data?.docs.length ?? 0;

                      return StreamBuilder<int>(
                        stream: _presentTodayStream(),

                        builder: (context, presentSnapshot) {
                          final isLoading =
                              studentSnapshot.connectionState ==
                                  ConnectionState.waiting ||
                              presentSnapshot.connectionState ==
                                  ConnectionState.waiting;

                          final presentToday = presentSnapshot.data ?? 0;

                          return Row(
                            children: [
                              Expanded(
                                child: _summaryCard(
                                  Icons.people_alt_outlined,
                                  "Total Students",
                                  isLoading ? "..." : totalStudents.toString(),
                                ),
                              ),

                              const SizedBox(width: 15),

                              Expanded(
                                child: _summaryCard(
                                  Icons.fact_check_outlined,
                                  "Present Today",
                                  isLoading ? "..." : presentToday.toString(),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // MANAGEMENT
                  // ==================================================
                  Text(
                    "Management",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 18),

                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),

                    crossAxisCount: 2,
                    mainAxisSpacing: 15,
                    crossAxisSpacing: 15,
                    childAspectRatio: 1.15,

                    children: [
                      _managementCard(
                        Icons.people_outline,
                        "Student\nManagement",
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const StudentManagementScreen(),
                            ),
                          );
                        },
                      ),

                      _managementCard(
                        Icons.fact_check_outlined,
                        "Attendance\nManagement",
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AttendanceManagementScreen(),
                            ),
                          );
                        },
                      ),

                      _managementCard(
                        Icons.campaign_outlined,
                        "Notice\nManagement",
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const NoticeManagementScreen(),
                            ),
                          );
                        },
                      ),

                      _managementCard(
                        Icons.local_library_outlined,
                        "Library\nManagement",
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const LibraryManagementScreen(),
                            ),
                          );
                        },
                      ),

                      _managementCard(
                        Icons.info_outline_rounded,
                        "About\nLibrary",
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const AboutLibraryManagementScreen(),
                            ),
                          );
                        },
                      ),

                      _managementCard(
                        Icons.bar_chart_rounded,
                        "Library\nReport",
                        () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const LibraryReportScreen(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // SUMMARY CARD
  // ============================================================

  Widget _summaryCard(IconData icon, String title, String value) {
    return Container(
      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: Colors.white, size: 30),

          const SizedBox(height: 15),

          Text(
            value,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 25,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            title,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // MANAGEMENT CARD
  // ============================================================

  Widget _managementCard(IconData icon, String title, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,

      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),

        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white24),
          ),

          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,

            children: [
              Container(
                padding: const EdgeInsets.all(13),

                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),

                child: Icon(icon, color: Colors.white, size: 30),
              ),

              const SizedBox(height: 13),

              Text(
                title,
                textAlign: TextAlign.center,

                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
