import 'package:attendence_app/screens/employee/profile_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'home_screen.dart';
import 'leave_screen.dart';
import 'attendance_screen.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:attendence_app/screens/common/notification_screen.dart';
import 'package:geolocator/geolocator.dart';

/// The main container screen for the employee view, hosting the primary pages.
///
/// This screen uses a [PageView] and a [BottomNavigationBar] to allow the
/// user to switch between the [HomeScreen], [LeaveScreen], and [AttendanceScreen].
/// It also handles requesting necessary permissions on startup.
class MainScreen extends StatefulWidget {
  /// Creates a [MainScreen].
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

/// The state for the [MainScreen].
///
/// Manages the [PageController] for the [PageView], the currently selected
/// navigation index, and the logic for handling permission requests.
class _MainScreenState extends State<MainScreen> {
  late PageController _pageController;
  int _selectedIndex = 0;

  /// A list of the main widgets to display in the [PageView].
  List<Widget> get _widgetOptions => <Widget>[
    HomeScreen(pageController: _pageController), // Controller is passed here
    const LeaveScreen(),
    const AttendanceScreen(),
  ];

  /// The titles corresponding to each page in the `_widgetOptions` list.
  static const List<String> _widgetTitles = <String>[
    'Home',
    'Leave Application',
    'Attendance History',
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _requestPermissions();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// Requests necessary app permissions on startup.
  ///
  /// This method requests permissions for notifications and location services.
  /// If a permission is permanently denied, it shows a dialog prompting the
  /// user to open the app settings. It also checks if location services are
  /// enabled on the device.
  Future<void> _requestPermissions() async {
    // Request Notification Permission
    PermissionStatus notificationStatus = await Permission.notification.request();
    if (notificationStatus.isPermanentlyDenied) {
      _showPermissionDialog('Notification Permission', 'To receive reminders, you need to enable notifications in your phone settings.');
    }

    // Request Location Permission
    PermissionStatus locationStatus = await Permission.locationWhenInUse.request();
    if (locationStatus.isPermanentlyDenied) {
      _showPermissionDialog('Location Permission', 'To use attendance features, you need to enable location services in your phone settings.');
    }

    // Check if the device's location service is turned on.
    bool isLocationServiceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!isLocationServiceEnabled && mounted) {
      _showEnableLocationDialog();
    }
  }

  /// Shows a dialog prompting the user to enable device location services.
  void _showEnableLocationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Enable Location Services'),
        content: const Text('To mark attendance, please enable location services on your device.'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Open Settings'),
            onPressed: () {
              Geolocator.openLocationSettings();
              Navigator.of(context).pop();
            },
          ),
        ],
      ),
    );
  }

  /// Shows a dialog for permanently denied permissions.
  ///
  /// This dialog informs the user why the permission is needed and provides a
  /// button to open the app's settings.
  ///
  /// - [title]: The title of the dialog.
  /// - [content]: The explanatory message for the dialog.
  void _showPermissionDialog(String title, String content) {
    if (mounted) {
      showDialog(
        context: context,
        builder: (BuildContext context) => AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              child: const Text('Open Settings'),
              onPressed: () {
                openAppSettings();
                Navigator.of(context).pop();
              },
            ),
          ],
        ),
      );
    }
  }

  /// Handles taps on the bottom navigation bar items.
  ///
  /// It updates the selected index and animates the [PageView] to the
  /// corresponding page.
  ///
  /// - [index]: The index of the tapped item.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context, listen: false);
    final user = Provider.of<AppUser?>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_widgetTitles[_selectedIndex]),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NotificationScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            onSelected: (value) async {
              if (value == 'profile') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileScreen()),
                );
              } else if (value == 'logout') {
                await authService.signOut();
              }
            },
            itemBuilder: (BuildContext context) {
              return [
                PopupMenuItem<String>(
                  value: 'profile',
                  child: ListTile(
                    leading: const Icon(Icons.person_outline),
                    title: Text(user?.name ?? 'Profile'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: ListTile(
                    leading: Icon(Icons.logout),
                    title: Text('Logout'),
                  ),
                ),
              ];
            },
            icon: const Icon(Icons.person_pin),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _widgetOptions,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_today),
            label: 'Leave',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.access_time_filled),
            label: 'Attendance',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo,
        type: BottomNavigationBarType.fixed, 
        onTap: _onItemTapped,
      ),
    );
  }
}