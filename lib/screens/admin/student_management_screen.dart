import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'add_student_screen.dart';
import 'student_details_screen.dart';
import '../../services/membership_service.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() =>
      _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  bool showBoys = true;
  bool showGirls = true;
  bool showSearchBar = false;

  // ============================================================
  // MEMBERSHIP FILTER
  // ============================================================

  bool showActiveMembership = true;
  bool showInactiveMembership = true;

  final TextEditingController searchController = TextEditingController();

  // Students whose membership has already been checked
  // during the current screen session.
  final Set<String> _membershipCheckedIds = {};

  // Prevent duplicate checks while one check is running.
  final Set<String> _membershipCheckInProgress = {};

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _checkMemberships(List<QueryDocumentSnapshot> documents) async {
    for (final document in documents) {
      final data = document.data() as Map<String, dynamic>;

      final libraryId = (data['libraryId'] ?? document.id).toString().trim();

      if (libraryId.isEmpty) {
        continue;
      }

      if (_membershipCheckedIds.contains(libraryId)) {
        continue;
      }

      if (_membershipCheckInProgress.contains(libraryId)) {
        continue;
      }

      _membershipCheckInProgress.add(libraryId);

      try {
        await MembershipService.checkAndUpdateMembership(libraryId);

        _membershipCheckedIds.add(libraryId);
      } finally {
        _membershipCheckInProgress.remove(libraryId);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xff0F172A),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        title: Text(
          "Student Management",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.white),

            color: const Color(0xff1E293B),

            onSelected: (value) {
              if (value == "search") {
                setState(() {
                  showSearchBar = !showSearchBar;

                  if (!showSearchBar) {
                    searchController.clear();
                  }
                });
              }

              if (value == "add") {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddStudentScreen(),
                  ),
                );
              }

              if (value == "filter") {
                _showFilterDialog(context);
              }
            },

            itemBuilder: (context) => [
              PopupMenuItem(
                value: "search",

                child: Row(
                  children: [
                    const Icon(Icons.search, color: Colors.white),

                    const SizedBox(width: 12),

                    Text(
                      "Search Student",
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ],
                ),
              ),

              PopupMenuItem(
                value: "add",

                child: Row(
                  children: [
                    const Icon(Icons.person_add_alt_1, color: Colors.white),

                    const SizedBox(width: 12),

                    Text(
                      "Add Student",
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ],
                ),
              ),

              PopupMenuItem(
                value: "filter",

                child: Row(
                  children: [
                    const Icon(Icons.filter_list, color: Colors.white),

                    const SizedBox(width: 12),

                    Text(
                      "Filter",
                      style: GoogleFonts.poppins(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          if (showSearchBar)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 5),

              child: TextField(
                controller: searchController,

                autofocus: true,

                style: GoogleFonts.poppins(color: Colors.white),

                onChanged: (value) {
                  setState(() {});
                },

                decoration: InputDecoration(
                  hintText: "Search by name or Library ID",

                  hintStyle: GoogleFonts.poppins(color: Colors.white54),

                  prefixIcon: const Icon(Icons.search, color: Colors.white70),

                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        searchController.clear();

                        showSearchBar = false;
                      });
                    },

                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),

                  filled: true,

                  fillColor: Colors.white.withValues(alpha: 0.10),

                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),

                    borderSide: const BorderSide(color: Colors.white24),
                  ),

                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),

                    borderSide: const BorderSide(color: Colors.blue),
                  ),
                ),
              ),
            ),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('students')
                  .snapshots(),

              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),

                      child: Text(
                        "Failed to load students.\n"
                        "${snapshot.error}",

                        textAlign: TextAlign.center,

                        style: GoogleFonts.poppins(color: Colors.redAccent),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData) {
                  return Center(
                    child: Text(
                      "No students found",

                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),
                  );
                }

                final documents = snapshot.data!.docs;

                if (documents.isEmpty) {
                  return Center(
                    child: Text(
                      "No students found",

                      style: GoogleFonts.poppins(color: Colors.white70),
                    ),
                  );
                }

                // Check membership expiry once
                // for each student in this screen session.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }

                  _checkMemberships(documents);
                });

                final searchText = searchController.text.trim().toLowerCase();

                final students = documents.where((document) {
                  final data = document.data() as Map<String, dynamic>;

                  final name = (data['name'] ?? '').toString().toLowerCase();

                  final libraryId = (data['libraryId'] ?? document.id)
                      .toString()
                      .toLowerCase();

                  final gender = (data['gender'] ?? '').toString();

                  final membershipStatus =
                      (data['membershipStatus'] ?? 'Inactive').toString();

                  // ==========================================
                  // SEARCH FILTER
                  // ==========================================

                  final matchesSearch =
                      searchText.isEmpty ||
                      name.contains(searchText) ||
                      libraryId.contains(searchText);

                  // ==========================================
                  // GENDER FILTER
                  // ==========================================

                  final matchesGender =
                      (gender == "Boy" && showBoys) ||
                      (gender == "Girl" && showGirls);

                  // ==========================================
                  // MEMBERSHIP FILTER
                  //
                  // Both selected  -> All
                  // Both unselected -> All
                  // Active only -> Active
                  // Inactive only -> Inactive
                  // ==========================================

                  final bool noMembershipSelected =
                      !showActiveMembership && !showInactiveMembership;

                  final bool matchesMembership =
                      noMembershipSelected ||
                      (membershipStatus == "Active" && showActiveMembership) ||
                      (membershipStatus == "Inactive" &&
                          showInactiveMembership);

                  return matchesSearch && matchesGender && matchesMembership;
                }).toList();

                if (students.isEmpty) {
                  return Center(
                    child: Text(
                      "No students found",

                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(20),

                  itemCount: students.length,

                  separatorBuilder: (context, index) {
                    return const SizedBox(height: 15);
                  },

                  itemBuilder: (context, index) {
                    final document = students[index];

                    final data = document.data() as Map<String, dynamic>;

                    final String name = data['name']?.toString() ?? "Unknown";

                    final String libraryId =
                        data['libraryId']?.toString() ?? document.id;

                    final String seat = data['seat']?.toString() ?? "-";

                    final String status =
                        data['membershipStatus']?.toString() ?? "Inactive";

                    final String gender = data['gender']?.toString() ?? "";

                    final Map<String, dynamic> shifts = data['shifts'] is Map
                        ? Map<String, dynamic>.from(data['shifts'])
                        : {};

                    final List<String> selectedShifts = [];

                    if (shifts['morning'] == true) {
                      selectedShifts.add("Morning");
                    }

                    if (shifts['day'] == true) {
                      selectedShifts.add("Day");
                    }

                    if (shifts['evening'] == true) {
                      selectedShifts.add("Evening");
                    }

                    if (shifts['night'] == true) {
                      selectedShifts.add("Night");
                    }

                    final String shift = selectedShifts.isEmpty
                        ? "-"
                        : selectedShifts.join(", ");

                    return _studentCard(
                      name: name,
                      libraryId: libraryId,
                      seat: seat,
                      shift: shift,
                      status: status,
                      gender: gender,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _studentCard({
    required String name,
    required String libraryId,
    required String seat,
    required String shift,
    required String status,
    required String gender,
  }) {
    final bool isActive = status == "Active";

    return Container(
      width: double.infinity,

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.white24),
      ),

      child: InkWell(
        borderRadius: BorderRadius.circular(20),

        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => StudentDetailsScreen(libraryId: libraryId),
            ),
          );
        },

        child: Padding(
          padding: const EdgeInsets.all(18),

          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              CircleAvatar(
                radius: 27,

                backgroundColor: Colors.white24,

                child: Icon(
                  gender == "Girl" ? Icons.person_2 : Icons.person,

                  color: Colors.white,

                  size: 32,
                ),
              ),

              const SizedBox(width: 15),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      name,

                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Text(
                      libraryId,

                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 14),

                    Text(
                      "Seat: $seat",

                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      "Shift: $shift",

                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      "Status: $status",

                      style: GoogleFonts.poppins(
                        color: isActive ? Colors.greenAccent : Colors.redAccent,

                        fontSize: 13,

                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
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
      ),
    );
  }

  // ============================================================
  // FILTER DIALOG
  // ============================================================

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,

      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xff1E293B),

              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),

              title: Text(
                "Filter Students",

                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  // ==================================================
                  // GENDER
                  // ==================================================
                  CheckboxListTile(
                    value: showBoys,

                    activeColor: Colors.blue,

                    checkColor: Colors.white,

                    contentPadding: EdgeInsets.zero,

                    title: Text(
                      "Boys",

                      style: GoogleFonts.poppins(color: Colors.white),
                    ),

                    onChanged: (value) {
                      setDialogState(() {
                        showBoys = value ?? true;
                      });

                      setState(() {});
                    },
                  ),

                  CheckboxListTile(
                    value: showGirls,

                    activeColor: Colors.blue,

                    checkColor: Colors.white,

                    contentPadding: EdgeInsets.zero,

                    title: Text(
                      "Girls",

                      style: GoogleFonts.poppins(color: Colors.white),
                    ),

                    onChanged: (value) {
                      setDialogState(() {
                        showGirls = value ?? true;
                      });

                      setState(() {});
                    },
                  ),

                  const Divider(color: Colors.white24, height: 20),

                  // ==================================================
                  // MEMBERSHIP
                  // ==================================================
                  Align(
                    alignment: Alignment.centerLeft,

                    child: Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        top: 5,
                        bottom: 5,
                      ),

                      child: Text(
                        "Membership",

                        style: GoogleFonts.poppins(
                          color: Colors.white70,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  CheckboxListTile(
                    value: showActiveMembership,

                    activeColor: Colors.green,

                    checkColor: Colors.white,

                    contentPadding: EdgeInsets.zero,

                    title: Text(
                      "Active",

                      style: GoogleFonts.poppins(color: Colors.white),
                    ),

                    onChanged: (value) {
                      setDialogState(() {
                        showActiveMembership = value ?? false;
                      });

                      setState(() {});
                    },
                  ),

                  CheckboxListTile(
                    value: showInactiveMembership,

                    activeColor: Colors.redAccent,

                    checkColor: Colors.white,

                    contentPadding: EdgeInsets.zero,

                    title: Text(
                      "Inactive",

                      style: GoogleFonts.poppins(color: Colors.white),
                    ),

                    onChanged: (value) {
                      setDialogState(() {
                        showInactiveMembership = value ?? false;
                      });

                      setState(() {});
                    },
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },

                  child: const Text("Done"),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
