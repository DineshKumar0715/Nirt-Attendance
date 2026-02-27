import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

/// A screen that displays the list of team members reporting to a specific manager.
///
/// This screen is used within the HR view to drill down into a manager's team.
/// It shows a real-time list of team members and their current day's attendance status.
class HRTeamMembersScreen extends StatelessWidget {
  /// The manager whose team members are to be displayed.
  final AppUser manager;

  /// Creates an [HRTeamMembersScreen].
  ///
  /// - [manager]: The [AppUser] object representing the manager.
  const HRTeamMembersScreen({super.key, required this.manager});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<FirestoreService>();

    return Scaffold(
      appBar: AppBar(
        // MODIFIED: AppBar title now uses the manager's name
        title: Text("${manager.name}'s Team"),
        elevation: 1,
      ),
      body: StreamBuilder<List<AppUser>>(
        // MODIFIED: Stream now calls getDirectReports using the manager's UID
        stream: firestoreService.getDirectReports(manager.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("This manager has no direct reports."));
          }
          final members = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0),
            itemCount: members.length,
            itemBuilder: (context, index) {
              return _buildMemberCard(context, members[index]);
            },
          );
        },
      ),
    );
  }

  /// Builds a card widget to display information about a single team member.
  ///
  /// This card shows the member's name, their avatar, and a real-time status
  /// of their attendance for the current day (e.g., Present, Absent, Completed).
  ///
  /// - [context]: The build context.
  /// - [member]: The [AppUser] object for the team member.
  /// - Returns a [StreamBuilder] wrapping a [Card] widget.
  Widget _buildMemberCard(BuildContext context, AppUser member) {
    final todayDocId = '${member.uid}-${DateFormat('yyyy-MM-dd').format(DateTime.now())}';

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('attendance').doc(todayDocId).snapshots(),
      builder: (context, snapshot) {
        
        String status = "Absent";
        String timeInfo = "Not checked in";
        Color statusColor = Colors.red.shade400;

        if (snapshot.connectionState == ConnectionState.active && snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final hasCheckedIn = data['checkIn'] != null;
          final hasCheckedOut = data['checkOut'] != null;

          if (hasCheckedIn && hasCheckedOut) {
            status = "Completed";
            statusColor = Colors.grey.shade600;
            final checkInTime = DateFormat.jm().format((data['checkIn'] as Timestamp).toDate());
            final checkOutTime = DateFormat.jm().format((data['checkOut'] as Timestamp).toDate());
            timeInfo = "In: $checkInTime | Out: $checkOutTime";
          } else if (hasCheckedIn) {
            status = "Present";
            statusColor = Colors.green.shade600;
            final checkInTime = DateFormat.jm().format((data['checkIn'] as Timestamp).toDate());
            timeInfo = "Checked In: $checkInTime";
          }
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Theme.of(context).primaryColorLight,
              child: Text(
                member.name?.isNotEmpty == true ? member.name![0].toUpperCase() : '?',
                style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).primaryColorDark),
              ),
            ),
            title: Text(member.name ?? 'No Name', style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(timeInfo),
            trailing: Chip(
              label: Text(status, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              backgroundColor: statusColor,
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }
}