import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';
import '../employee/main_screen.dart';
import 'hr_dashboard_screen.dart';

/// A top-level dashboard for HR users, providing a switch between their personal
/// employee view and the HR management tools.
///
/// This widget uses a [BottomNavigationBar] to toggle between the standard
/// [MainScreen] (for personal attendance, leave, etc.) and the [HRDashboardScreen]
/// (for managing company-wide leave requests).
class HRMainDashboard extends StatefulWidget {
  /// Creates an [HRMainDashboard].
  const HRMainDashboard({super.key});

  @override
  State<HRMainDashboard> createState() => _HRMainDashboardState();
}

/// The state for the [HRMainDashboard].
///
/// Manages the selected index for the bottom navigation and builds the
/// appropriate view.
class _HRMainDashboardState extends State<HRMainDashboard> {
  int _selectedIndex = 0;

  /// The list of widgets to display based on the selected navigation item.
  static const List<Widget> _widgetOptions = <Widget>[
    MainScreen(), // The HR user's personal employee view
    HRDashboardScreen(), // The HR management tools
  ];

  /// Handles taps on the bottom navigation bar items, updating the selected index.
  ///
  /// - [index]: The index of the tapped item.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // The MainScreen for employees has its own Scaffold, so we return it directly.
    if (_selectedIndex == 0) {
      return const MainScreen();
    }

    // For the HR Tools, we wrap it in our own Scaffold to provide a consistent AppBar.
    final authService = Provider.of<AuthService>(context, listen: false);
    return Scaffold(
       appBar: AppBar(
        title: const Text("HR Management"),
         actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          )
        ],
      ),
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'My View',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.business_center_outlined),
            activeIcon: Icon(Icons.business_center),
            label: 'HR Tools',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
