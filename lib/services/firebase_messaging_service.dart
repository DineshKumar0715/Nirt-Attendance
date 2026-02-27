import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import 'package:firebase_core/firebase_core.dart'; // Make sure this import is at the top
import 'package:firebase_messaging/firebase_messaging.dart';
 // Ensure this path is correct

/// A top-level function to handle background messages from Firebase Cloud Messaging.
///
/// This function is the entry point for handling FCM messages when the app is
/// in the background or terminated. It must be a top-level function and
/// annotated with `@pragma('vm:entry-point')`.
///
/// - [message]: The incoming [RemoteMessage] from FCM.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // If you're going to use other Firebase services in the background, like Firestore,
  // make sure you call `initializeApp` before using them.
await Firebase.initializeApp(); // You might need this if you do more here
  print("Handling a background message: ${message.messageId}");
}

/// A service to handle Firebase Cloud Messaging (FCM) functionalities.
///
/// This class is responsible for initializing notifications, requesting permissions,
/// handling incoming messages, and managing FCM tokens.
class FirebaseMessagingService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  /// Initializes notification settings and message handlers.
  ///
  /// This method requests notification permissions from the user and sets up
  /// handlers for background and foreground messages.
  Future<void> initNotifications() async {
    // Request permission from the user
    await _firebaseMessaging.requestPermission();

    // Set up handlers for when a message is received
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      print('Message data: ${message.data}');

      if (message.notification != null) {
        print('Message also contained a notification: ${message.notification}');
        // Here you could show an in-app dialog or snackbar if you want
      }
    });
  }

  /// Retrieves the FCM device token and saves it to the user's document in Firestore.
  ///
  /// If a token is successfully retrieved, it is updated in the 'users'
  /// collection for the given user.
  ///
  /// - [user]: The [AppUser] for whom the token should be saved.
  Future<void> saveTokenToDatabase(AppUser user) async {
    String? token = await _firebaseMessaging.getToken();
    if (token != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'fcmToken': token});
      print('FCM Token saved to database.');
    }
  }
}