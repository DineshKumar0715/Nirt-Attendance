import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// A service to handle local notifications.
///
/// This class is responsible for initializing the local notifications plugin,
/// displaying incoming notifications, and scheduling recurring notifications.
class LocalNotificationService {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  /// Initializes the local notifications plugin for Android and iOS.
  ///
  /// This method sets up the necessary settings and initializes the plugin.
  /// It also initializes the timezone database required for scheduling.
  Future<void> init() async {
    // Initialization settings for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // Initialization settings for iOS
    const DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings();

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
    
    // Initialize timezone database
    tz.initializeTimeZones();
  }

  /// Shows a notification that has just been received via FCM.
  ///
  /// This method constructs and displays a local notification based on the
  /// content of a [RemoteMessage]. It does nothing if the message does not
  /// contain a notification payload.
  ///
  /// - [message]: The [RemoteMessage] received from FCM.
  Future<void> showNotification(RemoteMessage message) async {
    // Do nothing if the message doesn't contain a notification payload.
    if (message.notification == null) return;

    // Define the notification details for Android
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'high_importance_channel', // Must match the channel ID in AndroidManifest.xml
      'High Importance Notifications',
      channelDescription: 'This channel is used for important notifications like leave requests.',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    // Show the notification
    await flutterLocalNotificationsPlugin.show(
      message.hashCode, // Use a unique ID for each notification
      message.notification!.title,
      message.notification!.body,
      notificationDetails,
    );
  }

  /// Schedules a daily notification to remind the user to check in.
  ///
  /// This method schedules a recurring daily notification that fires at 9:00 AM
  /// to remind the user to mark their attendance.
  Future<void> scheduleDailyCheckInReminder() async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'checkin_reminder_channel',
      'Check-In Reminders',
      channelDescription: 'Daily reminders to mark attendance',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails notificationDetails = NotificationDetails(android: androidDetails);

    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'Good Morning!',
      'It\'s time to check in for the day. Please mark your attendance.',
      _nextInstanceOf9AM(), // Changed to 9:00 AM for the reminder
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time, // Repeat daily at the same time
    );
     print("Daily check-in reminder scheduled for 9:00 AM.");
  }

  /// Calculates the next instance of 9:00 AM from the current time.
  ///
  /// If the current time is already past 9:00 AM today, it returns 9:00 AM tomorrow.
  ///
  /// - Returns a [tz.TZDateTime] object representing the next 9:00 AM.
  tz.TZDateTime _nextInstanceOf9AM() {
    final tz.TZDateTime now = tz.TZDateTime.now(tz.local);
    tz.TZDateTime scheduledDate =
        tz.TZDateTime(tz.local, now.year, now.month, now.day, 9, 0);
    if (scheduledDate.isBefore(now)) {
      scheduledDate = scheduledDate.add(const Duration(days: 1));
    }
    return scheduledDate;
  }
}