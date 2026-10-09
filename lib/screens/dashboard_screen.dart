import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:vision_the_library/services/attendance_service.dart';
import 'package:vision_the_library/services/membership_service.dart';

import '../../theme/app_theme.dart';
import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';
import 'attendance_screen.dart';
import 'profile_screen.dart';

class DashboardScreen extends StatefulWidget {
  final String libraryId;

  const DashboardScreen({super.key, required this.libraryId});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  bool _membershipChecked = false;

  // ============================================================
  // DATE
  // ============================================================

  String _todayId() {
    final now = DateTime.now();

    return '${now.year}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(dynamic value) {
    if (value == null) return '-';

    if (value is Timestamp) {
      final date = value.toDate();

      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];

      return '${date.day} '
          '${months[date.month - 1]} '
          '${date.year}';
    }

    return value.toString();
  }

  // ============================================================
  // SHIFTS
  // ============================================================

  String _getShifts(dynamic shiftData) {
    if (shiftData is! Map) return '-';

    final shifts = Map<String, dynamic>.from(shiftData);

    final selectedShifts = <String>[];

    if (shifts['morning'] == true) {
      selectedShifts.add('Morning');
    }

    if (shifts['day'] == true) {
      selectedShifts.add('Day');
    }

    if (shifts['evening'] == true) {
      selectedShifts.add('Evening');
    }

    if (shifts['night'] == true) {
      selectedShifts.add('Night');
    }

    if (selectedShifts.isEmpty) {
      return '-';
    }

    return selectedShifts.join(', ');
  }

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    AttendanceService().checkPreviousAttendance(widget.libraryId);
  }

  // ============================================================
  // MEMBERSHIP
  // ============================================================

  Future<void> _checkMembership() async {
    if (_membershipChecked) {
      return;
    }

    _membershipChecked = true;

    await MembershipService.checkAndUpdateMembership(widget.libraryId);
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Dashboard se Back karne par app close hoga.
      // Session logout nahi hoga.
      canPop: true,

      onPopInvokedWithResult: (didPop, result) {
        // Intentionally empty.
        //
        // SessionService.logout() yahan call nahi karna hai.
      },

      child: Scaffold(
        body: GradientBackground(
          child: SafeArea(
            child: StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .doc(widget.libraryId)
                  .snapshots(),

              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Failed to load student data',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  );
                }

                if (!snapshot.hasData || !snapshot.data!.exists) {
                  return Center(
                    child: Text(
                      'Student not found',
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  );
                }

                final data = snapshot.data!.data() as Map<String, dynamic>;

                // ------------------------------------------------
                // MEMBERSHIP CHECK
                // ------------------------------------------------

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;

                  _checkMembership();
                });

                final String name = data['name']?.toString() ?? 'Student';

                final String studentId =
                    data['libraryId']?.toString() ?? widget.libraryId;

                final String seat = data['seat']?.toString() ?? '-';

                final String membership =
                    data['membershipStatus']?.toString() ?? 'Inactive';

                final String gender = data['gender']?.toString() ?? '';

                final String shifts = _getShifts(data['shifts']);

                final String validTill = membership == 'Active'
                    ? _formatDate(data['validTill'])
                    : '-';

                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),

                  padding: const EdgeInsets.symmetric(horizontal: 20),

                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      const SizedBox(height: 20),

                      // ==================================================
                      // HEADER
                      // ==================================================
                      _buildHeader(context, studentId),

                      const SizedBox(height: 18),

                      // ==================================================
                      // PROFILE
                      // ==================================================
                      _buildProfileSection(
                        name: name,
                        studentId: studentId,
                        gender: gender,
                      ),

                      const SizedBox(height: 25),

                      // ==================================================
                      // STUDENT INFO
                      // ==================================================
                      _buildInfoCard(
                        libraryId: studentId,
                        shift: shifts,
                        seat: seat,
                        membership: membership,
                        validTill: validTill,
                        studentId: studentId,
                      ),

                      const SizedBox(height: 30),

                      // ==================================================
                      // ATTENDANCE BUTTON
                      // ==================================================
                      SizedBox(
                        width: double.infinity,
                        height: 55,

                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    AttendanceScreen(libraryId: studentId),
                              ),
                            );
                          },

                          icon: const Icon(Icons.fact_check),

                          label: Text(
                            'Attendance',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 30),
                    ],
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader(BuildContext context, String studentId) {
    return Row(
      children: [
        const Icon(Icons.local_library, color: Colors.white, size: 42),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                'Vision The Library',

                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              Text(
                'Knowledge Beyond Limits',

                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),

        Container(
          height: 54,
          width: 54,

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
                  builder: (context) => ProfileScreen(libraryId: studentId),
                ),
              );
            },

            icon: const Icon(
              Icons.account_circle,
              color: Colors.white,
              size: 30,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROFILE SECTION
  // ============================================================

  Widget _buildProfileSection({
    required String name,
    required String studentId,
    required String gender,
  }) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),

            decoration: BoxDecoration(
              shape: BoxShape.circle,

              border: Border.all(
                color: Colors.white.withValues(alpha: 0.20),
                width: 2,
              ),
            ),

            child: CircleAvatar(
              radius: 50,

              backgroundColor: Colors.white24,

              child: Icon(
                gender == 'Girl' ? Icons.person_2 : Icons.person,

                color: Colors.white,

                size: 60,
              ),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            name.toUpperCase(),

            textAlign: TextAlign.center,

            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'Student ID : $studentId',

            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 15),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _buildInfoCard({
    required String libraryId,
    required String shift,
    required String seat,
    required String membership,
    required String validTill,
    required String studentId,
  }) {
    final String today = _todayId();

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .doc(studentId)
          .collection('days')
          .doc(today)
          .snapshots(),

      builder: (context, attendanceSnapshot) {
        bool attendanceMarked = false;

        if (attendanceSnapshot.hasData && attendanceSnapshot.data!.exists) {
          final attendanceData =
              attendanceSnapshot.data!.data() as Map<String, dynamic>;

          attendanceMarked =
              attendanceData['status'] == 'Present' ||
              attendanceData['status'] == 'Completed';
        }

        return GlassCard(
          child: Column(
            children: [
              _buildInfoRow(Icons.badge_outlined, 'Library ID', libraryId),

              _divider(),

              _buildInfoRow(Icons.access_time, 'Shift', shift),

              _divider(),

              _buildInfoRow(Icons.event_seat, 'Seat', seat),

              _divider(),

              _buildInfoRow(
                Icons.verified_user_outlined,
                'Membership',
                membership,
                valueColor: membership == 'Active'
                    ? AppColors.successGreen
                    : Colors.redAccent,
              ),

              _divider(),

              _buildInfoRow(Icons.calendar_today, 'Valid Till', validTill),

              _divider(),

              _buildInfoRow(
                Icons.fact_check,
                "Today's Attendance",
                attendanceMarked ? 'Present' : 'Not Marked',
                valueColor: attendanceMarked
                    ? Colors.green
                    : Colors.orangeAccent,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // INFO ROW
  // ============================================================

  Widget _buildInfoRow(
    IconData icon,
    String title,
    String value, {
    Color? valueColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),

      child: Row(
        children: [
          Icon(icon, color: Colors.white70, size: 21),

          const SizedBox(width: 15),

          Expanded(
            child: Text(
              title,

              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),
          ),

          Flexible(
            child: Text(
              value,

              textAlign: TextAlign.right,

              style: GoogleFonts.poppins(
                color: valueColor ?? Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _divider() {
    return Divider(color: Colors.white.withValues(alpha: 0.10), height: 1);
  }
}
