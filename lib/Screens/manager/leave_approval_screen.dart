import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/leave_request.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

/// A screen for managers to view and act upon pending leave requests from their direct reports.
///
/// This screen displays a real-time list of leave applications that are awaiting
/// approval. It uses a [StreamProvider] to efficiently fetch and display the data.
class LeaveApprovalScreen extends StatelessWidget {
  /// Creates a [LeaveApprovalScreen].
  const LeaveApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser?>(context);
    // Use Provider to get the FirestoreService instance
    final firestoreService = Provider.of<FirestoreService>(context);

    // MODIFIED: Simplified the user check
    if (user == null) {
      return const Scaffold(body: Center(child: Text("Cannot load user data.")));
    }

    return Scaffold(
      // MODIFIED: Updated the AppBar title to be more generic
      appBar: AppBar(title: const Text("Pending Leave Approvals")),
      body: StreamProvider<List<LeaveRequest>>.value(
        // MODIFIED: Switched to the new method for fetching leave requests
        value: firestoreService.getLeaveRequestsForManager(user.uid),
        initialData: const [],
        child: Consumer<List<LeaveRequest>>(
          builder: (context, leaveRequests, child) {
            if (leaveRequests.isEmpty) {
              return const Center(
                child: Text(
                  "No pending leave requests from your team.",
                  textAlign: TextAlign.center,
                ),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.all(8.0),
              itemCount: leaveRequests.length,
              itemBuilder: (context, index) {
                // Each list item uses your existing detailed, stateful widget
                return LeaveRequestTile(
                  request: leaveRequests[index],
                  firestoreService: firestoreService,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// A tile widget that displays the details of a single leave request for approval.
///
/// This stateful widget shows all the information about a leave request and fetches
/// the employee's current leave balance. It provides "Approve" and "Reject" buttons
/// for the manager to act on the request.
class LeaveRequestTile extends StatefulWidget {
  /// The leave request data to display.
  final LeaveRequest request;
  /// An instance of [FirestoreService] to perform database operations.
  final FirestoreService firestoreService;

  /// Creates a [LeaveRequestTile].
  const LeaveRequestTile({
    super.key,
    required this.request,
    required this.firestoreService,
  });

  @override
  State<LeaveRequestTile> createState() => _LeaveRequestTileState();
}

/// The state for the [LeaveRequestTile].
///
/// Manages fetching the leave balance and building the UI for the tile.
class _LeaveRequestTileState extends State<LeaveRequestTile> {
  double? _approvedLeaveDays;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaveBalance();
  }

  /// Fetches the current leave balance of the employee who made the request.
  Future<void> _fetchLeaveBalance() async {
    final days = await widget.firestoreService.getApprovedLeaveDays(widget.request.uid);
    if (mounted) {
      setState(() {
        _approvedLeaveDays = days;
        _isLoading = false;
      });
    }
  }

  /// Formats the date range for display.
  ///
  /// - [request]: The [LeaveRequest] object.
  /// - Returns a formatted string (e.g., "Jan 5" or "Jan 5 - Jan 7").
  String _formatDateRange(LeaveRequest request) {
    final from = DateFormat.MMMd().format(request.fromDate);
    if (request.durationType == LeaveDurationType.fullDay) {
      if (request.fromDate == request.toDate) return from;
      final to = DateFormat.MMMd().format(request.toDate);
      return '$from - $to';
    }
    return from; // For half-day and timed
  }
  
  /// Formats the time range for display if the leave is timed.
  ///
  /// - [request]: The [LeaveRequest] object.
  /// - Returns a formatted time string or "N/A".
  String _formatTime(LeaveRequest request) {
    if (request.durationType == LeaveDurationType.timed && request.fromTime != null && request.toTime != null) {
      return '${request.fromTime} - ${request.toTime}';
    }
    return 'N/A';
  }


  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.request.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildDetailRow(Icons.calendar_today, 'Date(s):', _formatDateRange(widget.request)),
            _buildDetailRow(Icons.schedule, 'Time:', _formatTime(widget.request)),
            _buildDetailRow(Icons.comment, 'Reason:', widget.request.reason),
            const SizedBox(height: 8),
            _buildLeaveBalance(),
            const Divider(),
            _buildActionButtons(),
          ],
        ),
      ),
    );
  }

  /// Builds a reusable row for displaying a piece of detail information.
  ///
  /// - [icon]: The icon for the detail.
  /// - [label]: The label for the detail.
  /// - [value]: The value of the detail.
  /// - Returns a [Padding] widget containing a [Row].
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Builds the UI component that displays the employee's current leave balance.
  Widget _buildLeaveBalance() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Annual Leaves Taken: ', style: TextStyle(fontSize: 14)),
          if (_isLoading)
            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Text(
              '${_approvedLeaveDays ?? 0} / 15',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
        ],
      ),
    );
  }

  /// Builds the "Approve" and "Reject" action buttons.
  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.close),
          label: const Text('Reject'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => widget.firestoreService.updateLeaveStatus(widget.request.id, 'rejected'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Approve'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () => widget.firestoreService.updateLeaveStatus(widget.request.id, 'approved'),
        ),
      ],
    );
  }
}