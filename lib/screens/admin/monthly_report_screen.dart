import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/report_export_service.dart';

class MonthlyReportScreen extends StatefulWidget {
  const MonthlyReportScreen({super.key});

  @override
  State<MonthlyReportScreen> createState() => _MonthlyReportScreenState();
}

class _MonthlyReportScreenState extends State<MonthlyReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime selectedMonth = DateTime.now();

  bool isLoading = true;
  bool isExporting = false;

  int totalStudents = 0;
  int totalPresentRecords = 0;
  int totalAbsentRecords = 0;
  int totalSessions = 0;

  Duration totalStudyTime = Duration.zero;

  double overallAttendance = 0;

  List<_DailyLibraryReport> dailyReports = [];
  List<_StudentMonthlyReport> studentReports = [];

  @override
  void initState() {
    super.initState();
    _loadReport();
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  String _dateId(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _today() {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  DateTime _startOfMonth() {
    return DateTime(selectedMonth.year, selectedMonth.month, 1);
  }

  DateTime _endOfMonth() {
    final lastDay = DateTime(selectedMonth.year, selectedMonth.month + 1, 0);

    final today = _today();

    if (selectedMonth.year == today.year &&
        selectedMonth.month == today.month) {
      return today;
    }

    return lastDay;
  }

  // ============================================================
  // LOAD REPORT
  // ============================================================

  Future<void> _loadReport() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
    });

    try {
      final studentsSnapshot = await _firestore.collection('students').get();

      final studentDocuments = studentsSnapshot.docs;

      final startDate = _startOfMonth();
      final endDate = _endOfMonth();

      final Map<String, _StudentMonthlyReport> studentMap = {};

      // ----------------------------------------------------------
      // REGISTERED STUDENTS
      // ----------------------------------------------------------

      for (final document in studentDocuments) {
        final data = document.data();

        final libraryId = data['libraryId']?.toString() ?? document.id;

        final name = data['name']?.toString() ?? 'Unknown Student';

        final gender = data['gender']?.toString() ?? '-';

        final seat = data['seat']?.toString() ?? '-';

        studentMap[libraryId] = _StudentMonthlyReport(
          libraryId: libraryId,
          name: name,
          gender: gender,
          seat: seat,
          dailyRecords: [],
        );
      }

      // ----------------------------------------------------------
      // ATTENDANCE DATA
      // ----------------------------------------------------------

      for (final student in studentDocuments) {
        final studentData = student.data();

        final libraryId = studentData['libraryId']?.toString() ?? student.id;

        final studentReport = studentMap[libraryId];

        if (studentReport == null) {
          continue;
        }

        final attendanceSnapshot = await _firestore
            .collection('attendance')
            .doc(libraryId)
            .collection('days')
            .where('date', isGreaterThanOrEqualTo: _dateId(startDate))
            .where('date', isLessThanOrEqualTo: _dateId(endDate))
            .get();

        final Map<String, Map<String, dynamic>> attendanceByDate = {};

        for (final document in attendanceSnapshot.docs) {
          final data = document.data();

          final date = data['date']?.toString() ?? document.id;

          attendanceByDate[date] = data;
        }

        DateTime current = startDate;

        while (!current.isAfter(endDate)) {
          final dateId = _dateId(current);

          final attendance = attendanceByDate[dateId];

          studentReport.dailyRecords.add(
            _createStudentDayRecord(date: current, attendance: attendance),
          );

          current = current.add(const Duration(days: 1));
        }
      }

      // ----------------------------------------------------------
      // STUDENT TOTALS
      // ----------------------------------------------------------

      for (final student in studentMap.values) {
        student.calculateTotals();
      }

      // ----------------------------------------------------------
      // DAILY LIBRARY PERFORMANCE
      // ----------------------------------------------------------

      final List<_DailyLibraryReport> loadedDailyReports = [];

      DateTime current = startDate;

      while (!current.isAfter(endDate)) {
        int present = 0;
        int absent = 0;
        int sessions = 0;

        Duration studyTime = Duration.zero;

        for (final student in studentMap.values) {
          final dateId = _dateId(current);

          _StudentDayRecord? record;

          for (final item in student.dailyRecords) {
            if (_dateId(item.date) == dateId) {
              record = item;
              break;
            }
          }

          record ??= _StudentDayRecord(
            date: current,
            status: 'Absent',
            sessions: const [],
            studyTime: Duration.zero,
          );

          if (record.status == 'Present') {
            present++;
          } else {
            absent++;
          }

          sessions += record.sessions.length;

          studyTime += record.studyTime;
        }

        final totalForDay = present + absent;

        final percentage = totalForDay == 0
            ? 0.0
            : (present / totalForDay) * 100;

        loadedDailyReports.add(
          _DailyLibraryReport(
            date: current,
            totalStudents: studentMap.length,
            present: present,
            absent: absent,
            attendancePercentage: percentage,
            sessions: sessions,
            studyTime: studyTime,
          ),
        );

        current = current.add(const Duration(days: 1));
      }

      // ----------------------------------------------------------
      // OVERALL TOTALS
      // ----------------------------------------------------------

      int presentRecords = 0;
      int absentRecords = 0;
      int sessions = 0;

      Duration studyTime = Duration.zero;

      for (final day in loadedDailyReports) {
        presentRecords += day.present;

        absentRecords += day.absent;

        sessions += day.sessions;

        studyTime += day.studyTime;
      }

      final totalRecords = presentRecords + absentRecords;

      final percentage = totalRecords == 0
          ? 0.0
          : (presentRecords / totalRecords) * 100;

      final sortedStudents = studentMap.values.toList();

      sortedStudents.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      if (!mounted) return;

      setState(() {
        totalStudents = studentMap.length;

        totalPresentRecords = presentRecords;

        totalAbsentRecords = absentRecords;

        totalSessions = sessions;

        totalStudyTime = studyTime;

        overallAttendance = percentage;

        dailyReports = loadedDailyReports.reversed.toList();

        studentReports = sortedStudents;

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      _showMessage('Failed to load library report.');
    }
  }

  // ============================================================
  // CREATE DAILY STUDENT RECORD
  // ============================================================

  _StudentDayRecord _createStudentDayRecord({
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

    final List<_AttendanceSession> sessions = [];

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
  // MONTH SELECTOR
  // ============================================================

  Future<void> _selectMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: selectedMonth,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'Select any date in the month',
    );

    if (picked == null) {
      return;
    }

    setState(() {
      selectedMonth = DateTime(picked.year, picked.month, 1);
    });

    await _loadReport();
  }

  // ============================================================
  // EXPORT HEADERS
  // ============================================================

  List<String> _exportHeaders() {
    return const [
      'Section',
      'Date',
      'Library ID',
      'Student Name',
      'Gender',
      'Seat',
      'Status',
      'Attendance %',
      'Sessions',
      'Study Time',
      'S1 IN / OUT',
      'S2 IN / OUT',
      'S3 IN / OUT',
    ];
  }

  // ============================================================
  // BUILD COMPLETE EXPORT DATA
  // ============================================================

  List<List<String>> _buildExportRows() {
    final rows = <List<String>>[];

    // ==========================================================
    // SECTION 1
    // OVERALL LIBRARY PERFORMANCE
    // ==========================================================

    rows.add([
      'OVERALL LIBRARY PERFORMANCE',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ]);

    rows.add([
      'Daily Performance',
      'Date',
      'Total Students',
      'Library',
      '',
      '',
      'Present / Absent',
      'Attendance %',
      'Sessions',
      'Study Time',
      '',
      '',
      '',
    ]);

    for (final day in dailyReports.reversed) {
      rows.add([
        'Daily Performance',
        _formatDate(day.date),
        day.totalStudents.toString(),
        'Entire Library',
        '',
        '',
        '${day.present} / ${day.absent}',
        _percentage(day.attendancePercentage),
        day.sessions.toString(),
        _formatDuration(day.studyTime),
        '',
        '',
        '',
      ]);
    }

    // ==========================================================
    // SECTION 2
    // MONTHLY OVERALL SUMMARY
    // ==========================================================

    rows.add([
      'MONTHLY OVERALL SUMMARY',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ]);

    rows.add([
      'Monthly Summary',
      _monthName(),
      '',
      'Entire Library',
      '',
      '',
      'Present: $totalPresentRecords / Absent: $totalAbsentRecords',
      _percentage(overallAttendance),
      totalSessions.toString(),
      _formatDuration(totalStudyTime),
      '',
      '',
      '',
    ]);

    rows.add([
      'Registered Students',
      '',
      '',
      totalStudents.toString(),
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ]);

    // ==========================================================
    // SECTION 3
    // STUDENT-WISE MONTHLY SUMMARY
    // ==========================================================

    rows.add([
      'STUDENT-WISE MONTHLY SUMMARY',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ]);

    rows.add([
      'Student Summary',
      'Month',
      'Library ID',
      'Student Name',
      'Gender',
      'Seat',
      'Present / Absent',
      'Attendance %',
      'Sessions',
      'Study Time',
      '',
      '',
      '',
    ]);

    for (final student in studentReports) {
      rows.add([
        'Student Summary',
        _monthName(),
        student.libraryId,
        student.name,
        student.gender,
        student.seat,
        '${student.presentDays} / ${student.absentDays}',
        _percentage(student.attendancePercentage),
        student.totalSessions.toString(),
        _formatDuration(student.totalStudyTime),
        '',
        '',
        '',
      ]);
    }

    // ==========================================================
    // SECTION 4
    // DETAILED ATTENDANCE
    // ==========================================================

    rows.add([
      'DETAILED ATTENDANCE',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
      '',
    ]);

    rows.add([
      'Daily Attendance',
      'Date',
      'Library ID',
      'Student Name',
      'Gender',
      'Seat',
      'Status',
      '',
      'Sessions',
      'Study Time',
      'S1 IN / OUT',
      'S2 IN / OUT',
      'S3 IN / OUT',
    ]);

    for (final student in studentReports) {
      for (final record in student.dailyRecords.reversed) {
        final session1 = record.sessions.isNotEmpty ? record.sessions[0] : null;

        final session2 = record.sessions.length >= 2
            ? record.sessions[1]
            : null;

        final session3 = record.sessions.length >= 3
            ? record.sessions[2]
            : null;

        rows.add([
          'Daily Attendance',
          _formatDate(record.date),
          student.libraryId,
          student.name,
          student.gender,
          student.seat,
          record.status,
          '',
          record.sessions.length.toString(),
          _formatDuration(record.studyTime),
          _sessionTime(session1),
          _sessionTime(session2),
          _sessionTime(session3),
        ]);
      }
    }

    return rows;
  }

  String _sessionTime(_AttendanceSession? session) {
    if (session == null) {
      return '-';
    }

    final entry = _formatTime(session.entry);

    final exit = _formatTime(session.exit);

    return '$entry → $exit';
  }

  // ============================================================
  // EXPORT EXCEL
  // ============================================================

  Future<void> _exportExcel() async {
    if (isExporting) {
      return;
    }

    setState(() {
      isExporting = true;
    });

    try {
      final rows = _buildExportRows();

      await ReportExportService.exportExcel(
        fileName: 'Vision_Library_${_monthFileName()}.xlsx',
        title: 'Vision The Library - Complete Library Report - ${_monthName()}',
        headers: _exportHeaders(),
        rows: rows,
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
    if (isExporting) {
      return;
    }

    setState(() {
      isExporting = true;
    });

    try {
      final rows = _buildExportRows();

      await ReportExportService.exportPdf(
        fileName: 'Vision_Library_${_monthFileName()}.pdf',
        title: 'Vision The Library - Complete Library Report - ${_monthName()}',
        headers: _exportHeaders(),
        rows: rows,
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
  // FORMATTERS
  // ============================================================

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
          'Library Report',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            onPressed: isLoading || isExporting ? null : _loadReport,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
          const SizedBox(width: 8),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadReport,

              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),

                padding: const EdgeInsets.all(20),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    _monthSelector(),

                    const SizedBox(height: 20),

                    _exportButtons(),

                    const SizedBox(height: 30),

                    Text(
                      'Overall Library Performance',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    _overallSummary(),

                    const SizedBox(height: 25),

                    Text(
                      'Daily Performance',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    if (dailyReports.isEmpty)
                      _emptyCard()
                    else
                      ...dailyReports.map(
                        (day) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _dailyPerformanceCard(day),
                        ),
                      ),

                    const SizedBox(height: 30),

                    Text(
                      'Student-wise Monthly Performance',
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    if (studentReports.isEmpty)
                      _emptyCard()
                    else
                      ...studentReports.map(
                        (student) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _studentCard(student),
                        ),
                      ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================================
  // MONTH SELECTOR
  // ============================================================

  Widget _monthSelector() {
    return InkWell(
      onTap: isExporting ? null : _selectMonth,

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
  // EXPORT BUTTONS
  // ============================================================

  Widget _exportButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: isExporting ? null : _exportExcel,

            icon: const Icon(Icons.table_chart_outlined),

            label: Text(
              isExporting ? 'Preparing...' : 'Excel',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),

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

            label: Text(
              isExporting ? 'Preparing...' : 'PDF',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),

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
    );
  }

  // ============================================================
  // OVERALL SUMMARY
  // ============================================================

  Widget _overallSummary() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Registered',
                totalStudents.toString(),
                Icons.people_outline,
                Colors.blueAccent,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _summaryCard(
                'Present',
                totalPresentRecords.toString(),
                Icons.check_circle_outline,
                Colors.greenAccent,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Absent',
                totalAbsentRecords.toString(),
                Icons.cancel_outlined,
                Colors.redAccent,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _summaryCard(
                'Attendance',
                _percentage(overallAttendance),
                Icons.insights_outlined,
                Colors.orangeAccent,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _summaryCard(
                'Sessions',
                totalSessions.toString(),
                Icons.layers_outlined,
                Colors.purpleAccent,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: _summaryCard(
                'Study Time',
                _formatDuration(totalStudyTime),
                Icons.access_time,
                Colors.cyanAccent,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard(String title, String value, IconData icon, Color color) {
    return Container(
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
  // DAILY PERFORMANCE CARD
  // ============================================================

  Widget _dailyPerformanceCard(_DailyLibraryReport day) {
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
                  _formatDate(day.date),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Text(
                _percentage(day.attendancePercentage),
                style: GoogleFonts.poppins(
                  color: Colors.blueAccent,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _smallValue(
                  'Total',
                  day.totalStudents.toString(),
                  Colors.white,
                ),
              ),

              _verticalDivider(),

              Expanded(
                child: _smallValue(
                  'Present',
                  day.present.toString(),
                  Colors.greenAccent,
                ),
              ),

              _verticalDivider(),

              Expanded(
                child: _smallValue(
                  'Absent',
                  day.absent.toString(),
                  Colors.redAccent,
                ),
              ),

              _verticalDivider(),

              Expanded(
                child: _smallValue(
                  'Sessions',
                  day.sessions.toString(),
                  Colors.purpleAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(
            'Total Study Time: '
            '${_formatDuration(day.studyTime)}',
            style: GoogleFonts.poppins(
              color: Colors.cyanAccent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STUDENT CARD
  // ============================================================

  Widget _studentCard(_StudentMonthlyReport student) {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(16),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white24),
      ),

      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,

        childrenPadding: EdgeInsets.zero,

        iconColor: Colors.white70,

        collapsedIconColor: Colors.white54,

        title: Row(
          children: [
            CircleAvatar(
              radius: 22,

              backgroundColor: Colors.white24,

              child: Icon(
                student.gender == 'Girl' ? Icons.person_2 : Icons.person,
                color: Colors.white,
                size: 27,
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  Text(
                    student.name,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 2),

                  Text(
                    student.libraryId,
                    style: GoogleFonts.poppins(
                      color: Colors.white60,
                      fontSize: 11,
                    ),
                  ),

                  Text(
                    'Seat: ${student.seat}',
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        children: [
          const Divider(color: Colors.white24),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _smallValue(
                  'Present',
                  student.presentDays.toString(),
                  Colors.greenAccent,
                ),
              ),

              _verticalDivider(),

              Expanded(
                child: _smallValue(
                  'Absent',
                  student.absentDays.toString(),
                  Colors.redAccent,
                ),
              ),

              _verticalDivider(),

              Expanded(
                child: _smallValue(
                  'Attendance',
                  _percentage(student.attendancePercentage),
                  Colors.blueAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 15),

          Row(
            children: [
              Expanded(
                child: _smallValue(
                  'Sessions',
                  student.totalSessions.toString(),
                  Colors.purpleAccent,
                ),
              ),

              _verticalDivider(),

              Expanded(
                child: _smallValue(
                  'Study Time',
                  _formatDuration(student.totalStudyTime),
                  Colors.cyanAccent,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Align(
            alignment: Alignment.centerLeft,

            child: Text(
              'Daily Attendance',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          const SizedBox(height: 10),

          ...student.dailyRecords.reversed.map(
            (record) => _studentDayCard(record),
          ),

          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ============================================================
  // STUDENT DAILY CARD
  // ============================================================

  Widget _studentDayCard(_StudentDayRecord record) {
    final isPresent = record.status == 'Present';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),

      padding: const EdgeInsets.all(12),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),

        borderRadius: BorderRadius.circular(12),
      ),

      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _formatDate(record.date),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Text(
                record.status,
                style: GoogleFonts.poppins(
                  color: isPresent ? Colors.greenAccent : Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          if (isPresent && record.sessions.isNotEmpty) ...[
            const SizedBox(height: 10),

            ...List.generate(record.sessions.length, (index) {
              final session = record.sessions[index];

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),

                child: Row(
                  children: [
                    Container(
                      width: 25,
                      height: 25,
                      alignment: Alignment.center,

                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.18),

                        borderRadius: BorderRadius.circular(8),
                      ),

                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.poppins(
                          color: Colors.blueAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    Expanded(
                      child: Text(
                        'IN  ${_formatTime(session.entry)}',
                        style: GoogleFonts.poppins(
                          color: Colors.greenAccent,
                          fontSize: 10,
                        ),
                      ),
                    ),

                    Expanded(
                      child: Text(
                        'OUT  ${_formatTime(session.exit)}',
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
                _formatDuration(record.studyTime),
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
  // SMALL UI HELPERS
  // ============================================================

  Widget _smallValue(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,

          style: GoogleFonts.poppins(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 3),

        Text(
          title,
          textAlign: TextAlign.center,

          style: GoogleFonts.poppins(color: Colors.white54, fontSize: 9),
        ),
      ],
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 30, color: Colors.white24);
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(25),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white24),
      ),

      child: Text(
        'No report data found.',
        textAlign: TextAlign.center,

        style: GoogleFonts.poppins(color: Colors.white70),
      ),
    );
  }
}

// ============================================================
// DATA MODELS
// ============================================================

class _DailyLibraryReport {
  final DateTime date;
  final int totalStudents;
  final int present;
  final int absent;
  final double attendancePercentage;
  final int sessions;
  final Duration studyTime;

  const _DailyLibraryReport({
    required this.date,
    required this.totalStudents,
    required this.present,
    required this.absent,
    required this.attendancePercentage,
    required this.sessions,
    required this.studyTime,
  });
}

class _StudentMonthlyReport {
  final String libraryId;
  final String name;
  final String gender;
  final String seat;

  final List<_StudentDayRecord> dailyRecords;

  int presentDays = 0;
  int absentDays = 0;
  int totalSessions = 0;

  Duration totalStudyTime = Duration.zero;

  double attendancePercentage = 0;

  _StudentMonthlyReport({
    required this.libraryId,
    required this.name,
    required this.gender,
    required this.seat,
    required this.dailyRecords,
  });

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
