import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditStudentScreen extends StatefulWidget {
  final String libraryId;

  const EditStudentScreen({super.key, required this.libraryId});

  @override
  State<EditStudentScreen> createState() => _EditStudentScreenState();
}

class _EditStudentScreenState extends State<EditStudentScreen> {
  final TextEditingController nameController = TextEditingController();

  final TextEditingController libraryIdController = TextEditingController();

  final TextEditingController pinController = TextEditingController();

  final TextEditingController phoneController = TextEditingController();

  final TextEditingController emailController = TextEditingController();

  final TextEditingController addressController = TextEditingController();

  final TextEditingController seatController = TextEditingController();

  String selectedGender = "Boy";
  String selectedSeatPrefix = "B-";
  String selectedMembership = "Active";

  bool morningShift = false;
  bool dayShift = false;
  bool eveningShift = false;
  bool nightShift = false;

  DateTime? dateOfBirth;
  DateTime? joiningDate;
  DateTime? validTill;

  bool isLoading = true;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  DateTime? _timestampToDate(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }

    return null;
  }

  DateTime _todayOnly() {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  bool _isDateExpired(DateTime date) {
    final today = _todayOnly();

    final selectedDate = DateTime(date.year, date.month, date.day);

    return selectedDate.isBefore(today);
  }

  Future<void> _loadStudentData() async {
    try {
      final document = await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.libraryId)
          .get();

      if (!document.exists) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Student not found"),
            backgroundColor: Colors.red,
          ),
        );

        Navigator.pop(context);
        return;
      }

      final data = document.data()!;

      nameController.text = data['name']?.toString() ?? "";

      libraryIdController.text =
          data['libraryId']?.toString() ?? widget.libraryId;

      pinController.text = data['pin']?.toString() ?? "";

      phoneController.text = data['phone']?.toString() ?? "";

      emailController.text = data['email']?.toString() ?? "";

      addressController.text = data['address']?.toString() ?? "";

      selectedGender = data['gender']?.toString() ?? "Boy";

      selectedMembership = data['membershipStatus']?.toString() ?? "Active";

      selectedSeatPrefix = data['seatPrefix']?.toString() ?? "B-";

      seatController.text = data['seatNumber']?.toString() ?? "";

      final shiftData = data['shifts'];

      if (shiftData is Map) {
        final shifts = Map<String, dynamic>.from(shiftData);

        morningShift = shifts['morning'] == true;

        dayShift = shifts['day'] == true;

        eveningShift = shifts['evening'] == true;

        nightShift = shifts['night'] == true;
      }

      dateOfBirth = _timestampToDate(data['dateOfBirth']);

      joiningDate = _timestampToDate(data['joiningDate']);

      validTill = _timestampToDate(data['validTill']);

      // If membership is already inactive,
      // there should be no Valid Till date.
      if (selectedMembership == "Inactive") {
        validTill = null;
      }

      // Automatically expire an Active membership
      // when Valid Till has passed.
      if (selectedMembership == "Active" &&
          validTill != null &&
          _isDateExpired(validTill!)) {
        selectedMembership = "Inactive";
        validTill = null;

        await FirebaseFirestore.instance
            .collection('students')
            .doc(widget.libraryId)
            .update({
              'membershipStatus': 'Inactive',
              'validTill': null,
              'updatedAt': FieldValue.serverTimestamp(),
            });
      }

      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to load student: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  bool _isValidMembership() {
    if (selectedMembership == "Inactive") {
      return true;
    }

    if (validTill == null) {
      return false;
    }

    return !_isDateExpired(validTill!);
  }

  Future<void> _updateStudent() async {
    if (nameController.text.trim().isEmpty ||
        pinController.text.trim().length != 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill all required fields correctly"),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    // Active membership requires Valid Till.
    if (selectedMembership == "Active" && validTill == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please select Valid Till date for Active membership"),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    // Active membership cannot have an expired date.
    if (!_isValidMembership()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Valid Till date cannot be before today"),
          backgroundColor: Colors.red,
        ),
      );

      return;
    }

    // Inactive membership must not have Valid Till.
    if (selectedMembership == "Inactive") {
      validTill = null;
    }

    setState(() {
      isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection('students')
          .doc(widget.libraryId)
          .update({
            'name': nameController.text.trim(),

            'pin': pinController.text.trim(),

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

            // Active → selected date
            // Inactive → null
            'validTill': selectedMembership == "Active" && validTill != null
                ? Timestamp.fromDate(validTill!)
                : null,

            'updatedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Student Updated Successfully"),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to update student: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F172A),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,

        title: Text(
          "Edit Student",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
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
                        selectedGender = value ?? "Boy";
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
                        dateOfBirth,
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
                    readOnly: true,
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

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),

                              borderSide: const BorderSide(
                                color: Colors.white24,
                              ),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),

                              borderSide: const BorderSide(color: Colors.blue),
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

                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],

                          style: GoogleFonts.poppins(color: Colors.white),

                          decoration: InputDecoration(
                            labelText: "Seat Number",

                            labelStyle: const TextStyle(color: Colors.white70),

                            filled: true,

                            fillColor: Colors.white.withValues(alpha: 0.10),

                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),

                              borderSide: const BorderSide(
                                color: Colors.white24,
                              ),
                            ),

                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),

                              borderSide: const BorderSide(color: Colors.blue),
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

                        _shiftCheckbox("Morning", morningShift, (value) {
                          setState(() {
                            morningShift = value ?? false;
                          });
                        }),

                        _shiftCheckbox("Day", dayShift, (value) {
                          setState(() {
                            dayShift = value ?? false;
                          });
                        }),

                        _shiftCheckbox("Evening", eveningShift, (value) {
                          setState(() {
                            eveningShift = value ?? false;
                          });
                        }),

                        _shiftCheckbox("Night", nightShift, (value) {
                          setState(() {
                            nightShift = value ?? false;
                          });
                        }),
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
                        joiningDate,
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

                        // Inactive means
                        // no Valid Till date.
                        if (selectedMembership == "Inactive") {
                          validTill = null;
                        }
                      });
                    },
                  ),

                  // Valid Till is shown
                  // only for Active membership.
                  if (selectedMembership == "Active") ...[
                    const SizedBox(height: 15),

                    _dateField(
                      title: "Valid Till",
                      date: validTill,
                      icon: Icons.event_available_outlined,

                      onTap: () async {
                        final selectedDate = await _selectDate(
                          context,
                          validTill ?? DateTime.now(),
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
                      onPressed: isSaving ? null : _updateStudent,

                      icon: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,

                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),

                      label: Text(
                        isSaving ? "UPDATING..." : "UPDATE STUDENT",

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

    bool readOnly = false,
  }) {
    return TextField(
      controller: controller,

      keyboardType: keyboardType,

      inputFormatters: inputFormatters,

      readOnly: readOnly,

      style: GoogleFonts.poppins(
        color: readOnly ? Colors.white60 : Colors.white,
      ),

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

  Widget _shiftCheckbox(
    String title,

    bool value,

    ValueChanged<bool?> onChanged,
  ) {
    return CheckboxListTile(
      value: value,

      onChanged: onChanged,

      contentPadding: EdgeInsets.zero,

      activeColor: Colors.blue,

      checkColor: Colors.white,

      title: Text(
        title,

        style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
      ),
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
    BuildContext context,
    DateTime? currentDate, {
    DateTime? firstDate,
    DateTime? lastDate,
  }) async {
    final safeFirstDate = firstDate ?? DateTime(1950);

    final safeLastDate = lastDate ?? DateTime(2100);

    DateTime initialDate = currentDate ?? DateTime.now();

    if (initialDate.isBefore(safeFirstDate)) {
      initialDate = safeFirstDate;
    }

    if (initialDate.isAfter(safeLastDate)) {
      initialDate = safeLastDate;
    }

    return showDatePicker(
      context: context,

      initialDate: initialDate,

      firstDate: safeFirstDate,

      lastDate: safeLastDate,
    );
  }
}
