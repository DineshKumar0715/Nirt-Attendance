import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import '../../models/leave_request.dart';

/// A home screen dashboard specifically designed for managers.
///
/// This screen provides a high-level overview of key managerial responsibilities,
/// including the total size of their team and the number of pending leave
/// requests that require their attention.
class ManagerHomeScreen extends StatelessWidget {
  /// Creates a [ManagerHomeScreen].
  const ManagerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser?>(context);
    final firestoreService = Provider.of<FirestoreService>(context);

    if (user == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildWelcomeHeader(user),
          const SizedBox(height: 24),
          // MODIFIED: This card now fetches direct reports to show team size
          _buildTeamStatsCard(context, user.uid, firestoreService),
          const SizedBox(height: 16),
          // MODIFIED: This card now fetches leave requests for the manager's team
          _buildLeaveRequestsCard(context, user.uid, firestoreService),
        ],
      ),
    );
  }

  /// Builds the header widget that displays a welcome message.
  ///
  /// This includes the manager's name and their designation.
  ///
  /// - [user]: The currently logged-in manager as an [AppUser].
  /// - Returns a [Column] widget with the header text.
  Widget _buildWelcomeHeader(AppUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome,',
          style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
        ),
        Text(
          user.name ?? 'Manager',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        Text(
          // MODIFIED: Display the manager's designation
          user.designation ?? 'Manager Role',
          style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  /// Builds a card displaying the manager's team size.
  ///
  /// It uses a [StreamBuilder] to get the real-time count of direct reports.
  ///
  /// - [context]: The build context.
  /// - [managerUid]: The unique ID of the manager.
  /// - [service]: An instance of [FirestoreService].
  /// - Returns a [StreamBuilder] wrapping a [Card] widget.
  Widget _buildTeamStatsCard(BuildContext context, String managerUid, FirestoreService service) {
    // MODIFIED: Uses the new getDirectReports method
    return StreamBuilder<List<AppUser>>(
      stream: service.getDirectReports(managerUid),
      builder: (context, snapshot) {
        int teamSize = 0;
        if (snapshot.hasData) {
          teamSize = snapshot.data!.length;
        }
        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Icon(Icons.group, size: 40, color: Colors.indigo),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your Team Size',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    snapshot.connectionState == ConnectionState.waiting
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3))
                        : Text(
                            '$teamSize Members',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Builds a card displaying the number of pending leave approvals.
  ///
  /// It uses a [StreamBuilder] to get the real-time count of pending leave
  /// requests from the manager's team. The card's color changes if there are
  /// pending requests to draw attention.
  ///
  /// - [context]: The build context.
  /// - [managerUid]: The unique ID of the manager.
  /// - [service]: An instance of [FirestoreService].
  /// - Returns a [StreamBuilder] wrapping a [Card] widget.
  Widget _buildLeaveRequestsCard(BuildContext context, String managerUid, FirestoreService service) {
    // MODIFIED: Uses the new getLeaveRequestsForManager method
    return StreamBuilder<List<LeaveRequest>>(
      stream: service.getLeaveRequestsForManager(managerUid),
      builder: (context, snapshot) {
        int pendingRequests = 0;
        if (snapshot.hasData) {
          pendingRequests = snapshot.data!.length;
        }
        return Card(
          elevation: 2,
          color: pendingRequests > 0 ? Colors.orange.shade50 : Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(Icons.checklist, size: 40, color: Colors.orange.shade800),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pending Approvals',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                    snapshot.connectionState == ConnectionState.waiting
                        ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3))
                        : Text(
                            '$pendingRequests Requests',
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}