import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ChangeAdminPasswordScreen extends StatefulWidget {
  const ChangeAdminPasswordScreen({super.key});

  @override
  State<ChangeAdminPasswordScreen> createState() =>
      _ChangeAdminPasswordScreenState();
}

class _ChangeAdminPasswordScreenState extends State<ChangeAdminPasswordScreen> {
  final TextEditingController newPasswordController = TextEditingController();

  final TextEditingController confirmPasswordController =
      TextEditingController();

  bool hideNewPassword = true;
  bool hideConfirmPassword = true;
  bool isSaving = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  // ============================================================
  // CHANGE ADMIN PASSWORD
  // ============================================================

  Future<void> _changePassword() async {
    final newPassword = newPasswordController.text.trim();

    final confirmPassword = confirmPasswordController.text.trim();

    // ----------------------------------------------------------
    // VALIDATION
    // ----------------------------------------------------------

    if (newPassword.isEmpty || confirmPassword.isEmpty) {
      _showMessage('Please fill all fields.', Colors.red);
      return;
    }

    if (newPassword != confirmPassword) {
      _showMessage('New passwords do not match.', Colors.red);
      return;
    }

    if (newPassword.length < 6) {
      _showMessage('Password must be at least 6 characters.', Colors.red);
      return;
    }

    // ----------------------------------------------------------
    // SAVE
    // ----------------------------------------------------------

    setState(() {
      isSaving = true;
    });

    try {
      await _firestore.collection('settings').doc('admin').set({
        'adminPassword': newPassword,
      }, SetOptions(merge: true));

      if (!mounted) return;

      _showMessage('Admin password changed successfully.', Colors.green);

      newPasswordController.clear();
      confirmPasswordController.clear();

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      _showMessage('Failed to change admin password.', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
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
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F172A),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,

        title: Text(
          'Change Password',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            const SizedBox(height: 20),

            const CircleAvatar(
              radius: 45,
              backgroundColor: Colors.white24,

              child: Icon(
                Icons.lock_reset_rounded,
                color: Colors.white,
                size: 50,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Update Admin Password',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'Choose a new password.',
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
            ),

            const SizedBox(height: 35),

            // ------------------------------------------------
            // NEW PASSWORD
            // ------------------------------------------------
            _passwordField(
              controller: newPasswordController,
              hint: 'New Password',
              hidden: hideNewPassword,
              onVisibilityPressed: isSaving
                  ? null
                  : () {
                      setState(() {
                        hideNewPassword = !hideNewPassword;
                      });
                    },
            ),

            const SizedBox(height: 18),

            // ------------------------------------------------
            // CONFIRM PASSWORD
            // ------------------------------------------------
            _passwordField(
              controller: confirmPasswordController,
              hint: 'Confirm New Password',
              hidden: hideConfirmPassword,
              onVisibilityPressed: isSaving
                  ? null
                  : () {
                      setState(() {
                        hideConfirmPassword = !hideConfirmPassword;
                      });
                    },
            ),

            const SizedBox(height: 30),

            // ------------------------------------------------
            // CHANGE PASSWORD BUTTON
            // ------------------------------------------------
            SizedBox(
              width: double.infinity,
              height: 55,

              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _changePassword,

                icon: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.blue,
                        ),
                      )
                    : const Icon(Icons.lock_reset),

                label: Text(
                  isSaving ? 'UPDATING...' : 'CHANGE PASSWORD',

                  style: GoogleFonts.poppins(
                    fontSize: 16,
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
          ],
        ),
      ),
    );
  }

  // ============================================================
  // PASSWORD FIELD
  // ============================================================

  Widget _passwordField({
    required TextEditingController controller,
    required String hint,
    required bool hidden,
    required VoidCallback? onVisibilityPressed,
  }) {
    return TextField(
      controller: controller,

      obscureText: hidden,

      enabled: !isSaving,

      style: const TextStyle(color: Colors.black),

      decoration: InputDecoration(
        hintText: hint,

        prefixIcon: const Icon(Icons.lock_outline),

        suffixIcon: IconButton(
          onPressed: onVisibilityPressed,

          icon: Icon(hidden ? Icons.visibility_off : Icons.visibility),
        ),

        filled: true,

        fillColor: Colors.white,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),

          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
