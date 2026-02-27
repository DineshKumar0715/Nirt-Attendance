import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../common/notification_screen.dart';
import '../employee/home_screen.dart';
import '../employee/profile_screen.dart';
import 'hr_dashboard_screen.dart';
import 'hr_team_view_screen.dart';

/// The main container screen for the HR view, with bottom navigation.
///
/// This screen uses a [PageView] and a [BottomNavigationBar] to allow an HR user
/// to switch between their personal home screen ([HomeScreen]), the leave management
/// dashboard ([HRDashboardScreen]), and the company team view ([HRTeamViewScreen]).
class HRBottomNavScreen extends StatefulWidget {
  /// Creates an [HRBottomNavScreen].
  const HRBottomNavScreen({super.key});

  @override
  State<HRBottomNavScreen> createState() => _HRBottomNavScreenState();
}

/// The state for the [HRBottomNavScreen].
///
/// Manages the [PageController] for the [PageView] and the currently selected
/// navigation index to keep the UI in sync.
class _HRBottomNavScreenState extends State<HRBottomNavScreen> {
  late PageController _pageController;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  /// A list of the main widgets to display in the [PageView].
  List<Widget> get _widgetOptions => <Widget>[
    HomeScreen(
      pageController: _pageController,
      leaveScreenIndex: 1, // The HRDashboardScreen is at index 1
      attendanceScreenIndex: 2, // The HRTeamViewScreen is at index 2
    ),
    const HRDashboardScreen(),
    const HRTeamViewScreen(),
  ];

  /// The titles corresponding to each page in the `_widgetOptions` list.
  static const List<String> _widgetTitles = <String>[
    'My Home',
    'Leave Management',
    'Company Teams',
  ];

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
      // MODIFIED: Body now uses a PageView for smooth transitions
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
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'My Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.checklist_rtl_outlined),
            activeIcon: Icon(Icons.checklist_rtl),
            label: 'Leave Requests',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.corporate_fare_outlined),
            activeIcon: Icon(Icons.corporate_fare),
            label: 'Teams',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}