import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';
import 'hr_team_members_screen.dart';

/// A screen that displays a list of all managers and HR personnel in the company.
///
/// This screen allows an HR user to get an overview of the team leads. Tapping on
/// any manager's name navigates to the [HRTeamMembersScreen] to view their
/// direct reports.
class HRTeamViewScreen extends StatelessWidget {
  /// Creates an [HRTeamViewScreen].
  const HRTeamViewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // MODIFIED: Get FirestoreService from Provider for consistency
    final firestoreService = Provider.of<FirestoreService>(context);

    // MODIFIED: Changed from FutureBuilder<List<String>> to StreamBuilder<List<AppUser>>
    return StreamBuilder<List<AppUser>>(
      stream: firestoreService.getAllManagers(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text("No managers found."));
        }

        // MODIFIED: The data is now a list of AppUser objects (managers)
        final managers = snapshot.data!;

        return ListView.builder(
          itemCount: managers.length,
          itemBuilder: (context, index) {
            final manager = managers[index];
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: ListTile(
                leading: const Icon(Icons.person_pin_rounded),
                // MODIFIED: Display manager's name and designation
                title: Text(manager.name ?? 'No Name'),
                subtitle: Text(manager.designation ?? 'Manager'),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      // MODIFIED: Pass the entire manager object to the next screen
                      builder: (_) => HRTeamMembersScreen(manager: manager),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}