import 'package:attendence_app/Screens/manager/manager_dashboard.dart';
import 'package:attendence_app/screens/auth/pending_approval_screen.dart';
import 'package:attendence_app/screens/auth/splash_wrapper.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'models/user_model.dart';
import 'services/auth_service.dart';
import 'services/firestore_service.dart';
import 'screens/auth/login_screen.dart';
import 'services/firebase_messaging_service.dart';
import 'screens/employee/main_screen.dart';
import 'screens/hr/hr_bottom_nav_screen.dart';
import 'package:attendence_app/services/local_notification_service.dart'; 
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart'; // Import the generated options file

/// A top-level function to handle background messages from Firebase Cloud Messaging.
///
/// This function is the entry point for handling FCM messages when the app is
/// in the background or terminated. It must be a top-level function and
/// annotated with `@pragma('vm:entry-point')`.
///
/// - [message]: The incoming [RemoteMessage] from FCM.
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

/// The main entry point of the application.
///
/// This function initializes the Flutter app, sets up Firebase, and configures
/// services for handling local and remote notifications.
void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    
    // Initialize Firebase using the generated options file
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // Initialize services for handling notifications
    final localNotificationService = LocalNotificationService();
    await localNotificationService.init();
    
    // Set up the background and foreground message handlers
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      print('Got a message whilst in the foreground!');
      localNotificationService.showNotification(message);
    });

    runApp(const MyApp());

  } catch (e) {
    print('--- FAILED TO INITIALIZE APP ---');
    print(e);
  }
}

/// The root widget of the application.
///
/// This widget sets up the [MultiProvider] to make services like [AuthService]
/// and [FirestoreService] available throughout the widget tree. It also
/// configures the [MaterialApp], setting the theme and the initial screen.
class MyApp extends StatelessWidget {
  /// Creates the [MyApp] widget.
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<FirestoreService>(create: (_) => FirestoreService()),
        Provider<AuthService>(create: (_) => AuthService()),
        Provider<FirebaseMessagingService>(create: (_) => FirebaseMessagingService()),
        StreamProvider<AppUser?>.value(
          value: AuthService().user,
          initialData: null,
        ),
      ],
      child: MaterialApp(
        title: 'Attendance App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(primarySwatch: Colors.indigo),
        home: const SplashWrapper(),
      ),
    );
  }
}

/// A wrapper widget that directs users to the appropriate screen based on their role.
///
/// After a user successfully logs in, this widget determines their role
/// (e.g., admin, HR, manager, employee) and status. It then navigates them
/// to the corresponding dashboard or a pending approval screen.
class RoleBasedWrapper extends StatelessWidget {
  /// Creates a [RoleBasedWrapper].
  const RoleBasedWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<AppUser?>(context);

    if (user == null) {
      return const LoginScreen();
    }
    
    // Save the user's FCM token to the database on login
    final fcmService = Provider.of<FirebaseMessagingService>(context, listen: false);
    fcmService.saveTokenToDatabase(user);

    if (user.status == 'pending') {
      return const PendingApprovalScreen();
    }

    // Direct the user to the correct screen based on their role
    switch (user.role) {
      case UserRole.admin:
        return const MainScreen(); 
      case UserRole.hr:
        return const HRBottomNavScreen();
      case UserRole.manager:
        return const ManagerDashboard();
      case UserRole.employee:
      default:
        return const MainScreen();
    }
  }
}