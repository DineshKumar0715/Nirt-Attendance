import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../models/leave_request.dart';

/// A screen where employees can apply for leave and view the status of their past requests.
///
/// This screen provides a form to submit new leave requests with different
/// duration types (full-day, half-day, timed). It also displays a list of
/// previous leave applications with their current status (pending, approved, or rejected).
class LeaveScreen extends StatefulWidget {
  /// Creates a [LeaveScreen].
  const LeaveScreen({super.key});

  @override
  State<LeaveScreen> createState() => _LeaveScreenState();
}

/// The state for the [LeaveScreen].
///
/// Manages the form state for a new leave request, including selected dates,
/// times, and leave type. It handles the submission logic and fetches
/// existing leave data to prevent double booking.
class _LeaveScreenState extends State<LeaveScreen> {
  final _reasonController = TextEditingController();
  String _selectedType = 'Sick Leave';
  DateTime? _fromDate;
  DateTime? _toDate;
  bool _isSubmitting = false;

  LeaveDurationType _durationType = LeaveDurationType.fullDay;
  HalfDayPeriod _halfDayPeriod = HalfDayPeriod.forenoon;
  TimeOfDay? _fromTime;
  TimeOfDay? _toTime;

  Set<DateTime> _existingLeaveDates = {};

  @override
  void initState() {
    super.initState();
    _fetchAndSetLeaveDates();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  /// Fetches the user's existing leave dates from Firestore.
  ///
  /// This method retrieves all pending and approved leave requests for the current
  /// user and populates the `_existingLeaveDates` set. This set is then used
  /// by the date picker to disable dates that have already been applied for.
  Future<void> _fetchAndSetLeaveDates() async {
    final user = Provider.of<AppUser?>(context, listen: false);
    if (user == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('leaves')
        .where('uid', isEqualTo: user.uid)
        .where('status', whereIn: ['pending', 'approved'])
        .get();

    final Set<DateTime> disabledDates = {};
    for (var doc in snapshot.docs) {
      final request = LeaveRequest.fromFirestore(doc);
      for (var day = 0; day <= request.toDate.difference(request.fromDate).inDays; day++) {
        final date = request.fromDate.add(Duration(days: day));
        disabledDates.add(DateTime(date.year, date.month, date.day));
      }
    }

    if (mounted) {
      setState(() {
        _existingLeaveDates = disabledDates;
      });
    }
  }

  /// Opens a date picker dialog to allow the user to select a date.
  ///
  /// The date picker disables dates that are already part of an existing
  /// leave request. It handles logic for selecting 'from' and 'to' dates.
  ///
  /// - [context]: The build context.
  /// - [isFromDate]: A boolean indicating if the 'from' date is being picked.
  Future<void> _pickDate(BuildContext context, bool isFromDate) async {
    final now = DateTime.now();
    
    // MODIFIED: This rule now only checks if a leave has already been applied for a date.
    bool isSelectable(DateTime day) {
      final cleanDay = DateTime(day.year, day.month, day.day);
      return !_existingLeaveDates.contains(cleanDay);
    }

    DateTime initialDate = isFromDate ? (_fromDate ?? now) : (_toDate ?? _fromDate ?? now);
    final DateTime firstDate = isFromDate ? now : _fromDate ?? now;
    
    // This logic finds the next available date if the initial date is not selectable
    while (!isSelectable(initialDate)) {
      initialDate = initialDate.add(const Duration(days: 1));
    }
    
    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
      while (!isSelectable(initialDate)) {
        initialDate = initialDate.add(const Duration(days: 1));
      }
    }

    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: DateTime(now.year + 1),
      selectableDayPredicate: isSelectable,
    );
    
    if (picked != null) {
      setState(() {
        if (isFromDate) {
          _fromDate = picked;
          if (_durationType != LeaveDurationType.fullDay) {
            _toDate = picked;
          }
          if (_toDate != null && _toDate!.isBefore(_fromDate!)) {
            _toDate = null;
          }
        } else {
          _toDate = picked;
        }
      });
    }
  }

