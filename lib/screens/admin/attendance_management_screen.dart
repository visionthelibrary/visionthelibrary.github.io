import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'student_attendance_history_screen.dart';

class AttendanceManagementScreen extends StatefulWidget {
  const AttendanceManagementScreen({super.key});

  @override
  State<AttendanceManagementScreen> createState() =>
      _AttendanceManagementScreenState();
}

class _AttendanceManagementScreenState
    extends State<AttendanceManagementScreen> {
  DateTime selectedDate = DateTime.now();

  bool showSearchBar = false;

  final TextEditingController searchController = TextEditingController();

  bool showPresent = true;
  bool showAbsent = true;
  bool showBoys = true;
  bool showGirls = true;

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  String _dateId(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _formatTime(dynamic value) {
    if (value is Timestamp) {
      final dateTime = value.toDate();

      final hour = dateTime.hour;
      final minute = dateTime.minute;

      final hour12 = hour == 0
          ? 12
          : hour > 12
          ? hour - 12
          : hour;

      final period = hour >= 12 ? 'PM' : 'AM';

      return '${hour12.toString().padLeft(2, '0')}:'
          '${minute.toString().padLeft(2, '0')} $period';
    }

    return '--:--';
  }

  List<Map<String, dynamic>> _getSessions(Map<String, dynamic> data) {
    final rawSessions = data['sessions'];

    if (rawSessions is List) {
      final List<Map<String, dynamic>> sessions = [];

      for (final item in rawSessions) {
        if (item is Map) {
          sessions.add(Map<String, dynamic>.from(item));
        }
      }

      return sessions;
    }

    // Compatibility with old attendance documents.
    if (data['entryAt'] != null) {
      return [
        {
          'entryAt': data['entryAt'],
          'exitAt': data['exitAt'],
          'autoEntry': data['autoEntry'] == true,
          'autoExit': data['autoExit'] == true,
        },
      ];
    }

    return [];
  }

  bool _isPresent(Map<String, dynamic> data) {
    final status = data['status']?.toString();

    if (status == 'Present' || status == 'Completed') {
      return true;
    }

    final sessions = _getSessions(data);

    return sessions.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    final selectedDateId = _dateId(selectedDate);

    return Scaffold(
      backgroundColor: const Color(0xff0F172A),

      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,

        title: Text(
          'Attendance Management',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          PopupMenuButton<String>(
            color: const Color(0xff1E293B),

            icon: const Icon(Icons.more_vert, color: Colors.white),

            onSelected: (value) {
              if (value == 'search') {
                setState(() {
                  showSearchBar = !showSearchBar;

                  if (!showSearchBar) {
                    searchController.clear();
                  }
                });
              }

              if (value == 'filter') {
                _showFilterDialog(context);
              }
            },

            itemBuilder: (context) {
              return [
                PopupMenuItem<String>(
                  value: 'search',

                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.white),

                      const SizedBox(width: 12),

                      Text(
                        'Search Student',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ],
                  ),
                ),

                PopupMenuItem<String>(
                  value: 'filter',

                  child: Row(
                    children: [
                      const Icon(Icons.filter_list, color: Colors.white),

                      const SizedBox(width: 12),

                      Text(
                        'Filter',
                        style: GoogleFonts.poppins(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ];
            },
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 5, 20, 0),
            child: _buildDateSelector(),
          ),

          if (showSearchBar) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 15, 20, 0),
              child: _buildSearchBar(),
            ),
          ],

          const SizedBox(height: 20),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,

              child: Text(
                'Students Attendance',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

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
                        'Failed to load students.\n'
                        '${snapshot.error}',

                        textAlign: TextAlign.center,

                        style: GoogleFonts.poppins(color: Colors.redAccent),
                      ),
                    ),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Center(
                    child: Text(
                      'No students found',

                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                final searchText = searchController.text.trim().toLowerCase();

                final students = snapshot.data!.docs.where((document) {
                  final data = document.data() as Map<String, dynamic>;

                  final name = (data['name'] ?? '').toString().toLowerCase();

                  final libraryId = (data['libraryId'] ?? document.id)
                      .toString()
                      .toLowerCase();

                  final gender = (data['gender'] ?? '').toString();

                  final matchesSearch =
                      searchText.isEmpty ||
                      name.contains(searchText) ||
                      libraryId.contains(searchText);

                  final matchesGender =
                      (gender == 'Boy' && showBoys) ||
                      (gender == 'Girl' && showGirls);

                  return matchesSearch && matchesGender;
                }).toList();

                if (students.isEmpty) {
                  return Center(
                    child: Text(
                      'No students found',

                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  );
                }

                return ListView.separated(
                  physics: const BouncingScrollPhysics(),

                  padding: const EdgeInsets.fromLTRB(20, 5, 20, 30),

                  itemCount: students.length,

                  separatorBuilder: (context, index) {
                    return const SizedBox(height: 15);
                  },

                  itemBuilder: (context, index) {
                    final document = students[index];

                    final data = document.data() as Map<String, dynamic>;

                    final name = data['name']?.toString() ?? 'Unknown';

                    final libraryId =
                        data['libraryId']?.toString() ?? document.id;

                    final gender = data['gender']?.toString() ?? '';

                    return _buildStudentAttendanceCard(
                      name: name,
                      libraryId: libraryId,
                      gender: gender,
                      selectedDateId: selectedDateId,
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

  Widget _buildDateSelector() {
    return InkWell(
      onTap: () async {
        final DateTime? date = await showDatePicker(
          context: context,

          initialDate: selectedDate,

          firstDate: DateTime(2020),

          lastDate: DateTime(2100),
        );

        if (date == null) {
          return;
        }

        if (!mounted) {
          return;
        }

        setState(() {
          selectedDate = date;
        });
      },

      borderRadius: BorderRadius.circular(18),

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),

          borderRadius: BorderRadius.circular(18),

          border: Border.all(color: Colors.white24),
        ),

        child: Row(
          children: [
            const Icon(Icons.calendar_month, color: Colors.white, size: 28),

            const SizedBox(width: 15),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    'Attendance Date',

                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    '${selectedDate.day.toString().padLeft(2, '0')}/'
                    '${selectedDate.month.toString().padLeft(2, '0')}/'
                    '${selectedDate.year}',

                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(Icons.edit_calendar_outlined, color: Colors.white70),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      controller: searchController,

      autofocus: true,

      onChanged: (value) {
        setState(() {});
      },

      style: GoogleFonts.poppins(color: Colors.white),

      decoration: InputDecoration(
        hintText: 'Search by name or Library ID',

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
    );
  }

  Widget _buildStudentAttendanceCard({
    required String name,
    required String libraryId,
    required String gender,
    required String selectedDateId,
  }) {
    final attendanceStream = FirebaseFirestore.instance
        .collection('attendance')
        .doc(libraryId)
        .collection('days')
        .doc(selectedDateId)
        .snapshots();

    return StreamBuilder<DocumentSnapshot>(
      stream: attendanceStream,

      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildAttendanceCard(
            name: name,
            libraryId: libraryId,
            status: 'Error',
            sessions: const [],
            isLoading: false,
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _buildAttendanceCard(
            name: name,
            libraryId: libraryId,
            status: 'Loading',
            sessions: const [],
            isLoading: true,
          );
        }

        final hasAttendance = snapshot.hasData && snapshot.data!.exists;

        if (!hasAttendance) {
          return _buildAttendanceCard(
            name: name,
            libraryId: libraryId,
            status: 'Absent',
            sessions: const [],
            isLoading: false,
          );
        }

        final rawData = snapshot.data!.data();

        if (rawData is! Map) {
          return _buildAttendanceCard(
            name: name,
            libraryId: libraryId,
            status: 'Absent',
            sessions: const [],
            isLoading: false,
          );
        }

        final data = Map<String, dynamic>.from(rawData);

        final isPresent = _isPresent(data);

        final sessions = _getSessions(data);

        return _buildAttendanceCard(
          name: name,
          libraryId: libraryId,
          status: isPresent ? 'Present' : 'Absent',
          sessions: sessions,
          isLoading: false,
        );
      },
    );
  }

  Widget _buildAttendanceCard({
    required String name,
    required String libraryId,
    required String status,
    required List<Map<String, dynamic>> sessions,
    required bool isLoading,
  }) {
    final isPresent = status == 'Present';

    final isError = status == 'Error';

    final isLoadingStatus = status == 'Loading';

    if (!showPresent && isPresent) {
      return const SizedBox.shrink();
    }

    if (!showAbsent && !isPresent) {
      return const SizedBox.shrink();
    }

    return InkWell(
      onTap: isLoadingStatus || isError
          ? null
          : () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => StudentAttendanceHistoryScreen(
                    name: name,
                    libraryId: libraryId,
                  ),
                ),
              );
            },

      borderRadius: BorderRadius.circular(20),

      child: Container(
        width: double.infinity,

        padding: const EdgeInsets.all(18),

        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),

          borderRadius: BorderRadius.circular(20),

          border: Border.all(color: Colors.white24),
        ),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 25,

                  backgroundColor: Colors.white24,

                  child: Icon(Icons.person, color: Colors.white, size: 30),
                ),

                const SizedBox(width: 14),

                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [
                      Text(
                        name,

                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 2),

                      Text(
                        libraryId,

                        style: GoogleFonts.poppins(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                if (isLoading)
                  const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  _statusBadge(status),
              ],
            ),

            if (!isLoading && !isError && isPresent && sessions.isNotEmpty) ...[
              const SizedBox(height: 18),

              Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),

              const SizedBox(height: 15),

              Text(
                'Sessions: ${sessions.length} / 3',

                style: GoogleFonts.poppins(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 12),

              ...List.generate(sessions.length, (index) {
                final session = sessions[index];

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),

                  child: _buildSessionRow(
                    sessionNumber: index + 1,

                    entryAt: session['entryAt'],

                    exitAt: session['exitAt'],
                  ),
                );
              }),
            ],

            if (!isLoading && !isError && isPresent && sessions.isEmpty) ...[
              const SizedBox(height: 12),

              Text(
                'Attendance marked.',
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
              ),
            ],

            if (!isLoading && !isError && !isPresent) ...[
              const SizedBox(height: 12),

              Text(
                'No attendance recorded for this date.',

                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
              ),
            ],

            if (isError) ...[
              const SizedBox(height: 12),

              Text(
                'Failed to load attendance.',

                style: GoogleFonts.poppins(
                  color: Colors.redAccent,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final isPresent = status == 'Present';

    final color = isPresent
        ? Colors.greenAccent
        : status == 'Error'
        ? Colors.redAccent
        : Colors.orangeAccent;

    final backgroundColor = isPresent
        ? Colors.green.withValues(alpha: 0.20)
        : status == 'Error'
        ? Colors.red.withValues(alpha: 0.20)
        : Colors.orange.withValues(alpha: 0.20);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

      decoration: BoxDecoration(
        color: backgroundColor,

        borderRadius: BorderRadius.circular(20),
      ),

      child: Text(
        status,

        style: GoogleFonts.poppins(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildSessionRow({
    required int sessionNumber,
    required dynamic entryAt,
    required dynamic exitAt,
  }) {
    final hasExit = exitAt != null;

    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),

        borderRadius: BorderRadius.circular(12),
      ),

      child: Row(
        children: [
          Container(
            height: 32,
            width: 32,

            alignment: Alignment.center,

            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.20),

              borderRadius: BorderRadius.circular(10),
            ),

            child: Text(
              '$sessionNumber',

              style: GoogleFonts.poppins(
                color: Colors.blueAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  'IN',

                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),

                Text(
                  _formatTime(entryAt),

                  style: GoogleFonts.poppins(
                    color: Colors.greenAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),

          const Icon(Icons.arrow_forward, color: Colors.white38, size: 18),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,

              children: [
                Text(
                  'OUT',

                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),

                Text(
                  hasExit ? _formatTime(exitAt) : 'Active',

                  style: GoogleFonts.poppins(
                    color: hasExit ? Colors.orangeAccent : Colors.blueAccent,

                    fontSize: 13,

                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

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
                'Filter Attendance',

                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,

                children: [
                  CheckboxListTile(
                    value: showPresent,

                    title: const Text(
                      'Present',
                      style: TextStyle(color: Colors.white),
                    ),

                    onChanged: (value) {
                      setDialogState(() {
                        showPresent = value ?? true;
                      });
                    },
                  ),

                  CheckboxListTile(
                    value: showAbsent,

                    title: const Text(
                      'Absent',
                      style: TextStyle(color: Colors.white),
                    ),

                    onChanged: (value) {
                      setDialogState(() {
                        showAbsent = value ?? true;
                      });
                    },
                  ),

                  CheckboxListTile(
                    value: showBoys,

                    title: const Text(
                      'Boys',
                      style: TextStyle(color: Colors.white),
                    ),

                    onChanged: (value) {
                      setDialogState(() {
                        showBoys = value ?? true;
                      });
                    },
                  ),

                  CheckboxListTile(
                    value: showGirls,

                    title: const Text(
                      'Girls',
                      style: TextStyle(color: Colors.white),
                    ),

                    onChanged: (value) {
                      setDialogState(() {
                        showGirls = value ?? true;
                      });
                    },
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.pop(dialogContext);
                  },

                  child: Text(
                    'APPLY',

                    style: GoogleFonts.poppins(
                      color: Colors.blueAccent,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
