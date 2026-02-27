import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/firestore_service.dart';

/// A screen that displays the profile information of the currently logged-in user.
///
/// This screen shows the user's work details, contact information, and reporting
/// manager. It fetches data from the [AppUser] object available in the provider
/// and retrieves manager details from [FirestoreService].
class ProfileScreen extends StatelessWidget {
  /// Creates a [ProfileScreen].
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser?>(context);
    final firestoreService = Provider.of<FirestoreService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text("My Profile")),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                _buildProfileHeader(user),
                const SizedBox(height: 20),
                const Text("Work Details", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                const Divider(),
                _buildProfileInfoCard(
                    "Designation", user.designation ?? 'N/A', Icons.work_outline),
                _buildProfileInfoCard(
                    "Department", user.department ?? 'N/A', Icons.business_outlined),
                _buildProfileInfoCard(
                    "Work Location", user.workLocation ?? 'N/A', Icons.location_on_outlined),
                _buildReportsToCard(firestoreService, user.reportsTo),
                const SizedBox(height: 20),
                const Text("Contact Information", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey)),
                const Divider(),
                _buildProfileInfoCard(
                    "Phone", user.phone ?? 'N/A', Icons.phone_outlined),
              ],
            ),
    );
  }

  /// Builds the header section of the profile screen.
  ///
  /// This widget displays the user's avatar (as the first letter of their name)
  /// and their full name.
  ///
  /// - [user]: The [AppUser] object for the current user.
  /// - Returns a [Center] widget containing the header elements.
  Widget _buildProfileHeader(AppUser user) {
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 40,
            child: Text(
              user.name?.isNotEmpty == true ? user.name![0].toUpperCase() : '?',
              style: const TextStyle(fontSize: 32),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            user.name ?? 'No Name',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  /// Builds a card to display the user's reporting manager.
  ///
  /// It fetches the manager's name asynchronously from Firestore using the
  /// manager's ID. It shows a loading state while fetching.
  ///
  /// - [service]: An instance of [FirestoreService].
  /// - [managerId]: The unique ID of the reporting manager.
  /// - Returns a widget that displays the manager's name.
  Widget _buildReportsToCard(FirestoreService service, String? managerId) {
    if (managerId == null || managerId == 'nil') {
      return _buildProfileInfoCard("Reports To", "Top Level", Icons.supervisor_account_outlined);
    }

    return FutureBuilder<AppUser?>(
      future: service.getUserById(managerId),
      builder: (context, snapshot) {
        String managerName = 'Loading...';
        if (snapshot.connectionState == ConnectionState.done) {
           managerName = snapshot.hasData ? snapshot.data!.name ?? 'Unknown' : 'Not Found';
        }
        return _buildProfileInfoCard("Reports To", managerName, Icons.supervisor_account_outlined);
      },
    );
  }

  /// A helper widget to create a consistent information card with a title, subtitle, and icon.
  ///
  /// - [title]: The title of the information (e.g., "Designation").
  /// - [subtitle]: The value of the information (e.g., "Software Engineer").
  /// - [icon]: The icon to display on the card.
  /// - Returns a styled [Card] widget.
  Widget _buildProfileInfoCard(String title, String subtitle, IconData icon) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        leading: Icon(icon, color: Colors.indigo),
        title: Text(title, style: TextStyle(color: Colors.grey.shade600)),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
        ),
      ),
    );
  }
}