  /// Opens a time picker dialog for selecting a time for timed leave.
  ///
  /// - [context]: The build context.
  /// - [isFromTime]: A boolean indicating if the 'from' time is being picked.
  Future<void> _pickTime(BuildContext context, bool isFromTime) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFromTime) {
          _fromTime = picked;
        } else {
          _toTime = picked;
        }
      });
    }
  }

  /// Validates the form and submits the leave request to Firestore.
  ///
  /// This method performs several checks:
  /// 1. Ensures all required fields are filled.
  /// 2. Checks if the new leave request exceeds the user's annual leave limit.
  /// 3. Calls the [FirestoreService] to save the leave request.
  /// 4. Clears the form and shows a confirmation message upon success.
  void _submitLeaveRequest() async {
    final user = Provider.of<AppUser?>(context, listen: false);

    bool isReasonMissing = _selectedType == 'Others' && _reasonController.text.trim().isEmpty;
    bool isDateMissing = _fromDate == null || (_durationType == LeaveDurationType.fullDay && _toDate == null);
    bool isTimeMissing = _durationType == LeaveDurationType.timed && (_fromTime == null || _toTime == null);

    if (user == null || isDateMissing || isTimeMissing || isReasonMissing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all required fields.")));
      return;
    }
    
    final finalToDate = _durationType == LeaveDurationType.fullDay ? _toDate! : _fromDate!;
    setState(() => _isSubmitting = true);

    final firestoreService = FirestoreService();
    final daysTaken = await firestoreService.getApprovedLeaveDays(user.uid);
    double newLeaveDuration = (_durationType == LeaveDurationType.fullDay) ? finalToDate.difference(_fromDate!).inDays + 1 : 0.5;

    if (daysTaken + newLeaveDuration > 15) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Leave limit exceeded. You have ${15 - daysTaken} days remaining this year.'),
        backgroundColor: Colors.red,
      ));
      setState(() => _isSubmitting = false);
      return;
    }

    await firestoreService.applyLeave(
      user: user,
      type: _selectedType,
      reason: _reasonController.text.trim(),
      fromDate: _fromDate!,
      toDate: finalToDate,
      durationType: _durationType,
      fromTime: _fromTime?.format(context),
      toTime: _toTime?.format(context),
      halfDayPeriod: _durationType == LeaveDurationType.halfDay ? _halfDayPeriod : null,
    );

    await _fetchAndSetLeaveDates(); 

    _reasonController.clear();
    setState(() {
      _fromDate = null;
      _toDate = null;
      _fromTime = null;
      _toTime = null;
      _isSubmitting = false;
      _durationType = LeaveDurationType.fullDay;
      _halfDayPeriod = HalfDayPeriod.forenoon;
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Leave request submitted.")));
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser?>(context);
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildRequestCard(context),
          const SizedBox(height: 24),
          _buildStatusCard(context, user),
        ],
      ),
    );
  }

  /// Builds the main card containing the form for a new leave request.
  ///
  /// - [context]: The build context.
  /// - Returns a [Card] widget with the leave request form.
  Widget _buildRequestCard(BuildContext context) {
    bool reasonIsRequired = _selectedType == 'Others';

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("New Leave Request", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              items: ['Sick Leave', 'Personal Leave', 'Weekly Off', 'Others']
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (value) => setState(() => _selectedType = value!),
              decoration: const InputDecoration(labelText: "Leave Type", border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            SegmentedButton<LeaveDurationType>(
              segments: const [
                ButtonSegment(value: LeaveDurationType.fullDay, label: Text('Full Day')),
                ButtonSegment(value: LeaveDurationType.halfDay, label: Text('Half Day')),
                ButtonSegment(value: LeaveDurationType.timed, label: Text('Timed')),
              ],
              selected: {_durationType},
              onSelectionChanged: (Set<LeaveDurationType> newSelection) {
                setState(() {
                  _durationType = newSelection.first;
                  _fromDate = null;
                  _toDate = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_durationType == LeaveDurationType.halfDay)
              _buildHalfDaySelector(),
              
            _buildDatePickers(),

            if (_durationType == LeaveDurationType.timed) ...[
              const SizedBox(height: 16),
              _buildTimePickers(),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              maxLines: 3,
              decoration: InputDecoration(
                labelText: reasonIsRequired ? "Reason (Required)" : "Reason / Comments (Optional)",
                border: const OutlineInputBorder()
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: _isSubmitting
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton(
                      onPressed: _submitLeaveRequest,
                      child: const Text("Apply for Leave"),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the segmented button for selecting the half-day period (forenoon/afternoon).
  ///
  /// This widget is only shown when the `_durationType` is `halfDay`.
  Widget _buildHalfDaySelector() {
    return Column(
      children: [
        SegmentedButton<HalfDayPeriod>(
          segments: const [
            ButtonSegment(value: HalfDayPeriod.forenoon, label: Text('Forenoon')),
            ButtonSegment(value: HalfDayPeriod.afternoon, label: Text('Afternoon')),
          ],
          selected: {_halfDayPeriod},
          onSelectionChanged: (newSelection) {
            setState(() {
              _halfDayPeriod = newSelection.first;
            });
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  /// Builds the date picker buttons.
  ///
  /// It conditionally renders either a single date picker (for half-day/timed leave)
  /// or a date range picker (for full-day leave).
  Widget _buildDatePickers() {
    if (_durationType == LeaveDurationType.fullDay) {
      return Row(children: [
        Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.calendar_today, size: 18), label: Text(_fromDate == null ? 'From Date' : DateFormat.yMMMd().format(_fromDate!)), onPressed: () => _pickDate(context, true))),
        const SizedBox(width: 16),
        Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.calendar_today, size: 18), label: Text(_toDate == null ? 'To Date' : DateFormat.yMMMd().format(_toDate!)), onPressed: _fromDate == null ? null : () => _pickDate(context, false))),
      ]);
    } else {
      return OutlinedButton.icon(icon: const Icon(Icons.calendar_today, size: 18), label: Text(_fromDate == null ? 'Select Date' : DateFormat.yMMMd().format(_fromDate!)), onPressed: () => _pickDate(context, true));
    }
  }

  /// Builds the time picker buttons for timed leave.
  ///
  /// This widget is only shown when the `_durationType` is `timed`.
  Widget _buildTimePickers() {
    return Row(children: [
      Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.access_time, size: 18), label: Text(_fromTime == null ? 'From Time' : _fromTime!.format(context)), onPressed: () => _pickTime(context, true))),
      const SizedBox(width: 16),
      Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.access_time, size: 18), label: Text(_toTime == null ? 'To Time' : _toTime!.format(context)), onPressed: () => _pickTime(context, false))),
    ]);
  }
  
  /// Builds the card that displays the status of past leave applications.
  ///
  /// It uses a [StreamBuilder] to listen for real-time updates to the user's
  /// leave requests in Firestore and displays them in a list.
  ///
  /// - [context]: The build context.
  /// - [user]: The currently logged-in [AppUser].
  /// - Returns a [Card] widget containing the status list.
  Widget _buildStatusCard(BuildContext context, AppUser? user) {
    if (user == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("Could not load user data."),
        ),
      );
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Leave Application Status",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300, // Give the list a fixed height
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('leaves')
                    .where('uid', isEqualTo: user.uid)
                    .orderBy('timestamp', descending: true)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text("An error occurred."));
                  }
                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return const Center(
                      child: Text("You have no leave requests."),
                    );
                  }

                  final leaveDocs = snapshot.data!.docs;
                  return ListView.builder(
                    itemCount: leaveDocs.length,
                    itemBuilder: (context, index) {
                      final leaveRequest = LeaveRequest.fromFirestore(leaveDocs[index]);
                      return _buildLeaveStatusItem(
                        leaveRequest.type,
                        leaveRequest.fromDate,
                        leaveRequest.toDate,
                        leaveRequest.status,
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a single list item to display the details of a leave request.
  ///
  /// - [title]: The type of leave.
  /// - [fromDate]: The start date of the leave.
  /// - [toDate]: The end date of the leave.
  /// - [status]: The current status of the request ('pending', 'approved', 'rejected').
  /// - Returns a [Card] widget representing the list item.
  Widget _buildLeaveStatusItem(String title, DateTime fromDate, DateTime toDate, String status) {
    Map<String, dynamic> getStatusInfo(String status) {
      switch (status.toLowerCase()) {
        case 'approved':
          return {'color': Colors.green, 'icon': Icons.check_circle};
        case 'rejected':
          return {'color': Colors.red, 'icon': Icons.cancel};
        default: // 'pending'
          return {'color': Colors.orange, 'icon': Icons.hourglass_empty};
      }
    }

    final statusInfo = getStatusInfo(status);
    final isSameDay = fromDate.year == toDate.year &&
                        fromDate.month == toDate.month &&
                        fromDate.day == toDate.day;
    final dateDisplay = isSameDay 
        ? DateFormat.yMMMd().format(fromDate)
        : '${DateFormat.MMMd().format(fromDate)} - ${DateFormat.yMMMd().format(toDate)}';


    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: ListTile(
        leading: Icon(statusInfo['icon'], color: statusInfo['color']),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(dateDisplay),
        trailing: Chip(
          label: Text(
            status.toUpperCase(),
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          backgroundColor: statusInfo['color'],
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
      ),
    );
  }
}