import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/report_export_service.dart';

class StudentReportScreen extends StatefulWidget {
  const StudentReportScreen({super.key});

  @override
  State<StudentReportScreen> createState() => _StudentReportScreenState();
}

class _StudentReportScreenState extends State<StudentReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool isLoadingStudents = true;
  bool isLoadingReport = false;
  bool isExporting = false;

  List<_StudentItem> students = [];

  String? selectedLibraryId;

  DateTime selectedMonth = DateTime.now();

  _StudentMonthlyData? report;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  // ============================================================
  // LOAD STUDENTS
  // ============================================================

  Future<void> _loadStudents() async {
    try {
      final snapshot = await _firestore.collection('students').get();

      final loadedStudents = <_StudentItem>[];

      for (final doc in snapshot.docs) {
        final data = doc.data();

        final libraryId = data['libraryId']?.toString() ?? doc.id;

        loadedStudents.add(
          _StudentItem(
            libraryId: libraryId,
            name: data['name']?.toString() ?? 'Student',
            gender: data['gender']?.toString() ?? '-',
            seat: data['seat']?.toString() ?? '-',
          ),
        );
      }

      loadedStudents.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      if (!mounted) return;

      setState(() {
        students = loadedStudents;
        isLoadingStudents = false;

        if (students.isNotEmpty) {
          selectedLibraryId = students.first.libraryId;
        }
      });

      if (selectedLibraryId != null) {
        await _loadStudentReport();
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingStudents = false;
      });

      _showMessage('Failed to load students.');
    }
  }

  // ============================================================
  // LOAD MONTHLY STUDENT REPORT
  // ============================================================

  Future<void> _loadStudentReport() async {
    final libraryId = selectedLibraryId;

    if (libraryId == null) {
      return;
    }

    setState(() {
      isLoadingReport = true;
      report = null;
    });

    try {
      final studentDoc = await _firestore
          .collection('students')
          .doc(libraryId)
          .get();

      final studentData = studentDoc.data();

      final student = _StudentItem(
        libraryId: libraryId,
        name: studentData?['name']?.toString() ?? 'Student',
        gender: studentData?['gender']?.toString() ?? '-',
        seat: studentData?['seat']?.toString() ?? '-',
      );

      final startDate = DateTime(selectedMonth.year, selectedMonth.month, 1);

      final endDate = _getEndDate();

      final attendanceSnapshot = await _firestore
          .collection('attendance')
          .doc(libraryId)
          .collection('days')
          .get();

      final Map<String, Map<String, dynamic>> attendanceByDate = {};

      for (final doc in attendanceSnapshot.docs) {
        final data = doc.data();

        final date = data['date']?.toString() ?? doc.id;

        attendanceByDate[date] = data;
      }

      final dailyRecords = <_StudentDayRecord>[];

      DateTime current = startDate;

      while (!current.isAfter(endDate)) {
        final dateId = _dateId(current);

        final attendance = attendanceByDate[dateId];

        dailyRecords.add(
          _createDayRecord(date: current, attendance: attendance),
        );

        current = current.add(const Duration(days: 1));
      }

      final monthlyData = _StudentMonthlyData(
        student: student,
        dailyRecords: dailyRecords,
      );

      monthlyData.calculateTotals();

      if (!mounted) return;

      setState(() {
        report = monthlyData;
        isLoadingReport = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoadingReport = false;
      });

      _showMessage('Failed to load student report.');
    }
  }

  // ============================================================
  // CREATE DAILY RECORD
  // ============================================================

  _StudentDayRecord _createDayRecord({
    required DateTime date,
    required Map<String, dynamic>? attendance,
  }) {
    if (attendance == null) {
      return _StudentDayRecord(
        date: date,
        status: 'Absent',
        sessions: const [],
        studyTime: Duration.zero,
      );
    }

    final status = attendance['status']?.toString() ?? '';

    /*
     * AttendanceService uses:
     * Present  = active attendance
     * Completed = completed attendance
     */
    final isPresent = status == 'Present' || status == 'Completed';

    if (!isPresent) {
      return _StudentDayRecord(
        date: date,
        status: 'Absent',
        sessions: const [],
        studyTime: Duration.zero,
      );
    }

    final result = _parseSessions(attendance);

    return _StudentDayRecord(
      date: date,
      status: 'Present',
      sessions: result.sessions,
      studyTime: result.studyTime,
    );
  }

  // ============================================================
  // SESSION PARSER
  // ============================================================

  _SessionResult _parseSessions(Map<String, dynamic> data) {
    final rawSessions = data['sessions'];

    final sessions = <_AttendanceSession>[];

    Duration totalStudyTime = Duration.zero;

    if (rawSessions is List) {
      for (final item in rawSessions) {
        if (item is! Map) {
          continue;
        }

        final session = Map<String, dynamic>.from(item);

        final entry = _toDateTime(session['entryAt']);

        final exit = _toDateTime(session['exitAt']);

        if (entry == null) {
          continue;
        }

        Duration duration = Duration.zero;

        if (exit != null && exit.isAfter(entry)) {
          duration = exit.difference(entry);

          totalStudyTime += duration;
        }

        sessions.add(
          _AttendanceSession(entry: entry, exit: exit, duration: duration),
        );
      }
    } else {
      final entry = _toDateTime(data['entryAt']);

      final exit = _toDateTime(data['exitAt']);

      if (entry != null) {
        Duration duration = Duration.zero;

        if (exit != null && exit.isAfter(entry)) {
          duration = exit.difference(entry);

          totalStudyTime += duration;
        }

        sessions.add(
          _AttendanceSession(entry: entry, exit: exit, duration: duration),
        );
      }
    }

    return _SessionResult(sessions: sessions, studyTime: totalStudyTime);
  }

  DateTime? _toDateTime(dynamic value) {
    if (value == null) {
      return null;
    }

    if (value is Timestamp) {
      return value.toDate();
    }

    if (value is DateTime) {
      return value;
    }

    if (value is String) {
      return DateTime.tryParse(value);
    }

    return null;
  }

  // ============================================================
  // MONTH HELPERS
  // ============================================================

  DateTime _getEndDate() {
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    final today = DateTime.now();

    if (selectedMonth.year == today.year &&
        selectedMonth.month == today.month) {
      return DateTime(today.year, today.month, today.day);
    }

    return lastDay;
  }

  String _dateId(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  String _monthName() {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return '${months[selectedMonth.month - 1]} '
        '${selectedMonth.year}';
  }

  String _monthFileName() {
    return '${selectedMonth.year}_'
        '${selectedMonth.month.toString().padLeft(2, '0')}';
  }

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select any date in the required month',
    );

    if (picked == null) {
      return;
    }

    setState(() {
      selectedMonth = DateTime(picked.year, picked.month, 1);
    });

    await _loadStudentReport();
  }

  // ============================================================
  // EXPORT HEADERS
  // ============================================================

  List<String> _exportHeaders() {
    return const [
      'Date',
      'Status',
      'S1 Entry',
      'S1 Exit',
      'S2 Entry',
      'S2 Exit',
      'S3 Entry',
      'S3 Exit',
      'Sessions',
      'Study Time',
    ];
  }

  // ============================================================
  // EXPORT ROWS
  // ============================================================

  List<List<String>> _exportRows() {
    if (report == null) {
      return [];
    }

    final rows = <List<String>>[];

    for (final record in report!.dailyRecords.reversed) {
      String sessionEntry(int index) {
        if (record.sessions.length <= index) {
          return '-';
        }

        return _formatTime(record.sessions[index].entry);
      }

      String sessionExit(int index) {
        if (record.sessions.length <= index) {
          return '-';
        }

        return _formatTime(record.sessions[index].exit);
      }

      rows.add([
        _formatDate(record.date),
        record.status,

        sessionEntry(0),
        sessionExit(0),

        sessionEntry(1),
        sessionExit(1),

        sessionEntry(2),
        sessionExit(2),

        record.sessions.length.toString(),

        _formatDuration(record.studyTime),
      ]);
    }

    return rows;
  }

  // ============================================================
  // EXPORT EXCEL
  // ============================================================

  Future<void> _exportExcel() async {
    if (report == null) {
      _showMessage('Student report is not available.');
      return;
    }

    if (isExporting) {
      return;
    }

    setState(() {
      isExporting = true;
    });

    try {
      final student = report!.student;

      await ReportExportService.exportExcel(
        fileName: '${student.libraryId}_${_monthFileName()}_Report.xlsx',

        title:
            'Vision The Library - Student Monthly Report - '
            '${student.name} (${student.libraryId})',

        headers: _exportHeaders(),

        rows: _exportRows(),
      );

      _showMessage('Excel report generated successfully.');
    } catch (e) {
      _showMessage('Failed to generate Excel report.');
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  // ============================================================
  // EXPORT PDF
  // ============================================================

  Future<void> _exportPdf() async {
    if (report == null) {
      _showMessage('Student report is not available.');
      return;
    }

    if (isExporting) {
      return;
    }

    setState(() {
      isExporting = true;
    });

    try {
      final student = report!.student;

      await ReportExportService.exportPdf(
        fileName: '${student.libraryId}_${_monthFileName()}_Report.pdf',

        title:
            'Vision The Library - Student Monthly Report - '
            '${student.name} (${student.libraryId})',

        headers: _exportHeaders(),

        rows: _exportRows(),
      );

      _showMessage('PDF report generated successfully.');
    } catch (e) {
      _showMessage('Failed to generate PDF report.');
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  // ============================================================
  // PRINT PDF
  // ============================================================

  Future<void> _printPdf() async {
    if (report == null) {
      _showMessage('Student report is not available.');
      return;
    }

    if (isExporting) {
      return;
    }

    setState(() {
      isExporting = true;
    });

    try {
      final student = report!.student;

      await ReportExportService.printPdf(
        title:
            'Vision The Library - Student Monthly Report - '
            '${student.name} (${student.libraryId})',

        headers: _exportHeaders(),

        rows: _exportRows(),
      );
    } catch (e) {
      _showMessage('Failed to print report.');
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
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
          'Student Report',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            onPressed: isLoadingReport || isExporting
                ? null
                : _loadStudentReport,

            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),

      body: isLoadingStudents
          ? const Center(child: CircularProgressIndicator())
          : students.isEmpty
          ? _emptyStudents()
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),

              padding: const EdgeInsets.all(20),

              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  _studentSelector(),

                  const SizedBox(height: 15),

                  _monthSelector(),

                  const SizedBox(height: 25),

                  if (isLoadingReport)
                    const Center(child: CircularProgressIndicator())
                  else if (report == null)
                    _emptyReport()
                  else
                    _buildReport(),
                ],
              ),
            ),
    );
  }

  // ============================================================
  // STUDENT SELECTOR
  // ============================================================

  Widget _studentSelector() {
    return DropdownButtonFormField<String>(
      initialValue: selectedLibraryId,

      dropdownColor: const Color(0xff1E293B),

      style: GoogleFonts.poppins(color: Colors.white),

      iconEnabledColor: Colors.white,

      decoration: InputDecoration(
        labelText: 'Select Student',

        labelStyle: GoogleFonts.poppins(color: Colors.white70),

        prefixIcon: const Icon(
          Icons.person_search_outlined,
          color: Colors.white70,
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

      items: students.map((student) {
        return DropdownMenuItem<String>(
          value: student.libraryId,

          child: Text(
            '${student.name} • ${student.libraryId}',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),

      onChanged: isExporting
          ? null
          : (value) async {
              if (value == null) {
                return;
              }

              setState(() {
                selectedLibraryId = value;
              });

              await _loadStudentReport();
            },
    );
  }

  // ============================================================
  // MONTH SELECTOR
  // ============================================================

  Widget _monthSelector() {
    return InkWell(
      onTap: isLoadingReport || isExporting ? null : _selectMonth,

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
                    'Report Month',
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 12,
                    ),
                  ),

                  const SizedBox(height: 3),

                  Text(
                    _monthName(),
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

  // ============================================================
  // COMPLETE REPORT
  // ============================================================

  Widget _buildReport() {
    final data = report!;

    return Column(
      children: [
        _studentHeader(data.student),

        const SizedBox(height: 20),

        _summaryCards(data),

        const SizedBox(height: 20),

        _exportButtons(),

        const SizedBox(height: 30),

        Align(
          alignment: Alignment.centerLeft,

          child: Text(
            'Daily Attendance',
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),

        const SizedBox(height: 15),

        if (data.dailyRecords.isEmpty)
          _emptyReport()
        else
          ...data.dailyRecords.reversed.map(
            (record) => Padding(
              padding: const EdgeInsets.only(bottom: 12),

              child: _dailyAttendanceCard(record),
            ),
          ),

        const SizedBox(height: 20),
      ],
    );
  }

  // ============================================================
  // EXPORT BUTTONS
  // ============================================================

  Widget _exportButtons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,

      children: [
        Text(
          'Export Report',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: isExporting ? null : _exportExcel,

                icon: const Icon(Icons.table_chart_outlined),

                label: const Text('Excel'),

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,

                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(vertical: 14),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: ElevatedButton.icon(
                onPressed: isExporting ? null : _exportPdf,

                icon: const Icon(Icons.picture_as_pdf_outlined),

                label: const Text('PDF'),

                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,

                  foregroundColor: Colors.white,

                  padding: const EdgeInsets.symmetric(vertical: 14),

                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        OutlinedButton.icon(
          onPressed: isExporting ? null : _printPdf,

          icon: const Icon(Icons.print_outlined),

          label: const Text('Print Report'),

          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white,

            side: const BorderSide(color: Colors.white24),

            padding: const EdgeInsets.symmetric(vertical: 14),

            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // STUDENT HEADER
  // ============================================================

  Widget _studentHeader(_StudentItem student) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(18),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(20),

        border: Border.all(color: Colors.white24),
      ),

      child: Row(
        children: [
          CircleAvatar(
            radius: 30,

            backgroundColor: Colors.white24,

            child: Icon(
              student.gender == 'Girl' ? Icons.person_2 : Icons.person,

              color: Colors.white,

              size: 36,
            ),
          ),

          const SizedBox(width: 15),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,

              children: [
                Text(
                  student.name.toUpperCase(),

                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 4),

                Text(
                  'Library ID: ${student.libraryId}',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),

                Text(
                  'Seat: ${student.seat} • ${student.gender}',
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 11,
                  ),
                ),

                Text(
                  _monthName(),
                  style: GoogleFonts.poppins(
                    color: Colors.blueAccent,
                    fontSize: 11,
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

  // ============================================================
  // SUMMARY CARDS
  // ============================================================

  Widget _summaryCards(_StudentMonthlyData data) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Present',
                data.presentDays.toString(),
                Icons.check_circle_outline,
                Colors.greenAccent,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _summaryCard(
                'Absent',
                data.absentDays.toString(),
                Icons.cancel_outlined,
                Colors.redAccent,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Attendance',
                _percentage(data.attendancePercentage),
                Icons.insights_outlined,
                Colors.blueAccent,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _summaryCard(
                'Sessions',
                data.totalSessions.toString(),
                Icons.layers_outlined,
                Colors.purpleAccent,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        _summaryCard(
          'Total Study Time',
          _formatDuration(data.totalStudyTime),
          Icons.access_time,
          Colors.cyanAccent,
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
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
          Icon(icon, color: color, size: 27),

          const SizedBox(height: 10),

          Text(
            value,
            style: GoogleFonts.poppins(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 3),

          Text(
            title,
            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // DAILY ATTENDANCE CARD
  // ============================================================

  Widget _dailyAttendanceCard(_StudentDayRecord record) {
    final isPresent = record.status == 'Present';

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
              const Icon(
                Icons.calendar_today_outlined,
                color: Colors.white70,
                size: 21,
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Text(
                  _formatDate(record.date),

                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Text(
                record.status,

                style: GoogleFonts.poppins(
                  color: isPresent ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          if (isPresent && record.sessions.isNotEmpty) ...[
            const SizedBox(height: 15),

            Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),

            const SizedBox(height: 12),

            ...List.generate(record.sessions.length, (index) {
              final session = record.sessions[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 9),

                child: Row(
                  children: [
                    Container(
                      width: 27,
                      height: 27,
                      alignment: Alignment.center,

                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.18),

                        borderRadius: BorderRadius.circular(8),
                      ),

                      child: Text(
                        'S${index + 1}',
                        style: GoogleFonts.poppins(
                          color: Colors.blueAccent,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'IN ${_formatTime(session.entry)}',

                        style: GoogleFonts.poppins(
                          color: Colors.greenAccent,
                          fontSize: 10,
                        ),
                      ),
                    ),

                    Expanded(
                      child: Text(
                        'OUT ${_formatTime(session.exit)}',

                        textAlign: TextAlign.end,

                        style: GoogleFonts.poppins(
                          color: Colors.orangeAccent,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),

            Align(
              alignment: Alignment.centerRight,

              child: Text(
                'Study Time: '
                '${_formatDuration(record.studyTime)}',

                style: GoogleFonts.poppins(
                  color: Colors.cyanAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ============================================================
  // EMPTY STATES
  // ============================================================

  Widget _emptyStudents() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Text(
          'No students found.',
          textAlign: TextAlign.center,

          style: GoogleFonts.poppins(color: Colors.white70),
        ),
      ),
    );
  }

  Widget _emptyReport() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(25),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white24),
      ),

      child: Text(
        'No attendance data found for this month.',

        textAlign: TextAlign.center,

        style: GoogleFonts.poppins(color: Colors.white70),
      ),
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _formatDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  String _formatTime(DateTime? date) {
    if (date == null) {
      return '-';
    }

    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;

    final minute = date.minute.toString().padLeft(2, '0');

    final period = date.hour >= 12 ? 'PM' : 'AM';

    return '$hour:$minute $period';
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;

    final minutes = duration.inMinutes % 60;

    if (hours == 0 && minutes == 0) {
      return '0m';
    }

    if (hours == 0) {
      return '${minutes}m';
    }

    if (minutes == 0) {
      return '${hours}h';
    }

    return '${hours}h ${minutes}m';
  }

  String _percentage(double value) {
    return '${value.toStringAsFixed(1)}%';
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message, style: GoogleFonts.poppins())),
    );
  }
}

// ============================================================
// DATA MODELS
// ============================================================

class _StudentItem {
  final String libraryId;
  final String name;
  final String gender;
  final String seat;

  const _StudentItem({
    required this.libraryId,
    required this.name,
    required this.gender,
    required this.seat,
  });
}

class _StudentMonthlyData {
  final _StudentItem student;

  final List<_StudentDayRecord> dailyRecords;

  int presentDays = 0;
  int absentDays = 0;
  int totalSessions = 0;

  Duration totalStudyTime = Duration.zero;

  double attendancePercentage = 0;

  _StudentMonthlyData({required this.student, required this.dailyRecords});

  void calculateTotals() {
    presentDays = 0;
    absentDays = 0;
    totalSessions = 0;

    totalStudyTime = Duration.zero;

    for (final record in dailyRecords) {
      if (record.status == 'Present') {
        presentDays++;
      } else {
        absentDays++;
      }

      totalSessions += record.sessions.length;

      totalStudyTime += record.studyTime;
    }

    final totalDays = presentDays + absentDays;

    attendancePercentage = totalDays == 0 ? 0 : (presentDays / totalDays) * 100;
  }
}

class _StudentDayRecord {
  final DateTime date;
  final String status;

  final List<_AttendanceSession> sessions;

  final Duration studyTime;

  const _StudentDayRecord({
    required this.date,
    required this.status,
    required this.sessions,
    required this.studyTime,
  });
}

class _AttendanceSession {
  final DateTime entry;
  final DateTime? exit;
  final Duration duration;

  const _AttendanceSession({
    required this.entry,
    required this.exit,
    required this.duration,
  });
}

class _SessionResult {
  final List<_AttendanceSession> sessions;

  final Duration studyTime;

  const _SessionResult({required this.sessions, required this.studyTime});
}
