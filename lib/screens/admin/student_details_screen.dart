import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/membership_service.dart';
import 'edit_student_screen.dart';

class StudentDetailsScreen extends StatefulWidget {
  final String libraryId;

  const StudentDetailsScreen({super.key, required this.libraryId});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  bool _membershipChecked = false;

  String _formatDate(dynamic value) {
    if (value == null) {
      return "-";
    }

    if (value is Timestamp) {
      final date = value.toDate();

      return "${date.day.toString().padLeft(2, '0')}/"
          "${date.month.toString().padLeft(2, '0')}/"
          "${date.year}";
    }

    return value.toString();
  }

  String _getShifts(dynamic shiftData) {
    if (shiftData is! Map) {
      return "-";
    }

    final shifts = Map<String, dynamic>.from(shiftData);

    final selectedShifts = <String>[];

    if (shifts['morning'] == true) {
      selectedShifts.add("Morning");
    }

    if (shifts['day'] == true) {
      selectedShifts.add("Day");
    }

    if (shifts['evening'] == true) {
      selectedShifts.add("Evening");
    }

    if (shifts['night'] == true) {
      selectedShifts.add("Night");
    }

    return selectedShifts.isEmpty ? "-" : selectedShifts.join(", ");
  }

  Future<void> _checkMembership() async {
    if (_membershipChecked) {
      return;
    }

    _membershipChecked = true;

    await MembershipService.checkAndUpdateMembership(widget.libraryId);
  }

  // ============================================================
  // DELETE STUDENT + ALL RELATED DATA
  // ============================================================

  Future<void> _deleteStudentCompletely(String libraryId) async {
    final firestore = FirebaseFirestore.instance;

    // Firestore batch limit is 500.
    // Keeping it below 500 gives us a safe margin.
    const int batchLimit = 450;

    // ==========================================================
    // 1. DELETE STUDENT DOCUMENT
    //
    // students/{libraryId}
    // ==========================================================

    await firestore.collection('students').doc(libraryId).delete();

    // ==========================================================
    // 2. DELETE ALL ATTENDANCE DAY DOCUMENTS
    //
    // attendance/{libraryId}/days/{date}
    // ==========================================================

    final attendanceRef = firestore.collection('attendance').doc(libraryId);

    final daysSnapshot = await attendanceRef.collection('days').get();

    for (int start = 0; start < daysSnapshot.docs.length; start += batchLimit) {
      final end = (start + batchLimit < daysSnapshot.docs.length)
          ? start + batchLimit
          : daysSnapshot.docs.length;

      final batch = firestore.batch();

      for (int i = start; i < end; i++) {
        batch.delete(daysSnapshot.docs[i].reference);
      }

      await batch.commit();
    }

    // ==========================================================
    // 3. DELETE ATTENDANCE ROOT DOCUMENT
    //
    // attendance/{libraryId}
    // ==========================================================

    await attendanceRef.delete();

    // ==========================================================
    // 4. DELETE ATTENDANCE EDIT HISTORY
    //
    // attendance_edit_history/{documentId}
    //
    // Only records belonging to this student are deleted.
    // ==========================================================

    final historySnapshot = await firestore
        .collection('attendance_edit_history')
        .where('libraryId', isEqualTo: libraryId)
        .get();

    for (
      int start = 0;
      start < historySnapshot.docs.length;
      start += batchLimit
    ) {
      final end = (start + batchLimit < historySnapshot.docs.length)
          ? start + batchLimit
          : historySnapshot.docs.length;

      final batch = firestore.batch();

      for (int i = start; i < end; i++) {
        batch.delete(historySnapshot.docs[i].reference);
      }

      await batch.commit();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F172A),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,

        title: Text(
          "Student Details",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: StreamBuilder<DocumentSnapshot>(
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
                "Failed to load student",
                style: GoogleFonts.poppins(color: Colors.redAccent),
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Center(
              child: Text(
                "Student not found",
                style: GoogleFonts.poppins(color: Colors.white70),
              ),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          // Check membership once when the
          // student's details are opened.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) {
              return;
            }

            _checkMembership();
          });

          final name = data['name']?.toString() ?? "-";

          final id = data['libraryId']?.toString() ?? widget.libraryId;

          final phone = data['phone']?.toString() ?? "-";

          final email = data['email']?.toString() ?? "-";

          final gender = data['gender']?.toString() ?? "-";

          final address = data['address']?.toString() ?? "-";

          final seat = data['seat']?.toString() ?? "-";

          final membership = data['membershipStatus']?.toString() ?? "Inactive";

          final shifts = _getShifts(data['shifts']);

          // Valid Till is meaningful only
          // when membership is Active.
          final validTill = membership == "Active"
              ? _formatDate(data['validTill'])
              : "-";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),

