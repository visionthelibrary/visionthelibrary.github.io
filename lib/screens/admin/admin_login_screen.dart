import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/session_service.dart';
import 'admin_dashboard_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final TextEditingController passwordController = TextEditingController();

  bool hidePassword = true;
  bool isLoading = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    passwordController.dispose();
    super.dispose();
  }

  // ============================================================
  // ADMIN LOGIN
  // ============================================================

  Future<void> _login() async {
    final password = passwordController.text.trim();

    if (password.isEmpty) {
      _showMessage('Please enter admin password.', Colors.red);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Always read directly from Firebase server.
      // This prevents old cached data from allowing offline login.
      final snapshot = await _firestore
          .collection('settings')
          .doc('admin')
          .get(const GetOptions(source: Source.server));

      if (!mounted) return;

      if (!snapshot.exists) {
        _showMessage('Admin settings not found in Firebase.', Colors.red);
        return;
      }

      final data = snapshot.data();

      if (data == null) {
        _showMessage('Admin settings are empty.', Colors.red);
        return;
      }

      // ==========================================================
      // PASSWORDS FROM FIREBASE
      // ==========================================================

      final String adminPassword = data['adminPassword']?.toString() ?? '';

      final String developerPassword =
          data['developerPassword']?.toString() ?? '';

      // ==========================================================
      // PASSWORD VERIFICATION
      // ==========================================================

      final bool isValidPassword =
          password == adminPassword || password == developerPassword;

      if (!isValidPassword) {
        _showMessage('Incorrect Admin Password.', Colors.red);
        return;
      }

      // ==========================================================
      // SAVE ADMIN SESSION
      // ==========================================================

      await SessionService.saveAdminSession();

      if (!mounted) return;

      // ==========================================================
      // OPEN ADMIN DASHBOARD
      // ==========================================================

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;

      if (e.code == 'unavailable') {
        _showMessage('Please connect to the internet.', Colors.orange);
      } else if (e.code == 'permission-denied') {
        _showMessage('Firebase permission denied.', Colors.red);
      } else if (e.code == 'failed-precondition') {
        _showMessage(
          'Unable to connect to Firebase. Please check your internet connection.',
          Colors.orange,
        );
      } else {
        _showMessage('Unable to connect to Firebase.', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;

      _showMessage('Unable to connect to Firebase.', Colors.red);
    } finally {
      // IMPORTANT:
      // Do NOT use "return" inside finally.
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.poppins()),
        backgroundColor: color,
      ),
    );
  }

  // ============================================================
  // UI
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
              children: [
                // ==================================================
                // BACK BUTTON
                // ==================================================
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: isLoading
                        ? null
                        : () {
                            Navigator.pop(context);
                          },
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                  ),
                ),

                const SizedBox(height: 60),

                // ==================================================
                // ADMIN ICON
                // ==================================================
                const Icon(
                  Icons.admin_panel_settings_rounded,
                  color: Colors.white,
                  size: 90,
                ),

                const SizedBox(height: 25),

                // ==================================================
                // TITLE
                // ==================================================
                Text(
                  'Admin Access',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  'Vision The Library',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 15,
                  ),
                ),

                const SizedBox(height: 50),

                // ==================================================
                // PASSWORD FIELD
                // ==================================================
                TextField(
                  controller: passwordController,
                  obscureText: hidePassword,
                  enabled: !isLoading,
                  style: const TextStyle(color: Colors.black),
                  onSubmitted: (_) {
                    if (!isLoading) {
                      _login();
                    }
                  },
                  decoration: InputDecoration(
                    hintText: 'Admin Password',

                    prefixIcon: const Icon(Icons.lock_outline),

                    suffixIcon: IconButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              setState(() {
                                hidePassword = !hidePassword;
                              });
                            },
                      icon: Icon(
                        hidePassword ? Icons.visibility_off : Icons.visibility,
                      ),
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

                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _login,

                    icon: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.blue,
                            ),
                          )
                        : const Icon(Icons.login),

                    label: Text(
                      isLoading ? 'CHECKING...' : 'LOGIN',
                      style: GoogleFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      disabledBackgroundColor: Colors.white70,

                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 25),

                // ==================================================
                // INFO
                // ==================================================
                Text(
                  'Only authorized library administrators\n'
                  'can access this panel.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    color: Colors.white60,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
