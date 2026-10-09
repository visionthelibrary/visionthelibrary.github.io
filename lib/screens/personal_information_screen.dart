import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../widgets/glass_card.dart';
import '../../widgets/gradient_background.dart';

class PersonalInformationScreen extends StatelessWidget {
  final String libraryId;

  const PersonalInformationScreen({super.key, required this.libraryId});

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

      return "${date.day} "
          "${months[date.month - 1]} "
          "${date.year}";
    }

    return value.toString();
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
                    "Failed to load personal information",

                    textAlign: TextAlign.center,

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

              final String name = data['name']?.toString() ?? "-";

              final String studentId =
                  data['libraryId']?.toString() ?? libraryId;

              final String phone = data['phone']?.toString() ?? "-";

              final String email = data['email']?.toString() ?? "-";

              final String gender = data['gender']?.toString() ?? "-";

              final String address = data['address']?.toString() ?? "-";

              final String dateOfBirth = _formatDate(data['dateOfBirth']);

              return SingleChildScrollView(
                physics: const BouncingScrollPhysics(),

                padding: const EdgeInsets.all(20),

                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },

                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                        ),

                        Expanded(
                          child: Text(
                            "Personal Information",

                            textAlign: TextAlign.center,

                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 20,
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
                            Icons.person,
                            "Full Name",
                            name.toUpperCase(),
                          ),

                          _divider(),

                          _buildInfoTile(Icons.badge, "Student ID", studentId),

                          _divider(),

                          _buildInfoTile(Icons.phone, "Mobile Number", phone),

                          _divider(),

                          _buildInfoTile(Icons.email, "Email Address", email),

                          _divider(),

                          _buildInfoTile(
                            Icons.cake,
                            "Date of Birth",
                            dateOfBirth,
                          ),

                          _divider(),

                          _buildInfoTile(
                            gender == "Girl" ? Icons.female : Icons.male,
                            "Gender",
                            gender,
                          ),

                          _divider(),

                          _buildInfoTile(Icons.home, "Address", address),
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
