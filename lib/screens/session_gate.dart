import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/session_service.dart';
import 'dashboard_screen.dart';
import 'welcome_screen.dart';
import 'admin/admin_dashboard_screen.dart';

class SessionGate extends StatefulWidget {
  const SessionGate({super.key});

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    // ==========================================================
    // LOGO ANIMATION
    // ==========================================================

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );

    _scaleAnimation = Tween<double>(begin: 0.75, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutBack),
    );

    _animationController.forward();

    // ==========================================================
    // SESSION CHECK
    // ==========================================================

    _checkSession();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _checkSession() async {
    try {
      // ==========================================================
      // CHECK FIREBASE CONNECTION
      // ==========================================================

      await FirebaseFirestore.instance
          .collection('settings')
          .doc('admin')
          .get(const GetOptions(source: Source.server));

      if (!mounted) return;

      // ==========================================================
      // CHECK SAVED SESSION
      // ==========================================================

      final loggedIn = await SessionService.isLoggedIn();

      if (!mounted) return;

      if (!loggedIn) {
        _openWelcome();
        return;
      }

      // ==========================================================
      // GET USER TYPE
      // ==========================================================

      final userType = await SessionService.getUserType();

      if (!mounted) return;

      // ==========================================================
      // ADMIN
      // ==========================================================

      if (userType == 'admin') {
        _openAdminDashboard();
        return;
      }

      // ==========================================================
      // STUDENT
      // ==========================================================

      if (userType == 'student') {
        final libraryId = await SessionService.getLibraryId();

        if (!mounted) return;

        if (libraryId == null || libraryId.isEmpty) {
          await SessionService.logout();

          if (!mounted) return;

          _openWelcome();
          return;
        }

        // Verify student still exists on Firebase.
        final studentDocument = await FirebaseFirestore.instance
            .collection('students')
            .doc(libraryId)
            .get(const GetOptions(source: Source.server));

        if (!mounted) return;

        if (!studentDocument.exists) {
          await SessionService.logout();

          if (!mounted) return;

          _openWelcome();
          return;
        }

        _openStudentDashboard(libraryId);
        return;
      }

      // ==========================================================
      // UNKNOWN SESSION
      // ==========================================================

      await SessionService.logout();

      if (!mounted) return;

      _openWelcome();
    } on FirebaseException catch (e) {
      if (!mounted) return;

      String message = 'Please connect to internet.';

      if (e.code == 'permission-denied') {
        message = 'Firebase permission denied.';
      }

      _showConnectionError(message);
    } catch (e) {
      if (!mounted) return;

      _showConnectionError('Please connect to internet.');
    }
  }

  // ============================================================
  // WELCOME
  // ============================================================

  void _openWelcome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const WelcomeScreen()),
      (route) => false,
    );
  }

  // ============================================================
  // STUDENT DASHBOARD
  // ============================================================

  void _openStudentDashboard(String libraryId) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => DashboardScreen(libraryId: libraryId),
      ),
      (route) => false,
    );
  }

  // ============================================================
  // ADMIN DASHBOARD
  // ============================================================

  void _openAdminDashboard() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
      (route) => false,
    );
  }

  // ============================================================
  // CONNECTION ERROR
  // ============================================================

  void _showConnectionError(String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Connection Error'),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _checkSession();
              },
              child: const Text('RETRY'),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // LOADING / SPLASH UI
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F172A),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 135,
              height: 135,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}
