import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';

class LibraryInformationScreen extends StatelessWidget {
  final String libraryId;

  const LibraryInformationScreen({super.key, required this.libraryId});

  String _formatDate(dynamic value) {
    if (value == null) return "-";

    if (value is Timestamp) {
      final date = value.toDate();

      const months = [
        "Jan",
        "Feb",
        "Mar",
        "Apr",
        "May",
        "Jun",
        "Jul",
        "Aug",
        "Sep",
        "Oct",
        "Nov",
        "Dec",
      ];

      return "${date.day} ${months[date.month - 1]} ${date.year}";
    }

    return value.toString();
  }

  String _getShifts(dynamic shiftData) {
    if (shiftData is! Map) return "-";

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GradientBackground(
        child: SafeArea(
          child: StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance
                .collection('students')
                .doc(libraryId)
                .snapshots(),

            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    "Failed to load library information",
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

              final studentLibraryId =
                  data['libraryId']?.toString() ?? libraryId;

              final seat = data['seat']?.toString() ?? "-";

              final shift = _getShifts(data['shifts']);

              final joiningDate = _formatDate(data['joiningDate']);

              final membership = data['membershipStatus']?.toString() ?? "-";

              final validTill = _formatDate(data['validTill']);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),

                padding: const EdgeInsets.all(20),

                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),

                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            "Library Information",

                            textAlign: TextAlign.center,

                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(width: 48),
                      ],
                    ),

                    const SizedBox(height: 25),

                    GlassCard(
                      child: Column(
                        children: [
                          _buildInfoTile(
                            Icons.badge,
                            "Library ID",
                            studentLibraryId,
                          ),

                          _divider(),

                          _buildInfoTile(Icons.event_seat, "Seat Number", seat),

                          _divider(),

                          _buildInfoTile(Icons.schedule, "Shift", shift),

                          _divider(),

                          _buildInfoTile(
                            Icons.calendar_today,
                            "Joining Date",
                            joiningDate,
                          ),

                          _divider(),

                          _buildInfoTile(
                            Icons.verified_user,
                            "Membership",
                            membership,
                          ),

                          _divider(),

                          _buildInfoTile(
                            Icons.event_available,
                            "Valid Till",
                            validTill,
                          ),

                          _divider(),

                          _buildInfoTile(
                            Icons.wifi,
                            "Required Network",
                            "Vision Library Wi-Fi",
                          ),

                          _divider(),

                          _buildInfoTile(
                            Icons.fact_check,
                            "Attendance Mode",
                            "Wi-Fi Verification",
                          ),
                        ],
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
    );
  }

  Widget _buildInfoTile(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),

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
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  value,

                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
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
    return Divider(color: Colors.white.withValues(alpha: 0.12), height: 1);
  }
}