            child: Column(
              children: [
                CircleAvatar(
                  radius: 52,
                  backgroundColor: Colors.white24,

                  child: Icon(
                    gender == "Girl" ? Icons.person_2 : Icons.person,
                    color: Colors.white,
                    size: 62,
                  ),
                ),

                const SizedBox(height: 16),

                Text(
                  name,
                  textAlign: TextAlign.center,

                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  id,

                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 30),

                _sectionTitle("Personal Information"),

                const SizedBox(height: 12),

                _detailsCard(
                  children: [
                    _detailRow(Icons.person_outline, "Full Name", name),

                    _divider(),

                    _detailRow(Icons.phone_outlined, "Mobile Number", phone),

                    _divider(),

                    _detailRow(Icons.email_outlined, "Email", email),

                    _divider(),

                    _detailRow(Icons.people_outline, "Gender", gender),

                    _divider(),

                    _detailRow(
                      Icons.cake_outlined,
                      "Date of Birth",
                      _formatDate(data['dateOfBirth']),
                    ),

                    _divider(),

                    _detailRow(Icons.home_outlined, "Address", address),
                  ],
                ),

                const SizedBox(height: 30),

                _sectionTitle("Library Information"),

                const SizedBox(height: 12),

                _detailsCard(
                  children: [
                    _detailRow(Icons.badge_outlined, "Library ID", id),

                    _divider(),

                    _detailRow(Icons.pin_outlined, "PIN", "••••"),

                    _divider(),

                    _detailRow(Icons.event_seat_outlined, "Seat Number", seat),

                    _divider(),

                    _detailRow(Icons.schedule_outlined, "Shift", shifts),

                    _divider(),

                    _detailRow(
                      Icons.calendar_today_outlined,
                      "Joining Date",
                      _formatDate(data['joiningDate']),
                    ),

                    _divider(),

                    _detailRow(
                      Icons.verified_user_outlined,
                      "Membership",
                      membership,
                    ),

                    _divider(),

                    _detailRow(
                      Icons.event_available_outlined,
                      "Valid Till",
                      validTill,
                    ),
                  ],
                ),

                const SizedBox(height: 30),

                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => EditStudentScreen(
                                libraryId: widget.libraryId,
                              ),
                            ),
                          ).then((_) {
                            // Reset the check so that
                            // membership is checked again
                            // after returning from Edit.
                            _membershipChecked = false;

                            if (mounted) {
                              setState(() {});
                            }
                          });
                        },

                        icon: const Icon(Icons.edit_outlined),

                        label: Text(
                          "EDIT",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 15),

                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {
                          _showDeleteDialog(context);
                        },

                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),

                        icon: const Icon(Icons.delete_outline),

                        label: Text(
                          "DELETE",
                          style: GoogleFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 30),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Align(
      alignment: Alignment.centerLeft,

      child: Text(
        title,

        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _detailsCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 5),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.white24),
      ),

      child: Column(children: children),
    );
  }

  Widget _detailRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: Colors.white70, size: 22),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,

                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return const Divider(color: Colors.white24, height: 1);
  }

  // ============================================================
  // DELETE CONFIRMATION DIALOG
  // ============================================================

  void _showDeleteDialog(BuildContext context) {
    showDialog(
      context: context,

      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xff1E293B),

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),

          title: const Text(
            "Delete Student",
            style: TextStyle(color: Colors.white),
          ),

          content: const Text(
            "Are you sure you want to delete this student?",
            style: TextStyle(color: Colors.white70),
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },

              child: const Text("Cancel"),
            ),

            ElevatedButton(
              onPressed: () async {
                try {
                  // ==================================================
                  // COMPLETE DELETE
                  //
                  // Student document
                  // Attendance root document
                  // All attendance day documents
                  // Attendance edit history
                  // ==================================================

                  await _deleteStudentCompletely(widget.libraryId);

                  if (!context.mounted) {
                    return;
                  }

                  Navigator.pop(dialogContext);

                  Navigator.pop(context);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Student and all related data deleted successfully",
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                } catch (e) {
                  if (!context.mounted) {
                    return;
                  }

                  Navigator.pop(dialogContext);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Failed to delete student data: $e"),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },

              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,

                foregroundColor: Colors.white,
              ),

              child: const Text("Delete"),
            ),
          ],
        );
      },
    );
  }
}
