import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/report_export_service.dart';

class StudentAttendanceHistoryScreen extends StatefulWidget {
  final String name;
  final String libraryId;

  const StudentAttendanceHistoryScreen({
    super.key,
    required this.name,
    required this.libraryId,
  });

  @override
  State<StudentAttendanceHistoryScreen> createState() =>
      _StudentAttendanceHistoryScreenState();
}

enum AttendancePeriod { today, last7Days, specificDay, specificMonth }

class _StudentAttendanceHistoryScreenState
    extends State<StudentAttendanceHistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  AttendancePeriod selectedPeriod = AttendancePeriod.specificMonth;

  DateTime selectedDay = DateTime.now();

  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  bool isLoading = true;
  bool isExporting = false;

  String? errorMessage;

  List<_AttendanceDay> attendanceDays = [];

  int presentDays = 0;
  int absentDays = 0;

  double attendancePercentage = 0;

  Duration averageStudyTime = Duration.zero;

  @override
  void initState() {
    super.initState();

    _loadAttendanceHistory();
  }

  // ============================================================
  // DATE HELPERS
  // ============================================================

  String _dateId(DateTime date) {
    return '${date.year}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  DateTime _todayOnly() {
    final now = DateTime.now();

    return DateTime(now.year, now.month, now.day);
  }

  DateTime _firstDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month, 1);
  }

  DateTime _lastDayOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  // ============================================================
  // PERIOD
  // ============================================================

  DateTime _periodStart() {
    final today = _todayOnly();

    switch (selectedPeriod) {
      case AttendancePeriod.today:
        return today;

      case AttendancePeriod.last7Days:
        return today.subtract(const Duration(days: 6));

      case AttendancePeriod.specificDay:
        return DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

      case AttendancePeriod.specificMonth:
        return _firstDayOfMonth(selectedMonth);
    }
  }

  DateTime _periodEnd() {
    final today = _todayOnly();

    switch (selectedPeriod) {
      case AttendancePeriod.today:
        return today;

      case AttendancePeriod.last7Days:
        return today;

      case AttendancePeriod.specificDay:
        return DateTime(selectedDay.year, selectedDay.month, selectedDay.day);

      case AttendancePeriod.specificMonth:
        final lastDay = _lastDayOfMonth(selectedMonth);

        if (lastDay.isAfter(today)) {
          return today;
        }

        return lastDay;
    }
  }

  String _periodTitle() {
    switch (selectedPeriod) {
      case AttendancePeriod.today:
        return 'Today';

      case AttendancePeriod.last7Days:
        return 'Last 7 Days';

      case AttendancePeriod.specificDay:
        return _formatDate(selectedDay);

      case AttendancePeriod.specificMonth:
        return _formatMonth(selectedMonth);
    }
  }

  // ============================================================
  // LOAD ATTENDANCE
  // ============================================================

  Future<void> _loadAttendanceHistory() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final firstDay = _periodStart();
      final lastDay = _periodEnd();

      if (firstDay.isAfter(lastDay)) {
        if (!mounted) return;

        setState(() {
          attendanceDays = [];
          presentDays = 0;
          absentDays = 0;
          attendancePercentage = 0;
          averageStudyTime = Duration.zero;
          isLoading = false;
        });

        return;
      }

      final snapshot = await _firestore
          .collection('attendance')
          .doc(widget.libraryId)
          .collection('days')
          .get();

      final Map<String, Map<String, dynamic>> records = {};

      for (final doc in snapshot.docs) {
        final data = doc.data();

        String dateId = doc.id;

        final dateValue = data['date'];

        if (dateValue is String && dateValue.isNotEmpty) {
          dateId = dateValue;
        }

        records[dateId] = data;
      }

      final List<_AttendanceDay> result = [];

      DateTime current = firstDay;

      while (!current.isAfter(lastDay)) {
        final id = _dateId(current);

        final data = records[id];

        if (data == null) {
          result.add(
            _AttendanceDay(date: current, isPresent: false, sessions: const []),
          );
        } else {
          final sessions = _readSessions(data);

          result.add(
            _AttendanceDay(date: current, isPresent: true, sessions: sessions),
          );
        }

        current = current.add(const Duration(days: 1));
      }

      result.sort((a, b) => b.date.compareTo(a.date));

      final present = result.where((item) => item.isPresent).length;

      final absent = result.length - present;

      final percentage = result.isEmpty ? 0.0 : (present / result.length) * 100;

      Duration totalStudyTime = Duration.zero;

      int completedSessionCount = 0;

      for (final day in result) {
        for (final session in day.sessions) {
          final entry = _toDateTime(session.entryAt);

          final exit = _toDateTime(session.exitAt);

          if (entry != null && exit != null && exit.isAfter(entry)) {
            totalStudyTime += exit.difference(entry);

            completedSessionCount++;
          }
        }
      }

      final Duration calculatedAverageStudyTime = completedSessionCount == 0
          ? Duration.zero
          : Duration(
              milliseconds:
                  totalStudyTime.inMilliseconds ~/ completedSessionCount,
            );

      if (!mounted) return;

      setState(() {
        attendanceDays = result;
        presentDays = present;
        absentDays = absent;
        attendancePercentage = percentage;
        averageStudyTime = calculatedAverageStudyTime;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage = 'Unable to load attendance history.';
      });
    }
  }

  // ============================================================
  // SESSION READER
  // ============================================================

  List<_AttendanceSession> _readSessions(Map<String, dynamic> data) {
    final rawSessions = data['sessions'];

    if (rawSessions is List) {
      final List<_AttendanceSession> sessions = [];

      for (final item in rawSessions) {
        if (item is Map) {
          final session = Map<String, dynamic>.from(item);

          sessions.add(
            _AttendanceSession(
              entryAt: session['entryAt'],
              exitAt: session['exitAt'],
              autoEntry: session['autoEntry'] == true,
              autoExit: session['autoExit'] == true,
            ),
          );
        }
      }

      return sessions;
    }

    if (data['entryAt'] != null) {
      return [
        _AttendanceSession(
          entryAt: data['entryAt'],
          exitAt: data['exitAt'],
          autoEntry: data['autoEntry'] == true,
          autoExit: data['autoExit'] == true,
        ),
      ];
    }

    return [];
  }

  // ============================================================
  // EXPORT
  // ============================================================

  Future<void> _showExportOptions() async {
    if (isLoading || isExporting || attendanceDays.isEmpty) {
      if (attendanceDays.isEmpty && !isLoading) {
        _showMessage('No attendance data available to export.', Colors.orange);
      }

      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xff1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 45,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),

                const SizedBox(height: 18),

                Text(
                  'Export Attendance Report',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _periodTitle(),
                  style: GoogleFonts.poppins(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 20),

                _exportOption(
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'Export PDF',
                  subtitle: 'Detailed multi-page PDF report',
                  value: 'pdf',
                  color: Colors.redAccent,
                  onTap: () {
                    Navigator.pop(sheetContext, 'pdf');
                  },
                ),

                const SizedBox(height: 10),

                _exportOption(
                  icon: Icons.table_chart_outlined,
                  title: 'Export Excel',
                  subtitle: 'Detailed spreadsheet report',
                  value: 'excel',
                  color: Colors.greenAccent,
                  onTap: () {
                    Navigator.pop(sheetContext, 'excel');
                  },
                ),

                const SizedBox(height: 10),

                _exportOption(
                  icon: Icons.print_outlined,
                  title: 'Print',
                  subtitle: 'Print attendance report',
                  value: 'print',
                  color: Colors.blueAccent,
                  onTap: () {
                    Navigator.pop(sheetContext, 'print');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) return;

    await _performExport(choice);
  }

  Widget _exportOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String value,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white12),
        ),
        child: Row(
          children: [
            Container(
              width: 45,
              height: 45,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, color: color, size: 24),
            ),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),

            const Icon(
              Icons.arrow_forward_ios,
              color: Colors.white38,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _performExport(String type) async {
    if (!mounted) return;

    setState(() {
      isExporting = true;
    });

    try {
      final rows = _buildExportRows();

      final safeId = widget.libraryId.replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );

      final periodName = _periodFileName();

      final baseFileName = 'Attendance_${safeId}_$periodName';

      final title = 'Attendance Report - ${widget.name}';

      if (type == 'pdf') {
        await ReportExportService.exportPdf(
          fileName: baseFileName,
          title: _buildExportTitle(title),
          headers: _exportHeaders(),
          rows: rows,
        );
      } else if (type == 'excel') {
        await ReportExportService.exportExcel(
          fileName: baseFileName,
          title: _buildExportTitle(title),
          headers: _exportHeaders(),
          rows: rows,
        );
      } else if (type == 'print') {
        await ReportExportService.printPdf(
          title: _buildExportTitle(title),
          headers: _exportHeaders(),
          rows: rows,
        );
      }

      if (!mounted) return;

      _showMessage(
        type == 'print'
            ? 'Print report prepared.'
            : 'Report exported successfully.',
        Colors.green,
      );
    } catch (e) {
      if (!mounted) return;

      _showMessage('Unable to export report.', Colors.red);
    } finally {
      if (mounted) {
        setState(() {
          isExporting = false;
        });
      }
    }
  }

  String _buildExportTitle(String title) {
    return '$title\n'
        'Library ID: ${widget.libraryId}\n'
        'Period: ${_periodTitle()}\n'
        'Present: $presentDays | '
        'Absent: $absentDays | '
        'Attendance: ${attendancePercentage.toStringAsFixed(0)}% | '
        'Average Study: ${_formatDuration(averageStudyTime)}';
  }

  List<String> _exportHeaders() {
    return [
      'Date',
      'Status',
      'Session',
      'Entry Time',
      'Exit Time',
      'Entry Type',
      'Exit Type',
      'Study Time',
    ];
  }

  List<List<String>> _buildExportRows() {
    final rows = <List<String>>[];

    for (final day in attendanceDays) {
      if (!day.isPresent) {
        rows.add([
          _formatDate(day.date),
          'Absent',
          '-',
          '-',
          '-',
          '-',
          '-',
          '-',
        ]);

        continue;
      }

      if (day.sessions.isEmpty) {
        rows.add([
          _formatDate(day.date),
          'Present',
          '-',
          '-',
          '-',
          '-',
          '-',
          '-',
        ]);

        continue;
      }

      for (int i = 0; i < day.sessions.length; i++) {
        final session = day.sessions[i];

        final entry = _toDateTime(session.entryAt);

        final exit = _toDateTime(session.exitAt);

        Duration duration = Duration.zero;

        if (entry != null && exit != null && exit.isAfter(entry)) {
          duration = exit.difference(entry);
        }

        rows.add([
          _formatDate(day.date),
          'Present',
          '${i + 1}',
          _formatTime(session.entryAt),
          session.exitAt == null ? 'Active' : _formatTime(session.exitAt),
          session.autoEntry ? 'Auto' : 'Manual',
          session.exitAt == null
              ? '-'
              : session.autoExit
              ? 'Auto'
              : 'Manual',
          session.exitAt == null ? '-' : _formatDuration(duration),
        ]);
      }
    }

    return rows;
  }

  String _periodFileName() {
    switch (selectedPeriod) {
      case AttendancePeriod.today:
        return _dateId(_todayOnly());

      case AttendancePeriod.last7Days:
        return 'Last7Days';

      case AttendancePeriod.specificDay:
        return _dateId(selectedDay);

      case AttendancePeriod.specificMonth:
        return '${selectedMonth.year}-'
            '${selectedMonth.month.toString().padLeft(2, '0')}';
    }
  }

  // ============================================================
  // PERIOD SELECTOR
  // ============================================================

  Future<void> _selectPeriod() async {
    AttendancePeriod tempPeriod = selectedPeriod;

    final result = await showDialog<AttendancePeriod>(
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
                'Select Period',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _periodOption(
                    AttendancePeriod.today,
                    'Today',
                    Icons.today,
                    tempPeriod,
                    (value) {
                      tempPeriod = value;
                      setDialogState(() {});
                    },
                  ),

                  _periodOption(
                    AttendancePeriod.last7Days,
                    'Last 7 Days',
                    Icons.date_range,
                    tempPeriod,
                    (value) {
                      tempPeriod = value;
                      setDialogState(() {});
                    },
                  ),

                  _periodOption(
                    AttendancePeriod.specificDay,
                    'Specific Day',
                    Icons.event,
                    tempPeriod,
                    (value) {
                      tempPeriod = value;
                      setDialogState(() {});
                    },
                  ),

                  _periodOption(
                    AttendancePeriod.specificMonth,
                    'Specific Month',
                    Icons.calendar_month,
                    tempPeriod,
                    (value) {
                      tempPeriod = value;
                      setDialogState(() {});
                    },
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, tempPeriod);
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

    if (result == null) return;

    if (!mounted) return;

    setState(() {
      selectedPeriod = result;
    });

    if (result == AttendancePeriod.specificDay) {
      await _selectSpecificDay();
      return;
    }

    if (result == AttendancePeriod.specificMonth) {
      await _selectSpecificMonth();
      return;
    }

    await _loadAttendanceHistory();
  }

  Widget _periodOption(
    AttendancePeriod value,
    String title,
    IconData icon,
    AttendancePeriod current,
    ValueChanged<AttendancePeriod> onChanged,
  ) {
    final selected = current == value;

    return InkWell(
      onTap: () {
        onChanged(value);
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected
              ? Colors.blueAccent.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? Colors.blueAccent : Colors.white12,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? Colors.blueAccent : Colors.white70,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14),
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? Colors.blueAccent : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // SPECIFIC DAY
  // ============================================================

  Future<void> _selectSpecificDay() async {
    final today = _todayOnly();

    final result = await showDatePicker(
      context: context,
      initialDate: selectedDay.isAfter(today) ? today : selectedDay,
      firstDate: DateTime(2020),
      lastDate: today,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.dark(
              primary: Colors.blueAccent,
              surface: Color(0xff1E293B),
            ),
          ),
          child: child!,
        );
      },
    );

    if (result == null) return;

    if (!mounted) return;

    setState(() {
      selectedDay = result;
    });

    await _loadAttendanceHistory();
  }

  // ============================================================
  // SPECIFIC MONTH
  // ============================================================

  Future<void> _selectSpecificMonth() async {
    int month = selectedMonth.month;

    int year = selectedMonth.year;

    final now = DateTime.now();

    final result = await showDialog<DateTime>(
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
                'Select Month',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),

              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: month,
                    dropdownColor: const Color(0xff1E293B),
                    decoration: InputDecoration(
                      labelText: 'Month',
                      labelStyle: GoogleFonts.poppins(color: Colors.white60),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                    ),
                    style: GoogleFonts.poppins(color: Colors.white),
                    items: List.generate(12, (index) {
                      final value = index + 1;

                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(
                          _monthName(value),
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      );
                    }),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setDialogState(() {
                        month = value;
                      });
                    },
                  ),

                  const SizedBox(height: 15),

                  DropdownButtonFormField<int>(
                    initialValue: year,
                    dropdownColor: const Color(0xff1E293B),
                    decoration: InputDecoration(
                      labelText: 'Year',
                      labelStyle: GoogleFonts.poppins(color: Colors.white60),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Colors.white24),
                      ),
                    ),
                    style: GoogleFonts.poppins(color: Colors.white),
                    items: List.generate(11, (index) {
                      final value = now.year - 5 + index;

                      return DropdownMenuItem<int>(
                        value: value,
                        child: Text(
                          '$value',
                          style: GoogleFonts.poppins(color: Colors.white),
                        ),
                      );
                    }),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }

                      setDialogState(() {
                        year = value;
                      });
                    },
                  ),
                ],
              ),

              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext, DateTime(year, month));
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

    if (result == null) return;

    if (!mounted) return;

    setState(() {
      selectedMonth = DateTime(result.year, result.month);
    });

    await _loadAttendanceHistory();
  }

  // ============================================================
  // FORMATTERS
  // ============================================================

  DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;

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

  String _formatTime(dynamic value) {
    final dateTime = _toDateTime(value);

    if (dateTime == null) {
      return '--:--';
    }

    final hour = dateTime.hour;

    final minute = dateTime.minute;

    final hour12 = hour == 0
        ? 12
        : hour > 12
        ? hour - 12
        : hour;

    final period = hour >= 12 ? 'PM' : 'AM';

    return '${hour12.toString().padLeft(2, '0')}:'
        '${minute.toString().padLeft(2, '0')} '
        '$period';
  }

  String _formatDate(DateTime date) {
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

    return '${date.day} '
        '${months[date.month - 1]} '
        '${date.year}';
  }

  String _formatMonth(DateTime date) {
    return '${_monthName(date.month)} '
        '${date.year}';
  }

  String _monthName(int month) {
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

    return months[month - 1];
  }

  String _formatDuration(Duration duration) {
    if (duration <= Duration.zero) {
      return '0m';
    }

    final hours = duration.inHours;

    final minutes = duration.inMinutes.remainder(60);

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }

    return '${minutes}m';
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
          'Attendance History',
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          isExporting
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                )
              : IconButton(
                  tooltip: 'Export',
                  onPressed: _showExportOptions,
                  icon: const Icon(
                    Icons.file_download_outlined,
                    color: Colors.white,
                  ),
                ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: _loadAttendanceHistory,

        color: Colors.blueAccent,

        backgroundColor: const Color(0xff1E293B),

        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),

          padding: const EdgeInsets.all(20),

          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,

            children: [
              Text(
                widget.name,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                widget.libraryId,
                style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // PERIOD
              // ==================================================
              InkWell(
                onTap: _selectPeriod,

                borderRadius: BorderRadius.circular(18),

                child: Container(
                  width: double.infinity,

                  padding: const EdgeInsets.all(16),

                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),

                    borderRadius: BorderRadius.circular(18),

                    border: Border.all(color: Colors.white24),
                  ),

                  child: Row(
                    children: [
                      const Icon(
                        Icons.date_range,
                        color: Colors.white,
                        size: 25,
                      ),

                      const SizedBox(width: 13),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,

                          children: [
                            Text(
                              'Attendance Period',
                              style: GoogleFonts.poppins(
                                color: Colors.white60,
                                fontSize: 11,
                              ),
                            ),

                            const SizedBox(height: 2),

                            Text(
                              _periodTitle(),
                              style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ==================================================
              // SUMMARY
              // ==================================================
              Container(
                width: double.infinity,

                padding: const EdgeInsets.all(18),

                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.10),

                  borderRadius: BorderRadius.circular(20),

                  border: Border.all(color: Colors.white24),
                ),

                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _summaryItem(
                            'Present',
                            '$presentDays',
                            Colors.greenAccent,
                          ),
                        ),

                        Container(height: 45, width: 1, color: Colors.white24),

                        Expanded(
                          child: _summaryItem(
                            'Absent',
                            '$absentDays',
                            Colors.redAccent,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    const Divider(color: Colors.white24, height: 1),

                    const SizedBox(height: 18),

                    Row(
                      children: [
                        Expanded(
                          child: _summaryItem(
                            'Attendance',
                            '${attendancePercentage.toStringAsFixed(0)}%',
                            Colors.blueAccent,
                          ),
                        ),

                        Container(height: 45, width: 1, color: Colors.white24),

                        Expanded(
                          child: _summaryItem(
                            'Avg Study',
                            _formatDuration(averageStudyTime),
                            Colors.orangeAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              Text(
                'Attendance Records',
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 15),

              if (isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(50),
                    child: CircularProgressIndicator(color: Colors.blueAccent),
                  ),
                )
              else if (errorMessage != null)
                _errorWidget()
              else if (attendanceDays.isEmpty)
                _emptyWidget()
              else
                ...List.generate(attendanceDays.length, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == attendanceDays.length - 1 ? 0 : 15,
                    ),
                    child: _attendanceDayCard(attendanceDays[index]),
                  );
                }),

              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summaryItem(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 4),

        Text(
          title,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11),
        ),
      ],
    );
  }

  // ============================================================
  // DAY CARD
  // ============================================================

  Widget _attendanceDayCard(_AttendanceDay day) {
    final isPresent = day.isPresent;

    return Container(
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

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),

                decoration: BoxDecoration(
                  color: isPresent
                      ? Colors.green.withValues(alpha: 0.20)
                      : Colors.red.withValues(alpha: 0.20),

                  borderRadius: BorderRadius.circular(20),
                ),

                child: Text(
                  isPresent ? 'Present' : 'Absent',
                  style: GoogleFonts.poppins(
                    color: isPresent ? Colors.greenAccent : Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          if (isPresent) ...[
            const SizedBox(height: 15),

            Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),

            const SizedBox(height: 12),

            Text(
              'Sessions: ${day.sessions.length} / 3',
              style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
            ),

            const SizedBox(height: 10),

            if (day.sessions.isEmpty)
              Text(
                'No session details available.',
                style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
              )
            else
              ...List.generate(day.sessions.length, (index) {
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index == day.sessions.length - 1 ? 0 : 8,
                  ),
                  child: _sessionRow(day.date, index, day.sessions[index]),
                );
              }),
          ] else ...[
            const SizedBox(height: 10),

            Text(
              'No attendance recorded.',
              style: GoogleFonts.poppins(color: Colors.white54, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _sessionRow(
    DateTime day,
    int sessionIndex,
    _AttendanceSession session,
  ) {
    final isActive = session.exitAt == null;

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
              '${sessionIndex + 1}',
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
                  _formatTime(session.entryAt),
                  style: GoogleFonts.poppins(
                    color: Colors.greenAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (session.autoEntry)
                  Text(
                    'AUTO',
                    style: GoogleFonts.poppins(
                      color: Colors.orangeAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
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
                  isActive ? 'Active' : _formatTime(session.exitAt),
                  style: GoogleFonts.poppins(
                    color: isActive ? Colors.blueAccent : Colors.orangeAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (session.autoExit)
                  Text(
                    'AUTO',
                    style: GoogleFonts.poppins(
                      color: Colors.orangeAccent,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _emptyWidget() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(25),

      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.white24),
      ),

      child: Column(
        children: [
          const Icon(
            Icons.event_busy_outlined,
            color: Colors.white38,
            size: 45,
          ),

          const SizedBox(height: 12),

          Text(
            'No attendance records',
            style: GoogleFonts.poppins(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            'No attendance found for ${_periodTitle()}.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _errorWidget() {
    return Container(
      width: double.infinity,

      padding: const EdgeInsets.all(25),

      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),

        borderRadius: BorderRadius.circular(18),

        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),

      child: Column(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 42),

          const SizedBox(height: 12),

          Text(
            errorMessage ?? 'Something went wrong.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
          ),

          const SizedBox(height: 12),

          ElevatedButton(
            onPressed: _loadAttendanceHistory,
            child: const Text('RETRY'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// MODELS
// ============================================================

class _AttendanceDay {
  final DateTime date;
  final bool isPresent;
  final List<_AttendanceSession> sessions;

  const _AttendanceDay({
    required this.date,
    required this.isPresent,
    required this.sessions,
  });
}

class _AttendanceSession {
  final dynamic entryAt;
  final dynamic exitAt;
  final bool autoEntry;
  final bool autoExit;

  const _AttendanceSession({
    required this.entryAt,
    required this.exitAt,
    required this.autoEntry,
    required this.autoExit,
  });
}
