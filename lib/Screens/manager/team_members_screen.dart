import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

/// A screen for managers to view a list of their direct reports and their
/// current day's attendance status.
///
/// This screen fetches the list of team members who report to the current
/// manager and, for each member, displays their real-time attendance status
/// (e.g., "Present", "Absent").
class TeamMembersScreen extends StatelessWidget {
  /// Creates a [TeamMembersScreen].
  const TeamMembersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser?>(context);
    // Use Provider to get the FirestoreService instance
    final firestoreService = Provider.of<FirestoreService>(context);

    if (user == null) {
      return const Center(child: Text("Could not load user information."));
    }

    // This outer StreamBuilder gets the list of team members.
    return StreamBuilder<List<AppUser>>(
      // MODIFIED: Fetches direct reports instead of team members by name
      stream: firestoreService.getDirectReports(user.uid),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No members report to you."));
        }

        final teamMembers = snapshot.data!;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: teamMembers.length,
          itemBuilder: (context, index) {
            final member = teamMembers[index];
            return _buildMemberCard(context, member);
          },
        );
      },
    );
  }

  /// Builds a card widget to display information about a single team member.
  ///
  /// This card shows the member's name, designation, and a live status chip
  /// indicating their attendance for the current day, which is fetched via a
  /// nested [StreamBuilder].
  ///
  /// - [context]: The build context.
  /// - [member]: The [AppUser] object for the team member.
  /// - Returns a [StreamBuilder] wrapping a [Card] widget.
  Widget _buildMemberCard(BuildContext context, AppUser member) {
    // This inner StreamBuilder gets the real-time attendance status for each team member.
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('attendance')
          .doc('${member.uid}-${DateFormat('yyyy-MM-dd').format(DateTime.now())}')
          .snapshots(),
      builder: (context, snapshot) {
        String status = "Absent";
        String checkInTime = "--:--";
        Color statusColor = Colors.red;

        // Check if the attendance document exists and has a checkIn but no checkOut
        if (snapshot.hasData && snapshot.data!.exists) {
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final hasCheckedIn = data.containsKey('checkIn') && data['checkIn'] != null;
          final hasCheckedOut = data.containsKey('checkOut') && data['checkOut'] != null;

          if (hasCheckedIn && !hasCheckedOut) {
            status = "Present";
            statusColor = Colors.green;
            final checkInTimestamp = data['checkIn'] as Timestamp;
            checkInTime = DateFormat.jm().format(checkInTimestamp.toDate()); // Format to AM/PM
          }
        }

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
          child: ListTile(
            leading: CircleAvatar(
              child: Text(member.name?.isNotEmpty == true ? member.name![0] : '?'),
            ),
            title: Text(member.name ?? 'No Name'),
            // Display the designation for more context
            subtitle: Text(member.designation ?? "Checked In: $checkInTime"),
            trailing: Chip(
              label: Text(
                status,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              backgroundColor: statusColor,
            ),
          ),
        );
      },
    );
  }
}