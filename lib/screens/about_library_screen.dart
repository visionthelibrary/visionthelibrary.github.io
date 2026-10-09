import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AboutLibraryScreen extends StatefulWidget {
  const AboutLibraryScreen({super.key});

  @override
  State<AboutLibraryScreen> createState() => _AboutLibraryScreenState();
}

class _AboutLibraryScreenState extends State<AboutLibraryScreen> {
  bool isLoading = true;

  Map<String, dynamic> libraryData = {};

  bool hideWifiPassword = true;

  @override
  void initState() {
    super.initState();
    _loadLibraryData();
  }

  // ============================================================
  // LOAD LIBRARY DATA
  // ============================================================

  Future<void> _loadLibraryData() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("app_settings")
          .doc("library")
          .get();

      if (snapshot.exists) {
        libraryData = snapshot.data() ?? {};
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              "Unable to load About Library.",
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final String libraryName =
        libraryData["libraryName"]?.toString() ?? "Vision The Library";

    final String about = libraryData["about"]?.toString() ?? "";

    final String location = libraryData["location"]?.toString() ?? "";

    final String phone = libraryData["phone"]?.toString() ?? "";

    final String whatsapp = libraryData["whatsapp"]?.toString() ?? "";

    final String email = libraryData["email"]?.toString() ?? "";

    final String wifiName = libraryData["wifiName"]?.toString() ?? "";

    final String wifiPassword = libraryData["wifiPassword"]?.toString() ?? "";

    final Map<String, dynamic> pricing = libraryData["pricing"] is Map
        ? Map<String, dynamic>.from(libraryData["pricing"])
        : {};

    final Map<String, dynamic> shiftTimings = libraryData["shiftTimings"] is Map
        ? Map<String, dynamic>.from(libraryData["shiftTimings"])
        : {};

    final List<dynamic> customSections = libraryData["customSections"] is List
        ? libraryData["customSections"]
        : [];

    return Scaffold(
      backgroundColor: const Color(0xff0F172A),

      // ========================================================
      // APP BAR
      // ========================================================
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,

        title: Text(
          "About Library",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      // ========================================================
      // BODY
      // ========================================================
      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : RefreshIndicator(
              onRefresh: _loadLibraryData,
              color: Colors.blueAccent,
              backgroundColor: const Color(0xff1E293B),

              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(20),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    // ==================================================
                    // LIBRARY HEADER
                    // ==================================================
                    _libraryHeader(libraryName),

                    // ==================================================
                    // ABOUT
                    // ==================================================
                    if (about.isNotEmpty) ...[
                      const SizedBox(height: 25),

                      _sectionTitle("About"),

                      const SizedBox(height: 10),

                      _infoCard(Icons.info_outline, about),
                    ],

                    // ==================================================
                    // LOCATION
                    // ==================================================
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 25),

                      _sectionTitle("Location"),

                      const SizedBox(height: 10),

                      _infoCard(Icons.location_on_outlined, location),
                    ],

                    // ==================================================
                    // CONTACT
                    // ==================================================
                    if (phone.isNotEmpty ||
                        whatsapp.isNotEmpty ||
                        email.isNotEmpty) ...[
                      const SizedBox(height: 25),

                      _sectionTitle("Contact Information"),

                      const SizedBox(height: 10),

                      if (phone.isNotEmpty)
                        _contactCard(Icons.phone_outlined, "Phone", phone),

                      if (whatsapp.isNotEmpty) ...[
                        const SizedBox(height: 10),

                        _contactCard(Icons.chat_outlined, "WhatsApp", whatsapp),
                      ],

                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 10),

                        _contactCard(Icons.email_outlined, "Email", email),
                      ],
                    ],

                    // ==================================================
                    // PRICING
                    // ==================================================
                    const SizedBox(height: 30),

                    _sectionTitle("Membership Pricing"),

                    const SizedBox(height: 10),

                    _priceCard("Morning", pricing["morning"]),

                    _priceCard("Afternoon", pricing["afternoon"]),

                    _priceCard("Evening", pricing["evening"]),

                    _priceCard("Night", pricing["night"]),

                    _priceCard("Morning + Afternoon", pricing["morningNight"]),

                    _priceCard("Afternoon + Evening", pricing["nightEvening"]),

                    _priceCard(
                      "Morning + Afternoon + Evening",
                      pricing["morningNightEvening"],
                    ),

                    _priceCard("24 Hours", pricing["allDay"]),

                    // ==================================================
                    // LIBRARY TIMINGS
                    // ==================================================
                    const SizedBox(height: 30),

                    _sectionTitle("Library Timings"),

                    const SizedBox(height: 10),

                    _timingCard(
                      "Morning",
                      shiftTimings["morningStart"],
                      shiftTimings["morningEnd"],
                    ),

                    _timingCard(
                      "Afternoon",
                      shiftTimings["afternoonStart"],
                      shiftTimings["afternoonEnd"],
                    ),

                    _timingCard(
                      "Evening",
                      shiftTimings["eveningStart"],
                      shiftTimings["eveningEnd"],
                    ),

                    _timingCard(
                      "Night",
                      shiftTimings["nightStart"],
                      shiftTimings["nightEnd"],
                    ),

                    // ==================================================
                    // WI-FI
                    // ==================================================
                    if (wifiName.isNotEmpty || wifiPassword.isNotEmpty) ...[
                      const SizedBox(height: 30),

                      _sectionTitle("Library Wi-Fi"),

                      const SizedBox(height: 10),

                      _wifiCard(wifiName, wifiPassword),
                    ],

