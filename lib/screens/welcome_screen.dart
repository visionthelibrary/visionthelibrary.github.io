import 'package:flutter/material.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:vision_the_library/screens/login_screen.dart';
import 'package:vision_the_library/services/session_service.dart';
import 'package:vision_the_library/screens/dashboard_screen.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool checkingSession = true;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final loggedIn = await SessionService.isLoggedIn();

    if (!loggedIn) {
      if (mounted) {
        setState(() {
          checkingSession = false;
        });
      }
      return;
    }

    final userType = await SessionService.getUserType();

    if (!mounted) return;

    if (userType == 'student') {
      final libraryId = await SessionService.getLibraryId();

      if (libraryId != null && libraryId.isNotEmpty && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => DashboardScreen(libraryId: libraryId),
          ),
        );
        return;
      }
    }

    if (mounted) {
      setState(() {
        checkingSession = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (checkingSession) {
      return const Scaffold(
        backgroundColor: Color(0xff0F172A),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF2563EB)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.local_library_rounded,
                  color: Colors.white,
                  size: 100,
                ),

                const SizedBox(height: 30),

                Text(
                  "Vision The Library",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                AnimatedTextKit(
                  repeatForever: true,
                  animatedTexts: [
                    TypewriterAnimatedText(
                      "Learn • Read • Grow",
                      textStyle: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 18,
                      ),
                      speed: const Duration(milliseconds: 80),
                    ),
                  ],
                ),

                const SizedBox(height: 60),

                SizedBox(
                  width: 220,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                      ),
                    ),
                    child: Text(
                      "Get Started",
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
