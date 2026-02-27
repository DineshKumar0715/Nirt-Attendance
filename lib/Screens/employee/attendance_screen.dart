import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../models/user_model.dart';
import '../../models/leave_request.dart';
import 'checkin_checkout_screen.dart';

/// A screen that displays an employee's attendance records in a calendar view.
///
/// This screen provides a comprehensive view of the user's attendance,
/// including a calendar to visualize present, absent, and leave days,
/// details for a selected day, today's status, and a monthly summary.
class AttendanceScreen extends StatefulWidget {
  /// Creates an [AttendanceScreen].
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

/// The state for the [AttendanceScreen].
///
/// Manages the calendar's focused and selected days, fetches attendance and
/// leave data from Firestore, and builds the various UI components of the screen.
class _AttendanceScreenState extends State<AttendanceScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, dynamic> _events = {};
  bool _isLoadingCalendar = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final user = Provider.of<AppUser?>(context, listen: false);
      if (user != null) {
        _fetchMonthData(user.uid, _focusedDay);
      }
    });
  }

  /// Fetches attendance and leave data for a specific month from Firestore.
  ///
  /// This method populates the `_events` map, which is used to render the
  /// status of each day in the calendar (e.g., Present, Absent, Leave).
  /// It also marks past days without any record as 'Absent'.
  ///
  /// - [uid]: The unique ID of the user.
  /// - [month]: The month for which to fetch data.
  Future<void> _fetchMonthData(String uid, DateTime month) async {
    setState(() => _isLoadingCalendar = true);

    final startOfMonth = DateTime(month.year, month.month, 1);
    final endOfMonth = DateTime(month.year, month.month + 1, 0);
    final today = DateTime.now();
    
    final attendanceSnapshot = await FirebaseFirestore.instance
        .collection('attendance')
        .where('uid', isEqualTo: uid)
        .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startOfMonth))
        .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endOfMonth))
        .get();

    final leaveSnapshot = await FirebaseFirestore.instance
        .collection('leaves')
        .where('uid', isEqualTo: uid)
        .where('status', isEqualTo: 'approved')
        .where('fromDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
        .get();

    final Map<DateTime, dynamic> eventsMap = {};

    for (var doc in attendanceSnapshot.docs) {
      final date = DateTime.parse(doc.data()['date']);
      eventsMap[DateTime.utc(date.year, date.month, date.day)] = {'type': 'Present', 'data': doc.data()};
    }

    for (var doc in leaveSnapshot.docs) {
      final leave = LeaveRequest.fromFirestore(doc);
      for (int i = 0; i <= leave.toDate.difference(leave.fromDate).inDays; i++) {
        final date = leave.fromDate.add(Duration(days: i));
        if (date.isAfter(startOfMonth.subtract(const Duration(days: 1))) && date.isBefore(endOfMonth.add(const Duration(days: 1)))) {
           final dateOnly = DateTime.utc(date.year, date.month, date.day);
           eventsMap[dateOnly] = {'type': leave.durationType == LeaveDurationType.fullDay ? "Leave" : "Half-day", 'data': leave};
        }
      }
    }
    
    // MODIFIED: This logic now correctly marks ALL past days as absent, including weekends.
    if (!month.isAfter(today) || (month.year == today.year && month.month == today.month)) {
        DateTime loopEndDate = (month.year == today.year && month.month == today.month) ? today : endOfMonth;
        for (int i = 0; i < loopEndDate.day; i++) {
            final date = DateTime(month.year, month.month, i + 1);
            final dateOnly = DateTime.utc(date.year, date.month, date.day);
            // The check for Saturday and Sunday has been removed.
            if (!eventsMap.containsKey(dateOnly)) {
                eventsMap[dateOnly] = {'type': 'Absent'};
            }
        }
    }

    setState(() {
      _events = eventsMap;
      _isLoadingCalendar = false;
    });
  }
  
  /// Calculates the number of working days between two dates (inclusive).
  int _calculateWorkingDays(DateTime startDate, DateTime endDate) {
    if (endDate.isBefore(startDate)) return 0;
    return endDate.difference(startDate).inDays + 1;
  }

  /// Calculates the number of leave days a user has taken within a given month.
  ///
  /// Considers the leave's start and end dates to determine how many days
  /// fall within the specified month. Handles full-day and half-day leaves.
  ///
  /// - [leave]: The [LeaveRequest] object.
  /// - [startOfMonth]: The first day of the month.
  /// - [endOfMonth]: The last day of the month.
  /// - Returns the number of leave days as a [double].
  double _calculateLeaveDaysInMonth(LeaveRequest leave, DateTime startOfMonth, DateTime endOfMonth) {
    if (leave.durationType != LeaveDurationType.fullDay) {
      if (leave.fromDate.isAfter(startOfMonth.subtract(const Duration(days: 1))) && 
          leave.fromDate.isBefore(endOfMonth.add(const Duration(days: 1)))) {
        return 0.5;
      }
      return 0.0;
    }
    DateTime effectiveStartDate = leave.fromDate.isAfter(startOfMonth) ? leave.fromDate : startOfMonth;
    DateTime effectiveEndDate = leave.toDate.isBefore(endOfMonth) ? leave.toDate : endOfMonth;
    if (effectiveEndDate.isBefore(effectiveStartDate)) {
      return 0.0;
    }
    return _calculateWorkingDays(effectiveStartDate, effectiveEndDate).toDouble();
  }


  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser?>(context);

    if (user == null) {
      return const Scaffold(body: Center(child: Text("User not logged in.")));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Attendance Log"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildAttendanceCalendar(user),
          const SizedBox(height: 16),
          _buildDayDetails(),
          const SizedBox(height: 24),
          _buildTodayStatusCard(context, user),
          const SizedBox(height: 24),
          _buildLastActivityCard(context, user),
          const SizedBox(height: 24),
          _buildMonthlySummaryStream(context, user),
        ],
      ),
    );
  }

  /// Builds the main calendar widget for displaying attendance.
  ///
  /// This widget uses the `table_calendar` package to show a month view.
  /// It highlights days based on their status (Present, Absent, etc.) and
  /// handles page changes and day selections.
  ///
  /// - [user]: The currently logged-in [AppUser].
  /// - Returns a [Card] widget containing the `TableCalendar`.
  Widget _buildAttendanceCalendar(AppUser user) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2020, 1, 1),
              lastDay: DateTime.utc(2030, 12, 31),
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.month,
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = focusedDay;
                });
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                _fetchMonthData(user.uid, focusedDay);
              },
              calendarBuilders: CalendarBuilders(
                defaultBuilder: (context, day, focusedDay) {
                  final dateOnly = DateTime.utc(day.year, day.month, day.day);
                  final event = _events[dateOnly];
                  if (event != null) {
                    return _buildDayCell(day, event['type']);
                  }
                  return null;
                },
                todayBuilder: (context, day, focusedDay) {
                   final dateOnly = DateTime.utc(day.year, day.month, day.day);
                   final event = _events[dateOnly];
                   return _buildDayCell(day, event?['type'] ?? 'Today');
                },
              ),
              headerStyle: const HeaderStyle(
                formatButtonVisible: false,
                titleCentered: true,
              ),
            ),
            if (_isLoadingCalendar) const Padding(
              padding: EdgeInsets.all(8.0),
              child: LinearProgressIndicator(),
            )
          ],
        ),
      ),
    );
  }
  
  /// Builds a single cell for a day in the calendar.
  ///
  /// The cell is styled with a specific color based on the attendance status.
  ///
  /// - [day]: The [DateTime] of the cell.
  /// - [status]: The attendance status for that day (e.g., 'Present', 'Absent').
  /// - Returns a decorated [Container] widget.
  Widget _buildDayCell(DateTime day, String status) {
      Color cellColor;
      Color textColor = Colors.white;

      switch(status) {
        case 'Present':
          cellColor = Colors.green.shade400;
          break;
        case 'Absent':
        case 'Leave':
          cellColor = Colors.red.shade400;
          break;
        case 'Half-day':
          cellColor = Colors.amber.shade600;
          break;
        case 'Today':
          cellColor = Colors.blue.shade200;
          textColor = Colors.black;
          break;
        default:
          cellColor = Colors.transparent;
          textColor = Colors.black;
      }

      return Container(
        margin: const EdgeInsets.all(4.0),
        decoration: BoxDecoration(
          color: cellColor,
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Text(
            '${day.day}',
            style: TextStyle(color: textColor),
          ),
        ),
      );
  }

  /// Builds the details view for the currently selected day.
  ///
  /// Displays information such as check-in/out times for present days,
  /// leave reasons, or an "Absent" message.
  ///
  /// - Returns a [Card] widget with the details.
  Widget _buildDayDetails() {
    if (_selectedDay == null) return const SizedBox.shrink();
    
    final dateOnly = DateTime.utc(_selectedDay!.year, _selectedDay!.month, _selectedDay!.day);
    final event = _events[dateOnly];

    String title = "No Record";
    String subtitle = "No activity recorded for this day.";
    IconData icon = Icons.help_outline;
    Color iconColor = Colors.grey;

    if (event != null) {
      final type = event['type'];
      final data = event['data'];
      
      switch (type) {
        case 'Present':
          title = "Present";
          icon = Icons.check_circle_outline;
          iconColor = Colors.green;
          final checkIn = data['checkIn'] != null ? DateFormat.jm().format((data['checkIn'] as Timestamp).toDate()) : "--:--";
          final checkOut = data['checkOut'] != null ? DateFormat.jm().format((data['checkOut'] as Timestamp).toDate()) : "--:--";
          subtitle = "In: $checkIn  |  Out: $checkOut\nRemark: ${data['remark']}";
          break;
        case 'Absent':
          title = "Absent";
          icon = Icons.cancel_outlined;
          iconColor = Colors.red;
          subtitle = "You were marked absent on this day.";
          break;
        case 'Leave':
          title = "On Leave (Full Day)";
          icon = Icons.beach_access_outlined;
          iconColor = Colors.red;
          subtitle = "Reason: ${data.reason}";
          break;
        case 'Half-day':
          title = "On Leave (Half Day)";
          icon = Icons.wb_sunny_outlined;
          iconColor = Colors.amber;
          subtitle = "Reason: ${data.reason}";
          break;
      }
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: iconColor, size: 40),
        title: Text(
          "${DateFormat('EEEE, d MMMM').format(_selectedDay!)} - $title",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(subtitle, style: const TextStyle(height: 1.5)),
      ),
    );
  }
  
  /// Builds a card that shows the user's attendance status for the current day.
  ///
  /// It streams data from Firestore to show real-time status (e.g., "Present", "Absent")
  /// and provides a button to navigate to the [CheckInOutScreen].
  ///
  /// - [context]: The build context.
  /// - [user]: The currently logged-in [AppUser].
  /// - Returns a [Card] widget.
  Widget _buildTodayStatusCard(BuildContext context, AppUser user) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Today's Status", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .doc('${user.uid}-${DateFormat('yyyy-MM-dd').format(DateTime.now())}')
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                String statusText = "Absent";
                Color statusColor = Colors.red;
                IconData statusIcon = Icons.cancel;
                String? remark;

                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data() as Map<String, dynamic>;
                  final hasCheckedIn = data.containsKey('checkIn') && data['checkIn'] != null;
                  final hasCheckedOut = data.containsKey('checkOut') && data['checkOut'] != null;
                  remark = data['remark'];

                  if (hasCheckedIn && !hasCheckedOut) {
                    statusText = "Present";
                    statusColor = Colors.green;
                    statusIcon = Icons.check_circle;
                  } else if (hasCheckedOut) {
                    statusText = "Completed";
                    statusColor = Colors.grey;
                    statusIcon = Icons.done_all;
                  }
                }
                
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: statusColor),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Status", style: TextStyle(fontWeight: FontWeight.w500)),
                          Row(
                            children: [
                              Text(statusText, style: TextStyle(color: statusColor, fontWeight: FontWeight.bold)),
                              const SizedBox(width: 8),
                              Icon(statusIcon, color: statusColor, size: 20),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (remark != null && remark != "On Time")
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text("Remark: $remark", style: const TextStyle(fontSize: 14, color: Colors.deepOrange, fontWeight: FontWeight.bold)),
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CheckInOutScreen())),
                child: const Text("Mark Attendance"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a card that displays the user's last check-in and check-out times.
  ///
  /// It fetches the most recent attendance record from Firestore.
  ///
  /// - [context]: The build context.
  /// - [user]: The currently logged-in [AppUser].
  /// - Returns a [Card] widget.
  Widget _buildLastActivityCard(BuildContext context, AppUser user) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Last Activity", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('attendance')
                  .where('uid', isEqualTo: user.uid)
                  .orderBy('date', descending: true)
                  .limit(1)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text("No attendance history found."));
                }
                
                final lastRecord = snapshot.data!.docs.first.data() as Map<String, dynamic>;
                final checkInTimestamp = lastRecord['checkIn'] as Timestamp?;
                final checkOutTimestamp = lastRecord['checkOut'] as Timestamp?;

                return Column(
                  children: [
                    _buildActivityRow(
                      icon: Icons.login,
                      label: "Last Check-In",
                      timestamp: checkInTimestamp,
                      color: Colors.green,
                    ),
                    const SizedBox(height: 12),
                    _buildActivityRow(
                      icon: Icons.logout,
                      label: "Last Check-Out",
                      timestamp: checkOutTimestamp,
                      color: Colors.red,
                    ),
                  ],
                );
              },
            )
          ],
        ),
      ),
    );
  }

  /// Builds a single row for displaying an activity (e.g., last check-in).
  ///
  /// - [icon]: The icon to display.
  /// - [label]: The label for the activity.
  /// - [timestamp]: The [Timestamp] of the activity.
  /// - [color]: The color for the icon.
  /// - Returns a [Row] widget.
  Widget _buildActivityRow({required IconData icon, required String label, Timestamp? timestamp, required Color color}) {
    String formattedDate = "Not yet";
    if (timestamp != null) {
      formattedDate = DateFormat('d MMM, hh:mm a').format(timestamp.toDate());
    }

    return Row(
      children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Text("$label:", style: const TextStyle(fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(formattedDate, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// A stream-based widget that builds the monthly summary.
  ///
  /// This widget listens to both attendance and leave collections in Firestore
  /// to calculate and display a summary of the current month's attendance,
  /// including present/absent days, late count, and attendance percentage.
  ///
  /// - [context]: The build context.
  /// - [user]: The currently logged-in [AppUser].
  /// - Returns a widget that builds the summary card.
  Widget _buildMonthlySummaryStream(BuildContext context, AppUser user) {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);
    final totalWorkingDaysInMonth = _calculateWorkingDays(startOfMonth, endOfMonth);
    final workingDaysSoFar = _calculateWorkingDays(startOfMonth, now);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .where('uid', isEqualTo: user.uid)
          .where('date', isGreaterThanOrEqualTo: DateFormat('yyyy-MM-dd').format(startOfMonth))
          .where('date', isLessThanOrEqualTo: DateFormat('yyyy-MM-dd').format(endOfMonth))
          .snapshots(),
      builder: (context, attendanceSnapshot) {
        if (attendanceSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        
        int lateInCount = 0;
        int earlyOutCount = 0;
        if (attendanceSnapshot.hasData) {
          for (var doc in attendanceSnapshot.data!.docs) {
            final data = doc.data() as Map<String, dynamic>;
            final remark = data['remark'] as String?;
            
            if (remark != null) {
              if (remark.contains('Late Comer')) {
                lateInCount++;
              }
              if (remark.contains('Early Check-Out')) {
                earlyOutCount++;
              }
            }
          }
        }
        
        final presentDays = attendanceSnapshot.data?.docs.length ?? 0;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('leaves')
              .where('uid', isEqualTo: user.uid)
              .where('status', isEqualTo: 'approved')
              .where('fromDate', isLessThanOrEqualTo: Timestamp.fromDate(endOfMonth))
              .snapshots(),
          builder: (context, leaveSnapshot) {
            if (leaveSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

            double leaveDaysInMonth = 0;
            if (leaveSnapshot.hasData) {
              for (var doc in leaveSnapshot.data!.docs) {
                final leave = LeaveRequest.fromFirestore(doc);
                leaveDaysInMonth += _calculateLeaveDaysInMonth(leave, startOfMonth, endOfMonth);
              }
            }

            final absentDays = workingDaysSoFar - presentDays - leaveDaysInMonth;
            final percentageBase = workingDaysSoFar - leaveDaysInMonth;
            final attendancePercentage = percentageBase > 0 ? (presentDays / percentageBase * 100).toStringAsFixed(1) : "0.0";

            return _buildMonthlySummaryCard(
              presentDays,
              absentDays < 0 ? 0 : absentDays.round(),
              totalWorkingDaysInMonth,
              attendancePercentage,
              lateInCount,
              earlyOutCount,
            );
          },
        );
      },
    );
  }

  /// Builds the card that displays the calculated monthly summary.
  ///
  /// - [present]: Total present days.
  /// - [absent]: Total absent days.
  /// - [working]: Total working days in the month.
  /// - [percentage]: Attendance percentage string.
  /// - [lateIn]: Count of late check-ins.
  /// - [earlyOut]: Count of early check-outs.
  /// - Returns a [Card] widget with the summary details.
  Widget _buildMonthlySummaryCard(int present, int absent, int working, String percentage, int lateIn, int earlyOut) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Monthly Summary (${DateFormat('MMMM').format(DateTime.now())})", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(present.toString(), "Present", Colors.green),
                _buildSummaryItem(absent.toString(), "Absent", Colors.red),
                _buildSummaryItem(working.toString(), "Working Days", Colors.black87),
              ],
            ),
            const Divider(height: 32),
            _buildRemarkRow("Late In", lateIn),
            const SizedBox(height: 12),
            _buildRemarkRow("Early Out", earlyOut),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.indigo),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Attendance Percentage", style: TextStyle(fontWeight: FontWeight.w500)),
                  Text("$percentage%", style: const TextStyle(color: Colors.indigo, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a row for displaying a remark (e.g., "Late In") and its count.
  Widget _buildRemarkRow(String label, int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 16, color: Colors.black54)),
        Text(count.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      ],
    );
  }

  /// Builds a single item for the summary section (e.g., "Present", "Absent").
  Widget _buildSummaryItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: Colors.grey[600])),
      ],
    );
  }
}