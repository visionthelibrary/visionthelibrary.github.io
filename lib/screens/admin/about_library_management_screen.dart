import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AboutLibraryManagementScreen extends StatefulWidget {
  const AboutLibraryManagementScreen({super.key});

  @override
  State<AboutLibraryManagementScreen> createState() =>
      _AboutLibraryManagementScreenState();
}

class _AboutLibraryManagementScreenState
    extends State<AboutLibraryManagementScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ============================================================
  // BASIC INFORMATION
  // ============================================================

  final TextEditingController libraryNameController = TextEditingController();

  final TextEditingController aboutController = TextEditingController();

  final TextEditingController locationController = TextEditingController();

  final TextEditingController phoneController = TextEditingController();

  final TextEditingController whatsappController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  // ============================================================
  // WI-FI
  // ============================================================

  final TextEditingController wifiNameController = TextEditingController();

  final TextEditingController wifiPasswordController = TextEditingController();

  bool hideWifiPassword = true;

  // ============================================================
  // PRICING
  // ============================================================

  final TextEditingController morningPriceController = TextEditingController(
    text: "300",
  );

  final TextEditingController afternoonPriceController = TextEditingController(
    text: "400",
  );

  final TextEditingController eveningPriceController = TextEditingController(
    text: "400",
  );

  final TextEditingController nightPriceController = TextEditingController(
    text: "400",
  );

  // Existing Firestore keys are preserved for compatibility.
  // Their UI meaning is:
  // morningNight           -> Morning + Afternoon
  // nightEvening           -> Afternoon + Evening
  // morningNightEvening    -> Morning + Afternoon + Evening

  final TextEditingController morningAfternoonPriceController =
      TextEditingController(text: "600");

  final TextEditingController afternoonEveningPriceController =
      TextEditingController(text: "650");

  final TextEditingController morningAfternoonEveningPriceController =
      TextEditingController(text: "850");

  final TextEditingController allDayPriceController = TextEditingController(
    text: "1200",
  );

  // ============================================================
  // SHIFT TIMINGS
  // ============================================================

  TimeOfDay morningStart = const TimeOfDay(hour: 6, minute: 0);

  TimeOfDay morningEnd = const TimeOfDay(hour: 11, minute: 0);

  TimeOfDay afternoonStart = const TimeOfDay(hour: 11, minute: 0);

  TimeOfDay afternoonEnd = const TimeOfDay(hour: 16, minute: 0);

  TimeOfDay eveningStart = const TimeOfDay(hour: 16, minute: 0);

  TimeOfDay eveningEnd = const TimeOfDay(hour: 22, minute: 0);

  TimeOfDay nightStart = const TimeOfDay(hour: 22, minute: 0);

  TimeOfDay nightEnd = const TimeOfDay(hour: 6, minute: 0);

  // ============================================================
  // CUSTOM SECTIONS
  // ============================================================

  final List<Map<String, TextEditingController>> customSections = [];

  bool isLoading = true;
  bool isSaving = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();
    _loadAboutData();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    libraryNameController.dispose();
    aboutController.dispose();
    locationController.dispose();
    phoneController.dispose();
    whatsappController.dispose();
    emailController.dispose();

    wifiNameController.dispose();
    wifiPasswordController.dispose();

    morningPriceController.dispose();
    afternoonPriceController.dispose();
    eveningPriceController.dispose();
    nightPriceController.dispose();

    morningAfternoonPriceController.dispose();
    afternoonEveningPriceController.dispose();
    morningAfternoonEveningPriceController.dispose();
    allDayPriceController.dispose();

    for (final section in customSections) {
      section["title"]?.dispose();
      section["content"]?.dispose();
    }

    super.dispose();
  }

  // ============================================================
  // LOAD DATA
  // ============================================================

  Future<void> _loadAboutData() async {
    try {
      final snapshot = await _firestore
          .collection("app_settings")
          .doc("library")
          .get();

      if (snapshot.exists) {
        final data = snapshot.data() ?? {};

        // --------------------------------------------------------
        // BASIC INFORMATION
        // --------------------------------------------------------

        libraryNameController.text =
            data["libraryName"]?.toString() ?? "Vision The Library";

        aboutController.text = data["about"]?.toString() ?? "";

        locationController.text = data["location"]?.toString() ?? "";

        phoneController.text = data["phone"]?.toString() ?? "";

        whatsappController.text = data["whatsapp"]?.toString() ?? "";

        emailController.text = data["email"]?.toString() ?? "";

        // --------------------------------------------------------
        // WI-FI
        // --------------------------------------------------------

        wifiNameController.text = data["wifiName"]?.toString() ?? "";

        wifiPasswordController.text = data["wifiPassword"]?.toString() ?? "";

        // --------------------------------------------------------
        // PRICING
        // --------------------------------------------------------

        final pricing = data["pricing"];

        if (pricing is Map) {
          morningPriceController.text = pricing["morning"]?.toString() ?? "300";

          afternoonPriceController.text =
              pricing["afternoon"]?.toString() ?? "400";

          eveningPriceController.text = pricing["evening"]?.toString() ?? "400";

          nightPriceController.text = pricing["night"]?.toString() ?? "400";

          // Old Firestore keys intentionally preserved.
          morningAfternoonPriceController.text =
              pricing["morningNight"]?.toString() ?? "600";

          afternoonEveningPriceController.text =
              pricing["nightEvening"]?.toString() ?? "650";

          morningAfternoonEveningPriceController.text =
              pricing["morningNightEvening"]?.toString() ?? "850";

          allDayPriceController.text = pricing["allDay"]?.toString() ?? "1200";
        }

        // --------------------------------------------------------
        // SHIFT TIMINGS
        // --------------------------------------------------------

        final shifts = data["shiftTimings"];

        if (shifts is Map) {
          morningStart = _timeFromString(
            shifts["morningStart"]?.toString(),
            morningStart,
          );

          morningEnd = _timeFromString(
            shifts["morningEnd"]?.toString(),
            morningEnd,
          );

          afternoonStart = _timeFromString(
            shifts["afternoonStart"]?.toString(),
            afternoonStart,
          );

          afternoonEnd = _timeFromString(
            shifts["afternoonEnd"]?.toString(),
            afternoonEnd,
          );

          eveningStart = _timeFromString(
            shifts["eveningStart"]?.toString(),
            eveningStart,
          );

          eveningEnd = _timeFromString(
            shifts["eveningEnd"]?.toString(),
            eveningEnd,
          );

          nightStart = _timeFromString(
            shifts["nightStart"]?.toString(),
            nightStart,
          );

          nightEnd = _timeFromString(shifts["nightEnd"]?.toString(), nightEnd);
        }

        // --------------------------------------------------------
        // CUSTOM SECTIONS
        // --------------------------------------------------------

        final savedSections = data["customSections"];

        if (savedSections is List) {
          for (final item in savedSections) {
            if (item is Map) {
              final title = TextEditingController(
                text: item["title"]?.toString() ?? "",
              );

              final content = TextEditingController(
                text: item["content"]?.toString() ?? "",
              );

              customSections.add({"title": title, "content": content});
            }
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to load library information."),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
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
          "About Library",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Colors.blueAccent),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  // ==================================================
                  // BASIC INFORMATION
                  // ==================================================
                  _sectionTitle("Basic Information"),

                  const SizedBox(height: 15),

                  _textField(
                    controller: libraryNameController,
                    label: "Library Name",
                    icon: Icons.local_library_outlined,
                  ),

                  const SizedBox(height: 15),

                  _textField(
                    controller: aboutController,
                    label: "About Library",
                    icon: Icons.info_outline,
                    maxLines: 5,
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // LOCATION
                  // ==================================================
                  _sectionTitle("Location"),

                  const SizedBox(height: 15),

                  _textField(
                    controller: locationController,
                    label: "Full Address",
                    icon: Icons.location_on_outlined,
                    maxLines: 3,
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // CONTACT
                  // ==================================================
                  _sectionTitle("Contact Information"),

                  const SizedBox(height: 15),

                  _textField(
                    controller: phoneController,
                    label: "Phone Number",
                    icon: Icons.phone_outlined,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 15),

                  _textField(
                    controller: whatsappController,
                    label: "WhatsApp Number",
                    icon: Icons.chat_outlined,
                    keyboardType: TextInputType.phone,
                  ),

                  const SizedBox(height: 15),

                  _textField(
                    controller: emailController,
                    label: "Email Address",
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // PRICING
                  // ==================================================
                  _sectionTitle("Membership Pricing"),

                  const SizedBox(height: 8),

                  Text(
                    "Set the membership price for each available plan.",
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 15),

                  _priceField(
                    controller: morningPriceController,
                    title: "Morning",
                  ),

                  const SizedBox(height: 12),

                  _priceField(
                    controller: afternoonPriceController,
                    title: "Afternoon",
                  ),

                  const SizedBox(height: 12),

                  _priceField(
                    controller: eveningPriceController,
                    title: "Evening",
                  ),

                  const SizedBox(height: 12),

                  _priceField(controller: nightPriceController, title: "Night"),

                  const SizedBox(height: 12),

                  _priceField(
                    controller: morningAfternoonPriceController,
                    title: "Morning + Afternoon",
                  ),

                  const SizedBox(height: 12),

                  _priceField(
                    controller: afternoonEveningPriceController,
                    title: "Afternoon + Evening",
                  ),

                  const SizedBox(height: 12),

                  _priceField(
                    controller: morningAfternoonEveningPriceController,
                    title: "Morning + Afternoon + Evening",
                  ),

                  const SizedBox(height: 12),

                  _priceField(
                    controller: allDayPriceController,
                    title: "24 Hours",
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // SHIFT TIMINGS
                  // ==================================================
                  _sectionTitle("Shift Timings"),

                  const SizedBox(height: 8),

                  Text(
                    "Set the operating hours for each library shift.",
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 15),

                  _shiftTimingCard(
                    title: "Morning Shift",
                    startTime: morningStart,
                    endTime: morningEnd,
                    onStartTap: () async {
                      final time = await _selectTime(morningStart);

                      if (time != null) {
                        setState(() {
                          morningStart = time;
                        });
                      }
                    },
                    onEndTap: () async {
                      final time = await _selectTime(morningEnd);

                      if (time != null) {
                        setState(() {
                          morningEnd = time;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  _shiftTimingCard(
                    title: "Afternoon Shift",
                    startTime: afternoonStart,
                    endTime: afternoonEnd,
                    onStartTap: () async {
                      final time = await _selectTime(afternoonStart);

                      if (time != null) {
                        setState(() {
                          afternoonStart = time;
                        });
                      }
                    },
                    onEndTap: () async {
                      final time = await _selectTime(afternoonEnd);

                      if (time != null) {
                        setState(() {
                          afternoonEnd = time;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  _shiftTimingCard(
                    title: "Evening Shift",
                    startTime: eveningStart,
                    endTime: eveningEnd,
                    onStartTap: () async {
                      final time = await _selectTime(eveningStart);

                      if (time != null) {
                        setState(() {
                          eveningStart = time;
                        });
                      }
                    },
                    onEndTap: () async {
                      final time = await _selectTime(eveningEnd);

                      if (time != null) {
                        setState(() {
                          eveningEnd = time;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 12),

                  _shiftTimingCard(
                    title: "Night Shift",
                    startTime: nightStart,
                    endTime: nightEnd,
                    onStartTap: () async {
                      final time = await _selectTime(nightStart);

                      if (time != null) {
                        setState(() {
                          nightStart = time;
                        });
                      }
                    },
                    onEndTap: () async {
                      final time = await _selectTime(nightEnd);

                      if (time != null) {
                        setState(() {
                          nightEnd = time;
                        });
                      }
                    },
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // WI-FI
                  // ==================================================
                  _sectionTitle("Wi-Fi Information"),

                  const SizedBox(height: 8),

                  Text(
                    "Students can view the Wi-Fi name and password.",
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 15),

                  _textField(
                    controller: wifiNameController,
                    label: "Wi-Fi Name",
                    icon: Icons.wifi_outlined,
                  ),

                  const SizedBox(height: 15),

                  _passwordField(),

                  const SizedBox(height: 30),

                  // ==================================================
                  // CUSTOM SECTIONS
                  // ==================================================
                  _sectionTitle("Additional Information"),

                  const SizedBox(height: 8),

                  Text(
                    "Add additional information sections for students.",
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 15),

                  for (int i = 0; i < customSections.length; i++) ...[
                    _customSectionCard(i),
                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    width: double.infinity,
                    height: 50,

                    child: OutlinedButton.icon(
                      onPressed: _addCustomSection,

                      icon: const Icon(Icons.add),

                      label: Text(
                        "ADD INFORMATION SECTION",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // ==================================================
                  // SAVE
                  // ==================================================
                  SizedBox(
                    width: double.infinity,
                    height: 55,

                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : _saveAboutData,

                      icon: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),

                      label: Text(
                        isSaving ? "SAVING..." : "SAVE CHANGES",
                        style: GoogleFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 30),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // SAVE DATA
  // ============================================================

  Future<void> _saveAboutData() async {
    if (isSaving) return;

    // ------------------------------------------------------------
    // BASIC VALIDATION
    // ------------------------------------------------------------

    final prices = [
      morningPriceController,
      afternoonPriceController,
      eveningPriceController,
      nightPriceController,
      morningAfternoonPriceController,
      afternoonEveningPriceController,
      morningAfternoonEveningPriceController,
      allDayPriceController,
    ];

    for (final controller in prices) {
      final value = int.tryParse(controller.text.trim());

      if (value == null || value < 0) {
        _showMessage("Please enter valid pricing.", Colors.redAccent);
        return;
      }
    }

    setState(() {
      isSaving = true;
    });

    try {
      final List<Map<String, String>> savedCustomSections = [];

      for (final section in customSections) {
        final title = section["title"]?.text.trim() ?? "";

        final content = section["content"]?.text.trim() ?? "";

        if (title.isNotEmpty && content.isNotEmpty) {
          savedCustomSections.add({"title": title, "content": content});
        }
      }

      // ----------------------------------------------------------
      // FIRESTORE
      // ----------------------------------------------------------

      await _firestore.collection("app_settings").doc("library").set({
        "libraryName": libraryNameController.text.trim(),

        "about": aboutController.text.trim(),

        "location": locationController.text.trim(),

        "phone": phoneController.text.trim(),

        "whatsapp": whatsappController.text.trim(),

        "email": emailController.text.trim(),

        "wifiName": wifiNameController.text.trim(),

        "wifiPassword": wifiPasswordController.text.trim(),

        // ------------------------------------------------------
        // PRICING
        // Existing Firestore keys preserved.
        // ------------------------------------------------------
        "pricing": {
          "morning": _priceValue(morningPriceController),

          "afternoon": _priceValue(afternoonPriceController),

          "evening": _priceValue(eveningPriceController),

          "night": _priceValue(nightPriceController),

          "morningNight": _priceValue(morningAfternoonPriceController),

          "nightEvening": _priceValue(afternoonEveningPriceController),

          "morningNightEvening": _priceValue(
            morningAfternoonEveningPriceController,
          ),

          "allDay": _priceValue(allDayPriceController),
        },

        // ------------------------------------------------------
        // SHIFT TIMINGS
        // ------------------------------------------------------
        "shiftTimings": {
          "morningStart": _timeToString(morningStart),

          "morningEnd": _timeToString(morningEnd),

          "afternoonStart": _timeToString(afternoonStart),

          "afternoonEnd": _timeToString(afternoonEnd),

          "eveningStart": _timeToString(eveningStart),

          "eveningEnd": _timeToString(eveningEnd),

          "nightStart": _timeToString(nightStart),

          "nightEnd": _timeToString(nightEnd),
        },

        "customSections": savedCustomSections,

        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      _showMessage("Library information saved successfully.", Colors.green);
    } catch (e) {
      if (!mounted) return;

      _showMessage("Unable to save library information.", Colors.redAccent);
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }

  // ============================================================
  // CUSTOM SECTION
  // ============================================================

  void _addCustomSection() {
    setState(() {
      customSections.add({
        "title": TextEditingController(),
        "content": TextEditingController(),
      });
    });
  }

  void _removeCustomSection(int index) {
    final section = customSections[index];

    section["title"]?.dispose();
    section["content"]?.dispose();

    setState(() {
      customSections.removeAt(index);
    });
  }

  Widget _customSectionCard(int index) {
    final section = customSections[index];

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),

      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  "Information Section ${index + 1}",
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              IconButton(
                onPressed: () => _removeCustomSection(index),

                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              ),
            ],
          ),

          const SizedBox(height: 8),

          _textField(
            controller: section["title"]!,
            label: "Section Title",
            icon: Icons.title_outlined,
          ),

          const SizedBox(height: 12),

          _textField(
            controller: section["content"]!,
            label: "Information",
            icon: Icons.description_outlined,
            maxLines: 5,
          ),
        ],
      ),
    );
  }

  // ============================================================
  // WI-FI PASSWORD
  // ============================================================

  Widget _passwordField() {
    return TextField(
      controller: wifiPasswordController,

      obscureText: hideWifiPassword,

      style: GoogleFonts.poppins(color: Colors.white),

      decoration: InputDecoration(
        labelText: "Wi-Fi Password",

        labelStyle: GoogleFonts.poppins(color: Colors.white70),

        prefixIcon: const Icon(Icons.lock_outline, color: Colors.white70),

        suffixIcon: IconButton(
          onPressed: () {
            setState(() {
              hideWifiPassword = !hideWifiPassword;
            });
          },

          icon: Icon(
            hideWifiPassword ? Icons.visibility_off : Icons.visibility,
            color: Colors.white70,
          ),
        ),

        filled: true,

        fillColor: Colors.white.withValues(alpha: 0.10),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),

          borderSide: const BorderSide(color: Colors.white24),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),

          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
    );
  }

  // ============================================================
  // PRICE FIELD
  // ============================================================

  Widget _priceField({
    required TextEditingController controller,
    required String title,
  }) {
    return _textField(
      controller: controller,
      label: "$title Price (₹)",
      icon: Icons.currency_rupee,
      keyboardType: TextInputType.number,
    );
  }

  // ============================================================
  // SECTION TITLE
  // ============================================================

  Widget _sectionTitle(String title) {
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
  // TEXT FIELD
  // ============================================================

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,

      keyboardType: keyboardType,

      maxLines: maxLines,

      style: GoogleFonts.poppins(color: Colors.white),

      decoration: InputDecoration(
        labelText: label,

        labelStyle: GoogleFonts.poppins(color: Colors.white70),

        prefixIcon: Icon(icon, color: Colors.white70),

        filled: true,

        fillColor: Colors.white.withValues(alpha: 0.10),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),

          borderSide: const BorderSide(color: Colors.white24),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),

          borderSide: const BorderSide(color: Colors.blue, width: 2),
        ),
      ),
    );
  }

  // ============================================================
  // SHIFT CARD
  // ============================================================

  Widget _shiftTimingCard({
    required String title,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required VoidCallback onStartTap,
    required VoidCallback onEndTap,
  }) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white24),
      ),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            title,

            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 5),

          Text(
            _shiftDescription(title),
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _timeBox(
                  title: "Start Time",
                  time: startTime,
                  onTap: onStartTap,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: _timeBox(
                  title: "End Time",
                  time: endTime,
                  onTap: onEndTap,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _shiftDescription(String title) {
    switch (title) {
      case "Morning Shift":
        return "06:00 AM – 11:00 AM";

      case "Afternoon Shift":
        return "11:00 AM – 04:00 PM";

      case "Evening Shift":
        return "04:00 PM – 10:00 PM";

      case "Night Shift":
        return "10:00 PM – 06:00 AM";

      default:
        return "";
    }
  }

  // ============================================================
  // TIME BOX
  // ============================================================

  Widget _timeBox({
    required String title,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(12),

      child: Container(
        padding: const EdgeInsets.all(12),

        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),

          borderRadius: BorderRadius.circular(12),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              title,

              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 10),
            ),

            const SizedBox(height: 5),

            Row(
              children: [
                const Icon(Icons.access_time, color: Colors.white70, size: 18),

                const SizedBox(width: 7),

                Expanded(
                  child: Text(
                    time.format(context),

                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TIME PICKER
  // ============================================================

  Future<TimeOfDay?> _selectTime(TimeOfDay initialTime) async {
    return showTimePicker(context: context, initialTime: initialTime);
  }

  // ============================================================
  // PRICE VALUE
  // ============================================================

  int _priceValue(TextEditingController controller) {
    return int.tryParse(controller.text.trim()) ?? 0;
  }

  // ============================================================
  // TIME SERIALIZATION
  // ============================================================

  String _timeToString(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, "0");

    final minute = time.minute.toString().padLeft(2, "0");

    return "$hour:$minute";
  }

  TimeOfDay _timeFromString(String? value, TimeOfDay fallback) {
    if (value == null || !value.contains(":")) {
      return fallback;
    }

    final parts = value.split(":");

    if (parts.length != 2) {
      return fallback;
    }

    final hour = int.tryParse(parts[0]);

    final minute = int.tryParse(parts[1]);

    if (hour == null ||
        minute == null ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59) {
      return fallback;
    }

    return TimeOfDay(hour: hour, minute: minute);
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
}
