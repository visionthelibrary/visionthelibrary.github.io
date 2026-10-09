import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AddStudentScreen extends StatefulWidget {
  const AddStudentScreen({super.key});

  @override
  State<AddStudentScreen> createState() => _AddStudentScreenState();
}

class _AddStudentScreenState extends State<AddStudentScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController libraryIdController = TextEditingController();
  final TextEditingController pinController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController seatController = TextEditingController();

  String selectedSeatPrefix = "B-";
  String? selectedGender;

  bool morningShift = false;
  bool dayShift = false;
  bool eveningShift = false;
  bool nightShift = false;

  String selectedMembership = "Active";

  DateTime? dateOfBirth;
  DateTime? joiningDate;
  DateTime? validTill;

  bool isSaving = false;

  @override
  void dispose() {
    nameController.dispose();
    libraryIdController.dispose();
    pinController.dispose();
    phoneController.dispose();
    emailController.dispose();
    addressController.dispose();
    seatController.dispose();
    super.dispose();
  }

  DateTime _todayOnly() {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  bool _isValidMembershipDate() {
    if (selectedMembership != "Active") {
      return true;
    }

    if (validTill == null) {
      return false;
    }

    final today = _todayOnly();

    final selectedDate = DateTime(
      validTill!.year,
      validTill!.month,
      validTill!.day,
    );

    return !selectedDate.isBefore(today);
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
          "Add Student",
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
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            _sectionTitle("Personal Information"),

            const SizedBox(height: 15),

            _textField(
              controller: nameController,
              label: "Full Name",
              icon: Icons.person_outline,
            ),

            const SizedBox(height: 15),

            _textField(
              controller: phoneController,
              label: "Mobile Number",
              icon: Icons.phone_outlined,
              keyboardType: TextInputType.phone,
            ),

            const SizedBox(height: 15),

            _textField(
              controller: emailController,
              label: "Email Address",
              icon: Icons.email_outlined,
            ),

            const SizedBox(height: 15),

            _textField(
              controller: addressController,
              label: "Address",
              icon: Icons.home_outlined,
            ),

            const SizedBox(height: 15),

            _dropdownField(
              value: selectedGender,
              label: "Gender",
              icon: Icons.people_outline,
              items: const ["Boy", "Girl"],
              onChanged: (value) {
                setState(() {
                  selectedGender = value;
                });
              },
            ),

            const SizedBox(height: 15),

            _dateField(
              title: "Date of Birth",
              date: dateOfBirth,
              icon: Icons.cake_outlined,

              onTap: () async {
                final selectedDate = await _selectDate(
                  context,
                  initialDate: dateOfBirth,
                  firstDate: DateTime(1950),
                  lastDate: DateTime.now(),
                );

                if (selectedDate != null) {
                  setState(() {
                    dateOfBirth = selectedDate;
                  });
                }
              },
            ),

            const SizedBox(height: 30),

            _sectionTitle("Library Information"),

            const SizedBox(height: 15),

            _textField(
              controller: libraryIdController,
              label: "Library ID",
              icon: Icons.badge_outlined,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                UpperCaseTextFormatter(),
              ],
            ),

            const SizedBox(height: 15),

            _textField(
              controller: pinController,
              label: "4-Digit PIN",
              icon: Icons.pin_outlined,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
            ),

            const SizedBox(height: 15),

            Row(
              children: [
                SizedBox(
                  width: 100,

                  child: DropdownButtonFormField<String>(
                    initialValue: selectedSeatPrefix,

                    dropdownColor: const Color(0xff1E293B),

                    style: GoogleFonts.poppins(color: Colors.white),

                    decoration: InputDecoration(
                      filled: true,

                      fillColor: Colors.white.withValues(alpha: 0.10),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),

                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                    ),

                    items: const [
                      DropdownMenuItem(value: "B-", child: Text("B-")),
                      DropdownMenuItem(value: "G-", child: Text("G-")),
                    ],

                    onChanged: (value) {
                      setState(() {
                        selectedSeatPrefix = value ?? "B-";
                      });
                    },
                  ),
                ),

                const SizedBox(width: 10),

                Expanded(
                  child: TextField(
                    controller: seatController,

                    keyboardType: TextInputType.number,

                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],

                    style: GoogleFonts.poppins(color: Colors.white),

                    decoration: InputDecoration(
                      labelText: "Seat Number",

                      labelStyle: const TextStyle(color: Colors.white70),

                      filled: true,

                      fillColor: Colors.white.withValues(alpha: 0.10),

                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 15),

            Container(
              width: double.infinity,

              padding: const EdgeInsets.all(15),

              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.10),

                borderRadius: BorderRadius.circular(15),

                border: Border.all(color: Colors.white24),
              ),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.schedule_outlined,
                        color: Colors.white70,
                      ),

                      const SizedBox(width: 12),

                      Text(
                        "Select Shift",

                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  CheckboxListTile(
                    value: morningShift,

                    title: const Text(
                      "Morning",
                      style: TextStyle(color: Colors.white),
                    ),

                    contentPadding: EdgeInsets.zero,

                    onChanged: (value) {
                      setState(() {
                        morningShift = value ?? false;
                      });
                    },
                  ),

                  CheckboxListTile(
                    value: dayShift,

                    title: const Text(
                      "Day",
                      style: TextStyle(color: Colors.white),
                    ),

                    contentPadding: EdgeInsets.zero,

                    onChanged: (value) {
                      setState(() {
                        dayShift = value ?? false;
                      });
                    },
                  ),

                  CheckboxListTile(
                    value: eveningShift,

                    title: const Text(
                      "Evening",
                      style: TextStyle(color: Colors.white),
                    ),

                    contentPadding: EdgeInsets.zero,

                    onChanged: (value) {
                      setState(() {
                        eveningShift = value ?? false;
                      });
                    },
                  ),

                  CheckboxListTile(
                    value: nightShift,

                    title: const Text(
                      "Night",
                      style: TextStyle(color: Colors.white),
                    ),

                    contentPadding: EdgeInsets.zero,

                    onChanged: (value) {
                      setState(() {
                        nightShift = value ?? false;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            _dateField(
              title: "Joining Date",
              date: joiningDate,
              icon: Icons.calendar_today_outlined,

              onTap: () async {
                final selectedDate = await _selectDate(
                  context,
                  initialDate: joiningDate,
                  firstDate: DateTime(1950),
                  lastDate: DateTime(2100),
                );

                if (selectedDate != null) {
                  setState(() {
                    joiningDate = selectedDate;
                  });
                }
              },
            ),

            const SizedBox(height: 15),

            _dropdownField(
              value: selectedMembership,
              label: "Membership Status",
              icon: Icons.verified_user_outlined,

              items: const ["Active", "Inactive"],

              onChanged: (value) {
                setState(() {
                  selectedMembership = value ?? "Active";

                  // Inactive membership
                  // must not have a Valid Till date.
                  if (selectedMembership == "Inactive") {
                    validTill = null;
                  }
                });
              },
            ),

            // Valid Till is shown ONLY for Active membership.
            if (selectedMembership == "Active") ...[
              const SizedBox(height: 15),

              _dateField(
                title: "Valid Till",
                date: validTill,
                icon: Icons.event_available_outlined,

                onTap: () async {
                  final selectedDate = await _selectDate(
                    context,
                    initialDate: validTill ?? DateTime.now(),
                    firstDate: DateTime.now(),
                    lastDate: DateTime(2100),
                  );

                  if (selectedDate != null) {
                    setState(() {
                      validTill = selectedDate;
                    });
                  }
                },
              ),
            ],

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              height: 55,

              child: ElevatedButton.icon(
                onPressed: isSaving ? null : _addStudent,

                icon: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,

                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.person_add_alt_1),

                label: Text(
                  isSaving ? "ADDING..." : "ADD STUDENT",

                  style: GoogleFonts.poppins(
                    fontSize: 16,
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

  Future<void> _addStudent() async {
    final name = nameController.text.trim();

    final libraryId = libraryIdController.text.trim().toUpperCase();

    final pin = pinController.text.trim();

    // Basic required validation.
    if (name.isEmpty ||
        libraryId.isEmpty ||
        pin.length != 4 ||
        selectedGender == null) {
      _showMessage("Please fill all required fields correctly", Colors.red);

      return;
    }

    // Active membership requires Valid Till.
    if (selectedMembership == "Active" && validTill == null) {
      _showMessage(
        "Please select Valid Till date for Active membership",
        Colors.red,
      );

      return;
    }

    // Active membership cannot have an expired date.
    if (!_isValidMembershipDate()) {
      _showMessage("Valid Till date cannot be before today", Colors.red);

      return;
    }

    // Inactive membership must not contain a date.
    if (selectedMembership == "Inactive") {
      validTill = null;
    }

    setState(() {
      isSaving = true;
    });

    try {
      final studentRef = FirebaseFirestore.instance
          .collection('students')
          .doc(libraryId);

      final existingStudent = await studentRef.get();

      if (existingStudent.exists) {
        if (!mounted) return;

        _showMessage("This Library ID already exists", Colors.red);

        setState(() {
          isSaving = false;
        });

        return;
      }

      await studentRef.set({
        'name': name,

        'libraryId': libraryId,

        'pin': pin,

        'phone': phoneController.text.trim(),

        'email': emailController.text.trim(),

        'address': addressController.text.trim(),

        'gender': selectedGender,

        'dateOfBirth': dateOfBirth != null
            ? Timestamp.fromDate(dateOfBirth!)
            : null,

        'seatPrefix': selectedSeatPrefix,

        'seatNumber': seatController.text.trim(),

        'seat': '$selectedSeatPrefix${seatController.text.trim()}',

        'shifts': {
          'morning': morningShift,
          'day': dayShift,
          'evening': eveningShift,
          'night': nightShift,
        },

        'joiningDate': joiningDate != null
            ? Timestamp.fromDate(joiningDate!)
            : null,

        'membershipStatus': selectedMembership,

        // Inactive → null
        // Active → selected Valid Till
        'validTill': selectedMembership == "Active" && validTill != null
            ? Timestamp.fromDate(validTill!)
            : null,

        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;

      _showMessage("Student Added Successfully", Colors.green);

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      _showMessage("Failed to add student: $e", Colors.red);
    }
  }

  void _showMessage(String message, Color color) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message), backgroundColor: color));
  }

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

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,

      keyboardType: keyboardType,

      inputFormatters: inputFormatters,

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

  Widget _dropdownField({
    required String? value,
    required String label,
    required IconData icon,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,

      dropdownColor: const Color(0xff1E293B),

      style: GoogleFonts.poppins(color: Colors.white),

      iconEnabledColor: Colors.white70,

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

      items: items.map((item) {
        return DropdownMenuItem<String>(value: item, child: Text(item));
      }).toList(),

      onChanged: onChanged,
    );
  }

  Widget _dateField({
    required String title,
    required DateTime? date,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,

      borderRadius: BorderRadius.circular(15),

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 18),

        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),

          borderRadius: BorderRadius.circular(15),

          border: Border.all(color: Colors.white24),
        ),

        child: Row(
          children: [
            Icon(icon, color: Colors.white70),

            const SizedBox(width: 12),

            Expanded(
              child: Text(
                date == null
                    ? title
                    : '${date.day.toString().padLeft(2, '0')}/'
                          '${date.month.toString().padLeft(2, '0')}/'
                          '${date.year}',

                style: GoogleFonts.poppins(
                  color: date == null ? Colors.white70 : Colors.white,

                  fontSize: 15,
                ),
              ),
            ),

            const Icon(Icons.calendar_month, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Future<DateTime?> _selectDate(
    BuildContext context, {
    DateTime? initialDate,
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final today = _todayOnly();

    DateTime safeInitial = initialDate ?? today;

    final safeFirst = firstDate ?? DateTime(1950);

    final safeLast = lastDate ?? DateTime(2100);

    if (safeInitial.isBefore(safeFirst)) {
      safeInitial = safeFirst;
    }

    if (safeInitial.isAfter(safeLast)) {
      safeInitial = safeLast;
    }

    return showDatePicker(
      context: context,

      initialDate: safeInitial,

      firstDate: safeFirst,

      lastDate: safeLast,
    );
  }
}

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
