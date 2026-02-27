import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/leave_request.dart';
import '../../services/firestore_service.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';

/// A dashboard screen for HR personnel to manage leave requests.
///
/// This screen features a tabbed interface to view different categories of
/// leave requests: those from managers, escalated requests from employees,
-/// and a complete history of all leave applications.
class HRDashboardScreen extends StatefulWidget {
  /// Creates an [HRDashboardScreen].
  const HRDashboardScreen({super.key});

  @override
  State<HRDashboardScreen> createState() => _HRDashboardScreenState();
}

/// The state for the [HRDashboardScreen].
///
/// Manages the [TabController] for the tabbed view.
class _HRDashboardScreenState extends State<HRDashboardScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            // MODIFIED: Updated terminology
            Tab(text: "From Managers"),
            Tab(text: "Escalated from Employees"),
            Tab(text: "All Leave History"),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              // MODIFIED: Renamed enum for clarity
              LeaveList(type: LeaveListType.managers),
              LeaveList(type: LeaveListType.escalated),
              LeaveList(type: LeaveListType.all),
            ],
          ),
        ),
      ],
    );
  }
}

/// Defines the categories of leave requests to be displayed on the HR dashboard.
enum LeaveListType {
  /// Leave requests submitted by managers.
  managers,
  /// Leave requests from employees that have been pending for too long.
  escalated,
  /// All leave requests in the system.
  all
}

/// A widget that displays a list of leave requests based on a specific type.
///
/// It uses a [StreamBuilder] to fetch and display a real-time list of
/// leave requests from Firestore.
class LeaveList extends StatelessWidget {
  /// The category of leave requests to display.
  final LeaveListType type;
  /// Creates a [LeaveList].
  const LeaveList({super.key, required this.type});

  /// Returns the appropriate stream of leave requests based on the list type.
  ///
  /// - [service]: An instance of [FirestoreService].
  /// - Returns a [Stream] of a list of [LeaveRequest] objects.
  Stream<List<LeaveRequest>> _getStream(FirestoreService service) {
    switch (type) {
      // MODIFIED: Switched to the new method for manager requests
      case LeaveListType.managers:
        return service.getManagerLeaveRequests();
      case LeaveListType.escalated:
        return service.getEscalatedLeaveRequests();
      case LeaveListType.all:
      default:
        return service.getAllLeaveRequests();
    }
  }

  @override
  Widget build(BuildContext context) {
    // MODIFIED: Get FirestoreService from Provider
    final firestoreService = Provider.of<FirestoreService>(context);
    return StreamBuilder<List<LeaveRequest>>(
      stream: _getStream(firestoreService),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No requests found in this category."));
        }

        final requests = snapshot.data!;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: requests.length,
          itemBuilder: (context, index) {
            final request = requests[index];
            return LeaveHistoryTile(
              request: request,
              // Only show approval buttons for pending requests from managers or escalations
              showActions: request.status == 'pending' && type != LeaveListType.all,
            );
          },
        );
      },
    );
  }
}

/// A tile widget that displays the details of a single leave request.
///
/// This widget is designed to be used in a list. It shows all relevant
/// information about a leave request and can conditionally display action
/// buttons (Approve/Reject) for pending requests.
class LeaveHistoryTile extends StatefulWidget {
  /// The leave request data to display.
  final LeaveRequest request;
  /// A flag to determine whether to show the approval/rejection buttons.
  final bool showActions;

  /// Creates a [LeaveHistoryTile].
  const LeaveHistoryTile({
    super.key,
    required this.request,
    this.showActions = false,
  });

  @override
  State<LeaveHistoryTile> createState() => _LeaveHistoryTileState();
}

/// The state for the [LeaveHistoryTile].
///
/// Manages fetching the leave balance for the employee who made the request.
class _LeaveHistoryTileState extends State<LeaveHistoryTile> {
  double? _approvedLeaveDays;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaveBalance();
  }

  /// Fetches the total number of approved leave days for the employee.
  Future<void> _fetchLeaveBalance() async {
    final firestoreService = context.read<FirestoreService>();
    final days = await firestoreService.getApprovedLeaveDays(widget.request.uid);
    if (mounted) {
      setState(() {
        _approvedLeaveDays = days;
        _isLoading = false;
      });
    }
  }

  /// Formats the display string for the leave dates based on the duration type.
  ///
  /// - [request]: The [LeaveRequest] object.
  /// - Returns a formatted string representing the leave period.
  String _formatLeaveDetails(LeaveRequest request) {
    final from = DateFormat.MMMd().format(request.fromDate);
    
    switch (request.durationType) {
      case LeaveDurationType.fullDay:
        final to = DateFormat.MMMd().format(request.toDate);
        return (from == to) ? from : '$from - $to';
      case LeaveDurationType.halfDay:
        final period = request.halfDayPeriod == HalfDayPeriod.forenoon ? 'Forenoon' : 'Afternoon';
        return '$from ($period)';
      case LeaveDurationType.timed:
        return '$from (${request.fromTime} - ${request.toTime})';
      default:
        return from;
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();
    final request = widget.request;
    
    Color statusColor;
    switch (request.status) {
      case 'approved': statusColor = Colors.green; break;
      case 'rejected': statusColor = Colors.red; break;
      default: statusColor = Colors.orange;
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    request.name,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Chip(
                  label: Text(request.status, style: const TextStyle(color: Colors.white)),
                  backgroundColor: statusColor,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            Text(request.type, style: TextStyle(color: Colors.grey.shade600)),
            const Divider(),
            _buildDetailRow(Icons.calendar_today, 'Dates:', _formatLeaveDetails(request)),
            _buildDetailRow(Icons.comment_outlined, 'Reason:', request.reason.isNotEmpty ? request.reason : 'No reason provided.'),
            const SizedBox(height: 8),
            _buildLeaveBalance(),
            if (widget.showActions) ...[
              const Divider(),
              _buildActionButtons(firestoreService, request.id),
            ]
          ],
        ),
      ),
    );
  }

  /// Builds a single row of detail with an icon, label, and value.
  ///
  /// - [icon]: The icon for the detail row.
  /// - [label]: The label for the detail.
  /// - [value]: The value of the detail.
  /// - Returns a [Padding] widget containing a [Row].
  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// Builds the UI component to display the employee's leave balance.
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
            const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
          else
            Text(
              '${_approvedLeaveDays ?? 0} / 15',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: Colors.blue.shade800,
              ),
            ),
        ],
      ),
    );
  }

  /// Builds the "Approve" and "Reject" buttons for pending leave requests.
  ///
  /// - [service]: An instance of [FirestoreService] to handle the update.
  /// - [requestId]: The ID of the leave request to be updated.
  /// - Returns a [Row] containing the action buttons.
  Widget _buildActionButtons(FirestoreService service, String requestId) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        TextButton.icon(
          icon: const Icon(Icons.close),
          label: const Text('Reject'),
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          onPressed: () => service.updateLeaveStatus(requestId, 'rejected'),
        ),
        const SizedBox(width: 8),
        ElevatedButton.icon(
          icon: const Icon(Icons.check),
          label: const Text('Approve'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
          ),
          onPressed: () => service.updateLeaveStatus(requestId, 'approved'),
        ),
      ],
    );
  }
}