                    // ==================================================
                    // CUSTOM INFORMATION
                    // ==================================================
                    if (customSections.isNotEmpty) ...[
                      const SizedBox(height: 30),

                      _sectionTitle("Additional Information"),

                      const SizedBox(height: 10),

                      for (final section in customSections)
                        if (section is Map) ...[
                          if ((section["title"]?.toString() ?? "")
                              .trim()
                              .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _sectionTitle(
                                section["title"]?.toString() ?? "",
                              ),
                            ),

                          if ((section["content"]?.toString() ?? "")
                              .trim()
                              .isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _infoCard(
                                Icons.description_outlined,
                                section["content"]?.toString() ?? "",
                              ),
                            ),
                        ],
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================================
  // LIBRARY HEADER
  // ============================================================

  Widget _libraryHeader(String name) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(25),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(22),

        border: Border.all(color: Colors.white24),
      ),

      child: Column(
        children: [
          const Icon(
            Icons.local_library_rounded,
            color: Colors.white,
            size: 52,
          ),

          const SizedBox(height: 15),

          Text(
            name,
            textAlign: TextAlign.center,

            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            "About Library",
            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
    if (title.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Text(
      title,

      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  // ============================================================
  // INFO CARD
  // ============================================================

  Widget _infoCard(IconData icon, String text) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(16),

        border: Border.all(color: Colors.white12),
      ),

      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Icon(icon, color: Colors.white70, size: 22),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              text,

              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CONTACT CARD
  // ============================================================

  Widget _contactCard(IconData icon, String title, String value) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(15),

        border: Border.all(color: Colors.white12),
      ),

      child: Row(
        children: [
          Icon(icon, color: Colors.white70),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),

                const SizedBox(height: 3),

                Text(
                  value,

                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 13,
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

  // ============================================================
  // PRICE CARD
  // ============================================================

  Widget _priceCard(String title, dynamic price) {
    if (price == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(15),

        border: Border.all(color: Colors.white12),
      ),

      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,

            decoration: BoxDecoration(
              color: Colors.greenAccent.withValues(alpha: 0.12),

              borderRadius: BorderRadius.circular(10),
            ),

            child: const Icon(
              Icons.currency_rupee,
              color: Colors.greenAccent,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              title,

              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          Text(
            "₹$price",

            style: GoogleFonts.poppins(
              color: Colors.greenAccent,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // TIMING CARD
  // ============================================================

  Widget _timingCard(String title, dynamic start, dynamic end) {
    if (start == null || end == null) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,

      margin: const EdgeInsets.only(bottom: 10),

      padding: const EdgeInsets.all(15),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(15),

        border: Border.all(color: Colors.white12),
      ),

      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,

            decoration: BoxDecoration(
              color: Colors.blueAccent.withValues(alpha: 0.12),

              borderRadius: BorderRadius.circular(10),
            ),

            child: const Icon(
              Icons.access_time,
              color: Colors.blueAccent,
              size: 20,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              title,

              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),

          Text(
            _formatTiming(start.toString()),

            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 5),
            child: Icon(Icons.arrow_forward, color: Colors.white38, size: 14),
          ),

          Text(
            _formatTiming(end.toString()),

            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WIFI CARD
  // ============================================================

  Widget _wifiCard(String wifiName, String wifiPassword) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(17),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white12),
      ),

      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,

                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.15),

                  borderRadius: BorderRadius.circular(12),
                ),

                child: const Icon(
                  Icons.wifi,
                  color: Colors.blueAccent,
                  size: 23,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      "Wi-Fi Name",

                      style: GoogleFonts.poppins(
                        color: Colors.white54,
                        fontSize: 10,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      wifiName.isEmpty ? "Not available" : wifiName,

                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (wifiPassword.isNotEmpty) ...[
            const SizedBox(height: 15),

            const Divider(color: Colors.white12, height: 1),

            const SizedBox(height: 15),

            Row(
              children: [
                const Icon(Icons.lock_outline, color: Colors.white70, size: 21),

                const SizedBox(width: 12),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        "Wi-Fi Password",

                        style: GoogleFonts.poppins(
                          color: Colors.white54,
                          fontSize: 10,
                        ),
                      ),

                      const SizedBox(height: 3),

                      Text(
                        hideWifiPassword ? "••••••••" : wifiPassword,

                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          letterSpacing: hideWifiPassword ? 2 : 0,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  tooltip: hideWifiPassword ? "Show Password" : "Hide Password",

                  onPressed: () {
                    setState(() {
                      hideWifiPassword = !hideWifiPassword;
                    });
                  },

                  icon: Icon(
                    hideWifiPassword
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,

                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // FORMAT TIME
  // ============================================================

  String _formatTiming(String value) {
    if (!value.contains(":")) {
      return value;
    }

    final parts = value.split(":");

    if (parts.length != 2) {
      return value;
    }

    final hour = int.tryParse(parts[0]);

    final minute = int.tryParse(parts[1]);

    if (hour == null || minute == null) {
      return value;
    }

    final hour12 = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;

    final period = hour >= 12 ? "PM" : "AM";

    return "${hour12.toString().padLeft(2, '0')}:"
        "${minute.toString().padLeft(2, '0')} "
        "$period";
  }
}
