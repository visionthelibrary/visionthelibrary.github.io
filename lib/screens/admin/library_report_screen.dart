import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/report_export_service.dart';

class LibraryReportScreen extends StatefulWidget {
  const LibraryReportScreen({super.key});

  @override
  State<LibraryReportScreen> createState() => _LibraryReportScreenState();
}

class _LibraryReportScreenState extends State<LibraryReportScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  DateTime selectedDate = DateTime.now();
  DateTime? specificDate;
  DateTime? specificMonth;

  String selectedPeriod = "Today";

  bool isLoading = true;
  String? errorMessage;

  int totalStudents = 0;
  int presentStudents = 0;
  int absentStudents = 0;

  int boysCount = 0;
  int girlsCount = 0;

  double attendancePercentage = 0;

  Duration averageStudyTime = Duration.zero;

  List<_DailyReport> dailyReports = [];

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

  DateTime _todayOnly() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime _endOfMonth(DateTime date) {
    return DateTime(date.year, date.month + 1, 0);
  }

  DateTime _getStartDate() {
    final today = _todayOnly();

    switch (selectedPeriod) {
      case "Today":
        return today;

      case "Last 7 Days":
        return today.subtract(const Duration(days: 6));

      case "Specific Day":
        final date = specificDate ?? today;
        return DateTime(date.year, date.month, date.day);

      case "Specific Month":
        final date = specificMonth ?? today;
        return DateTime(date.year, date.month, 1);

      default:
        return today;
    }
  }

  DateTime _getEndDate() {
    final today = _todayOnly();

    switch (selectedPeriod) {
      case "Today":
        return today;

      case "Last 7 Days":
        return today;

      case "Specific Day":
        final date = specificDate ?? today;
        return DateTime(date.year, date.month, date.day);

      case "Specific Month":
        final date = specificMonth ?? today;
        final end = _endOfMonth(date);

        if (end.isAfter(today)) {
          return today;
        }

        return end;

      default:
        return today;
    }
  }

  // ============================================================
  // MAIN REPORT LOADER
  // ============================================================

  Future<void> _loadReport() async {
    if (!mounted) return;

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      final studentsSnapshot = await _firestore.collection('students').get();

      final students = studentsSnapshot.docs;

      final startDate = _getStartDate();
      final endDate = _getEndDate();

      final List<_StudentReportData> studentReports = [];

      int boys = 0;
      int girls = 0;

      for (final studentDocument in students) {
        final studentData = studentDocument.data();

        final String libraryId =
            studentData['libraryId']?.toString() ?? studentDocument.id;

        final String name =
            studentData['name']?.toString() ?? "Unknown Student";

        final String gender = studentData['gender']?.toString() ?? "";

        final String seat = studentData['seat']?.toString() ?? "";

        final genderLower = gender.toLowerCase();

        if (genderLower == "male" ||
            genderLower == "boy" ||
            genderLower == "boys") {
          boys++;
        } else if (genderLower == "female" ||
            genderLower == "girl" ||
            genderLower == "girls") {
          girls++;
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

          final String date = data['date']?.toString() ?? document.id;

          attendanceByDate[date] = data;
        }

        studentReports.add(
          _StudentReportData(
            libraryId: libraryId,
            name: name,
            gender: gender,
            seat: seat,
            attendanceByDate: attendanceByDate,
          ),
        );
      }

      final List<_DailyReport> reports = [];

      DateTime current = startDate;

      while (!current.isAfter(endDate)) {
        final String currentId = _dateId(current);

        int present = 0;
        int absent = 0;

        Duration studyTime = Duration.zero;
        int presentStudyRecords = 0;

        for (final student in studentReports) {
          final data = student.attendanceByDate[currentId];

          if (data == null) {
            absent++;
            continue;
          }

          final status = data['status']?.toString() ?? "";

          if (status == "Present" || status == "Completed") {
            present++;

            final sessionResult = _calculateSessions(data);

            if (sessionResult.studyTime > Duration.zero) {
              studyTime += sessionResult.studyTime;
              presentStudyRecords++;
            }
          } else {
            absent++;
          }
        }

        final int totalForDay = present + absent;

        final double percentage = totalForDay == 0
            ? 0
            : (present / totalForDay) * 100;

        final Duration dailyAverage = presentStudyRecords == 0
            ? Duration.zero
            : Duration(
                milliseconds: studyTime.inMilliseconds ~/ presentStudyRecords,
              );

        reports.add(
          _DailyReport(
            date: current,
            present: present,
            absent: absent,
            percentage: percentage,
            studyTime: studyTime,
            averageStudyTime: dailyAverage,
          ),
        );

        current = current.add(const Duration(days: 1));
      }

      // ========================================================
      // OVERALL PERIOD CALCULATION
      // ========================================================

      int totalPresent = 0;
      int totalAbsent = 0;

      Duration totalPresentStudyTime = Duration.zero;

      int totalPresentStudyRecords = 0;

      for (final report in reports) {
        totalPresent += report.present;
        totalAbsent += report.absent;

        if (report.averageStudyTime > Duration.zero && report.present > 0) {
          totalPresentStudyTime += Duration(
            milliseconds:
                report.averageStudyTime.inMilliseconds * report.present,
          );

          totalPresentStudyRecords += report.present;
        }
      }

      final int totalAttendance = totalPresent + totalAbsent;

      final double percentage = totalAttendance == 0
          ? 0
          : (totalPresent / totalAttendance) * 100;

      final Duration overallAverage = totalPresentStudyRecords == 0
          ? Duration.zero
          : Duration(
              milliseconds:
                  totalPresentStudyTime.inMilliseconds ~/
                  totalPresentStudyRecords,
            );

      // For single-day period, overview is naturally
      // that day's present/absent.

      if (!mounted) return;

      setState(() {
        totalStudents = students.length;

        presentStudents = totalPresent;
        absentStudents = totalAbsent;

        boysCount = boys;
        girlsCount = girls;

        attendancePercentage = percentage;

        averageStudyTime = overallAverage;

        dailyReports = reports.reversed.toList();

        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
        errorMessage =
            "Failed to load report.\nPlease check your internet connection.";
      });
    }
  }

  // ============================================================
  // SESSION CALCULATION
  // ============================================================

  _SessionCalculation _calculateSessions(Map<String, dynamic> data) {
    final rawSessions = data['sessions'];

    if (rawSessions is List) {
      Duration total = Duration.zero;

      for (final item in rawSessions) {
        if (item is! Map) continue;

        final session = Map<String, dynamic>.from(item);

        final entry = _toDateTime(session['entryAt']);

        final exit = _toDateTime(session['exitAt']);

        if (entry != null && exit != null && exit.isAfter(entry)) {
          total += exit.difference(entry);
        }
      }

      return _SessionCalculation(studyTime: total);
    }

    final entry = _toDateTime(data['entryAt']);

    final exit = _toDateTime(data['exitAt']);

    if (entry == null || exit == null || !exit.isAfter(entry)) {
      return const _SessionCalculation(studyTime: Duration.zero);
    }

    return _SessionCalculation(studyTime: exit.difference(entry));
  }

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

  // ============================================================
  // PERIOD LABEL
  // ============================================================

  String _periodDescription() {
    switch (selectedPeriod) {
      case "Today":
        return _formatDate(_getStartDate());

      case "Last 7 Days":
        return "${_formatShortDate(_getStartDate())} - "
            "${_formatShortDate(_getEndDate())}";

      case "Specific Day":
        return _formatDate(_getStartDate());

      case "Specific Month":
        final date = _getStartDate();

        return "${_monthName(date.month)} ${date.year}";

      default:
        return "";
    }
  }

  // ============================================================
  // DATE PICKERS
  // ============================================================

  Future<void> _selectSpecificDay() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: specificDate ?? now,
      firstDate: DateTime(2020),
      lastDate: now,
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

    if (picked == null) return;

    setState(() {
      specificDate = picked;
    });

    await _loadReport();
  }

  Future<void> _selectSpecificMonth() async {
    final now = DateTime.now();

    int selectedYear = (specificMonth ?? now).year;

    int selectedMonth = (specificMonth ?? now).month;

    await showDialog(
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
                "Select Month",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: selectedMonth,
                    dropdownColor: const Color(0xff1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Month",
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    items: List.generate(12, (index) {
                      final month = index + 1;

                      return DropdownMenuItem(
                        value: month,
                        child: Text(_monthName(month)),
                      );
                    }),
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selectedMonth = value;
                      });
                    },
                  ),

                  const SizedBox(height: 18),

                  DropdownButtonFormField<int>(
                    initialValue: selectedYear,
                    dropdownColor: const Color(0xff1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      labelText: "Year",
                      labelStyle: TextStyle(color: Colors.white70),
                    ),
                    items: List.generate(7, (index) {
                      final year = now.year - index;

                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) {
                      if (value == null) return;

                      setDialogState(() {
                        selectedYear = value;
                      });
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Cancel"),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      specificMonth = DateTime(selectedYear, selectedMonth, 1);
                    });

                    Navigator.pop(dialogContext);

                    _loadReport();
                  },
                  child: const Text("Apply"),
                ),
              ],
            );
          },
        );
      },
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
          "Library Report",
          style: GoogleFonts.poppins(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.bold,
          ),
        ),

        actions: [
          IconButton(
            tooltip: "Export Report",
            onPressed: isLoading ? null : _showExportDialog,
            icon: const Icon(Icons.file_download_outlined, color: Colors.white),
          ),

          const SizedBox(width: 8),
        ],
      ),

      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : errorMessage != null
          ? _errorView()
          : RefreshIndicator(
              onRefresh: _loadReport,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _periodSelector(),

                    const SizedBox(height: 12),

                    Text(
                      _periodDescription(),
                      style: GoogleFonts.poppins(
                        color: Colors.white60,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 25),

                    Text(
                      "Overview",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    _overviewGrid(),

                    const SizedBox(height: 30),

                    _attendanceTrend(),

                    const SizedBox(height: 30),

                    _calendarSection(),

                    const SizedBox(height: 30),

                    _genderAnalysis(),

                    const SizedBox(height: 30),

                    Text(
                      "Detailed Attendance",
                      style: GoogleFonts.poppins(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 15),

                    if (dailyReports.isEmpty)
                      _emptyView()
                    else
                      ...dailyReports.map(
                        (report) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _historyCard(report),
                        ),
                      ),

                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  // ============================================================
  // PERIOD SELECTOR
  // ============================================================

  Widget _periodSelector() {
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
            "Report Period",
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 12),

          DropdownButtonFormField<String>(
            initialValue: selectedPeriod,
            dropdownColor: const Color(0xff1E293B),
            style: GoogleFonts.poppins(color: Colors.white),
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.date_range_outlined,
                color: Colors.white70,
              ),
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.08),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
            items: const [
              DropdownMenuItem(value: "Today", child: Text("Today")),
              DropdownMenuItem(
                value: "Last 7 Days",
                child: Text("Last 7 Days"),
              ),
              DropdownMenuItem(
                value: "Specific Day",
                child: Text("Specific Day"),
              ),
              DropdownMenuItem(
                value: "Specific Month",
                child: Text("Specific Month"),
              ),
            ],
            onChanged: (value) async {
              if (value == null) return;

              setState(() {
                selectedPeriod = value;
              });

              if (value == "Specific Day") {
                await _selectSpecificDay();
                return;
              }

              if (value == "Specific Month") {
                await _selectSpecificMonth();
                return;
              }

              await _loadReport();
            },
          ),

          if (selectedPeriod == "Specific Day") ...[
            const SizedBox(height: 12),
            _selectorActionButton(
              icon: Icons.calendar_today,
              text: specificDate == null
                  ? "Select Date"
                  : _formatDate(specificDate!),
              onTap: _selectSpecificDay,
            ),
          ],

          if (selectedPeriod == "Specific Month") ...[
            const SizedBox(height: 12),
            _selectorActionButton(
              icon: Icons.calendar_month_outlined,
              text: specificMonth == null
                  ? "Select Month"
                  : "${_monthName(specificMonth!.month)} "
                        "${specificMonth!.year}",
              onTap: _selectSpecificMonth,
            ),
          ],
        ],
      ),
    );
  }

  Widget _selectorActionButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white70),
        label: Text(text, style: GoogleFonts.poppins(color: Colors.white)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 13),
          side: const BorderSide(color: Colors.white24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // OVERVIEW GRID
  // ============================================================

  Widget _overviewGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _reportCard(
                title: "Total Students",
                value: totalStudents.toString(),
                icon: Icons.people_outline,
                valueColor: Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _reportCard(
                title: "Present",
                value: presentStudents.toString(),
                icon: Icons.check_circle_outline,
                valueColor: Colors.greenAccent,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _reportCard(
                title: "Absent",
                value: absentStudents.toString(),
                icon: Icons.cancel_outlined,
                valueColor: Colors.redAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _reportCard(
                title: "Attendance",
                value: _formatPercentage(attendancePercentage),
                icon: Icons.insights_outlined,
                valueColor: Colors.orangeAccent,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _reportCard(
                title: "Boys",
                value: boysCount.toString(),
                icon: Icons.male_outlined,
                valueColor: Colors.lightBlueAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _reportCard(
                title: "Girls",
                value: girlsCount.toString(),
                icon: Icons.female_outlined,
                valueColor: Colors.pinkAccent,
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: _reportCard(
                title: "Average Study Time",
                value: _formatDuration(averageStudyTime),
                icon: Icons.access_time_outlined,
                valueColor: Colors.cyanAccent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InkWell(
                onTap: isLoading ? null : _loadReport,
                borderRadius: BorderRadius.circular(18),
                child: _reportCard(
                  title: "Refresh",
                  value: "",
                  icon: Icons.refresh,
                  valueColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _reportCard({
    required String title,
    required String value,
    required IconData icon,
    required Color valueColor,
  }) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: valueColor, size: 27),

          const Spacer(),

          if (value.isNotEmpty)
            Text(
              value,
              style: GoogleFonts.poppins(
                color: valueColor,
                fontSize: 21,
                fontWeight: FontWeight.bold,
              ),
            ),

          const SizedBox(height: 3),

          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // ATTENDANCE TREND
  // ============================================================

  Widget _attendanceTrend() {
    if (dailyReports.isEmpty) {
      return const SizedBox.shrink();
    }

    final reports = dailyReports.reversed.toList();

    final maxValue = reports.fold<double>(
      0,
      (max, item) => item.percentage > max ? item.percentage : max,
    );

    return _sectionCard(
      title: "Attendance Trend",
      icon: Icons.show_chart,
      child: Column(
        children: [
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                ...reports.map((report) {
                  final height = maxValue == 0
                      ? 0.0
                      : (report.percentage / 100) * 130;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            "${report.percentage.toStringAsFixed(0)}%",
                            style: GoogleFonts.poppins(
                              color: Colors.white70,
                              fontSize: 8,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Container(
                            height: height.clamp(3.0, 130.0),
                            decoration: BoxDecoration(
                              color: Colors.blueAccent,
                              borderRadius: BorderRadius.circular(5),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            "${report.date.day}",
                            style: GoogleFonts.poppins(
                              color: Colors.white54,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 8),

          Text(
            "Daily attendance percentage for ${_periodDescription()}",
            style: GoogleFonts.poppins(color: Colors.white54, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CALENDAR
  // ============================================================

  Widget _calendarSection() {
    if (selectedPeriod != "Specific Month" && dailyReports.length > 7) {
      return const SizedBox.shrink();
    }

    final reportsByDate = {
      for (final report in dailyReports) _dateId(report.date): report,
    };

    return _sectionCard(
      title: "Attendance Calendar",
      icon: Icons.calendar_month_outlined,
      child: _buildCalendar(reportsByDate),
    );
  }

  Widget _buildCalendar(Map<String, _DailyReport> reportsByDate) {
    final date = _getStartDate();

    final firstDay = DateTime(date.year, date.month, 1);

    final daysInMonth = DateTime(date.year, date.month + 1, 0).day;

    final leadingEmpty = firstDay.weekday - 1;

    final totalCells = leadingEmpty + daysInMonth;

    return Column(
      children: [
        Row(
          children: [
            ...["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"].map(
              (day) => Expanded(
                child: Center(
                  child: Text(
                    day,
                    style: GoogleFonts.poppins(
                      color: Colors.white54,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 7,
            crossAxisSpacing: 7,
          ),
          itemBuilder: (context, index) {
            if (index < leadingEmpty) {
              return const SizedBox();
            }

            final day = index - leadingEmpty + 1;

            final currentDate = DateTime(date.year, date.month, day);

            final report = reportsByDate[_dateId(currentDate)];

            Color background = Colors.white.withValues(alpha: 0.06);

            if (report != null) {
              if (report.present > 0) {
                background = Colors.green.withValues(alpha: 0.30);
              } else {
                background = Colors.red.withValues(alpha: 0.25);
              }
            }

            return Container(
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white12),
              ),
              child: Center(
                child: Text(
                  day.toString(),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  // ============================================================
  // GENDER ANALYSIS
  // ============================================================

  Widget _genderAnalysis() {
    final totalGender = boysCount + girlsCount;

    final boysPercentage = totalGender == 0
        ? 0.0
        : boysCount / totalGender * 100;

    final girlsPercentage = totalGender == 0
        ? 0.0
        : girlsCount / totalGender * 100;

    return _sectionCard(
      title: "Gender Analysis",
      icon: Icons.people_outline,
      child: Column(
        children: [
          _genderRow("Boys", boysCount, boysPercentage, Colors.lightBlueAccent),

          const SizedBox(height: 14),

          _genderRow("Girls", girlsCount, girlsPercentage, Colors.pinkAccent),
        ],
      ),
    );
  }

  Widget _genderRow(String title, int count, double percentage, Color color) {
    return Column(
      children: [
        Row(
          children: [
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
              "$count (${percentage.toStringAsFixed(1)}%)",
              style: GoogleFonts.poppins(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),

        const SizedBox(height: 7),

        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: percentage / 100,
            minHeight: 8,
            backgroundColor: Colors.white12,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SECTION CARD
  // ============================================================

  Widget _sectionCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white70, size: 21),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          child,
        ],
      ),
    );
  }

  // ============================================================
  // HISTORY
  // ============================================================

  Widget _historyCard(_DailyReport report) {
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
                  _formatDate(report.date),
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

              Text(
                _formatPercentage(report.percentage),
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
                child: _historyValue(
                  "Present",
                  report.present.toString(),
                  Colors.greenAccent,
                ),
              ),

              _verticalDivider(),

              Expanded(
                child: _historyValue(
                  "Absent",
                  report.absent.toString(),
                  Colors.redAccent,
                ),
              ),

              _verticalDivider(),

              Expanded(
                child: _historyValue(
                  "Average Study",
                  _formatDuration(report.averageStudyTime),
                  Colors.cyanAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _verticalDivider() {
    return Container(width: 1, height: 35, color: Colors.white24);
  }

  Widget _historyValue(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            color: color,
            fontSize: 15,
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

  // ============================================================
  // EXPORT DIALOG
  // ============================================================

  void _showExportDialog() {
    String exportPeriod = selectedPeriod;

    DateTime? exportDate = specificDate;

    DateTime? exportMonth = specificMonth;

    String format = "PDF";

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
                "Export Report",
                style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Report Period",
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),

                    const SizedBox(height: 8),

                    DropdownButtonFormField<String>(
                      initialValue: exportPeriod,
                      dropdownColor: const Color(0xff1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        filled: true,
                        fillColor: Colors.white10,
                      ),
                      items: const [
                        DropdownMenuItem(value: "Today", child: Text("Today")),
                        DropdownMenuItem(
                          value: "Last 7 Days",
                          child: Text("Last 7 Days"),
                        ),
                        DropdownMenuItem(
                          value: "Specific Day",
                          child: Text("Specific Day"),
                        ),
                        DropdownMenuItem(
                          value: "Specific Month",
                          child: Text("Specific Month"),
                        ),
                      ],
                      onChanged: (value) {
                        if (value == null) {
                          return;
                        }

                        setDialogState(() {
                          exportPeriod = value;
                        });
                      },
                    ),

                    const SizedBox(height: 18),

                    if (exportPeriod == "Specific Day")
                      OutlinedButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();

                          final picked = await showDatePicker(
                            context: context,
                            initialDate: exportDate ?? now,
                            firstDate: DateTime(2020),
                            lastDate: now,
                          );

                          if (picked == null) {
                            return;
                          }

                          setDialogState(() {
                            exportDate = picked;
                          });
                        },
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          exportDate == null
                              ? "Select Date"
                              : _formatDate(exportDate!),
                        ),
                      ),

                    if (exportPeriod == "Specific Month")
                      OutlinedButton.icon(
                        onPressed: () async {
                          final now = DateTime.now();

                          final picked = await showDatePicker(
                            context: context,
                            initialDate: exportMonth ?? now,
                            firstDate: DateTime(2020),
                            lastDate: now,
                            initialDatePickerMode: DatePickerMode.year,
                          );

                          if (picked == null) {
                            return;
                          }

                          setDialogState(() {
                            exportMonth = DateTime(
                              picked.year,
                              picked.month,
                              1,
                            );
                          });
                        },
                        icon: const Icon(Icons.calendar_month),
                        label: Text(
                          exportMonth == null
                              ? "Select Month"
                              : "${_monthName(exportMonth!.month)} "
                                    "${exportMonth!.year}",
                        ),
                      ),

                    const SizedBox(height: 18),

                    Text(
                      "Format",
                      style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),

                    RadioGroup<String>(
                      groupValue: format,
                      onChanged: (value) {
                        if (value == null) return;

                        setDialogState(() {
                          format = value;
                        });
                      },
                      child: Column(
                        children: [
                          RadioListTile<String>(
                            value: "PDF",
                            title: Text(
                              "PDF",
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                          ),

                          RadioListTile<String>(
                            value: "Excel",
                            title: Text(
                              "Excel",
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                          ),

                          RadioListTile<String>(
                            value: "Print",
                            title: Text(
                              "Print",
                              style: GoogleFonts.poppins(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text("Cancel"),
                ),

                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dialogContext);

                    _performExport(
                      period: exportPeriod,
                      date: exportDate,
                      month: exportMonth,
                      format: format,
                    );
                  },
                  icon: const Icon(Icons.file_download),
                  label: const Text("EXPORT"),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ============================================================
  // EXPORT
  // ============================================================

  Future<void> _performExport({
    required String period,
    required DateTime? date,
    required DateTime? month,
    required String format,
  }) async {
    try {
      final studentsSnapshot = await _firestore.collection('students').get();

      final startDate = _exportStartDate(period, date, month);

      final endDate = _exportEndDate(period, date, month);

      final headers = <String>[
        "Date",
        "Present",
        "Absent",
        "Attendance %",
        "Average Study Time",
      ];

      final rows = <List<String>>[];

      DateTime current = startDate;

      while (!current.isAfter(endDate)) {
        int present = 0;
        int absent = 0;

        Duration totalStudy = Duration.zero;

        int studyRecords = 0;

        for (final student in studentsSnapshot.docs) {
          final libraryId =
              student.data()['libraryId']?.toString() ?? student.id;

          final attendance = await _firestore
              .collection('attendance')
              .doc(libraryId)
              .collection('days')
              .doc(_dateId(current))
              .get();

          if (!attendance.exists) {
            absent++;
            continue;
          }

          final data = attendance.data();

          if (data == null) {
            absent++;
            continue;
          }

          final status = data['status']?.toString() ?? "";

          if (status == "Present" || status == "Completed") {
            present++;

            final calculation = _calculateSessions(data);

            if (calculation.studyTime > Duration.zero) {
              totalStudy += calculation.studyTime;

              studyRecords++;
            }
          } else {
            absent++;
          }
        }

        final total = present + absent;

        final percentage = total == 0 ? 0.0 : present / total * 100;

        final average = studyRecords == 0
            ? Duration.zero
            : Duration(milliseconds: totalStudy.inMilliseconds ~/ studyRecords);

        rows.add([
          _formatDate(current),
          present.toString(),
          absent.toString(),
          _formatPercentage(percentage),
          _formatDuration(average),
        ]);

        current = current.add(const Duration(days: 1));
      }

      final fileName =
          "Vision_The_Library_Report_"
          "${period.replaceAll(' ', '_')}";

      if (format == "PDF") {
        await ReportExportService.exportPdf(
          fileName: fileName,
          title:
              "Vision The Library - Library Report\n"
              "${_exportPeriodText(period, date, month)}",
          headers: headers,
          rows: rows,
        );
      } else if (format == "Excel") {
        await ReportExportService.exportExcel(
          fileName: fileName,
          title:
              "Vision The Library - Library Report\n"
              "${_exportPeriodText(period, date, month)}",
          headers: headers,
          rows: rows,
        );
      } else {
        await ReportExportService.printPdf(
          title:
              "Vision The Library - Library Report\n"
              "${_exportPeriodText(period, date, month)}",
          headers: headers,
          rows: rows,
        );
      }
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Unable to export report."),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  DateTime _exportStartDate(String period, DateTime? date, DateTime? month) {
    final today = _todayOnly();

    switch (period) {
      case "Today":
        return today;

      case "Last 7 Days":
        return today.subtract(const Duration(days: 6));

      case "Specific Day":
        final value = date ?? today;

        return DateTime(value.year, value.month, value.day);

      case "Specific Month":
        final value = month ?? today;

        return DateTime(value.year, value.month, 1);

      default:
        return today;
    }
  }

  DateTime _exportEndDate(String period, DateTime? date, DateTime? month) {
    final today = _todayOnly();

    switch (period) {
      case "Today":
        return today;

      case "Last 7 Days":
        return today;

      case "Specific Day":
        final value = date ?? today;

        return DateTime(value.year, value.month, value.day);

      case "Specific Month":
        final value = month ?? today;

        final end = _endOfMonth(value);

        return end.isAfter(today) ? today : end;

      default:
        return today;
    }
  }

  String _exportPeriodText(String period, DateTime? date, DateTime? month) {
    switch (period) {
      case "Today":
        return _formatDate(_todayOnly());

      case "Last 7 Days":
        return "${_formatDate(_todayOnly().subtract(const Duration(days: 6)))} - ${_formatDate(_todayOnly())}";

      case "Specific Day":
        return _formatDate(date ?? _todayOnly());

      case "Specific Month":
        final value = month ?? _todayOnly();

        return "${_monthName(value.month)} "
            "${value.year}";

      default:
        return "";
    }
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String _formatDate(DateTime date) {
    const months = [
      "Jan",
      "Feb",
      "Mar",
      "Apr",
      "May",
      "Jun",
      "Jul",
      "Aug",
      "Sep",
      "Oct",
      "Nov",
      "Dec",
    ];

    return "${date.day} "
        "${months[date.month - 1]} "
        "${date.year}";
  }

  String _formatShortDate(DateTime date) {
    return "${date.day}/${date.month}";
  }

  String _monthName(int month) {
    const months = [
      "January",
      "February",
      "March",
      "April",
      "May",
      "June",
      "July",
      "August",
      "September",
      "October",
      "November",
      "December",
    ];

    return months[month - 1];
  }

  String _formatPercentage(double value) {
    return "${value.toStringAsFixed(1)}%";
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;

    final minutes = duration.inMinutes % 60;

    if (hours == 0 && minutes == 0) {
      return "0h";
    }

    if (hours == 0) {
      return "${minutes}m";
    }

    if (minutes == 0) {
      return "${hours}h";
    }

    return "${hours}h ${minutes}m";
  }

  // ============================================================
  // EMPTY / ERROR
  // ============================================================

  Widget _emptyView() {
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
          const Icon(Icons.bar_chart_outlined, color: Colors.white54, size: 45),

          const SizedBox(height: 12),

          Text(
            "No attendance data found",
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _errorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 50),

            const SizedBox(height: 15),

            Text(
              errorMessage ?? "Something went wrong",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(color: Colors.white70, fontSize: 14),
            ),

            const SizedBox(height: 20),

            ElevatedButton(onPressed: _loadReport, child: const Text("Retry")),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// DATA MODELS
// ============================================================

class _DailyReport {
  final DateTime date;
  final int present;
  final int absent;
  final double percentage;
  final Duration studyTime;
  final Duration averageStudyTime;

  const _DailyReport({
    required this.date,
    required this.present,
    required this.absent,
    required this.percentage,
    required this.studyTime,
    required this.averageStudyTime,
  });
}

class _StudentReportData {
  final String libraryId;
  final String name;
  final String gender;
  final String seat;
  final Map<String, Map<String, dynamic>> attendanceByDate;

  const _StudentReportData({
    required this.libraryId,
    required this.name,
    required this.gender,
    required this.seat,
    required this.attendanceByDate,
  });
}

class _SessionCalculation {
  final Duration studyTime;

  const _SessionCalculation({required this.studyTime});
}
