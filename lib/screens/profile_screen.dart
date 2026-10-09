import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import '../services/session_service.dart';
import 'personal_information_screen.dart';
import 'library_information_screen.dart';
import 'notice_board_screen.dart';
import 'attendance_history_screen.dart';
import 'login_screen.dart';
import 'about_library_screen.dart';

class ProfileScreen extends StatelessWidget {
  final String libraryId;

  const ProfileScreen({super.key, required this.libraryId});

  // Open Instagram profile
  Future<void> _openInstagram(BuildContext context) async {
    final Uri instagramUrl = Uri.parse(
      'https://www.instagram.com/aryanrajnke/',
    );

    final bool launched = await launchUrl(
      instagramUrl,
      mode: LaunchMode.externalApplication,
    );

    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Instagram link could not be opened please search @aryanrajnke on Instagram',
          ),
        ),
      );
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
          "Profile",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: StreamBuilder<DocumentSnapshot>(
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
                "Failed to load profile",
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

          final String name = data['name']?.toString() ?? "Student";

          final String studentId = data['libraryId']?.toString() ?? libraryId;

          final String gender = data['gender']?.toString() ?? "";

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),

            child: Column(
              children: [
                CircleAvatar(
                  radius: 55,
                  backgroundColor: Colors.white24,

                  child: Icon(
                    gender == "Girl" ? Icons.person_2 : Icons.person,
                    color: Colors.white,
                    size: 65,
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  name.toUpperCase(),
                  textAlign: TextAlign.center,

                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  "Student ID : $studentId",

                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 30),

                Container(
                  width: double.infinity,

                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),

                    borderRadius: BorderRadius.circular(20),

                    border: Border.all(color: Colors.white24),
                  ),

                  child: Column(
                    children: [
                      profileTile(
                        context,
                        Icons.person_2_outlined,
                        "Personal Information",
                        studentId,
                        name,
                      ),

                      const Divider(color: Colors.white24, height: 1),

                      profileTile(
                        context,
                        Icons.badge_outlined,
                        "Library Information",
                        studentId,
                        name,
                      ),

                      const Divider(color: Colors.white24, height: 1),

                      profileTile(
                        context,
                        Icons.info_outline,
                        "About Library",
                        studentId,
                        name,
                      ),

                      const Divider(color: Colors.white24, height: 1),

                      profileTile(
                        context,
                        Icons.campaign_outlined,
                        "Notice Board",
                        studentId,
                        name,
                      ),

                      const Divider(color: Colors.white24, height: 1),

                      profileTile(
                        context,
                        Icons.history,
                        "Attendance History",
                        studentId,
                        name,
                      ),

                      const Divider(color: Colors.white24, height: 1),

                      profileTile(
                        context,
                        Icons.logout,
                        "Logout",
                        studentId,
                        name,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),

                // DEVELOPER CREDIT
                Text(
                  "Developed & Managed by ARYAN RAJ",
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.15,
                  ),
                ),

                const SizedBox(height: 6),

                // INSTAGRAM
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      "For More Information ·",
                      style: GoogleFonts.poppins(
                        color: Colors.white38,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w400,
                      ),
                    ),

                    const SizedBox(width: 6),

                    InkWell(
                      onTap: () => _openInstagram(context),
                      borderRadius: BorderRadius.circular(8),

                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 2,
                        ),

                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            FaIcon(
                              FontAwesomeIcons.instagram,
                              color: Colors.white60,
                              size: 13,
                            ),

                            const SizedBox(width: 5),

                            Text(
                              "@aryanrajnke",
                              style: GoogleFonts.poppins(
                                color: Colors.white60,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Library name
                Text(
                  "Vision The Library",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                // App version
                Text(
                  "Version 1.0.0",
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),

                const SizedBox(height: 18),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget profileTile(
    BuildContext context,
    IconData icon,
    String title,
    String studentId,
    String name,
  ) {
    return InkWell(
      onTap: () {
        if (title == "Attendance History") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentAttendanceHistoryScreen(
                name: name,
                libraryId: studentId,
              ),
            ),
          );

          return;
        }

        if (title == "Notice Board") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const NoticeBoardScreen()),
          );
        }

        if (title == "Library Information") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  LibraryInformationScreen(libraryId: studentId),
            ),
          );
        }

        if (title == "About Library") {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AboutLibraryScreen()),
          );
        }

        if (title == "Personal Information") {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  PersonalInformationScreen(libraryId: studentId),
            ),
          );
        }

        if (title == "Logout") {
          showDialog(
            context: context,

            builder: (dialogContext) {
              return AlertDialog(
                backgroundColor: const Color(0xff1E293B),

                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),

                title: const Text(
                  "Logout",
                  style: TextStyle(color: Colors.white),
                ),

                content: const Text(
                  "Are you sure you want to logout?",
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
                      Navigator.pop(dialogContext);

                      await SessionService.logout();

                      if (!context.mounted) return;

                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                        (route) => false,
                      );
                    },

                    child: const Text("Logout"),
                  ),
                ],
              );
            },
          );
        }
      },

      borderRadius: BorderRadius.circular(20),

      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),

        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 24),

            const SizedBox(width: 16),

            Expanded(
              child: Text(
                title,

                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white54,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }
}
