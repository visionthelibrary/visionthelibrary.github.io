import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/session_service.dart';
import 'dashboard_screen.dart';
import 'admin/admin_login_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController libraryIdController = TextEditingController();

  final TextEditingController pinController = TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;

  @override
  void dispose() {
    libraryIdController.dispose();
    pinController.dispose();
    super.dispose();
  }

  // ============================================================
  // STUDENT LOGIN
  // ============================================================

  Future<void> _loginStudent() async {
    final String libraryId = libraryIdController.text.trim().toUpperCase();

    final String pin = pinController.text.trim();

    if (libraryId.isEmpty || pin.length != 4) {
      _showMessage(
        'Please enter a valid Library ID and 4-digit PIN',
        Colors.red,
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      // --------------------------------------------------------
      // IMPORTANT:
      // Always use Firebase SERVER.
      //
      // Cached/offline Firebase data must NOT be used for login.
      // --------------------------------------------------------

      final studentDocument = await FirebaseFirestore.instance
          .collection('students')
          .doc(libraryId)
          .get(const GetOptions(source: Source.server))
          .timeout(const Duration(seconds: 15));

      if (!mounted) return;

      // --------------------------------------------------------
      // STUDENT NOT FOUND
      // --------------------------------------------------------

      if (!studentDocument.exists) {
        _showMessage('Invalid Library ID or PIN', Colors.red);

        setState(() {
          isLoading = false;
        });

        return;
      }

      final studentData = studentDocument.data();

      if (studentData == null) {
        _showMessage('Unable to load student information.', Colors.red);

        setState(() {
          isLoading = false;
        });

        return;
      }

      // --------------------------------------------------------
      // CHECK PIN
      // --------------------------------------------------------

      final String savedPin = studentData['pin']?.toString() ?? '';

      if (savedPin != pin) {
        _showMessage('Invalid Library ID or PIN', Colors.red);

        setState(() {
          isLoading = false;
        });

        return;
      }

      // --------------------------------------------------------
      // SAVE SESSION ONLY AFTER SUCCESSFUL SERVER LOGIN
      // --------------------------------------------------------

      await SessionService.saveStudentSession(libraryId);

      if (!mounted) return;

      // --------------------------------------------------------
      // OPEN DASHBOARD
      // --------------------------------------------------------

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => DashboardScreen(libraryId: libraryId),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      String message;

      switch (e.code) {
        case 'unavailable':
          message = 'Please connect to the internet.';
          break;

        case 'permission-denied':
          message = 'Firebase permission denied.';
          break;

        case 'deadline-exceeded':
          message = 'Connection timed out. Please check your internet.';
          break;

        case 'failed-precondition':
          message = 'Unable to connect to Firebase.';
          break;

        default:
          message = 'Unable to connect to Firebase.';
      }

      _showMessage(message, Colors.red);

      setState(() {
        isLoading = false;
      });
    } on TimeoutException {
      if (!mounted) return;

      _showMessage(
        'Connection timed out. Please check your internet.',
        Colors.red,
      );

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      _showMessage('Please connect to the internet.', Colors.red);

      setState(() {
        isLoading = false;
      });
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins()),
          backgroundColor: color,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,

        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xff0F172A), Color(0xff1E3A8A), Color(0xff2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),

            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,

              children: [
                // ==================================================
                // ADMIN BUTTON
                // ==================================================
                Align(
                  alignment: Alignment.topRight,

                  child: TextButton.icon(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AdminLoginScreen(),
                              ),
                            );
                          },

                    icon: const Icon(
                      Icons.admin_panel_settings,
                      color: Colors.white,
                    ),

                    label: Text(
                      'Admin',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // ==================================================
                // LIBRARY ICON
                // ==================================================
                const Icon(Icons.local_library, color: Colors.white, size: 90),

                const SizedBox(height: 20),

                // ==================================================
                // TITLE
                // ==================================================
                Center(
                  child: Text(
                    'Vision The Library',
                    textAlign: TextAlign.center,

                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Student Login',

                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 17,
                  ),
                ),

                const SizedBox(height: 90),

                // ==================================================
                // LIBRARY ID
                // ==================================================
                TextField(
                  controller: libraryIdController,

                  textCapitalization: TextCapitalization.characters,

                  inputFormatters: [UpperCaseTextFormatter()],

                  decoration: InputDecoration(
                    hintText: 'Library ID',

                    prefixIcon: const Icon(Icons.badge),

                    filled: true,
                    fillColor: Colors.white,

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // ==================================================
                // PIN
                // ==================================================
                TextField(
                  controller: pinController,

                  obscureText: hidePassword,

                  keyboardType: TextInputType.number,

                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],

                  decoration: InputDecoration(
                    hintText: '4-Digit PIN',

                    prefixIcon: const Icon(Icons.pin),

                    suffixIcon: IconButton(
                      icon: Icon(
                        hidePassword ? Icons.visibility_off : Icons.visibility,
                      ),

                      onPressed: () {
                        setState(() {
                          hidePassword = !hidePassword;
                        });
                      },
                    ),

                    filled: true,
                    fillColor: Colors.white,

                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // ==================================================
                // LOGIN BUTTON
                // ==================================================
                SizedBox(
                  width: double.infinity,
                  height: 55,

                  child: ElevatedButton(
                    onPressed: isLoading ? null : _loginStudent,

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),

                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,

                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : Text(
                            'LOGIN',

                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 25),

                const Divider(color: Colors.white38, thickness: 1),

                const SizedBox(height: 20),

                // ==================================================
                // FOOTER
                // ==================================================
                Text(
                  '© Vision The Library',

                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 14,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Knowledge Beyond Limits',

                  style: GoogleFonts.poppins(
                    color: Colors.white38,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// UPPERCASE FORMATTER
// ============================================================

class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    return TextEditingValue(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}
