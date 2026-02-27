import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../models/user_model.dart';

/// A screen that displays a list of notifications for the current user.
///
/// This screen fetches notifications from a subcollection in the user's
/// Firestore document and displays them in a real-time, scrollable list.
/// It handles loading, error, and empty states.
class NotificationScreen extends StatelessWidget {
  /// Creates a [NotificationScreen].
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser?>(context);

    // If the user is not logged in, show a simple message.
    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Notifications")),
        body: const Center(child: Text("Please log in to see notifications.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      // Use a StreamBuilder to listen for real-time updates to the notifications.
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('notifications')
            .orderBy('timestamp', descending: true) // Show newest first
            .snapshots(),
        builder: (context, snapshot) {
          // Show a loading indicator while data is being fetched.
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          // Show an error message if something goes wrong.
          if (snapshot.hasError) {
            return const Center(child: Text("Error loading notifications."));
          }
          // Show a friendly message if there are no notifications.
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.notifications_off_outlined, size: 80, color: Colors.grey),
                  SizedBox(height: 16),
                  Text("No Notifications Yet", style: TextStyle(fontSize: 18, color: Colors.grey)),
                ],
              ),
            );
          }

          final notifications = snapshot.data!.docs;

          // Build a list of notifications.
          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final notificationData = notifications[index].data() as Map<String, dynamic>;
              final timestamp = (notificationData['timestamp'] as Timestamp?)?.toDate();

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                elevation: 2,
                child: ListTile(
                  leading: const Icon(Icons.notifications, color: Colors.indigo),
                  title: Text(notificationData['title'] ?? 'No Title', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(notificationData['body'] ?? 'No Content'),
                  trailing: Text(
                    timestamp != null ? DateFormat.yMMMd().add_jm().format(timestamp) : '',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
